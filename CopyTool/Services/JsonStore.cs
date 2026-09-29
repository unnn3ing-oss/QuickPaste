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

    public static List<ButtonItem> DefaultItems() => new()
    {
        new ButtonItem { Label = "範例按鈕 1", Text = "這裡是要被複製的文字內容 1" },
        new ButtonItem { Label = "範例按鈕 2", Text = "這裡是要被複製的文字內容 2" },
    };
}
