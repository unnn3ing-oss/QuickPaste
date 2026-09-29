using System.ComponentModel;
using System.Runtime.CompilerServices;

namespace CopyTool.Models;

// 一顆複製按鈕對應的資料。實作 INotifyPropertyChanged 是為了讓編輯模式的
// 文字輸入框用 TwoWay binding 改值時，MainWindow 能訂閱 PropertyChanged
// 做到「改了立即存檔」（跟舊版 WinForms 的 TextChanged += SaveItems 行為一致）。
public class ButtonItem : INotifyPropertyChanged
{
    private string _id = Guid.NewGuid().ToString("N")[..8];
    private string _label = "";
    private string _text = "";
    private string _group = "";

    public string Id
    {
        get => _id;
        set => SetField(ref _id, value);
    }

    public string Label
    {
        get => _label;
        set => SetField(ref _label, value);
    }

    public string Text
    {
        get => _text;
        set => SetField(ref _text, value);
    }

    // 分類／粉專，可留空（顯示為「未分類」）。
    public string Group
    {
        get => _group;
        set => SetField(ref _group, value);
    }

    public event PropertyChangedEventHandler? PropertyChanged;

    private void SetField<T>(ref T field, T value, [CallerMemberName] string? propertyName = null)
    {
        if (Equals(field, value)) { return; }
        field = value;
        PropertyChanged?.Invoke(this, new PropertyChangedEventArgs(propertyName));
    }
}
