using System.IO;
using System.Text.Json;
using Snipster.Models;

namespace Snipster.Storage;

/// <summary>
/// Persists to %LOCALAPPDATA%\Snipster\snipster-library.json by default —
/// a per-user, per-machine path that never requires elevation to read or
/// write, unlike the macOS app's ~/Library/Application Support equivalent.
/// </summary>
public class FileStorageManager
{
    private static readonly JsonSerializerOptions JsonOptions = new()
    {
        WriteIndented = true,
    };

    public string LibraryFilePath { get; }

    public FileStorageManager(string? customFolder = null)
    {
        var folder = customFolder ?? Path.Combine(
            Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),
            "Snipster");

        Directory.CreateDirectory(folder);
        LibraryFilePath = Path.Combine(folder, "snipster-library.json");
    }

    public SnippetLibrary Load()
    {
        if (!File.Exists(LibraryFilePath))
        {
            var seeded = CreateSeedLibrary();
            Save(seeded);
            return seeded;
        }

        var json = File.ReadAllText(LibraryFilePath);
        return JsonSerializer.Deserialize<SnippetLibrary>(json, JsonOptions) ?? new SnippetLibrary();
    }

    public void Save(SnippetLibrary library)
    {
        var json = JsonSerializer.Serialize(library, JsonOptions);

        // Write-to-temp-then-rename avoids a half-written JSON file if the
        // process is killed mid-save. File.Move (same volume) is an atomic
        // rename; Copy+Delete is NOT atomic and can itself be interrupted
        // mid-copy, defeating the whole point of this pattern.
        var tempPath = LibraryFilePath + ".tmp";
        File.WriteAllText(tempPath, json);
        File.Move(tempPath, LibraryFilePath, overwrite: true);
    }

    /// <summary>Export/import use an arbitrary path, unlike the main library file.</summary>
    public static void SaveTo(string path, SnippetLibrary library) =>
        File.WriteAllText(path, JsonSerializer.Serialize(library, JsonOptions));

    public static SnippetLibrary LoadFrom(string path) =>
        JsonSerializer.Deserialize<SnippetLibrary>(File.ReadAllText(path), JsonOptions)
        ?? throw new InvalidDataException("File did not contain a valid Snipster library.");

    /// <summary>
    /// Merges an imported library into the current one, skipping any
    /// incoming snippet whose trigger already exists — the simplest of the
    /// macOS app's three conflict strategies (merge/replace/skip), chosen
    /// here because it can never silently destroy existing snippets.
    /// </summary>
    public static int MergeSkippingDuplicates(SnippetLibrary target, SnippetLibrary incoming)
    {
        var existingTriggers = new HashSet<string>(
            target.Snippets.Select(s => s.Trigger), StringComparer.OrdinalIgnoreCase);

        var tagIdRemap = new Dictionary<string, string>();
        foreach (var tag in incoming.Tags)
        {
            var match = target.Tags.FirstOrDefault(t => string.Equals(t.Name, tag.Name, StringComparison.OrdinalIgnoreCase));
            if (match is not null)
            {
                tagIdRemap[tag.Id] = match.Id;
            }
            else
            {
                target.Tags.Add(tag);
                tagIdRemap[tag.Id] = tag.Id;
            }
        }

        var skipped = 0;
        foreach (var snippet in incoming.Snippets)
        {
            if (string.IsNullOrWhiteSpace(snippet.Trigger))
            {
                skipped++;
                continue;
            }

            if (!existingTriggers.Add(snippet.Trigger))
            {
                skipped++;
                continue;
            }

            if (snippet.TagId is not null && tagIdRemap.TryGetValue(snippet.TagId, out var remapped))
                snippet.TagId = remapped;

            target.Snippets.Add(snippet);
        }

        return skipped;
    }

    private static SnippetLibrary CreateSeedLibrary()
    {
        var generalTag = new Tag { Name = "General", ColorHex = "#4A90D9" };

        return new SnippetLibrary
        {
            Tags = new List<Tag> { generalTag },
            Snippets = new List<Snippet>
            {
                new()
                {
                    Trigger = "!email",
                    Content = "example@example.com",
                    TagId = generalTag.Id,
                },
                new()
                {
                    Trigger = "!addr",
                    Content = "123 Example St, Springfield, USA",
                    TagId = generalTag.Id,
                },
                new()
                {
                    Trigger = "!intro",
                    Content = "Hi {{INPUT:Name}}, you can reach me at {{INPUT:Email}}. Sent {{DATE}}.",
                    TagId = generalTag.Id,
                },
            },
            Contacts = new List<Contact>
            {
                new()
                {
                    Name = "Jane Doe",
                    Email = "jane.doe@example.com",
                    Phone = "555-0100",
                    Address = "456 Sample Ave, Springfield, USA",
                },
            },
        };
    }
}
