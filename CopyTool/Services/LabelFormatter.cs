using System.Globalization;

namespace CopyTool.Services;

public static class LabelFormatter
{
    // 按鈕名稱最多顯示兩行：
    // 1. 名稱含「/」：在第一個「/」換行（「/」是換行記號，不顯示），例如「新聞/文字」→「新聞」「文字」。
    // 2. 沒有「/」：前兩個字為第一行，其餘為第二行，例如「新聞脆」→「新聞」「脆」。
    // 3. 名稱結尾加「/」：不換行，整個名稱一行（「/」不顯示），例如「擠看看/」→「擠看看」。
    // 名稱最前面的「/」會被忽略。兩個字以內不換行。
    public static string ToTwoLines(string? label)
    {
        string raw = (label ?? "").TrimStart('/');
        string text = raw.TrimEnd('/');
        if (text.Length == 0) { return ""; }
        if (raw.Length != text.Length) { return text; }

        int slash = text.IndexOf('/');
        if (slash > 0)
        {
            return text.Substring(0, slash).TrimEnd() + "\n" + text.Substring(slash + 1).TrimStart();
        }

        // 用文字元素計算，避免把 emoji 等代理對從中間切開。
        var info = new StringInfo(text);
        if (info.LengthInTextElements <= 2) { return text; }
        return info.SubstringByTextElements(0, 2) + "\n" + info.SubstringByTextElements(2);
    }
}
