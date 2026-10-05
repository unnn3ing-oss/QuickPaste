namespace CopyTool.Services;

public static class ButtonSizing
{
    private const double DefaultWidth = 90;
    private const double DefaultFontSize = 16;
    private const double MinFontSize = 11;
    private const double MaxFontSize = 22;

    // 按鈕名稱的字級隨按鈕寬度等比縮放：預設寬度 90 維持原本的 16，
    // 縮小到 70 時兩行字仍放得進最小高度 48，放大時有上限避免字太大。
    public static double FontSizeFor(double tileWidth)
        => Math.Max(MinFontSize, Math.Min(MaxFontSize, tileWidth * DefaultFontSize / DefaultWidth));
}
