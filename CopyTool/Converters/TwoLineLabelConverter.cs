using System.Globalization;
using System.Windows.Data;
using CopyTool.Services;

namespace CopyTool.Converters;

// 按鈕名稱顯示成最多兩行，規則見 LabelFormatter.ToTwoLines。
public class TwoLineLabelConverter : IValueConverter
{
    public object Convert(object? value, Type targetType, object? parameter, CultureInfo culture)
        => LabelFormatter.ToTwoLines(value as string);

    public object ConvertBack(object? value, Type targetType, object? parameter, CultureInfo culture)
        => throw new NotSupportedException();
}
