using System.Windows;
using Snipster.Models;
using Snipster.Services;
using Snipster.Storage;
using Snipster.Views;

namespace Snipster;

public partial class App : System.Windows.Application
{
    private PreferencesStore _preferencesStore = null!;
    private Preferences _preferences = null!;
    private FileStorageManager _storage = null!;
    private SnippetLibrary _library = null!;
    private TrayIconManager _tray = null!;
    private HotkeyManager _hotkeys = null!;
    private TextExpansionMonitor _expansion = null!;
    private ClipboardHistoryMonitor _clipboardHistory = null!;
    private QuickAccessWindow? _quickAccessWindow;
    private SnippetManagerWindow? _snippetManagerWindow;
    private PreferencesWindow? _preferencesWindow;

    protected override void OnStartup(StartupEventArgs e)
    {
        base.OnStartup(e);

        // A background tray app has no window to crash "in front of" the
        // user — an unhandled exception anywhere just silently vanishes the
        // whole process, hook and all. Log it and keep running instead of
        // letting one bad event handler take everything down.
        DispatcherUnhandledException += (_, args) =>
        {
            DebugLog.Write($"UNHANDLED EXCEPTION: {args.Exception}");
            args.Handled = true;

            // An exception that unwinds mid-click (e.g. out of a Button's
            // OnClick) skips WPF's normal end-of-click capture release,
            // which can leave mouse input stuck on a dead/invisible element
            // — every subsequent click anywhere in the app silently does
            // nothing until the process restarts. Force capture back to
            // "nobody" so a swallowed exception can't strand input.
            if (System.Windows.Input.Mouse.Captured is not null)
                System.Windows.Input.Mouse.Capture(null);
        };

        _preferencesStore = new PreferencesStore();
        _preferences = _preferencesStore.Load();

        // The startup registry key is the actual source of truth (the user
        // could remove it via Task Manager's Startup tab); re-apply our
        // preference each launch so the two can't silently drift apart.
        try { StartupManager.SetEnabled(_preferences.LaunchAtStartup); } catch { /* non-fatal */ }

        _storage = new FileStorageManager(_preferences.CustomLibraryFolder);
        _library = _storage.Load();

        _expansion = new TextExpansionMonitor(() => _library) { IsEnabled = _preferences.TextExpansionEnabled };
        _clipboardHistory = new ClipboardHistoryMonitor { MaxEntries = _preferences.ClipboardHistoryMaxEntries };

        _tray = new TrayIconManager(_expansion.IsEnabled)
        {
            ClipboardHistoryProvider = () => _clipboardHistory.Entries,
        };
        _tray.OpenRequested += ShowQuickAccessWindow;
        _tray.ManageSnippetsRequested += () => ShowSnippetManagerWindow();
        _tray.PreferencesRequested += ShowPreferencesWindow;
        _tray.ImportRequested += ImportLibrary;
        _tray.ExportRequested += ExportLibrary;
        _tray.ExpansionToggleRequested += enabled =>
        {
            _expansion.IsEnabled = enabled;
            _preferences.TextExpansionEnabled = enabled;
            _preferencesStore.Save(_preferences);
        };
        _tray.ClipboardEntrySelected += text => System.Windows.Clipboard.SetText(text);
        _tray.CreateSnippetFromClipboardRequested += text => ShowSnippetManagerWindow(text);
        _tray.ExitRequested += Shutdown;

        _hotkeys = new HotkeyManager();
        _hotkeys.HotkeyPressed += ShowQuickAccessWindow;
        if (!_hotkeys.RegisterDefault())
        {
            System.Windows.MessageBox.Show(
                "Could not register the global hotkey (Ctrl+Shift+S) — it's already " +
                "in use by another running application. Snipster is still running via the " +
                "tray icon; pick a different combo from Preferences.",
                "Snipster", MessageBoxButton.OK, MessageBoxImage.Warning);
        }

        try
        {
            _expansion.Start();
        }
        catch (InvalidOperationException ex)
        {
            System.Windows.MessageBox.Show(ex.Message, "Snipster", MessageBoxButton.OK, MessageBoxImage.Warning);
        }
    }

    private void ShowQuickAccessWindow()
    {
        if (_quickAccessWindow is { IsVisible: true })
        {
            _quickAccessWindow.Activate();
            return;
        }

        _quickAccessWindow = new QuickAccessWindow(_library.Snippets, _library.Tags);
        _quickAccessWindow.Show();
        _quickAccessWindow.Activate();
    }

    private void ShowSnippetManagerWindow(string? prefillContent = null)
    {
        if (_snippetManagerWindow is { IsVisible: true })
        {
            // "Create Snippet from This..." must still apply the clipboard
            // content even when the window was already open — otherwise
            // this branch would just activate it and silently drop the
            // request entirely.
            if (prefillContent is not null)
                _snippetManagerWindow.AddSnippetFromClipboard(prefillContent);

            _snippetManagerWindow.Activate();
            return;
        }

        _snippetManagerWindow = new SnippetManagerWindow(_library, _storage, _preferences, _preferencesStore, prefillContent);
        _snippetManagerWindow.Show();
        _snippetManagerWindow.Activate();
    }

    private void ShowPreferencesWindow()
    {
        if (_preferencesWindow is { IsVisible: true })
        {
            _preferencesWindow.Activate();
            return;
        }

        _preferencesWindow = new PreferencesWindow(
            _preferences, _preferencesStore, _hotkeys, _expansion, _clipboardHistory, _storage);
        _preferencesWindow.ExpansionEnabledChanged += _tray.SetExpansionEnabled;
        _preferencesWindow.Show();
        _preferencesWindow.Activate();
    }

    private void ImportLibrary()
    {
        var dialog = new Microsoft.Win32.OpenFileDialog
        {
            Filter = "Snipster library (*.json)|*.json|All files (*.*)|*.*",
            Title = "Import Snipster Library",
        };

        if (dialog.ShowDialog() != true) return;

        try
        {
            var incoming = FileStorageManager.LoadFrom(dialog.FileName);

            var preview = new ImportPreviewWindow(incoming, _library);
            preview.ShowDialog();
            if (!preview.Confirmed) return;

            var skipped = FileStorageManager.MergeSkippingDuplicates(_library, incoming);
            _storage.Save(_library);

            var message = skipped > 0
                ? $"Import complete. {skipped} snippet(s) were skipped because their trigger already existed."
                : "Import complete.";
            System.Windows.MessageBox.Show(message, "Snipster", MessageBoxButton.OK, MessageBoxImage.Information);
        }
        catch (Exception ex)
        {
            System.Windows.MessageBox.Show($"Import failed: {ex.Message}", "Snipster", MessageBoxButton.OK, MessageBoxImage.Error);
        }
    }

    private void ExportLibrary()
    {
        var dialog = new Microsoft.Win32.SaveFileDialog
        {
            Filter = "Snipster library (*.json)|*.json",
            FileName = "snipster-library-export.json",
            Title = "Export Snipster Library",
        };

        if (dialog.ShowDialog() != true) return;

        try
        {
            FileStorageManager.SaveTo(dialog.FileName, _library);
        }
        catch (Exception ex)
        {
            System.Windows.MessageBox.Show($"Export failed: {ex.Message}", "Snipster", MessageBoxButton.OK, MessageBoxImage.Error);
        }
    }

    protected override void OnExit(ExitEventArgs e)
    {
        _expansion.Dispose();
        _clipboardHistory.Dispose();
        _hotkeys.Dispose();
        _tray.Dispose();
        base.OnExit(e);
    }
}
