using System.IO;
using System.Text.Encodings.Web;
using System.Text.Json;
using CopyTool.Models;

namespace CopyTool.Services;

// 用 .NET 內建的 System.Text.Json，取代舊版 WinForms 那版手刻的 MiniJson
// parser（那是因為舊環境沒有方便的套件管理才不得已手寫的，正規專案不需要）。
public static class JsonStore
{
    private static readonly JsonSerializerOptions Options = new()
    {
        WriteIndented = true,
        Encoder = JavaScriptEncoder.UnsafeRelaxedJsonEscaping, // 允許中文等非 ASCII 字元原樣輸出，不要變成 \uXXXX
    };

    public static List<ButtonItem> Load(string path)
    {
        if (!File.Exists(path)) { return DefaultItems(); }
        try
        {
            string json = File.ReadAllText(path);
            var items = JsonSerializer.Deserialize<List<ButtonItem>>(json, Options);
            return (items is { Count: > 0 }) ? items : DefaultItems();
        }
        catch
        {
            return DefaultItems();
        }
    }

    public static void Save(string path, List<ButtonItem> items)
    {
        string json = JsonSerializer.Serialize(items, Options);
        File.WriteAllText(path, json);
    }

    // 匯出檔：按鈕清單加上分類顯示順序（順序存在 copy-tool-settings.json，
    // 不跟著按鈕檔走，換電腦匯入時才不會順序全部重置）。
    public record ImportResult(List<ButtonItem> Items, List<string>? GroupOrder);

    private class ExportFile
    {
        public List<ButtonItem?>? Buttons { get; set; }
        public List<string>? GroupOrder { get; set; }
    }

    public static void SaveExport(string path, List<ButtonItem> items, List<string> groupOrder)
    {
        string json = JsonSerializer.Serialize(new ExportFile { Buttons = items!, GroupOrder = groupOrder }, Options);
        File.WriteAllText(path, json);
    }

    // 匯入專用的嚴格讀取：檔案有任何問題都丟例外，讓呼叫端顯示錯誤並保留現有資料。
    // 不能用 Load()——它為了讓程式啟動時永遠有東西可顯示，會吞掉例外並回傳範例按鈕。
    // 同時接受新格式（物件，含 GroupOrder）與舊格式（純按鈕陣列，GroupOrder 為 null）。
    public static ImportResult LoadExport(string path)
    {
        string json = File.ReadAllText(path);
        using var doc = JsonDocument.Parse(json);

        List<ButtonItem?>? buttons;
        List<string>? order = null;
        switch (doc.RootElement.ValueKind)
        {
            case JsonValueKind.Array:
                buttons = doc.RootElement.Deserialize<List<ButtonItem?>>(Options);
                break;
            case JsonValueKind.Object:
                var file = doc.RootElement.Deserialize<ExportFile>(Options);
                buttons = file?.Buttons;
                order = file?.GroupOrder;
                break;
            default:
                throw new InvalidDataException("檔案內容不是按鈕清單。");
        }

        if (buttons is null || buttons.Count == 0) { throw new InvalidDataException("檔案裡沒有任何按鈕。"); }
        if (buttons.Any(b => b is null)) { throw new InvalidDataException("按鈕清單裡有空白項目。"); }
        return new ImportResult(buttons!.ToList<ButtonItem>(), order);
    }

    public static List<ButtonItem> DefaultItems() => new()
    {
        new ButtonItem { Label = "範例按鈕 1", Text = "這裡是要被複製的文字內容 1" },
        new ButtonItem { Label = "範例按鈕 2", Text = "這裡是要被複製的文字內容 2" },
    };
}
