using System.Drawing.Drawing2D;
using Snipster.Models;
using Snipster.Native;

namespace Snipster.Services;

/// <summary>
/// System tray icon and its dropdown menu — the Windows counterpart to the
/// macOS NSStatusItem menu bar icon and its menu. WPF has no built-in tray
/// API, so this uses WinForms' NotifyIcon (enabled via UseWindowsForms in
/// the csproj).
/// </summary>
public class TrayIconManager : IDisposable
{
    private readonly NotifyIcon _notifyIcon;
    private readonly Icon _icon;
    private readonly ToolStripMenuItem _expansionToggleItem;
    private readonly ToolStripMenuItem _clipboardHistoryItem;

    public event Action? OpenRequested;
    public event Action? ManageSnippetsRequested;
    public event Action? PreferencesRequested;
    public event Action? ImportRequested;
    public event Action? ExportRequested;
    public event Action? ExitRequested;

    /// <summary>Raised with the NEW desired enabled state when the user clicks the toggle.</summary>
    public event Action<bool>? ExpansionToggleRequested;

    public event Action<string>? ClipboardEntrySelected;
    public event Action<string>? CreateSnippetFromClipboardRequested;

    /// <summary>Pulled fresh each time the menu opens, so it's never stale.</summary>
    public Func<IReadOnlyList<ClipboardHistoryEntry>>? ClipboardHistoryProvider { get; set; }

    public TrayIconManager(bool expansionInitiallyEnabled)
    {
        _expansionToggleItem = new ToolStripMenuItem("Text Expansion Enabled")
        {
            CheckOnClick = true,
            Checked = expansionInitiallyEnabled,
        };
        _expansionToggleItem.Click += (_, _) => ExpansionToggleRequested?.Invoke(_expansionToggleItem.Checked);

        _clipboardHistoryItem = new ToolStripMenuItem("Clipboard History");

        var menu = new ContextMenuStrip();
        menu.Items.Add("Open Quick Access", null, (_, _) => OpenRequested?.Invoke());
        menu.Items.Add(_expansionToggleItem);
        menu.Items.Add(_clipboardHistoryItem);
        menu.Items.Add(new ToolStripSeparator());
        menu.Items.Add("Manage Snippets...", null, (_, _) => ManageSnippetsRequested?.Invoke());
        menu.Items.Add("Preferences...", null, (_, _) => PreferencesRequested?.Invoke());
        menu.Items.Add(new ToolStripSeparator());
        menu.Items.Add("Import Library...", null, (_, _) => ImportRequested?.Invoke());
        menu.Items.Add("Export Library...", null, (_, _) => ExportRequested?.Invoke());
        menu.Items.Add(new ToolStripSeparator());
        menu.Items.Add("Exit", null, (_, _) => ExitRequested?.Invoke());

        menu.Opening += (_, _) => RebuildClipboardHistoryMenu();

        _icon = CreateAppIcon();
        _notifyIcon = new NotifyIcon
        {
            Icon = _icon,
            Text = "Snipster",
            Visible = true,
            ContextMenuStrip = menu,
        };

        _notifyIcon.DoubleClick += (_, _) => OpenRequested?.Invoke();
    }

    /// <summary>Keeps the tray checkbox in sync when the toggle is changed from Preferences instead.</summary>
    public void SetExpansionEnabled(bool enabled) => _expansionToggleItem.Checked = enabled;

    private void RebuildClipboardHistoryMenu()
    {
        _clipboardHistoryItem.DropDownItems.Clear();

        var entries = ClipboardHistoryProvider?.Invoke() ?? Array.Empty<ClipboardHistoryEntry>();
        if (entries.Count == 0)
        {
            _clipboardHistoryItem.DropDownItems.Add("(empty)").Enabled = false;
            return;
        }

        foreach (var entry in entries)
        {
            var label = entry.Text.Replace('\n', ' ').Replace('\r', ' ');
            if (label.Length > 60) label = label[..60] + "…";

            // Each entry is its own submenu so both actions are reachable
            // from a plain left-click menu (NotifyIcon context menus don't
            // support a distinct right-click-on-item gesture).
            var entryItem = new ToolStripMenuItem(label);
            entryItem.DropDownItems.Add("Copy to Clipboard", null, (_, _) => ClipboardEntrySelected?.Invoke(entry.Text));
            entryItem.DropDownItems.Add("Create Snippet from This...", null, (_, _) => CreateSnippetFromClipboardRequested?.Invoke(entry.Text));
            _clipboardHistoryItem.DropDownItems.Add(entryItem);
        }
    }

    /// <summary>
    /// Draws a simple "S" badge at runtime instead of shipping a .ico asset —
    /// swap this for a real icon file once one exists.
    /// </summary>
    private static Icon CreateAppIcon()
    {
        const int size = 32;
        using var bitmap = new Bitmap(size, size);
        using (var g = Graphics.FromImage(bitmap))
        {
            g.SmoothingMode = SmoothingMode.AntiAlias;
            g.TextRenderingHint = System.Drawing.Text.TextRenderingHint.AntiAlias;

            using var backgroundBrush = new SolidBrush(ColorTranslator.FromHtml("#4A90D9"));
            g.FillEllipse(backgroundBrush, 0, 0, size - 1, size - 1);

            using var font = new Font("Segoe UI", 16, FontStyle.Bold, GraphicsUnit.Pixel);
            using var textBrush = new SolidBrush(Color.White);
            var format = new StringFormat
            {
                Alignment = StringAlignment.Center,
                LineAlignment = StringAlignment.Center,
            };
            g.DrawString("S", font, textBrush, new RectangleF(0, 0, size, size), format);
        }

        // Bitmap.GetHicon() allocates a native HICON that .NET does not own
        // or free automatically — clone it into a managed Icon, then
        // explicitly destroy the native handle to avoid leaking a GDI object.
        var hIcon = bitmap.GetHicon();
        try
        {
            using var temp = Icon.FromHandle(hIcon);
            return (Icon)temp.Clone();
        }
        finally
        {
            NativeMethods.DestroyIcon(hIcon);
        }
    }

    public void Dispose()
    {
        _notifyIcon.Visible = false;
        _notifyIcon.Dispose();
        _icon.Dispose();
    }
}
