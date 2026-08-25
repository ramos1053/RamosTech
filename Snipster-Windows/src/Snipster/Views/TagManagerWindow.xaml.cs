using System.Collections.ObjectModel;
using System.Windows;
using Snipster.Models;
using Snipster.Services;
using Snipster.Storage;
using Brush = System.Windows.Media.Brush;
using Brushes = System.Windows.Media.Brushes;

namespace Snipster.Views;

/// <summary>
/// Add/edit/delete UI for tags — previously the library only ever had the
/// single seeded "General" tag with no way to change that.
/// </summary>
public partial class TagManagerWindow : Window
{
    private readonly SnippetLibrary _library;
    private readonly FileStorageManager _storage;
    private readonly ObservableCollection<TagListItem> _items;
    private TagListItem? _selected;
    private bool _suppressColorPreviewUpdate;

    public TagManagerWindow(SnippetLibrary library, FileStorageManager storage)
    {
        InitializeComponent();
        _library = library;
        _storage = storage;
        _items = new ObservableCollection<TagListItem>(
            _library.Tags.Select(t => new TagListItem(t, CountSnippetsForTag(t.Id))));

        TagList.ItemsSource = _items;
        if (_items.Count > 0) TagList.SelectedIndex = 0;
    }

    private void TagList_SelectionChanged(object sender, System.Windows.Controls.SelectionChangedEventArgs e)
    {
        _selected = TagList.SelectedItem as TagListItem;
        EditorPanel.IsEnabled = _selected is not null;
        ValidationLabel.Visibility = Visibility.Collapsed;

        _suppressColorPreviewUpdate = true;
        NameBox.Text = _selected?.Tag.Name ?? "";
        ColorBox.Text = _selected?.Tag.ColorHex ?? "";
        _suppressColorPreviewUpdate = false;
        UpdateColorPreview();
    }

    private void ColorBox_TextChanged(object sender, System.Windows.Controls.TextChangedEventArgs e)
    {
        if (!_suppressColorPreviewUpdate) UpdateColorPreview();
    }

    /// <summary>
    /// The actual "real" color picker — hex codes stay available in the text
    /// box for anyone who wants one, but this is the primary way to pick a
    /// color without knowing hex at all.
    /// </summary>
    private void ChooseColor_Click(object sender, RoutedEventArgs e)
    {
        using var dialog = new System.Windows.Forms.ColorDialog
        {
            FullOpen = true,
            AnyColor = true,
        };

        if (TagColorParser.TryParse(ColorBox.Text, out var currentBrush) && currentBrush.Color is var c)
            dialog.Color = System.Drawing.Color.FromArgb(c.A, c.R, c.G, c.B);

        if (dialog.ShowDialog() != System.Windows.Forms.DialogResult.OK) return;

        ColorBox.Text = $"#{dialog.Color.R:X2}{dialog.Color.G:X2}{dialog.Color.B:X2}";
    }

    private void UpdateColorPreview()
    {
        ColorPreview.Fill = TagColorParser.TryParse(ColorBox.Text, out var brush) ? brush : Brushes.Transparent;
    }

    private int CountSnippetsForTag(string tagId) => _library.Snippets.Count(s => s.TagId == tagId);

    private void New_Click(object sender, RoutedEventArgs e)
    {
        var tag = new Tag { Name = "New Tag", ColorHex = "#808080" };
        _library.Tags.Add(tag);
        var item = new TagListItem(tag, 0);
        _items.Add(item);
        TagList.SelectedItem = item;
    }

    private void Delete_Click(object sender, RoutedEventArgs e)
    {
        if (_selected is null) return;

        var deletedTag = _selected.Tag;

        _library.Tags.Remove(deletedTag);

        // Removing the selected item fires SelectionChanged synchronously,
        // which reassigns the `_selected` field (to another tag, or null if
        // the list is now empty) before this method continues. `deletedTag`
        // was captured above so the snippet cleanup below still targets the
        // tag that was actually deleted, not whatever `_selected` becomes.
        _items.Remove(_selected);

        // Snippets pointing at the deleted tag must fall back to "no tag" —
        // expansion never depended on a tag, but a dangling TagId would
        // show up as a broken reference in the snippet editor.
        foreach (var snippet in _library.Snippets.Where(s => s.TagId == deletedTag.Id))
            snippet.TagId = null;

        _storage.Save(_library);
    }

    private void Save_Click(object sender, RoutedEventArgs e)
    {
        if (_selected is null) return;

        var name = NameBox.Text.Trim();
        if (string.IsNullOrEmpty(name))
        {
            ShowValidationError("Name can't be empty.");
            return;
        }

        if (!TagColorParser.TryParse(ColorBox.Text, out _))
        {
            ShowValidationError("Color must be a valid hex code, e.g. #4A90D9.");
            return;
        }

        _selected.Tag.Name = name;
        _selected.Tag.ColorHex = ColorBox.Text.Trim();
        _selected.Refresh();

        ValidationLabel.Visibility = Visibility.Collapsed;
        TagList.Items.Refresh();
        _storage.Save(_library);
    }

    private void ShowValidationError(string message)
    {
        ValidationLabel.Text = message;
        ValidationLabel.Visibility = Visibility.Visible;
    }

    /// <summary>Wraps a Tag with a pre-parsed swatch brush and snippet count for the ListBox's DataTemplate.</summary>
    public class TagListItem
    {
        public Tag Tag { get; }
        public string Name => Tag.Name;
        public Brush SwatchBrush { get; private set; }
        public int SnippetCount { get; }
        public string SnippetCountLabel => SnippetCount == 1 ? "(1 snippet)" : $"({SnippetCount} snippets)";

        public TagListItem(Tag tag, int snippetCount)
        {
            Tag = tag;
            SnippetCount = snippetCount;
            SwatchBrush = TagColorParser.TryParse(tag.ColorHex, out var brush) ? brush : Brushes.Gray;
        }

        public void Refresh() => SwatchBrush = TagColorParser.TryParse(Tag.ColorHex, out var brush) ? brush : Brushes.Gray;
    }
}
