using System.IO;
using System.Text.Json;
using CopyTool.Models;

namespace CopyTool.Services;

// 讀寫 AppSettings（視窗大小/按鈕尺寸/分類排序）。還沒被 MainWindow 使用，
// 見 HANDOFF.md 待辦清單——這是給接下來實作用的現成工具。
public static class SettingsStore
{
    private static readonly JsonSerializerOptions Options = new() { WriteIndented = true };

    public static AppSettings Load(string path)
    {
        if (!File.Exists(path)) { return new AppSettings(); }
        try
        {
            string json = File.ReadAllText(path);
            return JsonSerializer.Deserialize<AppSettings>(json, Options) ?? new AppSettings();
        }
        catch
        {
            return new AppSettings();
        }
    }

    public static void Save(string path, AppSettings settings)
    {
        string json = JsonSerializer.Serialize(settings, Options);
        File.WriteAllText(path, json);
    }
}
