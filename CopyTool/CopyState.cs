using System.Windows;

namespace CopyTool;

// 「這顆按鈕剛複製完」的狀態，給 CopyButtonStyle 的樣板觸發器用。
// 不直接改 Background：樣板裡 hover 觸發器會把底色蓋掉，滑鼠還停在按鈕上時
// （剛點完一定還在）綠色回饋就看不到。改用狀態屬性，觸發器排在 hover 之後就會贏。
public static class CopyState
{
    public static readonly DependencyProperty IsCopiedProperty =
        DependencyProperty.RegisterAttached("IsCopied", typeof(bool), typeof(CopyState), new PropertyMetadata(false));

    public static bool GetIsCopied(DependencyObject obj) => (bool)obj.GetValue(IsCopiedProperty);
    public static void SetIsCopied(DependencyObject obj, bool value) => obj.SetValue(IsCopiedProperty, value);
}
