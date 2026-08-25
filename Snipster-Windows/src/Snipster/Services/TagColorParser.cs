using Color = System.Windows.Media.Color;
using ColorConverter = System.Windows.Media.ColorConverter;
using Colors = System.Windows.Media.Colors;
using SolidColorBrush = System.Windows.Media.SolidColorBrush;

namespace Snipster.Services;

/// <summary>
/// Parses a Tag's stored hex color into a WPF brush. Shared by every view
/// that renders a tag swatch, so a malformed hex string degrades the same
/// way everywhere instead of each view inventing its own fallback.
/// </summary>
internal static class TagColorParser
{
    public static bool TryParse(string hex, out SolidColorBrush brush)
    {
        try
        {
            brush = new SolidColorBrush((Color)ColorConverter.ConvertFromString(hex));
            return true;
        }
        catch
        {
            brush = new SolidColorBrush(Colors.Transparent);
            return false;
        }
    }
}
