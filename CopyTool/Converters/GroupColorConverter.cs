using System.Globalization;
using System.Windows.Data;
using System.Windows.Media;
using CopyTool.Models;
using CopyTool.Services;

namespace CopyTool.Converters;

// 把按鈕（ButtonItem）轉成它所屬分類的色帶顏色。顏色表由 MainWindow 在啟動時
// 指到設定檔的 GroupColors，所以自動配色或手動改色後，下次重新整理就會生效。
// 未分類、查不到、或色碼格式錯誤都回傳透明（不顯示色帶）。
public class GroupColorConverter : IValueConverter
{
    public Dictionary<string, string> Colors { get; set; } = new();

    private readonly Dictionary<string, Brush> _cache = new(StringComparer.OrdinalIgnoreCase);

    public object Convert(object? value, Type targetType, object? parameter, CultureInfo culture)
    {
        if (value is not ButtonItem { Group: { Length: > 0 } group }) { return Brushes.Transparent; }
        if (!Colors.TryGetValue(group, out var hex) || !GroupColors.IsValidHex(hex)) { return Brushes.Transparent; }

        if (!_cache.TryGetValue(hex, out var brush))
        {
            brush = new SolidColorBrush((Color)ColorConverter.ConvertFromString(hex));
            brush.Freeze();
            _cache[hex] = brush;
        }
        return brush;
    }

    public object ConvertBack(object? value, Type targetType, object? parameter, CultureInfo culture)
        => throw new NotSupportedException();
}
