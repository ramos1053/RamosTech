namespace Snipster.Models;

/// <summary>
/// App-level settings, separate from the snippet library itself — stored at
/// a FIXED default location even when the library file is relocated (see
/// CustomLibraryFolder), since this is what tells the app where to look.
/// </summary>
public class Preferences
{
    public bool LaunchAtStartup { get; set; }
    public bool TextExpansionEnabled { get; set; } = true;
    public int ClipboardHistoryMaxEntries { get; set; } = 50;

    /// <summary>Null = default %LOCALAPPDATA%\Snipster location.</summary>
    public string? CustomLibraryFolder { get; set; }
}
