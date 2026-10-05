using System.Globalization;
using System.Windows.Data;
using CopyTool.Services;

namespace CopyTool.Converters;

// 按鈕名稱字級跟著按鈕寬度走，規則見 ButtonSizing.FontSizeFor。
public class TileFontSizeConverter : IValueConverter
{
    public object Convert(object? value, Type targetType, object? parameter, CultureInfo culture)
    {
        double width = value switch
        {
            int i => i,
            double d => d,
            _ => 90,
        };
        return ButtonSizing.FontSizeFor(width);
    }

    public object ConvertBack(object? value, Type targetType, object? parameter, CultureInfo culture)
        => throw new NotSupportedException();
}
