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

    /// <summary>Whether Manage Snippets was left grouping its list by tag.</summary>
    public bool SnippetManagerGroupByTag { get; set; }

    /// <summary>
    /// Names of tag groups left collapsed in Manage Snippets — keyed by tag
    /// name (the group identity the list already groups by) rather than tag
    /// Id, since that's the value the collapse/expand UI actually observes.
    /// </summary>
    public List<string> SnippetManagerCollapsedTagGroups { get; set; } = new();
}
