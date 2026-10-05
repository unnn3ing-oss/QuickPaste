using System.Text.RegularExpressions;

namespace CopyTool.Services;

public static class GroupColors
{
    // 使用者沒指定顏色的新分類，從這個色盤依序挑一個還沒被用過的。
    // 刻意避開預設的藍／桃紅／深藍／綠／鵝黃，免得跟常用分類撞色。
    public static readonly string[] FallbackPalette =
    {
        "#9B7BF0", // 紫
        "#F5A340", // 橘
        "#2EC4B6", // 青
        "#A8B0BD", // 灰
        "#E86A5C", // 珊瑚
        "#8BC34A", // 草綠
        "#5CC8F2", // 天藍
        "#D98BE0", // 粉紫
    };

    private static readonly Regex HexPattern = new("^#[0-9A-Fa-f]{6}$", RegexOptions.Compiled);

    public static bool IsValidHex(string? value) => value != null && HexPattern.IsMatch(value);

    // 幫還沒有顏色的分類配色，已經有顏色的一律不動（包含使用者手動改過的）。
    // 回傳 true 表示有新增，呼叫端要存檔。「未分類」（空字串）不配色。
    public static bool EnsureAssigned(IEnumerable<string?> groups, Dictionary<string, string> colors)
    {
        bool changed = false;
        foreach (var group in groups)
        {
            if (string.IsNullOrEmpty(group) || colors.ContainsKey(group)) { continue; }

            var used = new HashSet<string>(colors.Values, StringComparer.OrdinalIgnoreCase);
            string pick = FallbackPalette.FirstOrDefault(c => !used.Contains(c))
                          ?? FallbackPalette[colors.Count % FallbackPalette.Length];
            colors[group] = pick;
            changed = true;
        }
        return changed;
    }
}
