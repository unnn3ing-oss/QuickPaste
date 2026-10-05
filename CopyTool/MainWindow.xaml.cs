using System.Collections.Generic;
using System.Collections.ObjectModel;
using System.ComponentModel;
using System.IO;
using System.Linq;
using System.Runtime.CompilerServices;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Media;
using System.Windows.Threading;
using CopyTool.Models;
using CopyTool.Services;
using Microsoft.Win32;

namespace CopyTool;

public partial class MainWindow : Window, INotifyPropertyChanged
{
    private const string AllGroupsOption = "全部粉專";
    private const string UncategorizedOption = "未分類";
    private const int MinButtonWidth = 70;
    private const int MaxButtonWidth = 220;
    private const int ButtonSizeStep = 10;

    private readonly string _buttonsPath;
    private readonly string _settingsPath;
    private readonly AppSettings _settings;
    private readonly HashSet<string> _selectedGroups = new();
    private bool _editMode;

    // 所有按鈕（含編輯模式看到的完整清單，不受值班篩選影響）。
    public ObservableCollection<ButtonItem> Items { get; } = new();

    // 主頁面實際顯示的清單：套用值班篩選＋依分類排序後的結果。
    public ObservableCollection<ButtonItem> VisibleItems { get; } = new();

    // 編輯模式「分類」欄位的自動完成建議清單，跟值班篩選彈出視窗用同一套分類排序。
    public ObservableCollection<string> GroupSuggestions { get; } = new();

    // 值班粉專篩選彈出視窗目前顯示的選項（每次開啟或分類異動時重新建構）。
    public ObservableCollection<FilterOptionItem> FilterOptions { get; } = new();

    public event PropertyChangedEventHandler? PropertyChanged;

    public MainWindow()
    {
        InitializeComponent();
        DataContext = this;

        // 跟舊版一樣，資料檔放在執行檔同一個資料夾，方便整個資料夾一起帶著走。
        string dir = AppDomain.CurrentDomain.BaseDirectory;
        _buttonsPath = Path.Combine(dir, "copy-tool-buttons.json");
        _settingsPath = Path.Combine(dir, "copy-tool-settings.json");

        _settings = SettingsStore.Load(_settingsPath);
        ApplyLoadedWindowSettings();

        foreach (var item in JsonStore.Load(_buttonsPath))
        {
            AddItemWithAutoSave(item, save: false);
        }

        RefreshAll();
    }

    private void ApplyLoadedWindowSettings()
    {
        if (_settings.WindowWidth >= MinWidth) { Width = _settings.WindowWidth; }
        if (_settings.WindowHeight >= MinHeight) { Height = _settings.WindowHeight; }
        _buttonTileWidth = Math.Max(MinButtonWidth, Math.Min(MaxButtonWidth, _settings.ButtonTileWidth));
    }

    // === 按鈕大小（設定，可由下方工具列的 －/＋ 調整，結果延續到下次開啟） ===

    private int _buttonTileWidth = 90;
    public int ButtonTileWidth
    {
        get => _buttonTileWidth;
        set
        {
            int clamped = Math.Max(MinButtonWidth, Math.Min(MaxButtonWidth, value));
            SetField(ref _buttonTileWidth, clamped);
        }
    }

    // === 值班粉專篩選按鈕文字／彈出視窗提示文字 ===

    private string _filterButtonText = AllGroupsOption;
    public string FilterButtonText { get => _filterButtonText; set => SetField(ref _filterButtonText, value); }

    private string _filterHintText = "";
    public string FilterHintText { get => _filterHintText; set => SetField(ref _filterHintText, value); }

    // === 主頁面「沒有按鈕/篩選後無符合分類」的提示文字 ===

    private string _emptyHintText = "";
    public string EmptyHintText { get => _emptyHintText; set => SetField(ref _emptyHintText, value); }

    private Visibility _emptyHintVisibility = Visibility.Collapsed;
    public Visibility EmptyHintVisibility { get => _emptyHintVisibility; set => SetField(ref _emptyHintVisibility, value); }

    private void SetField<T>(ref T field, T value, [CallerMemberName] string? propertyName = null)
    {
        if (Equals(field, value)) { return; }
        field = value;
        PropertyChanged?.Invoke(this, new PropertyChangedEventArgs(propertyName));
    }

    // === 資料存取 ===

    // 加入清單的同時訂閱 PropertyChanged，讓 TextBox/ComboBox 綁定改值時自動存檔
    // 並重新整理主頁面顯示（分類篩選選項、排序、自動完成建議都可能因此改變）。
    private void AddItemWithAutoSave(ButtonItem item, bool save = true)
    {
        item.PropertyChanged += (_, _) => { SaveItems(); RefreshAll(); };
        Items.Add(item);
        if (save) { SaveItems(); }
    }

    private void SaveItems()
    {
        JsonStore.Save(_buttonsPath, new List<ButtonItem>(Items));
    }

    private void SaveSettings()
    {
        _settings.WindowWidth = (int)Width;
        _settings.WindowHeight = (int)Height;
        _settings.ButtonTileWidth = ButtonTileWidth;
        SettingsStore.Save(_settingsPath, _settings);
    }

    // === 分類排序／篩選相關邏輯（對應舊版 OrderGroups / GetDistinctGroups / ...） ===

    private List<string> GetDistinctGroups()
    {
        var seen = new HashSet<string>();
        var groups = new List<string>();
        foreach (var it in Items)
        {
            if (!string.IsNullOrEmpty(it.Group) && seen.Add(it.Group)) { groups.Add(it.Group); }
        }
        groups.Sort(StringComparer.CurrentCulture);
        return groups;
    }

    // 把目前實際存在的分類，依照使用者自訂的排序排好；排序清單裡沒出現過的
    // 新分類（新增/剛改名的）就照字母序接在最後面。
    private List<string> OrderGroups(List<string> currentGroups)
    {
        var result = new List<string>();
        foreach (var g in _settings.GroupOrder)
        {
            if (currentGroups.Contains(g) && !result.Contains(g)) { result.Add(g); }
        }
        foreach (var g in currentGroups)
        {
            if (!result.Contains(g)) { result.Add(g); }
        }
        return result;
    }

    private List<string> GetFilterOptions()
    {
        var options = OrderGroups(GetDistinctGroups());
        bool hasUncategorized = Items.Any(it => string.IsNullOrEmpty(it.Group));
        if (hasUncategorized) { options.Add(UncategorizedOption); }
        return options;
    }

    // 只搬動真正的分類，「未分類」固定放最後，不參與排序。
    private void MoveGroupOrder(string group, int direction)
    {
        if (group == UncategorizedOption) { return; }
        _settings.GroupOrder = OrderGroups(GetDistinctGroups());
        var order = _settings.GroupOrder;
        int i = order.IndexOf(group);
        int j = i + direction;
        if (i < 0 || j < 0 || j >= order.Count) { return; }
        (order[i], order[j]) = (order[j], order[i]);
        SaveSettings();
    }

    // 選了任何項目時，把不再存在的分類（被改名/刪除）從已選集合裡拿掉，
    // 避免篩選卡在一個畫面上已經看不到、也選不到的幽靈分類。
    private void PruneAndRefreshFilter()
    {
        var valid = new HashSet<string>(GetFilterOptions());
        _selectedGroups.RemoveWhere(g => !valid.Contains(g));
        UpdateFilterButtonText();
    }

    private void UpdateFilterButtonText()
    {
        if (_selectedGroups.Count == 0)
        {
            FilterButtonText = AllGroupsOption;
            return;
        }
        var sorted = new List<string>(_selectedGroups);
        sorted.Sort(StringComparer.CurrentCulture);
        string joined = string.Join("+", sorted);
        FilterButtonText = (joined.Length > 9) ? (joined.Substring(0, 8) + "…") : joined;
    }

    // 統一的重新整理入口：篩選選項清空幽靈分類、主頁面顯示清單（篩選＋排序）、
    // 空清單提示文字、編輯模式分類自動完成建議，全部在這裡一次算好。
    private void RefreshAll()
    {
        PruneAndRefreshFilter();

        var orderedGroups = OrderGroups(GetDistinctGroups());
        var groupRank = new Dictionary<string, int>();
        for (int i = 0; i < orderedGroups.Count; i++) { groupRank[orderedGroups[i]] = i; }

        IEnumerable<ButtonItem> filtered = Items;
        if (_selectedGroups.Count > 0)
        {
            filtered = Items.Where(it => string.IsNullOrEmpty(it.Group)
                ? _selectedGroups.Contains(UncategorizedOption)
                : _selectedGroups.Contains(it.Group));
        }

        var sorted = filtered
            .OrderBy(it => string.IsNullOrEmpty(it.Group)
                ? orderedGroups.Count
                : (groupRank.TryGetValue(it.Group, out int rank) ? rank : orderedGroups.Count))
            .ToList();

        VisibleItems.Clear();
        foreach (var it in sorted) { VisibleItems.Add(it); }

        if (VisibleItems.Count == 0)
        {
            EmptyHintText = Items.Count == 0
                ? "目前沒有按鈕，按下方「編輯」新增一個吧。"
                : "這個粉專分類目前沒有按鈕。";
            EmptyHintVisibility = Visibility.Visible;
        }
        else
        {
            EmptyHintVisibility = Visibility.Collapsed;
        }

        // 不能用 Clear() 再重加：Reset 會讓編輯模式的可編輯 ComboBox 把 Text 清成空字串
        // 並寫回 Group，造成所有按鈕的分類被洗掉。改成只套用差異。
        CollectionSync.Sync(GroupSuggestions, orderedGroups);
    }

    private void BuildFilterOptions()
    {
        var options = GetFilterOptions();
        FilterOptions.Clear();
        for (int i = 0; i < options.Count; i++)
        {
            string name = options[i];
            bool isUncategorized = name == UncategorizedOption;
            bool canUp = !isUncategorized && i > 0;
            bool canDown = !isUncategorized && i < options.Count - 1 && options[i + 1] != UncategorizedOption;
            FilterOptions.Add(new FilterOptionItem
            {
                Name = name,
                IsChecked = _selectedGroups.Contains(name),
                CanMoveUp = canUp,
                CanMoveDown = canDown,
            });
        }
        FilterHintText = options.Count == 0
            ? "目前還沒有粉專分類，先到編輯模式設定。"
            : "可複選；用 ↑↓ 調整排列順序。";
    }

    // === 狀態提示列（toast） ===

    private void ShowStatus(string message)
    {
        StatusLabel.Text = message;
        StatusToast.Visibility = Visibility.Visible;
        var timer = new DispatcherTimer { Interval = TimeSpan.FromSeconds(1.4) };
        timer.Tick += (_, _) => { StatusToast.Visibility = Visibility.Collapsed; timer.Stop(); };
        timer.Start();
    }

    // === 事件處理 ===

    private void CopyButton_Click(object sender, RoutedEventArgs e)
    {
        if (sender is not Button { Tag: ButtonItem item } button) { return; }

        Clipboard.SetText(item.Text ?? "");
        ShowStatus("已複製到剪貼簿");

        // 按鈕本身短暫顯示「已複製 ✓」視覺回饋，700ms 後恢復原本文字/顏色。
        // 回饋期間再點一次只複製、不重新啟動回饋，否則會把「已複製 ✓」當成原文字存起來。
        if (button.Content is TextBlock tb && !CopyState.GetIsCopied(button))
        {
            string original = tb.Text;
            tb.Text = "已複製 ✓";
            CopyState.SetIsCopied(button, true);
            var timer = new DispatcherTimer { Interval = TimeSpan.FromMilliseconds(700) };
            timer.Tick += (_, _) =>
            {
                tb.Text = original;
                CopyState.SetIsCopied(button, false);
                timer.Stop();
            };
            timer.Start();
        }
    }

    private void EditToggle_Click(object sender, RoutedEventArgs e)
    {
        _editMode = !_editMode;
        ViewScroller.Visibility = _editMode ? Visibility.Collapsed : Visibility.Visible;
        EditScroller.Visibility = _editMode ? Visibility.Visible : Visibility.Collapsed;
        EditToggleButton.Content = _editMode ? "儲存並返回" : "編輯";

        if (!_editMode)
        {
            SaveItems();
            RefreshAll();
            ShowStatus("已儲存");
        }
    }

    private void AddItem_Click(object sender, RoutedEventArgs e)
    {
        AddItemWithAutoSave(new ButtonItem { Label = "新按鈕" });
        RefreshAll();
    }

    private void DeleteItem_Click(object sender, RoutedEventArgs e)
    {
        if (sender is Button { Tag: ButtonItem item })
        {
            Items.Remove(item);
            SaveItems();
            RefreshAll();
        }
    }

    private void SettingsMenuButton_Click(object sender, RoutedEventArgs e)
    {
        if (sender is Button { ContextMenu: { } menu } button)
        {
            menu.PlacementTarget = button;
            menu.IsOpen = true;
        }
    }

    private void Export_Click(object sender, RoutedEventArgs e)
    {
        var dlg = new SaveFileDialog { Filter = "JSON 檔案 (*.json)|*.json", FileName = "copy-tool-buttons.json" };
        if (dlg.ShowDialog() == true)
        {
            JsonStore.SaveExport(dlg.FileName, new List<ButtonItem>(Items), OrderGroups(GetDistinctGroups()));
            ShowStatus("已匯出設定檔");
        }
    }

    private void Import_Click(object sender, RoutedEventArgs e)
    {
        var dlg = new OpenFileDialog { Filter = "JSON 檔案 (*.json)|*.json" };
        if (dlg.ShowDialog() != true) { return; }

        try
        {
            // 先完整解析成功才動現有資料；舊格式（純陣列）沒有順序資訊，沿用目前的分類順序。
            var imported = JsonStore.LoadExport(dlg.FileName);
            Items.Clear();
            foreach (var item in imported.Items) { AddItemWithAutoSave(item, save: false); }
            if (imported.GroupOrder is not null) { _settings.GroupOrder = imported.GroupOrder; }
            SaveItems();
            SaveSettings();
            RefreshAll();
            ShowStatus("已匯入設定");
        }
        catch (Exception ex)
        {
            MessageBox.Show("匯入失敗，請確認是本工具匯出的 JSON 檔案。\n" + ex.Message, "錯誤");
        }
    }

    // 一般檢視模式沒有直向內容可以捲，滾輪預設轉不動；改成滾輪帶動橫向捲動，
    // 體感上才會像左右滑動。編輯模式維持滾輪原本的直向捲動，不套用這段。
    private void ViewScroller_PreviewMouseWheel(object sender, System.Windows.Input.MouseWheelEventArgs e)
    {
        if (ViewScroller.ScrollableWidth <= 0) { return; }
        e.Handled = true;
        ViewScroller.ScrollToHorizontalOffset(ViewScroller.HorizontalOffset - e.Delta);
    }

    private void SizePlus_Click(object sender, RoutedEventArgs e) => AdjustButtonSize(ButtonSizeStep);

    private void SizeMinus_Click(object sender, RoutedEventArgs e) => AdjustButtonSize(-ButtonSizeStep);

    private void AdjustButtonSize(int delta)
    {
        ButtonTileWidth += delta;
        SaveSettings();
    }

    private void FilterToggle_Click(object sender, RoutedEventArgs e)
    {
        if (FilterPopup.IsOpen) { FilterPopup.IsOpen = false; return; }
        PruneAndRefreshFilter();
        BuildFilterOptions();
        FilterPopup.IsOpen = true;
    }

    private void FilterCheckBox_Click(object sender, RoutedEventArgs e)
    {
        if (sender is not CheckBox { Tag: string groupName } cb) { return; }
        if (cb.IsChecked == true) { _selectedGroups.Add(groupName); } else { _selectedGroups.Remove(groupName); }
        UpdateFilterButtonText();
        RefreshAll();
    }

    private void FilterGroupUp_Click(object sender, RoutedEventArgs e)
    {
        if (sender is Button { Tag: string groupName })
        {
            MoveGroupOrder(groupName, -1);
            BuildFilterOptions();
            RefreshAll();
        }
    }

    private void FilterGroupDown_Click(object sender, RoutedEventArgs e)
    {
        if (sender is Button { Tag: string groupName })
        {
            MoveGroupOrder(groupName, 1);
            BuildFilterOptions();
            RefreshAll();
        }
    }

    private void ClearFilter_Click(object sender, RoutedEventArgs e)
    {
        _selectedGroups.Clear();
        UpdateFilterButtonText();
        RefreshAll();
        FilterPopup.IsOpen = false;
    }

    private void RootWindow_Closing(object? sender, CancelEventArgs e)
    {
        SaveSettings();
    }
}
