namespace Snipster.Models;

/// <summary>
/// Combined-file format, mirrors the macOS app's single snipster-library.json
/// (snippets + tags together) so exports remain interchangeable between ports.
/// </summary>
public class SnippetLibrary
{
    public int Version { get; set; } = 1;
    public List<Snippet> Snippets { get; set; } = new();
    public List<Tag> Tags { get; set; } = new();
    public List<Contact> Contacts { get; set; } = new();
}
