using System.Windows;
using CopyTool.Models;

namespace CopyTool;

// 每次開啟應用程式時詢問今天值班哪些粉專。預設全部不勾；
// 按「顯示全部」、不勾直接確定、或直接關閉視窗，都代表不篩選。
public partial class GroupPromptWindow : Window
{
    private readonly List<FilterOptionItem> _options;

    public IReadOnlyList<string> SelectedGroups { get; private set; } = Array.Empty<string>();

    public GroupPromptWindow(IEnumerable<string> groups)
    {
        InitializeComponent();
        _options = groups.Select(g => new FilterOptionItem { Name = g }).ToList();
        OptionsList.ItemsSource = _options;
    }

    private void Ok_Click(object sender, RoutedEventArgs e)
    {
        SelectedGroups = _options.Where(o => o.IsChecked).Select(o => o.Name).ToList();
        DialogResult = true;
    }

    private void ShowAll_Click(object sender, RoutedEventArgs e)
    {
        SelectedGroups = Array.Empty<string>();
        DialogResult = true;
    }
}
