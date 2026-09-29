using System.Globalization;
using System.Text;
using System.Windows.Data;

namespace CopyTool.Converters;

// 按鈕文字每 N 個字元強制換行（預設 4），對應舊版 WrapLabelText 的行為，
// 讓長短不一的名稱在同樣大小的按鈕裡排版整齊、可預期。
public class ChunkLabelConverter : IValueConverter
{
    public object Convert(object? value, Type targetType, object? parameter, CultureInfo culture)
    {
        string text = value as string ?? "";
        int chunkSize = 4;
        if (parameter is string p && int.TryParse(p, out int parsed) && parsed > 0) { chunkSize = parsed; }
        if (text.Length == 0) { return text; }

        var sb = new StringBuilder();
        for (int i = 0; i < text.Length; i += chunkSize)
        {
            if (i > 0) { sb.Append('\n'); }
            sb.Append(text.Substring(i, Math.Min(chunkSize, text.Length - i)));
        }
        return sb.ToString();
    }

    public object ConvertBack(object? value, Type targetType, object? parameter, CultureInfo culture)
        => throw new NotSupportedException();
}
