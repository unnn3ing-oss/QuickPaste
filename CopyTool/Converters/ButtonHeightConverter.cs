using System.Globalization;
using System.Windows.Data;

namespace CopyTool.Converters;

// 按鈕高度跟寬度連動（長寬比接近 3:2，比 4:3 更緊湊）。使用者只需要調整
// 寬度，高度照比例自動算出來，跟舊版 RenderView 裡的算法一致。
public class ButtonHeightConverter : IValueConverter
{
    public object Convert(object? value, Type targetType, object? parameter, CultureInfo culture)
    {
        double width = value switch
        {
            int i => i,
            double d => d,
            _ => 120,
        };
        return Math.Max(48, width * 0.68);
    }

    public object ConvertBack(object? value, Type targetType, object? parameter, CultureInfo culture)
        => throw new NotSupportedException();
}
