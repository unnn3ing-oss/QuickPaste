using System.Collections.ObjectModel;

namespace CopyTool.Services;

public static class CollectionSync
{
    // 把 target 的內容與順序調整成 desired，只用 Remove / Move / Insert，
    // 不用 Clear()。ObservableCollection.Clear() 會發出 Reset，可編輯 ComboBox 收到
    // Reset 會把 Text 重設成空字串，並透過 TwoWay binding 寫回來源屬性，
    // 結果每次重新整理分類建議清單都把所有按鈕的分類洗成空白。
    // desired 不可含重複元素（呼叫端是 GetDistinctGroups 的結果，本來就不重複）。
    public static void Sync<T>(ObservableCollection<T> target, IReadOnlyList<T> desired)
        where T : notnull
    {
        var desiredSet = new HashSet<T>(desired);
        for (int i = target.Count - 1; i >= 0; i--)
        {
            if (!desiredSet.Contains(target[i])) { target.RemoveAt(i); }
        }

        for (int i = 0; i < desired.Count; i++)
        {
            if (i < target.Count && EqualityComparer<T>.Default.Equals(target[i], desired[i])) { continue; }

            int existing = IndexOf(target, desired[i], i + 1);
            if (existing >= 0) { target.Move(existing, i); }
            else { target.Insert(i, desired[i]); }
        }
    }

    private static int IndexOf<T>(ObservableCollection<T> list, T value, int start)
    {
        for (int i = start; i < list.Count; i++)
        {
            if (EqualityComparer<T>.Default.Equals(list[i], value)) { return i; }
        }
        return -1;
    }
}
