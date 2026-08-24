using System.IO;
using System.Text.Json;
using Snipster.Models;

namespace Snipster.Storage;

/// <summary>
/// Always lives at the fixed default %LOCALAPPDATA%\Snipster\preferences.json
/// — unlike the snippet library, this can never be relocated, since it's
/// what tells the app where a relocated library actually lives.
/// </summary>
public class PreferencesStore
{
    private static readonly JsonSerializerOptions JsonOptions = new() { WriteIndented = true };

    private readonly string _path;

    public PreferencesStore()
    {
        var folder = Path.Combine(
            Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), "Snipster");
        Directory.CreateDirectory(folder);
        _path = Path.Combine(folder, "preferences.json");
    }

    public Preferences Load()
    {
        if (!File.Exists(_path)) return new Preferences();

        try
        {
            return JsonSerializer.Deserialize<Preferences>(File.ReadAllText(_path), JsonOptions) ?? new Preferences();
        }
        catch (JsonException)
        {
            return new Preferences();
        }
    }

    public void Save(Preferences preferences)
    {
        var json = JsonSerializer.Serialize(preferences, JsonOptions);
        var tempPath = _path + ".tmp";
        File.WriteAllText(tempPath, json);
        File.Move(tempPath, _path, overwrite: true);
    }
}
