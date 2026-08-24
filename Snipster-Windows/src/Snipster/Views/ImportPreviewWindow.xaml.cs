using System.Windows;
using Snipster.Models;

namespace Snipster.Views;

/// <summary>
/// Shows exactly what an imported library file contains before it's merged
/// in — previously Import silently merged with no preview at all, which is
/// a real risk given expansion content gets typed wherever the user is
/// working (including, if a trigger fires while a terminal has focus,
/// executed as commands). The user gets to see it first and cancel.
/// </summary>
public partial class ImportPreviewWindow : Window
{
    public bool Confirmed { get; private set; }

    public ImportPreviewWindow(SnippetLibrary incoming, SnippetLibrary target)
    {
        InitializeComponent();

        var existingTriggers = new HashSet<string>(
            target.Snippets.Select(s => s.Trigger), StringComparer.OrdinalIgnoreCase);

        var rows = incoming.Snippets.Select(s => new PreviewRow
        {
            Trigger = s.Trigger,
            ContentPreview = BuildContentPreview(s.Content, existingTriggers.Contains(s.Trigger)),
        }).ToList();

        PreviewList.ItemsSource = rows;

        if (rows.Count == 0) ImportButton.IsEnabled = false;
    }

    private static string BuildContentPreview(string content, bool isDuplicate)
    {
        // Newlines make multi-line content look like a single short line in
        // a ListView cell, hiding exactly the kind of payload (e.g. a
        // command + Enter) worth noticing before import — surface them
        // visibly instead of letting them disappear.
        var singleLine = content.Replace("\r\n", " ⏎ ").Replace("\n", " ⏎ ");
        if (singleLine.Length > 80) singleLine = singleLine[..80] + "…";

        return isDuplicate ? $"{singleLine}  (duplicate trigger — will be skipped)" : singleLine;
    }

    private void Import_Click(object sender, RoutedEventArgs e)
    {
        Confirmed = true;
        Close();
    }

    private void Cancel_Click(object sender, RoutedEventArgs e) => Close();

    private class PreviewRow
    {
        public string Trigger { get; set; } = "";
        public string ContentPreview { get; set; } = "";
    }
}
