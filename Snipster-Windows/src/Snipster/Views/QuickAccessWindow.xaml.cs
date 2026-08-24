using System.Windows;
using System.Windows.Input;
using Snipster.Models;
using RadioButton = System.Windows.Controls.RadioButton;

namespace Snipster.Views;

/// <summary>
/// Spotlight-style search window opened by the global hotkey, mirroring the
/// macOS app's tag-based quick-access window — including filtering by tag,
/// not just free-text search.
/// </summary>
public partial class QuickAccessWindow : Window
{
    private readonly List<Snippet> _allSnippets;
    private string? _selectedTagId; // null = "All"

    // Close() itself deactivates the window as part of shutting down, which
    // re-enters Window_Deactivated and calls Close() again WHILE it's still
    // closing — WPF throws InvalidOperationException on that re-entrant
    // call, which (with no global handler) took down the whole app. Every
    // path that closes this window has to go through here.
    private bool _isClosing;

    private void CloseOnce()
    {
        if (_isClosing) return;
        _isClosing = true;
        Close();
    }

    public QuickAccessWindow(IReadOnlyList<Snippet> snippets, IReadOnlyList<Tag> tags)
    {
        InitializeComponent();
        _allSnippets = snippets.ToList();
        BuildTagFilterChips(tags);
        ApplyFilters();
        Loaded += (_, _) => SearchBox.Focus();
    }

    private void BuildTagFilterChips(IReadOnlyList<Tag> tags)
    {
        var allChip = new RadioButton
        {
            Content = "All",
            GroupName = "TagFilter",
            IsChecked = true,
            Margin = new Thickness(0, 0, 8, 4),
        };
        allChip.Checked += (_, _) => { _selectedTagId = null; ApplyFilters(); };
        TagFilterPanel.Children.Add(allChip);

        foreach (var tag in tags)
        {
            var chip = new RadioButton
            {
                Content = tag.Name,
                GroupName = "TagFilter",
                Margin = new Thickness(0, 0, 8, 4),
                Tag = tag.Id,
            };
            chip.Checked += (_, _) => { _selectedTagId = tag.Id; ApplyFilters(); };
            TagFilterPanel.Children.Add(chip);
        }

        TagFilterPanel.Visibility = tags.Count > 0 ? Visibility.Visible : Visibility.Collapsed;
    }

    private void SearchBox_TextChanged(object sender, System.Windows.Controls.TextChangedEventArgs e) => ApplyFilters();

    private void ApplyFilters()
    {
        var query = SearchBox.Text.Trim();

        IEnumerable<Snippet> results = _allSnippets;

        if (_selectedTagId is not null)
            results = results.Where(s => s.TagId == _selectedTagId);

        if (!string.IsNullOrEmpty(query))
        {
            results = results.Where(s =>
                s.Trigger.Contains(query, StringComparison.OrdinalIgnoreCase) ||
                s.Content.Contains(query, StringComparison.OrdinalIgnoreCase));
        }

        ResultsList.ItemsSource = results.ToList();
    }

    private void SearchBox_KeyDown(object sender, System.Windows.Input.KeyEventArgs e)
    {
        if (e.Key == Key.Escape)
        {
            CloseOnce();
        }
        else if (e.Key == Key.Enter && ResultsList.Items.Count > 0)
        {
            CopySelectedAndClose();
        }
    }

    private void ResultsList_MouseDoubleClick(object sender, System.Windows.Input.MouseButtonEventArgs e)
    {
        CopySelectedAndClose();
    }

    private void CopySelectedAndClose()
    {
        var snippet = (ResultsList.SelectedItem as Snippet) ?? (ResultsList.ItemsSource as List<Snippet>)?.FirstOrDefault();
        if (snippet is not null)
        {
            System.Windows.Clipboard.SetText(snippet.Content);
        }
        CloseOnce();
    }

    private void Window_Deactivated(object sender, EventArgs e) => CloseOnce();
}
