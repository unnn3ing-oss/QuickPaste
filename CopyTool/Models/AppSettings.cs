namespace CopyTool.Models;

// 視窗大小、按鈕尺寸、分類自訂排序與分類顏色的本機設定，存在 copy-tool-settings.json。
public class AppSettings
{
    public int WindowWidth { get; set; } = 450;
    public int WindowHeight { get; set; } = 155;
    public int ButtonTileWidth { get; set; } = 90;
    public List<string> GroupOrder { get; set; } = new();

    // 分類名稱 → 色帶顏色（#RRGGBB）。沒有的分類會自動分配並存回來，也可以手動改。
    public Dictionary<string, string> GroupColors { get; set; } = new();
}
