using System.IO;
using System.Windows;
using Snipster.Models;
using Snipster.Services;
using Snipster.Storage;

namespace Snipster.Views;

/// <summary>
/// Single consolidated settings window, reachable from the tray menu —
/// the counterpart to the macOS app's Preferences window. Every control
/// here writes straight through to the live running services (no separate
/// "Apply"/"OK" step) so changes take effect immediately, same as the
/// tray's own quick toggles.
/// </summary>
public partial class PreferencesWindow : Window
{
    private readonly Preferences _preferences;
    private readonly PreferencesStore _preferencesStore;
    private readonly HotkeyManager _hotkeyManager;
    private readonly TextExpansionMonitor _expansionMonitor;
    private readonly ClipboardHistoryMonitor _clipboardHistory;
    private readonly FileStorageManager _storage;
    private bool _isLoading = true;

    /// <summary>Lets App.xaml.cs keep the tray's own checkbox in sync.</summary>
    public event Action<bool>? ExpansionEnabledChanged;

    public PreferencesWindow(
        Preferences preferences,
        PreferencesStore preferencesStore,
        HotkeyManager hotkeyManager,
        TextExpansionMonitor expansionMonitor,
        ClipboardHistoryMonitor clipboardHistory,
        FileStorageManager storage)
    {
        InitializeComponent();
        _preferences = preferences;
        _preferencesStore = preferencesStore;
        _hotkeyManager = hotkeyManager;
        _expansionMonitor = expansionMonitor;
        _clipboardHistory = clipboardHistory;
        _storage = storage;

        LaunchAtStartupBox.IsChecked = _preferences.LaunchAtStartup;
        ExpansionEnabledBox.IsChecked = _expansionMonitor.IsEnabled;
        LibraryPathBox.Text = _storage.LibraryFilePath;

        foreach (System.Windows.Controls.ComboBoxItem item in ClipboardMaxBox.Items)
        {
            if (item.Content?.ToString() == _clipboardHistory.MaxEntries.ToString())
                ClipboardMaxBox.SelectedItem = item;
        }
        ClipboardMaxBox.SelectedItem ??= ClipboardMaxBox.Items[2]; // default: 50

        RefreshHotkeyLabel();
        _isLoading = false;
    }

    private void RefreshHotkeyLabel() =>
        HotkeyLabel.Text = HotkeyManager.Describe(_hotkeyManager.CurrentModifiers, _hotkeyManager.CurrentVirtualKey);

    private void LaunchAtStartupBox_Changed(object sender, RoutedEventArgs e)
    {
        if (_isLoading) return;
        var enabled = LaunchAtStartupBox.IsChecked == true;

        try
        {
            StartupManager.SetEnabled(enabled);
            _preferences.LaunchAtStartup = enabled;
            _preferencesStore.Save(_preferences);
        }
        catch (Exception ex)
        {
            System.Windows.MessageBox.Show($"Couldn't update startup setting: {ex.Message}", "Snipster",
                MessageBoxButton.OK, MessageBoxImage.Error);
            LaunchAtStartupBox.IsChecked = !enabled;
        }
    }

    private void ExpansionEnabledBox_Changed(object sender, RoutedEventArgs e)
    {
        if (_isLoading) return;
        var enabled = ExpansionEnabledBox.IsChecked == true;
        _expansionMonitor.IsEnabled = enabled;
        _preferences.TextExpansionEnabled = enabled;
        _preferencesStore.Save(_preferences);
        ExpansionEnabledChanged?.Invoke(enabled);
    }

    private void ChangeHotkey_Click(object sender, RoutedEventArgs e)
    {
        var capture = new HotkeyCaptureWindow(_hotkeyManager) { Owner = this };
        capture.ShowDialog();
        RefreshHotkeyLabel();
    }

    private void ClipboardMaxBox_Changed(object sender, System.Windows.Controls.SelectionChangedEventArgs e)
    {
        if (_isLoading) return;
        if (ClipboardMaxBox.SelectedItem is not System.Windows.Controls.ComboBoxItem item) return;
        if (!int.TryParse(item.Content?.ToString(), out var max)) return;

        _clipboardHistory.MaxEntries = max;
        _preferences.ClipboardHistoryMaxEntries = max;
        _preferencesStore.Save(_preferences);
    }

    private void ClearNow_Click(object sender, RoutedEventArgs e) => _clipboardHistory.Clear();

    private void OpenFolder_Click(object sender, RoutedEventArgs e)
    {
        var folder = Path.GetDirectoryName(_storage.LibraryFilePath);
        if (folder is not null) System.Diagnostics.Process.Start("explorer.exe", folder);
    }

    private void ChangeLocation_Click(object sender, RoutedEventArgs e)
    {
        using var dialog = new System.Windows.Forms.FolderBrowserDialog
        {
            Description = "Choose a folder for Snipster's snippet library (e.g. a OneDrive or Dropbox folder to sync it)",
            UseDescriptionForTitle = true,
        };

        if (dialog.ShowDialog() != System.Windows.Forms.DialogResult.OK) return;

        var newFolder = dialog.SelectedPath;
        var newLibraryPath = Path.Combine(newFolder, "snipster-library.json");

        string resultMessage;
        if (File.Exists(newLibraryPath))
        {
            resultMessage = "An existing Snipster library was found at that location and will be used from now on.";
        }
        else
        {
            File.Copy(_storage.LibraryFilePath, newLibraryPath);
            resultMessage = "Your snippet library was moved to the new location.";
        }

        _preferences.CustomLibraryFolder = newFolder;
        _preferencesStore.Save(_preferences);

        System.Windows.MessageBox.Show(
            $"{resultMessage}\n\nSnipster needs to restart to use the new location.",
            "Snipster", MessageBoxButton.OK, MessageBoxImage.Information);

        System.Diagnostics.Process.Start(Environment.ProcessPath!);
        System.Windows.Application.Current.Shutdown();
    }

    private void Close_Click(object sender, RoutedEventArgs e) => Close();
}
