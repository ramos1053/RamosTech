using System.Collections.ObjectModel;
using System.Windows;
using Snipster.Models;
using Snipster.Storage;

namespace Snipster.Views;

/// <summary>
/// Add/edit/delete UI for the snippet library — the macOS app's counterpart
/// managed snippets through its main window; here it's reachable from the
/// tray menu since this port has no persistent main window.
/// </summary>
public partial class SnippetManagerWindow : Window
{
    // Sentinel representing "no tag" in the ComboBox — a Tag with Id == ""
    // is never a real tag (FileStorageManager always assigns a GUID), so
    // this can't collide with an actual saved tag.
    private static readonly Tag NoTagOption = new() { Id = "", Name = "(No Tag)" };

    private readonly SnippetLibrary _library;
    private readonly FileStorageManager _storage;
    private readonly ObservableCollection<Snippet> _snippets;
    private Snippet? _selected;

    public SnippetManagerWindow(SnippetLibrary library, FileStorageManager storage, string? prefillContent = null)
    {
        InitializeComponent();
        _library = library;
        _storage = storage;
        _snippets = new ObservableCollection<Snippet>(_library.Snippets);

        SnippetList.ItemsSource = _snippets;
        RefreshTagBoxItems();

        if (prefillContent is not null)
            AddSnippetFromClipboard(prefillContent);
        else if (_snippets.Count > 0)
            SnippetList.SelectedIndex = 0;
    }

    /// <summary>
    /// Public so App.xaml.cs can call this on an ALREADY-OPEN window too —
    /// "Create Snippet from This..." must still work if Manage Snippets was
    /// already open, not silently drop the content when the window just
    /// gets activated instead of constructed fresh.
    /// </summary>
    public void AddSnippetFromClipboard(string content)
    {
        AddNewSnippet(content);

        // Focus() is a no-op before the window has actually loaded (a fresh
        // instance isn't shown yet at this point), so defer it; but if this
        // is an already-open window, focusing right away is correct.
        if (IsLoaded)
            FocusTriggerBox();
        else
            Loaded += (_, _) => FocusTriggerBox();
    }

    private void FocusTriggerBox()
    {
        TriggerBox.Focus();
        TriggerBox.SelectAll();
    }

    private void RefreshTagBoxItems()
    {
        TagBox.ItemsSource = new[] { NoTagOption }.Concat(_library.Tags).ToList();
    }

    private void SnippetList_SelectionChanged(object sender, System.Windows.Controls.SelectionChangedEventArgs e)
    {
        _selected = SnippetList.SelectedItem as Snippet;
        EditorPanel.IsEnabled = _selected is not null;
        ValidationLabel.Visibility = Visibility.Collapsed;

        if (_selected is null)
        {
            TriggerBox.Text = "";
            ContentBox.Text = "";
            TagBox.SelectedItem = NoTagOption;
            return;
        }

        TriggerBox.Text = _selected.Trigger;
        ContentBox.Text = _selected.Content;
        TagBox.SelectedItem = _library.Tags.FirstOrDefault(t => t.Id == _selected.TagId) ?? NoTagOption;
    }

    private void New_Click(object sender, RoutedEventArgs e) => AddNewSnippet("");

    private void AddNewSnippet(string content)
    {
        // No tag by design — a snippet is fully functional with TagId left
        // null; tags are organization only, never a requirement to expand.
        var snippet = new Snippet { Trigger = "!new", Content = content };
        _snippets.Add(snippet);
        SnippetList.SelectedItem = snippet;
    }

    private void Delete_Click(object sender, RoutedEventArgs e)
    {
        if (_selected is null) return;
        _snippets.Remove(_selected);
        SaveToLibrary();
    }

    private void ManageTags_Click(object sender, RoutedEventArgs e)
    {
        var previouslySelectedTagId = (TagBox.SelectedItem as Tag)?.Id;

        var tagManager = new TagManagerWindow(_library, _storage) { Owner = this };
        tagManager.ShowDialog();

        RefreshTagBoxItems();

        // Restore the selection if that tag still exists; fall back to "no
        // tag" if it was the one just deleted, rather than silently picking
        // something else.
        TagBox.SelectedItem = _library.Tags.FirstOrDefault(t => t.Id == previouslySelectedTagId) ?? NoTagOption;
    }

    private void Save_Click(object sender, RoutedEventArgs e)
    {
        if (_selected is null) return;

        var trigger = TriggerBox.Text.Trim();
        if (string.IsNullOrEmpty(trigger))
        {
            ShowValidationError("Trigger can't be empty.");
            return;
        }

        // The expansion monitor matches by suffix against the FIRST
        // snippet found — a duplicate trigger would silently shadow
        // whichever snippet loses that race, so it's rejected outright.
        var conflict = _snippets.FirstOrDefault(s =>
            s.Id != _selected.Id && string.Equals(s.Trigger, trigger, StringComparison.OrdinalIgnoreCase));

        if (conflict is not null)
        {
            ShowValidationError($"Trigger \"{trigger}\" is already used by another snippet.");
            return;
        }

        var chosenTag = TagBox.SelectedItem as Tag;
        _selected.Trigger = trigger;
        _selected.Content = ContentBox.Text;
        _selected.TagId = chosenTag is null || chosenTag.Id == NoTagOption.Id ? null : chosenTag.Id;
        _selected.ModifiedAt = DateTimeOffset.UtcNow;

        ValidationLabel.Visibility = Visibility.Collapsed;
        SnippetList.Items.Refresh();
        SaveToLibrary();
    }

    private void ShowValidationError(string message)
    {
        ValidationLabel.Text = message;
        ValidationLabel.Visibility = Visibility.Visible;
    }

    private void SaveToLibrary()
    {
        _library.Snippets.Clear();
        _library.Snippets.AddRange(_snippets);
        _storage.Save(_library);
    }
}
