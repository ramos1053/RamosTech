// TabbyApp.swift
// Tabby
//
// Main app entry point. Runs as a menu bar agent with a global hotkey.
// The Mission Control window appears when the hotkey is pressed and
// hides when pressed again or when the window loses focus.

import SwiftUI
import Carbon
import ServiceManagement

// MARK: - TabbyApp

@main
struct TabbyApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        // Settings window (opened from menu bar)
        Settings {
            SettingsView(viewModel: appDelegate.settingsViewModel, onOpenHelp: {
                appDelegate.openHelp()
            })
        }
    }
}

// MARK: - AppDelegate

/// AppKit delegate managing the menu bar item, global hotkey, and Mission Control window.
class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {

    // MARK: - Properties

    private var statusItem: NSStatusItem!
    private var missionControlWindow: NSWindow?
    private var missionControlHostingView: NSHostingView<MissionControlView>?
    private var hotKeyRef: EventHotKeyRef?

    let tabViewModel = TabViewModel()
    lazy var settingsViewModel: SettingsViewModel = {
        let vm = SettingsViewModel()
        vm.onHotkeyChanged = { [weak self] config in
            self?.reregisterHotKey(with: config)
        }
        vm.onAppearanceChanged = { [weak self] mode in
            self?.applyAppearance(mode)
        }
        return vm
    }()

    // MARK: - App Lifecycle

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Hide dock icon — we're a menu bar agent
        NSApp.setActivationPolicy(.accessory)

        setupMenuBarItem()
        registerGlobalHotKey()

        // Auto-update installed extension files so browser extensions
        // pick up new handlers (e.g. closeTab) after an app update.
        ExtensionInstaller.updateInstalledExtensions()

        tabViewModel.startMonitoring()

        // Apply saved appearance
        applyAppearance(settingsViewModel.appearanceMode)

        print("[Tabby] Application launched (menu bar agent)")
        let hostPath = ExtensionInstaller.hostBinaryPath
        let exists = FileManager.default.fileExists(atPath: hostPath)
        print("[Tabby] Host binary at \(hostPath): \(exists ? "EXISTS" : "MISSING")")
    }

    func applicationWillTerminate(_ notification: Notification) {
        unregisterGlobalHotKey()
        tabViewModel.stopMonitoring()
        print("[Tabby] Application terminating")
    }

    // MARK: - Menu Bar

    private func setupMenuBarItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)

        if let button = statusItem.button {
            if let catImage = NSImage(named: "MenuBarIcon") {
                catImage.size = NSSize(width: 18, height: 18)
                button.image = catImage
            } else {
                // Fallback: SF Symbol cat
                button.image = NSImage(systemSymbolName: "cat.fill", accessibilityDescription: "Tabby")
            }
            button.toolTip = "Tabby — Tab Manager"
        }

        let menu = NSMenu()

        let showItem = NSMenuItem(title: "Show Tabby", action: #selector(toggleMissionControl), keyEquivalent: "")
        showItem.target = self
        showItem.keyEquivalentModifierMask = [.command, .shift]
        showItem.keyEquivalent = "t"
        menu.addItem(showItem)

        menu.addItem(NSMenuItem.separator())

        let settingsItem = NSMenuItem(title: "Settings...", action: #selector(openSettings), keyEquivalent: ",")
        settingsItem.target = self
        menu.addItem(settingsItem)

        let helpItem = NSMenuItem(title: "Help", action: #selector(openHelp), keyEquivalent: "")
        helpItem.target = self
        menu.addItem(helpItem)

        menu.addItem(NSMenuItem.separator())

        let quitItem = NSMenuItem(title: "Quit Tabby", action: #selector(quitApp), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        statusItem.menu = menu
    }

    // MARK: - Menu Actions

    @objc private func toggleMissionControl() {
        if let window = missionControlWindow, window.isVisible {
            hideMissionControl()
        } else {
            showMissionControl()
        }
    }

    @objc private func openSettings() {
        NSApp.activate(ignoringOtherApps: true)

        // Check if settings window already exists
        for window in NSApp.windows where window.title.contains("Settings") {
            window.makeKeyAndOrderFront(nil)
            return
        }

        // Create settings window manually
        let settingsView = SettingsView(viewModel: settingsViewModel, onOpenHelp: { [weak self] in
            self?.openHelp()
        })
        let hostingView = NSHostingView(rootView: settingsView)
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 500, height: 400),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Tabby Settings"
        window.contentView = hostingView
        window.center()
        window.isReleasedWhenClosed = false
        window.makeKeyAndOrderFront(nil)
    }

    @objc func openHelp() {
        NSApp.activate(ignoringOtherApps: true)

        // Check if help window already exists
        for window in NSApp.windows where window.title == "Tabby Help" {
            window.makeKeyAndOrderFront(nil)
            return
        }

        // Create help window manually
        let helpView = HelpView()
        let hostingView = NSHostingView(rootView: helpView)
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 650, height: 700),
            styleMask: [.titled, .closable, .resizable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Tabby Help"
        window.contentView = hostingView
        window.center()
        window.isReleasedWhenClosed = false
        window.makeKeyAndOrderFront(nil)
    }

    @objc private func quitApp() {
        NSApp.terminate(nil)
    }

    // MARK: - Mission Control Window

    private func showMissionControl() {
        if missionControlWindow == nil {
            createMissionControlWindow()
        }

        guard let window = missionControlWindow else { return }

        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        tabViewModel.refreshAllTabs()
    }

    private func hideMissionControl() {
        missionControlWindow?.orderOut(nil)
    }

    private func createMissionControlWindow() {
        let contentView = MissionControlView(viewModel: tabViewModel)
        let hostingView = NSHostingView(rootView: contentView)

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 900, height: 600),
            styleMask: [.titled, .closable, .resizable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Tabby"
        window.contentView = hostingView
        window.center()
        window.setFrameAutosaveName("TabbyMissionControl")
        window.delegate = self
        window.isReleasedWhenClosed = false
        window.titlebarAppearsTransparent = true
        window.backgroundColor = NSColor.windowBackgroundColor

        missionControlWindow = window
        missionControlHostingView = hostingView
    }

    // MARK: - NSWindowDelegate

    func windowWillClose(_ notification: Notification) {
        // No-op — we stay as .accessory always
    }

    // MARK: - Global Hotkey

    private var eventHandlerRef: EventHandlerRef?

    private func registerGlobalHotKey() {
        let config = settingsViewModel.hotkeyConfig

        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard),
                                       eventKind: UInt32(kEventHotKeyPressed))

        // Install handler (only once)
        if eventHandlerRef == nil {
            InstallEventHandler(
                GetApplicationEventTarget(),
                { (_, event, userData) -> OSStatus in
                    guard let userData = userData else { return OSStatus(eventNotHandledErr) }
                    let appDelegate = Unmanaged<AppDelegate>.fromOpaque(userData).takeUnretainedValue()
                    DispatchQueue.main.async {
                        appDelegate.toggleMissionControl()
                    }
                    return noErr
                },
                1,
                &eventType,
                Unmanaged.passUnretained(self).toOpaque(),
                &eventHandlerRef
            )
        }

        var hotKeyID = EventHotKeyID()
        hotKeyID.signature = OSType(0x54_42_42_59) // "TBBY"
        hotKeyID.id = 1

        let status = RegisterEventHotKey(
            config.keyCode,
            config.carbonModifiers,
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )

        if status == noErr {
            print("[Tabby] Global hotkey registered: \(config.displayString)")
        } else {
            print("[Tabby] Failed to register hotkey: \(status)")
        }
    }

    private func unregisterGlobalHotKey() {
        if let ref = hotKeyRef {
            UnregisterEventHotKey(ref)
            hotKeyRef = nil
        }
    }

    /// Re-register hotkey when user changes it in Settings
    func reregisterHotKey(with config: HotkeyConfig) {
        unregisterGlobalHotKey()
        registerGlobalHotKey()
    }

    /// Apply appearance mode to all windows
    func applyAppearance(_ mode: AppearanceMode) {
        let appearance: NSAppearance?
        switch mode {
        case .automatic: appearance = nil
        case .light:     appearance = NSAppearance(named: .aqua)
        case .dark:      appearance = NSAppearance(named: .darkAqua)
        }
        NSApp.appearance = appearance
    }
}
