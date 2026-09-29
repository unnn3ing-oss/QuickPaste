# ============================================
# 快速複製小工具（原生視窗版，免安裝，非網頁）
# GUI 邏輯全部用 C# 寫（透過 Add-Type 現場編譯），
# 避免 PowerShell ScriptBlock 事件處理常式在這個
# 執行環境下作用域不穩定導致的資料損毀問題。
# 設定會存在同目錄下的 copy-tool-buttons.json
# ============================================

$scriptDir = $env:COPY_TOOL_DIR
if (-not $scriptDir) { $scriptDir = $PSScriptRoot }
if (-not $scriptDir) { $scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path }
if (-not $scriptDir) { $scriptDir = (Get-Location).Path }
$configPath = Join-Path $scriptDir "copy-tool-buttons.json"

$csharpSource = @'
using System;
using System.Collections.Generic;
using System.Drawing;
using System.Drawing.Drawing2D;
using System.IO;
using System.Linq;
using System.Text;
using System.Windows.Forms;

public class ButtonItem
{
    public string Id;
    public string Label;
    public string Text;
    public string Group;
}

public static class MiniJson
{
    public static List<Dictionary<string, string>> ParseArrayOfStringObjects(string json)
    {
        int i = 0;
        var list = new List<Dictionary<string, string>>();
        SkipWs(json, ref i);
        Expect(json, ref i, '[');
        SkipWs(json, ref i);
        if (Peek(json, i) == ']') { i++; return list; }
        while (true)
        {
            SkipWs(json, ref i);
            Expect(json, ref i, '{');
            var obj = new Dictionary<string, string>();
            SkipWs(json, ref i);
            if (Peek(json, i) == '}')
            {
                i++;
            }
            else
            {
                while (true)
                {
                    SkipWs(json, ref i);
                    string key = ParseString(json, ref i);
                    SkipWs(json, ref i);
                    Expect(json, ref i, ':');
                    SkipWs(json, ref i);
                    string val;
                    if (Peek(json, i) == '"') { val = ParseString(json, ref i); }
                    else { val = ParseRawToken(json, ref i); }
                    obj[key] = val;
                    SkipWs(json, ref i);
                    char c = json[i];
                    if (c == ',') { i++; continue; }
                    if (c == '}') { i++; break; }
                    throw new Exception("JSON 格式錯誤（物件內，位置 " + i + "）");
                }
            }
            list.Add(obj);
            SkipWs(json, ref i);
            char c2 = json[i];
            if (c2 == ',') { i++; continue; }
            if (c2 == ']') { i++; break; }
            throw new Exception("JSON 格式錯誤（陣列內，位置 " + i + "）");
        }
        return list;
    }

    private static char Peek(string s, int i) { return s[i]; }

    private static void Expect(string s, ref int i, char c)
    {
        if (s[i] != c) { throw new Exception("JSON 格式錯誤：預期 '" + c + "'，但在位置 " + i + " 遇到 '" + s[i] + "'"); }
        i++;
    }

    private static void SkipWs(string s, ref int i)
    {
        while (i < s.Length && (s[i] == ' ' || s[i] == '\t' || s[i] == '\r' || s[i] == '\n')) { i++; }
    }

    private static string ParseRawToken(string s, ref int i)
    {
        int start = i;
        while (i < s.Length && s[i] != ',' && s[i] != '}' && s[i] != ']') { i++; }
        return s.Substring(start, i - start).Trim();
    }

    private static string ParseString(string s, ref int i)
    {
        Expect(s, ref i, '"');
        var sb = new StringBuilder();
        while (true)
        {
            char c = s[i];
            if (c == '"') { i++; break; }
            if (c == '\\')
            {
                i++;
                char esc = s[i];
                switch (esc)
                {
                    case '"': sb.Append('"'); break;
                    case '\\': sb.Append('\\'); break;
                    case '/': sb.Append('/'); break;
                    case 'b': sb.Append('\b'); break;
                    case 'f': sb.Append('\f'); break;
                    case 'n': sb.Append('\n'); break;
                    case 'r': sb.Append('\r'); break;
                    case 't': sb.Append('\t'); break;
                    case 'u':
                        string hex = s.Substring(i + 1, 4);
                        int code = Convert.ToInt32(hex, 16);
                        sb.Append((char)code);
                        i += 4;
                        break;
                    default:
                        sb.Append(esc);
                        break;
                }
                i++;
            }
            else
            {
                sb.Append(c);
                i++;
            }
        }
        return sb.ToString();
    }

    public static string Escape(string s)
    {
        if (s == null) { return ""; }
        var sb = new StringBuilder();
        foreach (char c in s)
        {
            switch (c)
            {
                case '"': sb.Append("\\\""); break;
                case '\\': sb.Append("\\\\"); break;
                case '\n': sb.Append("\\n"); break;
                case '\r': sb.Append("\\r"); break;
                case '\t': sb.Append("\\t"); break;
                default:
                    if (c < ' ')
                    {
                        sb.Append("\\u" + ((int)c).ToString("x4"));
                    }
                    else
                    {
                        sb.Append(c);
                    }
                    break;
            }
        }
        return sb.ToString();
    }
}

public class CopyToolForm : Form
{
    private readonly string configPath;
    private List<ButtonItem> items = new List<ButtonItem>();
    private bool editMode = false;

    private Panel topPanel;
    private Panel bottomPanel;
    private Panel contentPanel;
    private Label statusLabel;
    private Button btnEdit;
    private Button btnExport;
    private Button btnImport;
    private Button btnTopMost;
    private Button filterButton;
    private Form activeFilterPopup;
    private readonly HashSet<string> selectedGroups = new HashSet<string>();
    private List<string> groupOrder = new List<string>();
    private System.Windows.Forms.Timer toastTimer;
    private System.Windows.Forms.Timer resizeTimer;

    // 藍色系配色：主色用偏深的鋼藍（不是 Bootstrap/Tailwind 那種
    // 標準飽和藍），背景／邊框也都帶一點冷色調，讓整體看起來是同一家族的藍，
    // 而不是隨便挑一個藍當主色、其他仍是暖色的不協調組合。
    // 刪除／新增維持紅／綠語意色，但同樣往冷色調靠，跟藍色系背景更搭。
    private static readonly Color ColorBg = Color.FromArgb(236, 240, 245);
    private static readonly Color ColorCard = Color.FromArgb(255, 255, 255);
    private static readonly Color ColorAccent = Color.FromArgb(30, 86, 145);
    private static readonly Color ColorAccentHover = Color.FromArgb(20, 66, 115);
    private static readonly Color ColorDanger = Color.FromArgb(176, 60, 70);
    private static readonly Color ColorDangerHover = Color.FromArgb(146, 46, 55);
    private static readonly Color ColorSuccess = Color.FromArgb(56, 122, 105);
    private static readonly Color ColorSuccessHover = Color.FromArgb(42, 98, 84);
    private static readonly Color ColorText = Color.FromArgb(28, 33, 41);
    private static readonly Color ColorMuted = Color.FromArgb(103, 114, 130);
    private static readonly Color ColorBorder = Color.FromArgb(210, 219, 230);
    private static readonly Color ColorBottomBar = Color.FromArgb(219, 227, 237);

    private const int CardRadius = 10;
    private const string AllGroupsOption = "全部粉專";
    private const string UncategorizedOption = "未分類";
    private readonly List<Rectangle> shadowRects = new List<Rectangle>();

    // 選項按鈕的「理想寬度」，可以用下方工具列的 － / ＋ 調整，
    // 高度會跟著同一個比例連動（見 RenderView），所以縮放時形狀不會跑掉。
    private int idealButtonWidth = 120;
    private const int MinButtonWidth = 70;
    private const int MaxButtonWidth = 220;
    private const int ButtonSizeStep = 10;
    private Label buttonSizeLabel;

    public CopyToolForm(string configPath)
    {
        this.configPath = configPath;
        BuildUi();
        LoadItems();
        LoadGroupOrder();
        RenderView();
    }

    private static string NewId()
    {
        return Guid.NewGuid().ToString("N").Substring(0, 8);
    }

    // 按鈕文字每 chunkSize 個字元強制換一行（例如 4 字一行），
    // 讓長短不一的名稱在同樣大小的按鈕裡排版整齊、可預期。
    private static string WrapLabelText(string text, int chunkSize)
    {
        if (string.IsNullOrEmpty(text)) { return text; }
        var sb = new StringBuilder();
        for (int i = 0; i < text.Length; i += chunkSize)
        {
            if (i > 0) { sb.Append('\n'); }
            int len = Math.Min(chunkSize, text.Length - i);
            sb.Append(text.Substring(i, len));
        }
        return sb.ToString();
    }

    // 幫控制項套用圓角外形：WinForms 沒有 CSS border-radius，
    // 但可以用 GraphicsPath 畫一個圓角矩形當作控制項的 Region，
    // 讓它的可視範圍（含滑鼠點擊範圍）變成圓角，達到類似效果。
    private static GraphicsPath RoundedRectPath(int width, int height, int radius)
    {
        int d = Math.Min(radius * 2, Math.Min(width, height));
        var path = new GraphicsPath();
        path.StartFigure();
        path.AddArc(0, 0, d, d, 180, 90);
        path.AddArc(width - d, 0, d, d, 270, 90);
        path.AddArc(width - d, height - d, d, d, 0, 90);
        path.AddArc(0, height - d, d, d, 90, 90);
        path.CloseFigure();
        return path;
    }

    private static void ApplyRoundedRegion(Control c, int radius)
    {
        using (var path = RoundedRectPath(c.Width, c.Height, radius))
        {
            c.Region = new Region(path);
        }
    }

    private static void StylePrimaryButton(Button b, Color normal, Color hover)
    {
        b.FlatStyle = FlatStyle.Flat;
        b.FlatAppearance.BorderSize = 0;
        b.BackColor = normal;
        b.ForeColor = Color.White;
        b.Cursor = Cursors.Hand;
        b.Padding = new Padding(2);
        ApplyRoundedRegion(b, CardRadius);
        b.MouseEnter += delegate { b.BackColor = hover; };
        b.MouseLeave += delegate { b.BackColor = normal; };
    }

    private static void StyleSecondaryButton(Button b)
    {
        b.FlatStyle = FlatStyle.Flat;
        b.FlatAppearance.BorderSize = 1;
        b.FlatAppearance.BorderColor = ColorBorder;
        b.BackColor = Color.White;
        b.ForeColor = ColorText;
        b.Cursor = Cursors.Hand;
        ApplyRoundedRegion(b, 6);
        b.MouseEnter += delegate { b.BackColor = ColorBg; };
        b.MouseLeave += delegate { b.BackColor = Color.White; };
    }

    private string WindowConfigPath
    {
        get { return Path.Combine(Path.GetDirectoryName(configPath), "copy-tool-window.txt"); }
    }

    private string GroupOrderPath
    {
        get { return Path.Combine(Path.GetDirectoryName(configPath), "copy-tool-group-order.txt"); }
    }

    private void LoadGroupOrder()
    {
        try
        {
            if (File.Exists(GroupOrderPath))
            {
                string content = File.ReadAllText(GroupOrderPath, Encoding.UTF8);
                var loaded = new List<string>(content.Split('\n'));
                loaded.RemoveAll(string.IsNullOrEmpty);
                groupOrder = loaded;
            }
        }
        catch { }
    }

    private void SaveGroupOrder()
    {
        try
        {
            File.WriteAllText(GroupOrderPath, string.Join("\n", groupOrder), new UTF8Encoding(false));
        }
        catch { }
    }

    // 把目前實際存在的分類，依照使用者自訂的排序（groupOrder）排好；
    // 排序清單裡沒出現過的新分類（新增/剛改名的）就照字母序接在最後面。
    private List<string> OrderGroups(List<string> currentGroups)
    {
        var result = new List<string>();
        foreach (var g in groupOrder)
        {
            if (currentGroups.Contains(g) && !result.Contains(g)) { result.Add(g); }
        }
        foreach (var g in currentGroups)
        {
            if (!result.Contains(g)) { result.Add(g); }
        }
        return result;
    }

    // 只搬動真正的分類，「未分類」固定放最後，不參與排序。
    private void MoveGroupOrder(string group, int direction)
    {
        if (group == UncategorizedOption) { return; }
        groupOrder = OrderGroups(GetDistinctGroups());
        int i = groupOrder.IndexOf(group);
        int j = i + direction;
        if (i < 0 || j < 0 || j >= groupOrder.Count) { return; }
        string tmp = groupOrder[i];
        groupOrder[i] = groupOrder[j];
        groupOrder[j] = tmp;
        SaveGroupOrder();
    }

    private void LoadWindowSize()
    {
        try
        {
            if (File.Exists(WindowConfigPath))
            {
                string[] parts = File.ReadAllText(WindowConfigPath).Trim().Split('x');
                if (parts.Length >= 2)
                {
                    int w = int.Parse(parts[0]);
                    int h = int.Parse(parts[1]);
                    if (w > 0 && h > 0) { this.ClientSize = new Size(w, h); }
                }
                if (parts.Length >= 3)
                {
                    int bw = int.Parse(parts[2]);
                    if (bw >= MinButtonWidth && bw <= MaxButtonWidth) { idealButtonWidth = bw; }
                }
            }
        }
        catch { }
    }

    private void SaveWindowSize()
    {
        try
        {
            File.WriteAllText(WindowConfigPath, this.ClientSize.Width + "x" + this.ClientSize.Height + "x" + idealButtonWidth);
        }
        catch { }
    }

    private void BuildUi()
    {
        this.Text = "快速複製小工具";
        // 預設開啟大小走比較緊湊的「小工具」尺寸；如果使用者之前手動調整過
        // 視窗大小並正常關閉過，下面 LoadWindowSize() 會覆蓋成上次關閉時的大小，
        // 所以視窗會記住使用者調整過的大小，不用每次都手動調整。
        this.ClientSize = new Size(560, 240);
        this.StartPosition = FormStartPosition.CenterScreen;
        this.Font = new Font("Microsoft JhengHei UI", 10);
        this.MinimumSize = new Size(480, 220);
        this.BackColor = ColorBg;
        LoadWindowSize();
        this.FormClosing += delegate { SaveWindowSize(); };

        int topH = 38;
        int bottomH = 52;
        int statusH = 22;

        // 頂端列：左邊放值班粉專篩選，右邊放置頂圖示按鈕。
        topPanel = new Panel();
        topPanel.Location = new Point(0, 0);
        topPanel.Size = new Size(this.ClientSize.Width, topH);
        topPanel.Anchor = AnchorStyles.Top | AnchorStyles.Left | AnchorStyles.Right;
        topPanel.BackColor = ColorBg;
        this.Controls.Add(topPanel);

        // 值班粉專篩選：只影響一般檢視模式顯示哪些按鈕，編輯模式一律顯示全部。
        int comboWidth = 130;
        var filterLabel = new Label();
        filterLabel.Text = "值班：";
        filterLabel.AutoSize = true;
        filterLabel.Location = new Point(10, 12);
        filterLabel.Anchor = AnchorStyles.Top | AnchorStyles.Left;
        filterLabel.ForeColor = ColorText;
        topPanel.Controls.Add(filterLabel);

        // 用按鈕＋彈出勾選清單做「多選下拉」，因為 WinForms 的 ComboBox
        // 本身不支援複選，值班常常要同時顧兩個以上粉專，單選下拉不夠用。
        filterButton = new Button();
        filterButton.Text = AllGroupsOption;
        filterButton.Size = new Size(comboWidth, 26);
        filterButton.Location = new Point(56, 7);
        filterButton.Anchor = AnchorStyles.Top | AnchorStyles.Left;
        filterButton.TextAlign = ContentAlignment.MiddleLeft;
        filterButton.Padding = new Padding(6, 0, 0, 0);
        StyleSecondaryButton(filterButton);
        filterButton.Click += delegate { ToggleFilterPopup(); };
        topPanel.Controls.Add(filterButton);

        btnTopMost = new Button();
        btnTopMost.Text = "📌";
        btnTopMost.Size = new Size(26, 24);
        btnTopMost.Location = new Point(this.ClientSize.Width - 26 - 6, 7);
        btnTopMost.Anchor = AnchorStyles.Top | AnchorStyles.Right;
        btnTopMost.Font = new Font("Segoe UI Emoji", 10);
        btnTopMost.FlatStyle = FlatStyle.Flat;
        btnTopMost.FlatAppearance.BorderSize = 0;
        btnTopMost.BackColor = ColorBg;
        btnTopMost.ForeColor = ColorText;
        btnTopMost.Cursor = Cursors.Hand;
        btnTopMost.TextAlign = ContentAlignment.MiddleCenter;
        var toolTip = new ToolTip();
        toolTip.SetToolTip(btnTopMost, "視窗置頂");
        btnTopMost.Click += BtnTopMost_Click;
        topPanel.Controls.Add(btnTopMost);

        // 下方獨立區塊：跟內容區用不同底色 + 頂端色線分隔，放編輯/匯出/匯入。
        bottomPanel = new Panel();
        bottomPanel.Size = new Size(this.ClientSize.Width, bottomH);
        bottomPanel.Location = new Point(0, this.ClientSize.Height - bottomH);
        bottomPanel.Anchor = AnchorStyles.Bottom | AnchorStyles.Left | AnchorStyles.Right;
        bottomPanel.BackColor = ColorBottomBar;
        bottomPanel.Paint += delegate (object s, PaintEventArgs e)
        {
            using (var pen = new Pen(ColorAccent, 2))
            {
                e.Graphics.DrawLine(pen, 0, 0, bottomPanel.Width, 0);
            }
        };
        this.Controls.Add(bottomPanel);

        btnEdit = new Button();
        btnEdit.Text = "編輯";
        btnEdit.Size = new Size(76, 32);
        btnEdit.Location = new Point(10, 10);
        btnEdit.Click += BtnEdit_Click;
        StyleSecondaryButton(btnEdit);
        bottomPanel.Controls.Add(btnEdit);

        btnExport = new Button();
        btnExport.Text = "匯出設定";
        btnExport.Size = new Size(88, 32);
        btnExport.Location = new Point(94, 10);
        btnExport.Click += BtnExport_Click;
        StyleSecondaryButton(btnExport);
        bottomPanel.Controls.Add(btnExport);

        btnImport = new Button();
        btnImport.Text = "匯入設定";
        btnImport.Size = new Size(88, 32);
        btnImport.Location = new Point(190, 10);
        btnImport.Click += BtnImport_Click;
        StyleSecondaryButton(btnImport);
        bottomPanel.Controls.Add(btnImport);

        // 選項按鈕大小調整：－ / 目前寬度 / ＋，靠右對齊。
        var sizePlusBtn = new Button();
        sizePlusBtn.Text = "＋";
        sizePlusBtn.Size = new Size(28, 32);
        sizePlusBtn.Location = new Point(this.ClientSize.Width - 28 - 10, 10);
        sizePlusBtn.Anchor = AnchorStyles.Top | AnchorStyles.Right;
        StyleSecondaryButton(sizePlusBtn);
        sizePlusBtn.Click += delegate { AdjustButtonSize(ButtonSizeStep); };
        bottomPanel.Controls.Add(sizePlusBtn);

        buttonSizeLabel = new Label();
        buttonSizeLabel.Text = idealButtonWidth + "px";
        buttonSizeLabel.Size = new Size(48, 32);
        buttonSizeLabel.Location = new Point(sizePlusBtn.Left - 48, 10);
        buttonSizeLabel.Anchor = AnchorStyles.Top | AnchorStyles.Right;
        buttonSizeLabel.TextAlign = ContentAlignment.MiddleCenter;
        buttonSizeLabel.ForeColor = ColorMuted;
        bottomPanel.Controls.Add(buttonSizeLabel);

        var sizeMinusBtn = new Button();
        sizeMinusBtn.Text = "－";
        sizeMinusBtn.Size = new Size(28, 32);
        sizeMinusBtn.Location = new Point(buttonSizeLabel.Left - 28 - 4, 10);
        sizeMinusBtn.Anchor = AnchorStyles.Top | AnchorStyles.Right;
        StyleSecondaryButton(sizeMinusBtn);
        sizeMinusBtn.Click += delegate { AdjustButtonSize(-ButtonSizeStep); };
        bottomPanel.Controls.Add(sizeMinusBtn);

        statusLabel = new Label();
        statusLabel.Size = new Size(this.ClientSize.Width, statusH);
        statusLabel.Location = new Point(0, this.ClientSize.Height - bottomH - statusH);
        statusLabel.Anchor = AnchorStyles.Bottom | AnchorStyles.Left | AnchorStyles.Right;
        statusLabel.TextAlign = ContentAlignment.MiddleCenter;
        statusLabel.ForeColor = ColorSuccess;
        statusLabel.BackColor = ColorBg;
        this.Controls.Add(statusLabel);

        contentPanel = new Panel();
        contentPanel.Location = new Point(0, topH);
        contentPanel.Size = new Size(this.ClientSize.Width, this.ClientSize.Height - topH - statusH - bottomH);
        contentPanel.Anchor = AnchorStyles.Top | AnchorStyles.Bottom | AnchorStyles.Left | AnchorStyles.Right;
        contentPanel.AutoScroll = true;
        contentPanel.BorderStyle = BorderStyle.None;
        contentPanel.BackColor = ColorBg;
        contentPanel.Paint += ContentPanel_Paint;
        // 一般檢視模式沒有直向內容可以捲，滑鼠滾輪預設轉不動；
        // 改成滾輪帶動橫向捲動，體感上才會像左右滑動。編輯模式（卡片
        // 由上往下排）維持滾輪原本的直向捲動行為，不受這裡影響。
        contentPanel.MouseWheel += delegate (object s, MouseEventArgs e)
        {
            if (editMode) { return; }
            int max = Math.Max(0, contentPanel.HorizontalScroll.Maximum - contentPanel.HorizontalScroll.LargeChange + 1);
            int current = -contentPanel.AutoScrollPosition.X;
            int next = Math.Max(0, Math.Min(max, current - e.Delta));
            contentPanel.AutoScrollPosition = new Point(next, 0);
        };
        this.Controls.Add(contentPanel);

        // 內容區要蓋在最上層，避免被上方置頂列、下方功能列或狀態列的 Z-order 遮住。
        contentPanel.BringToFront();
        topPanel.BringToFront();
        statusLabel.BringToFront();
        bottomPanel.BringToFront();

        toastTimer = new System.Windows.Forms.Timer();
        toastTimer.Interval = 1400;
        toastTimer.Tick += delegate { statusLabel.Text = ""; toastTimer.Stop(); };

        // 視窗大小改變時，延遲一小段時間再重新排版一次，
        // 讓按鈕格數/每列寬度依照新的視窗大小自動調整，
        // 用計時器 debounce 避免拖曳視窗邊框時瘋狂重繪。
        resizeTimer = new System.Windows.Forms.Timer();
        resizeTimer.Interval = 120;
        resizeTimer.Tick += delegate { resizeTimer.Stop(); RenderView(); };
        this.Resize += delegate { resizeTimer.Stop(); resizeTimer.Start(); };
    }

    private void BtnTopMost_Click(object sender, EventArgs e)
    {
        this.TopMost = !this.TopMost;
        btnTopMost.BackColor = this.TopMost ? ColorAccent : ColorBg;
        btnTopMost.ForeColor = this.TopMost ? Color.White : ColorText;
    }

    // 卡片陰影：在內容區自己的 Paint 事件裡先畫一層偏移、半透明的圓角矩形，
    // 因為父層一定比子控制項先畫，陰影自然會被之後畫上去的按鈕/卡片蓋在上面，
    // 造成有深度的「浮起來」效果，而不是平貼在背景上。
    private void ContentPanel_Paint(object sender, PaintEventArgs e)
    {
        e.Graphics.SmoothingMode = SmoothingMode.AntiAlias;
        foreach (var r in shadowRects)
        {
            using (var path = RoundedRectPath(r.Width, r.Height, CardRadius))
            using (var brush = new SolidBrush(Color.FromArgb(26, 0, 0, 0)))
            {
                var state = e.Graphics.Save();
                e.Graphics.TranslateTransform(r.X + 2, r.Y + 3);
                e.Graphics.FillPath(brush, path);
                e.Graphics.Restore(state);
            }
        }
    }

    private void AdjustButtonSize(int delta)
    {
        idealButtonWidth = Math.Max(MinButtonWidth, Math.Min(MaxButtonWidth, idealButtonWidth + delta));
        buttonSizeLabel.Text = idealButtonWidth + "px";
        RenderView();
    }

    private void ShowToast(string msg)
    {
        statusLabel.Text = msg;
        toastTimer.Stop();
        toastTimer.Start();
    }

    private static List<ButtonItem> DefaultItems()
    {
        return new List<ButtonItem>
        {
            new ButtonItem { Id = NewId(), Label = "範例按鈕 1", Text = "這裡是要被複製的文字內容 1", Group = "" },
            new ButtonItem { Id = NewId(), Label = "範例按鈕 2", Text = "這裡是要被複製的文字內容 2", Group = "" }
        };
    }

    private void LoadItems()
    {
        if (File.Exists(configPath))
        {
            try
            {
                string json = File.ReadAllText(configPath, Encoding.UTF8);
                var parsed = MiniJson.ParseArrayOfStringObjects(json);
                if (parsed.Count > 0)
                {
                    var loaded = new List<ButtonItem>();
                    foreach (var d in parsed)
                    {
                        string id = (d.ContainsKey("Id") && !string.IsNullOrEmpty(d["Id"])) ? d["Id"] : NewId();
                        string label = d.ContainsKey("Label") ? d["Label"] : "";
                        string text = d.ContainsKey("Text") ? d["Text"] : "";
                        string group = d.ContainsKey("Group") ? d["Group"] : "";
                        loaded.Add(new ButtonItem { Id = id, Label = label, Text = text, Group = group });
                    }
                    items = loaded;
                    return;
                }
            }
            catch { }
        }
        items = DefaultItems();
        SaveItems();
    }

    private void SaveItems()
    {
        var sb = new StringBuilder();
        sb.Append("[\n");
        for (int i = 0; i < items.Count; i++)
        {
            sb.Append("  {\n");
            sb.Append("    \"Id\": \"" + MiniJson.Escape(items[i].Id) + "\",\n");
            sb.Append("    \"Label\": \"" + MiniJson.Escape(items[i].Label) + "\",\n");
            sb.Append("    \"Text\": \"" + MiniJson.Escape(items[i].Text) + "\",\n");
            sb.Append("    \"Group\": \"" + MiniJson.Escape(items[i].Group) + "\"\n");
            sb.Append("  }" + (i < items.Count - 1 ? "," : "") + "\n");
        }
        sb.Append("]\n");
        File.WriteAllText(configPath, sb.ToString(), new UTF8Encoding(false));
    }

    private List<string> GetDistinctGroups()
    {
        var groups = new List<string>();
        var seen = new HashSet<string>();
        foreach (var it in items)
        {
            if (!string.IsNullOrEmpty(it.Group) && seen.Add(it.Group))
            {
                groups.Add(it.Group);
            }
        }
        groups.Sort(StringComparer.CurrentCulture);
        return groups;
    }

    private List<string> GetFilterOptions()
    {
        var options = OrderGroups(GetDistinctGroups());
        bool hasUncategorized = items.Exists(it => string.IsNullOrEmpty(it.Group));
        if (hasUncategorized) { options.Add(UncategorizedOption); }
        return options;
    }

    // 選了任何項目時，把不再存在的分類（被改名/刪除）從已選集合裡拿掉，
    // 避免篩選卡在一個畫面上已經看不到、也選不到的幽靈分類。
    private void PruneAndRefreshFilter()
    {
        var valid = new HashSet<string>(GetFilterOptions());
        selectedGroups.RemoveWhere(g => !valid.Contains(g));
        UpdateFilterButtonText();
    }

    private void UpdateFilterButtonText()
    {
        if (selectedGroups.Count == 0)
        {
            filterButton.Text = AllGroupsOption;
            return;
        }
        var sorted = new List<string>(selectedGroups);
        sorted.Sort(StringComparer.CurrentCulture);
        string joined = string.Join("+", sorted);
        filterButton.Text = (joined.Length > 9) ? (joined.Substring(0, 8) + "…") : joined;
    }

    private void ToggleFilterPopup()
    {
        if (activeFilterPopup != null && !activeFilterPopup.IsDisposed)
        {
            activeFilterPopup.Close();
            return;
        }
        ShowFilterPopup();
    }

    private void ShowFilterPopup()
    {
        Point reopenLocation = filterButton.PointToScreen(new Point(0, filterButton.Height + 2));
        ShowFilterPopupAt(reopenLocation);
    }

    // 每列一個勾選框＋↑↓排序鈕，取代原本的 CheckedListBox，
    // 因為 CheckedListBox 沒辦法在每一列旁邊加自訂的排序按鈕。
    private void ShowFilterPopupAt(Point screenLocation)
    {
        var options = GetFilterOptions();

        var popup = new Form();
        popup.FormBorderStyle = FormBorderStyle.FixedToolWindow;
        popup.ShowInTaskbar = false;
        popup.StartPosition = FormStartPosition.Manual;
        popup.Text = "選擇值班粉專（可複選、可排序）";
        popup.BackColor = ColorCard;
        popup.Font = this.Font;

        var listPanel = new Panel();
        listPanel.BorderStyle = BorderStyle.FixedSingle;
        listPanel.AutoScroll = true;
        listPanel.Location = new Point(8, 8);
        int rowH = 28;
        listPanel.Size = new Size(226, Math.Max(rowH, Math.Min(options.Count, 8) * rowH + 4));

        int rowY = 2;
        for (int idx = 0; idx < options.Count; idx++)
        {
            string optionValue = options[idx];
            bool isUncategorized = optionValue == UncategorizedOption;

            var chk = new CheckBox();
            chk.Text = optionValue;
            chk.AutoSize = false;
            chk.Size = new Size(148, rowH - 2);
            chk.Location = new Point(4, rowY);
            chk.Checked = selectedGroups.Contains(optionValue);
            chk.CheckedChanged += delegate
            {
                if (chk.Checked) { selectedGroups.Add(optionValue); } else { selectedGroups.Remove(optionValue); }
                UpdateFilterButtonText();
                RenderView();
            };
            listPanel.Controls.Add(chk);

            var upBtn = new Button();
            upBtn.Text = "↑";
            upBtn.Size = new Size(24, rowH - 4);
            upBtn.Location = new Point(154, rowY + 1);
            StyleSecondaryButton(upBtn);
            upBtn.Enabled = !isUncategorized && idx > 0;
            upBtn.Click += delegate
            {
                MoveGroupOrder(optionValue, -1);
                popup.Close();
                ShowFilterPopupAt(screenLocation);
            };
            listPanel.Controls.Add(upBtn);

            var downBtn = new Button();
            downBtn.Text = "↓";
            downBtn.Size = new Size(24, rowH - 4);
            downBtn.Location = new Point(182, rowY + 1);
            StyleSecondaryButton(downBtn);
            downBtn.Enabled = !isUncategorized && idx < options.Count - 1 && options[idx + 1] != UncategorizedOption;
            downBtn.Click += delegate
            {
                MoveGroupOrder(optionValue, 1);
                popup.Close();
                ShowFilterPopupAt(screenLocation);
            };
            listPanel.Controls.Add(downBtn);

            rowY += rowH;
        }
        popup.Controls.Add(listPanel);

        var hint = new Label();
        hint.Text = (options.Count == 0) ? "目前還沒有粉專分類，先到編輯模式設定。" : "可複選；用 ↑↓ 調整排列順序。";
        hint.AutoSize = true;
        hint.ForeColor = ColorMuted;
        hint.Location = new Point(8, listPanel.Bottom + 6);
        popup.Controls.Add(hint);

        var clearBtn = new Button();
        clearBtn.Text = "清除（顯示全部）";
        clearBtn.Size = new Size(226, 28);
        clearBtn.Location = new Point(8, hint.Bottom + 6);
        StyleSecondaryButton(clearBtn);
        clearBtn.Click += delegate
        {
            selectedGroups.Clear();
            UpdateFilterButtonText();
            RenderView();
            popup.Close();
        };
        popup.Controls.Add(clearBtn);

        popup.ClientSize = new Size(242, clearBtn.Bottom + 10);
        popup.Location = screenLocation;
        popup.Deactivate += delegate { popup.Close(); };
        popup.FormClosed += delegate { activeFilterPopup = null; };
        activeFilterPopup = popup;
        popup.Show(this);
    }

    public void RenderView()
    {
        contentPanel.SuspendLayout();
        // 逐一 Dispose 舊控制項再清空，避免每次重繪（每次調整視窗大小、
        // 切換編輯模式都會整批重建）都留下沒釋放的原生控制代碼。
        // 一定要先複製成陣列再逐一 Dispose——直接對 Controls 做 foreach
        // 的同時又把項目移除，會讓列舉器跳過一半的項目、沒被正確清掉，
        // 畫面上就會殘留舊按鈕的殘影。
        var oldControls = new Control[contentPanel.Controls.Count];
        contentPanel.Controls.CopyTo(oldControls, 0);
        foreach (Control c in oldControls) { c.Dispose(); }
        contentPanel.Controls.Clear();
        shadowRects.Clear();
        int y = 10;

        if (!editMode)
        {
            PruneAndRefreshFilter();
            List<ButtonItem> visibleItems;
            if (selectedGroups.Count == 0)
            {
                visibleItems = items;
            }
            else
            {
                visibleItems = items.FindAll(it =>
                    string.IsNullOrEmpty(it.Group)
                        ? selectedGroups.Contains(UncategorizedOption)
                        : selectedGroups.Contains(it.Group));
            }

            // 主頁面顯示順序改成照分類排序（用跟值班篩選彈出視窗同一套
            // 自訂分類順序），而不是原本的新增順序；同分類內的按鈕仍維持
            // 原本相對順序（OrderBy 是穩定排序，不會把同分類的順序打亂）。
            // 用 OrderBy 產生新清單，不會動到 items 本身的順序（存檔也不受影響）。
            var orderedGroups = OrderGroups(GetDistinctGroups());
            var groupRank = new Dictionary<string, int>();
            for (int gi = 0; gi < orderedGroups.Count; gi++) { groupRank[orderedGroups[gi]] = gi; }
            visibleItems = visibleItems
                .OrderBy(it => string.IsNullOrEmpty(it.Group)
                    ? orderedGroups.Count
                    : (groupRank.ContainsKey(it.Group) ? groupRank[it.Group] : orderedGroups.Count))
                .ToList();

            if (visibleItems.Count == 0)
            {
                var hint = new Label();
                hint.Text = (items.Count == 0)
                    ? "目前沒有按鈕，按下方「編輯」新增一個吧。"
                    : "這個粉專分類目前沒有按鈕。";
                hint.AutoSize = true;
                hint.ForeColor = ColorMuted;
                hint.Location = new Point(10, y);
                contentPanel.Controls.Add(hint);
                y += 40;
                contentPanel.AutoScrollMinSize = new Size(0, 0);
            }
            else
            {
                // 主頁面改成左右滑動：按鈕先往下排滿目前可見高度（排成一欄），
                // 排滿了才往右開新的一欄，內容區改成橫向捲動，
                // 而不是像之前那樣往下長、直向捲動。
                int btnWidth = idealButtonWidth;
                int btnHeight = Math.Max(48, (int)(btnWidth * 0.68));
                const int gap = 10;
                int availableHeight = Math.Max(contentPanel.ClientSize.Height - 20, btnHeight);
                int perCol = Math.Max(1, (availableHeight + gap) / (btnHeight + gap));
                int row = 0;
                int col = 0;
                int maxX = 10;
                foreach (var item in visibleItems)
                {
                    var btn = new Button();
                    btn.Text = WrapLabelText(item.Label, 4);
                    btn.Font = new Font("Microsoft JhengHei UI", 13, FontStyle.Bold);
                    btn.TextAlign = ContentAlignment.MiddleCenter;
                    btn.Size = new Size(btnWidth, btnHeight);
                    btn.Location = new Point(10 + col * (btnWidth + gap), 10 + row * (btnHeight + gap));
                    StylePrimaryButton(btn, ColorAccent, ColorAccentHover);
                    btn.Click += (s, e) => OnCopyClick(item, btn);
                    contentPanel.Controls.Add(btn);
                    shadowRects.Add(new Rectangle(btn.Location, btn.Size));
                    maxX = Math.Max(maxX, btn.Right + gap);
                    row++;
                    if (row >= perCol) { row = 0; col++; }
                }
                contentPanel.AutoScrollMinSize = new Size(maxX, 0);
            }
        }
        else
        {
            int rowWidth = Math.Max(contentPanel.ClientSize.Width - 30, 460);
            string[] groupSuggestions = OrderGroups(GetDistinctGroups()).ToArray();
            foreach (var item in items)
            {
                var row = new Panel();
                row.BorderStyle = BorderStyle.None;
                row.BackColor = ColorCard;
                row.Location = new Point(10, y);
                row.Size = new Size(rowWidth, 160);
                ApplyRoundedRegion(row, CardRadius);
                row.Paint += delegate (object s, PaintEventArgs e)
                {
                    e.Graphics.SmoothingMode = SmoothingMode.AntiAlias;
                    using (var pen = new Pen(ColorBorder))
                    using (var path = RoundedRectPath(row.Width - 1, row.Height - 1, CardRadius))
                    {
                        e.Graphics.DrawPath(pen, path);
                    }
                };
                shadowRects.Add(new Rectangle(row.Location, row.Size));

                var lbl1 = new Label();
                lbl1.Text = "名稱";
                lbl1.Location = new Point(10, 8);
                lbl1.AutoSize = true;
                lbl1.ForeColor = ColorMuted;
                row.Controls.Add(lbl1);

                var lblBox = new TextBox();
                lblBox.Text = item.Label;
                lblBox.Location = new Point(10, 28);
                lblBox.Size = new Size(rowWidth - 282, 23);
                lblBox.BorderStyle = BorderStyle.FixedSingle;
                lblBox.Anchor = AnchorStyles.Top | AnchorStyles.Left | AnchorStyles.Right;
                lblBox.TextChanged += (s, e) => { item.Label = lblBox.Text; SaveItems(); };
                row.Controls.Add(lblBox);

                var lblGroup = new Label();
                lblGroup.Text = "分類（粉專）";
                lblGroup.Location = new Point(rowWidth - 260, 8);
                lblGroup.AutoSize = true;
                lblGroup.ForeColor = ColorMuted;
                lblGroup.Anchor = AnchorStyles.Top | AnchorStyles.Right;
                row.Controls.Add(lblGroup);

                var groupCombo = new ComboBox();
                groupCombo.DropDownStyle = ComboBoxStyle.DropDown;
                groupCombo.Items.AddRange(groupSuggestions);
                groupCombo.Text = item.Group ?? "";
                groupCombo.Location = new Point(rowWidth - 260, 28);
                groupCombo.Size = new Size(150, 23);
                groupCombo.Anchor = AnchorStyles.Top | AnchorStyles.Right;
                groupCombo.TextChanged += (s, e) => { item.Group = groupCombo.Text; SaveItems(); };
                row.Controls.Add(groupCombo);

                var delBtn = new Button();
                delBtn.Text = "刪除";
                delBtn.Location = new Point(rowWidth - 100, 27);
                delBtn.Size = new Size(90, 25);
                delBtn.Anchor = AnchorStyles.Top | AnchorStyles.Right;
                StylePrimaryButton(delBtn, ColorDanger, ColorDangerHover);
                delBtn.Click += (s, e) => { items.Remove(item); SaveItems(); RenderView(); };
                row.Controls.Add(delBtn);

                var lbl2 = new Label();
                lbl2.Text = "複製內容（可換行）";
                lbl2.Location = new Point(10, 58);
                lbl2.AutoSize = true;
                lbl2.ForeColor = ColorMuted;
                row.Controls.Add(lbl2);

                var txtBox = new TextBox();
                txtBox.Multiline = true;
                txtBox.AcceptsReturn = true;
                txtBox.ScrollBars = ScrollBars.Vertical;
                txtBox.BorderStyle = BorderStyle.FixedSingle;
                txtBox.Text = item.Text;
                txtBox.Location = new Point(10, 80);
                txtBox.Size = new Size(rowWidth - 20, 70);
                txtBox.Anchor = AnchorStyles.Top | AnchorStyles.Left | AnchorStyles.Right;
                txtBox.TextChanged += (s, e) => { item.Text = txtBox.Text; SaveItems(); };
                row.Controls.Add(txtBox);

                contentPanel.Controls.Add(row);
                y += 172;
            }

            var addBtn = new Button();
            addBtn.Text = "＋ 新增按鈕";
            addBtn.Size = new Size(150, 36);
            addBtn.Location = new Point(10, y);
            StylePrimaryButton(addBtn, ColorSuccess, ColorSuccessHover);
            addBtn.Click += (s, e) =>
            {
                items.Add(new ButtonItem { Id = NewId(), Label = "新按鈕", Text = "", Group = "" });
                SaveItems();
                RenderView();
            };
            contentPanel.Controls.Add(addBtn);
            y += 46;
            // 編輯模式維持直向捲動（卡片列表由上往下），
            // 橫向捲動的設定只用在一般檢視模式的按鈕格。
            contentPanel.AutoScrollMinSize = new Size(0, y + 10);
        }

        contentPanel.ResumeLayout();
        // 保險起見強制整個內容區重繪一次，避免舊控制項移除後
        // 殘留的畫面沒有被正確清乾淨（殘影）。
        contentPanel.Invalidate(true);
    }

    private void OnCopyClick(ButtonItem item, Button btn)
    {
        Clipboard.SetText(item.Text ?? "");
        string orig = btn.Text;
        btn.Text = "已複製 ✓";
        btn.BackColor = ColorSuccess;
        var t = new System.Windows.Forms.Timer();
        t.Interval = 700;
        t.Tick += delegate
        {
            btn.Text = orig;
            btn.BackColor = ColorAccent;
            t.Stop();
            t.Dispose();
        };
        t.Start();
        ShowToast("已複製到剪貼簿");
    }

    private void BtnEdit_Click(object sender, EventArgs e)
    {
        editMode = !editMode;
        btnEdit.Text = editMode ? "儲存並返回" : "編輯";
        if (!editMode)
        {
            SaveItems();
            ShowToast("已儲存");
        }
        RenderView();
    }

    private void BtnExport_Click(object sender, EventArgs e)
    {
        using (var dlg = new SaveFileDialog())
        {
            dlg.Filter = "JSON 檔案 (*.json)|*.json";
            dlg.FileName = "copy-tool-buttons.json";
            if (dlg.ShowDialog() == DialogResult.OK)
            {
                SaveItems();
                File.Copy(configPath, dlg.FileName, true);
                ShowToast("已匯出設定檔");
            }
        }
    }

    private void BtnImport_Click(object sender, EventArgs e)
    {
        using (var dlg = new OpenFileDialog())
        {
            dlg.Filter = "JSON 檔案 (*.json)|*.json";
            if (dlg.ShowDialog() == DialogResult.OK)
            {
                try
                {
                    string json = File.ReadAllText(dlg.FileName, Encoding.UTF8);
                    var parsed = MiniJson.ParseArrayOfStringObjects(json);
                    var newItems = new List<ButtonItem>();
                    foreach (var d in parsed)
                    {
                        string label = d.ContainsKey("Label") ? d["Label"] : "";
                        string text = d.ContainsKey("Text") ? d["Text"] : "";
                        string group = d.ContainsKey("Group") ? d["Group"] : "";
                        newItems.Add(new ButtonItem { Id = NewId(), Label = label, Text = text, Group = group });
                    }
                    items = newItems;
                    SaveItems();
                    RenderView();
                    ShowToast("已匯入設定");
                }
                catch (Exception ex)
                {
                    MessageBox.Show("匯入失敗，請確認是本工具匯出的 JSON 檔案。\n" + ex.Message, "錯誤");
                }
            }
        }
    }
}
'@

Add-Type -Language CSharp -ReferencedAssemblies System.Windows.Forms, System.Drawing, System.Core -TypeDefinition $csharpSource

[System.Windows.Forms.Application]::EnableVisualStyles()
$form = New-Object CopyToolForm -ArgumentList $configPath
[System.Windows.Forms.Application]::Run($form)
