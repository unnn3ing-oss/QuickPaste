namespace CopyTool.Models;

// 視窗大小、按鈕尺寸、分類自訂排序的本機設定，存在 copy-tool-settings.json。
public class AppSettings
{
    public int WindowWidth { get; set; } = 560;
    public int WindowHeight { get; set; } = 240;
    public int ButtonTileWidth { get; set; } = 90;
    public List<string> GroupOrder { get; set; } = new();
}
