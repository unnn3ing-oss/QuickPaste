namespace CopyTool.Models;

// 值班粉專篩選彈出視窗裡的一列（純畫面用的暫存物件，每次開啟彈出視窗都會
// 重新從 Items 現況建構，不需要參與 JSON 存檔，也不需要 INotifyPropertyChanged）。
public class FilterOptionItem
{
    public string Name { get; set; } = "";
    public bool IsChecked { get; set; }
    public bool CanMoveUp { get; set; }
    public bool CanMoveDown { get; set; }
}
