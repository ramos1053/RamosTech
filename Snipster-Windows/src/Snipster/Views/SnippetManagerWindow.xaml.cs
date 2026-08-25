using System.Collections.ObjectModel;
using System.ComponentModel;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Data;
using Snipster.Models;
using Snipster.Services;
using Snipster.Storage;
using Brush = System.Windows.Media.Brush;
using Brushes = System.Windows.Media.Brushes;

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
    private readonly Preferences _preferences;
    private readonly PreferencesStore _preferencesStore;
    private readonly ObservableCollection<SnippetListItem> _items;
    private readonly ICollectionView _view;

    // Which tag groups are collapsed, keyed by tag name — the same value
    // the group-by-tag view already groups on. Loaded from Preferences so
    // the layout persists across reopening this window (and across app
    // restarts), and handed to _groupExpandedConverter so the Expander in
    // each group's ControlTemplate can read it without a code-behind hook.
    private readonly HashSet<string> _collapsedGroups;
    private readonly GroupExpandedConverter _groupExpandedConverter;

    private SnippetListItem? _selected;
    private bool _isLoading = true;

    public SnippetManagerWindow(
        SnippetLibrary library, FileStorageManager storage,
        Preferences preferences, PreferencesStore preferencesStore,
        string? prefillContent = null)
    {
        InitializeComponent();
        _library = library;
        _storage = storage;
        _preferences = preferences;
        _preferencesStore = preferencesStore;
        _collapsedGroups = new HashSet<string>(_preferences.SnippetManagerCollapsedTagGroups);

        _groupExpandedConverter = (GroupExpandedConverter)Resources["GroupExpandedConverter"];
        _groupExpandedConverter.CollapsedGroupNames = _collapsedGroups;

        _items = new ObservableCollection<SnippetListItem>(
            _library.Snippets.Select(s => new SnippetListItem(s, TagFor(s))));

        SnippetList.ItemsSource = _items;
        _view = CollectionViewSource.GetDefaultView(_items);
        RefreshTagBoxItems();

        // Setting this fires GroupByTag_Changed via the CheckBox's own
        // Checked/Unchecked event, which applies the restored grouping.
        GroupByTagBox.IsChecked = _preferences.SnippetManagerGroupByTag;
        _isLoading = false;

        if (prefillContent is not null)
            AddSnippetFromClipboard(prefillContent);
        else if (_items.Count > 0)
            SnippetList.SelectedIndex = 0;
    }

    private Tag? TagFor(Snippet snippet) => _library.Tags.FirstOrDefault(t => t.Id == snippet.TagId);

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

    private void GroupByTag_Changed(object sender, RoutedEventArgs e)
    {
        var grouped = GroupByTagBox.IsChecked == true;

        _view.GroupDescriptions.Clear();
        _view.SortDescriptions.Clear();

        if (grouped)
        {
            _view.GroupDescriptions.Add(new PropertyGroupDescription(nameof(SnippetListItem.TagName)));
            _view.SortDescriptions.Add(new SortDescription(nameof(SnippetListItem.TagName), ListSortDirection.Ascending));
        }

        _view.SortDescriptions.Add(new SortDescription(nameof(SnippetListItem.Trigger), ListSortDirection.Ascending));

        ExpandAllButton.IsEnabled = grouped;
        CollapseAllButton.IsEnabled = grouped;

        if (_isLoading) return;
        _preferences.SnippetManagerGroupByTag = grouped;
        _preferencesStore.Save(_preferences);
    }

    /// <summary>
    /// Fired by the Expander inside each group's ControlTemplate — updates
    /// the persisted collapsed set to match whichever group's triangle was
    /// just clicked.
    /// </summary>
    private void TagGroupExpander_Toggled(object sender, RoutedEventArgs e)
    {
        if (sender is not Expander expander || expander.DataContext is not CollectionViewGroup group) return;

        var name = group.Name?.ToString() ?? "";
        if (expander.IsExpanded) _collapsedGroups.Remove(name);
        else _collapsedGroups.Add(name);

        PersistCollapsedGroups();
    }

    private void ExpandAll_Click(object sender, RoutedEventArgs e) => SetAllGroupsExpanded(true);
    private void CollapseAll_Click(object sender, RoutedEventArgs e) => SetAllGroupsExpanded(false);

    private void SetAllGroupsExpanded(bool expanded)
    {
        _collapsedGroups.Clear();
        if (!expanded)
        {
            foreach (var group in (_view.Groups ?? (IEnumerable<object>)Array.Empty<object>()).OfType<CollectionViewGroup>())
                _collapsedGroups.Add(group.Name?.ToString() ?? "");
        }

        // The Expanders' IsExpanded bindings are one-way (there's nothing
        // sensible to write a group's Name back to), so they only re-read
        // _collapsedGroups when their container is (re)generated — forcing
        // that here is what actually applies the change visually.
        SnippetList.Items.Refresh();
        PersistCollapsedGroups();
    }

    private void PersistCollapsedGroups()
    {
        _preferences.SnippetManagerCollapsedTagGroups = _collapsedGroups.ToList();
        _preferencesStore.Save(_preferences);
    }

    private void SnippetList_SelectionChanged(object sender, System.Windows.Controls.SelectionChangedEventArgs e)
    {
        _selected = SnippetList.SelectedItem as SnippetListItem;
        EditorPanel.IsEnabled = _selected is not null;
        ValidationLabel.Visibility = Visibility.Collapsed;

        if (_selected is null)
        {
            TriggerBox.Text = "";
            ContentBox.Text = "";
            TagBox.SelectedItem = NoTagOption;
            return;
        }

        TriggerBox.Text = _selected.Snippet.Trigger;
        ContentBox.Text = _selected.Snippet.Content;
        TagBox.SelectedItem = TagFor(_selected.Snippet) ?? NoTagOption;
    }

    private void New_Click(object sender, RoutedEventArgs e) => AddNewSnippet("");

    private void AddNewSnippet(string content)
    {
        // No tag by design — a snippet is fully functional with TagId left
        // null; tags are organization only, never a requirement to expand.
        var snippet = new Snippet { Trigger = "!new", Content = content };
        var item = new SnippetListItem(snippet, tag: null);
        _items.Add(item);
        SnippetList.SelectedItem = item;
    }

    private void Delete_Click(object sender, RoutedEventArgs e)
    {
        if (_selected is null) return;
        _items.Remove(_selected);
        SaveToLibrary();
    }

    private void ManageTags_Click(object sender, RoutedEventArgs e)
    {
        var previouslySelectedTagId = (TagBox.SelectedItem as Tag)?.Id;

        var tagManager = new TagManagerWindow(_library, _storage) { Owner = this };
        tagManager.ShowDialog();

        RefreshTagBoxItems();

        // Tag names/colors may have changed (or a tag may have been
        // deleted) while that dialog was open — every list entry's cached
        // swatch and group name need to catch up, not just the one in the
        // Tag combo box above.
        foreach (var item in _items)
            item.RefreshTag(TagFor(item.Snippet));
        SnippetList.Items.Refresh();

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
        var conflict = _items.FirstOrDefault(i =>
            i.Snippet.Id != _selected.Snippet.Id &&
            string.Equals(i.Snippet.Trigger, trigger, StringComparison.OrdinalIgnoreCase));

        if (conflict is not null)
        {
            ShowValidationError($"Trigger \"{trigger}\" is already used by another snippet.");
            return;
        }

        var chosenTag = TagBox.SelectedItem as Tag;
        _selected.Snippet.Trigger = trigger;
        _selected.Snippet.Content = ContentBox.Text;
        _selected.Snippet.TagId = chosenTag is null || chosenTag.Id == NoTagOption.Id ? null : chosenTag.Id;
        _selected.Snippet.ModifiedAt = DateTimeOffset.UtcNow;
        _selected.RefreshTag(chosenTag is null || chosenTag.Id == NoTagOption.Id ? null : chosenTag);

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
        _library.Snippets.AddRange(_items.Select(i => i.Snippet));
        _storage.Save(_library);
    }

    /// <summary>Wraps a Snippet with a pre-resolved tag name and swatch brush for the ListBox's DataTemplate and tag grouping.</summary>
    public class SnippetListItem
    {
        public Snippet Snippet { get; }
        public string Trigger => Snippet.Trigger;
        public string TagName { get; private set; } = "";
        public Brush TagColorBrush { get; private set; } = Brushes.Transparent;

        public SnippetListItem(Snippet snippet, Tag? tag)
        {
            Snippet = snippet;
            RefreshTag(tag);
        }

        public void RefreshTag(Tag? tag)
        {
            TagName = tag?.Name ?? NoTagOption.Name;
            TagColorBrush = tag is not null && TagColorParser.TryParse(tag.ColorHex, out var brush)
                ? brush
                : Brushes.Transparent;
        }
    }
}

/// <summary>
/// Drives each tag group's Expander.IsExpanded from the persisted collapsed
/// set. A XAML-declared resource has no other way to reach that instance
/// state, so SnippetManagerWindow assigns CollapsedGroupNames right after
/// InitializeComponent.
/// </summary>
internal class GroupExpandedConverter : IValueConverter
{
    public HashSet<string> CollapsedGroupNames { get; set; } = new();

    public object Convert(object value, Type targetType, object parameter, System.Globalization.CultureInfo culture)
        => !CollapsedGroupNames.Contains(value?.ToString() ?? "");

    public object ConvertBack(object value, Type targetType, object parameter, System.Globalization.CultureInfo culture)
        => throw new NotSupportedException("Expander.IsExpanded is one-way here — there's nothing to write a group's Name back to.");
}
