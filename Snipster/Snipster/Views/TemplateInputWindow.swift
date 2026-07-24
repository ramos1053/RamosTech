//
//  TemplateInputWindow.swift
//  Snipster
//

import SwiftUI
import AppKit
import Combine

/// A small floating panel that prompts for {{INPUT:...}} values during
/// snippet expansion. Mirrors SpotlightWindow's shape (borderless, floating
/// panel) but doesn't persist its position — it's meant to appear fresh near
/// the cursor each time, not be a browsable tool window like Spotlight is.
class TemplateInputWindow: NSPanel {
    // nonisolated(unsafe) — deinit (always nonisolated for a class) needs to
    // remove this monitor; it's otherwise only ever touched from
    // MainActor-isolated setup code, and deinit only runs once the last
    // reference is gone, so there's no real concurrent access to guard
    // against.
    nonisolated(unsafe) private var clickOutsideMonitor: Any?

    convenience init(contentViewController: NSViewController, size: NSSize) {
        self.init(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        self.contentViewController = contentViewController

        // Visual styling
        self.isOpaque = false
        self.backgroundColor = .clear
        self.hasShadow = true
        self.level = .floating

        // Behavior
        self.isFloatingPanel = true
        self.hidesOnDeactivate = false
        self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        // Draggable by its background — a safety valve if cursor-relative
        // placement ever lands somewhere awkward (near a screen edge, under
        // another window), so the user isn't stuck with an unreachable popup.
        self.isMovable = true
        self.isMovableByWindowBackground = true

        // Allow keyboard interaction
        self.becomesKeyOnlyIfNeeded = false
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    /// Positions the window at `size`, near the mouse if there's room for it
    /// to drop down below the cursor without running off the bottom of the
    /// screen, or — the user's requested "safety zone" — top-center of the
    /// current screen otherwise. Always fully on-screen, never computed
    /// against a placeholder size that later growth could outgrow.
    func placeNearCursor(size: NSSize) {
        let mouseLocation = NSEvent.mouseLocation
        let screenFrame = screenContaining(mouseLocation)

        let cursorGap: CGFloat = 20
        let fitsBelowCursor = (mouseLocation.y - screenFrame.minY) >= size.height + cursorGap

        let x: CGFloat
        let y: CGFloat
        if fitsBelowCursor {
            x = clamp(mouseLocation.x - size.width / 2, screenFrame.minX, screenFrame.maxX - size.width)
            y = mouseLocation.y - cursorGap - size.height
        } else {
            x = screenFrame.midX - size.width / 2
            y = screenFrame.maxY - size.height - 40
        }

        setFrame(NSRect(origin: NSPoint(x: x, y: y), size: size), display: false)
        bringToFront()
    }

    /// Grows or shrinks in place, keeping the top edge fixed (NSWindow's
    /// origin is bottom-left, so the origin has to shift by the height delta
    /// to avoid the window appearing to grow upward instead of downward),
    /// then re-clamps to the screen — the same on-screen guarantee
    /// `placeNearCursor` makes, so later growth (more fields measured, a
    /// calendar expanding) can't push the window off the bottom edge the way
    /// an unclamped delta-shift could.
    func resize(toHeight newHeight: CGFloat) {
        guard newHeight > 0, newHeight != frame.height else { return }
        let screenFrame = screenContaining(NSPoint(x: frame.midX, y: frame.midY))

        var newFrame = frame
        let delta = newHeight - newFrame.height
        newFrame.origin.y -= delta
        newFrame.size.height = newHeight
        newFrame.origin.y = clamp(newFrame.origin.y, screenFrame.minY, screenFrame.maxY - newHeight)

        setFrame(newFrame, display: true, animate: true)
    }

    private func screenContaining(_ point: NSPoint) -> NSRect {
        let screen = NSScreen.screens.first { $0.frame.contains(point) } ?? NSScreen.main
        return screen?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
    }

    private func clamp(_ value: CGFloat, _ lower: CGFloat, _ upper: CGFloat) -> CGFloat {
        guard lower <= upper else { return lower }
        return max(lower, min(value, upper))
    }

    /// Activates Snipster and forces the panel to the front of every other
    /// app's windows. Snipster runs as a menu-bar accessory app — without
    /// explicitly activating first, `.floating` alone wasn't reliably enough
    /// to surface the panel above whatever app was frontmost, which is why
    /// it could appear behind the active window instead of on top of it.
    private func bringToFront() {
        NSApp.activate(ignoringOtherApps: true)
        makeKeyAndOrderFront(nil)
        orderFrontRegardless()
        makeFirstResponder(contentView)
    }

    func dismiss() {
        orderOut(nil)
        close()
    }

    /// Clicking outside cancels, same as Escape — this is a transient prompt,
    /// not a tool window you dismiss-and-return-to.
    func setupDismissOnClickOutside(action: @escaping () -> Void) {
        clickOutsideMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            guard let self, self.isVisible else { return }
            if !self.frame.contains(NSEvent.mouseLocation) {
                action()
            }
        }
    }

    deinit {
        if let monitor = clickOutsideMonitor {
            NSEvent.removeMonitor(monitor)
        }
    }
}

/// Manager for the template input popup — ensures only one instance exists,
/// same shape as SpotlightWindowManager.
@MainActor
final class TemplateInputWindowManager: ObservableObject {
    static let shared = TemplateInputWindowManager()

    private static let width: CGFloat = 320
    /// A rough guess used only for the very first frame, before AppKit has
    /// measured the hosted SwiftUI view's real intrinsic height and our
    /// frame-change observer has had a chance to correct it.
    private static let initialRoughEstimate: CGFloat = 200
    /// How much margin to leave against the screen edges when the window
    /// would otherwise grow taller than the display.
    private static let screenMargin: CGFloat = 80

    private var window: TemplateInputWindow?
    private var completion: (([String: String]?) -> Void)?
    private var frameObserver: NSObjectProtocol?
    /// Whatever app was frontmost before we activated Snipster to bring the
    /// popup to the front (see TemplateInputWindow.bringToFront) — reactivated
    /// in `finish(with:)` so the paste that follows submission lands back in
    /// the app the user was actually typing into, not in Snipster itself.
    private var previousApp: NSRunningApplication?

    private init() {}

    /// Shows one control per field, in order (a text box for `.text`, a
    /// compact row for `.date`). The window is sized to the hosted SwiftUI
    /// view's real intrinsic height (measured by AppKit itself via
    /// `NSHostingController.sizingOptions`, not a hand-rolled SwiftUI
    /// preference round-trip — see the frame-change observer below), capped
    /// against the screen height, with a scrollable field list as the
    /// fallback for whatever doesn't fit. `completion` receives the
    /// collected values — dates already formatted to strings — on submit,
    /// or `nil` if cancelled (Escape or clicking outside the popup).
    func show(fields: [InputField], completion: @escaping ([String: String]?) -> Void) {
        // Shouldn't normally happen — isExpanding blocks new triggers while a
        // popup is up — but resolve any prior popup as cancelled rather than
        // silently drop its completion handler.
        finish(with: nil)

        previousApp = NSWorkspace.shared.frontmostApplication
        self.completion = completion

        let placeholderSize = NSSize(width: Self.width, height: Self.initialRoughEstimate)

        let contentView = TemplateInputView(
            fields: fields,
            width: Self.width,
            onComplete: { [weak self] values in
                self?.finish(with: values)
            }
        )

        let hostingController = NSHostingController(rootView: contentView)
        // .intrinsicContentSize keeps hostingController.view's own frame in
        // sync with the SwiftUI content's real ideal size on every layout
        // pass — this is AppKit measuring the actual rendered view, not
        // SwiftUI self-reporting through a PreferenceKey, which is what was
        // silently plateauing partway through taller templates before.
        hostingController.sizingOptions = [.intrinsicContentSize]

        let newWindow = TemplateInputWindow(contentViewController: hostingController, size: placeholderSize)
        newWindow.setupDismissOnClickOutside { [weak self] in
            self?.finish(with: nil)
        }
        self.window = newWindow

        // Force a real layout pass so fittingSize reflects the true content
        // height before the window is ever positioned or shown — placing it
        // against the small placeholder size (fixed only after the fact by
        // resize()'s delta-shift) was what let a tall popup land somewhere
        // that growth then pushed off-screen.
        hostingController.view.layoutSubtreeIfNeeded()
        let initialSize = NSSize(width: Self.width, height: cappedHeight(hostingController.view.fittingSize.height))
        newWindow.placeNearCursor(size: initialSize)

        hostingController.view.postsFrameChangedNotifications = true
        frameObserver = NotificationCenter.default.addObserver(
            forName: NSView.frameDidChangeNotification,
            object: hostingController.view,
            queue: .main
        ) { [weak self] _ in
            // NotificationCenter's closure type isn't statically @MainActor
            // even with queue: .main — but queue: .main guarantees this body
            // only ever runs on the main thread, so assumeIsolated is safe
            // and avoids an extra async hop for what's a reactive resize.
            MainActor.assumeIsolated {
                guard let self else { return }
                self.window?.resize(toHeight: self.cappedHeight(hostingController.view.fittingSize.height))
            }
        }
    }

    private func cappedHeight(_ height: CGFloat) -> CGFloat {
        let maxHeight = (NSScreen.main?.visibleFrame.height ?? 900) - Self.screenMargin
        return min(max(height, Self.initialRoughEstimate), maxHeight)
    }

    private func finish(with values: [String: String]?) {
        if let frameObserver {
            NotificationCenter.default.removeObserver(frameObserver)
        }
        frameObserver = nil

        window?.dismiss()
        window = nil

        let callback = completion
        completion = nil

        let appToRestore = previousApp
        previousApp = nil
        appToRestore?.activate(options: [])

        guard let callback else { return }
        // App reactivation isn't instantaneous — invoking the callback (which
        // triggers the paste on submit) immediately risks the synthetic
        // Cmd+V still landing in Snipster instead of the app being restored,
        // which is exactly what caused the "beep, nothing pasted" symptom.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            callback(values)
        }
    }
}

/// One control per field — a text box for `.text`, a compact date row for
/// `.date`. Return advances to the next field, or submits everything if the
/// current field is the last one. Escape cancels (completion(nil)).
///
/// This view has no explicit height — it sizes itself naturally (up to
/// `maxHeight`, past which the ScrollView takes over) and lets
/// `TemplateInputWindowManager` measure the hosting view's real AppKit frame
/// to size the window, rather than this view trying to report its own size
/// back out through a SwiftUI PreferenceKey.
///
/// The graphical calendar is NOT shown via SwiftUI's `.popover` — this view
/// is hosted inside TemplateInputWindow, a borderless `.nonactivatingPanel`,
/// and `.popover`'s child-window presentation turned out not to reliably
/// appear at all in that context. Instead, tapping a date field's calendar
/// icon expands it inline, directly in the field list, and the same
/// measured-height mechanism picks up the extra space it needs. The contact
/// picker instead opens its own standalone window (ContactPickerWindowManager)
/// — a real system contact-picker view controller doesn't exist outside Mac
/// Catalyst/UIKit, and a hand-rolled list crammed into this narrow panel
/// didn't leave room to actually browse results.
struct TemplateInputView: View {
    let fields: [InputField]
    let width: CGFloat
    let onComplete: ([String: String]?) -> Void

    @State private var textValues: [String: String] = [:]
    @State private var dateValues: [String: Date] = [:]
    @FocusState private var focusedLabel: String?
    /// At most one date field's inline calendar is expanded at a time —
    /// opening another collapses whichever was open.
    @State private var expandedFieldLabel: String?

    private static let dateDisplayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter
    }()

    /// How much taller the window is allowed to grow before the field list
    /// switches to scrolling instead — a screen-height cap, not a field
    /// count/content estimate.
    private static let maxHeight: CGFloat = (NSScreen.main?.visibleFrame.height ?? 900) - 80

    var body: some View {
        ScrollView {
            fieldsList
        }
        .frame(width: width)
        .frame(maxHeight: Self.maxHeight)
        .background(Color(nsColor: .windowBackgroundColor))
        .cornerRadius(10)
        .shadow(color: .black.opacity(0.25), radius: 14, x: 0, y: 6)
        .onAppear {
            focusedLabel = fields.first?.label
        }
        .onKeyPress(.escape) {
            onComplete(nil)
            return .handled
        }
        .onKeyPress(.return) {
            advanceOrSubmit()
            return .handled
        }
    }

    private var fieldsList: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Template Filler")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, alignment: .center)

            ForEach(fields, id: \.label) { field in
                switch field.kind {
                case .text:
                    VStack(alignment: .leading, spacing: 6) {
                        Text(field.label)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.primary)
                        HStack(spacing: 6) {
                            TextField("", text: textBinding(for: field.label))
                                .textFieldStyle(.roundedBorder)
                                .font(.system(size: 14))
                                .focused($focusedLabel, equals: field.label)

                            if ContactAutofillService.classify(label: field.label) != nil {
                                contactButton(for: field)
                            }
                        }
                    }
                case .date:
                    dateField(for: field)
                }
            }

            Text("Return to insert · Esc to cancel")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .padding(18)
    }

    /// Small person-icon button, same footprint as the date field's calendar
    /// button, shown beside any text field whose label looks contact-related.
    /// Tapping it opens the contact picker in its own window and fills only
    /// this one field from whatever's picked — not the rest of the form.
    private func contactButton(for field: InputField) -> some View {
        Button {
            ContactPickerWindowManager.shared.show { contact in
                guard let contact,
                      let role = ContactAutofillService.classify(label: field.label),
                      let value = contact.value(for: role) else { return }
                textValues[field.label] = value
            }
        } label: {
            // background/clipShape/contentShape all live inside the label
            // (not chained after Button) so the whole 22x22 swatch is one
            // tappable button — chained outside, only the glyph's own
            // rendered pixels were hit-testable with .buttonStyle(.plain),
            // leaving the lighter background ring dead to clicks.
            Image(systemName: "person.crop.circle")
                .font(.system(size: 12))
                .foregroundColor(.accentColor)
                .frame(width: 22, height: 22)
                .background(Color.accentColor.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 5))
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    /// Compact row showing the currently-picked date as text, plus a small
    /// calendar-icon button that expands the graphical picker inline below
    /// this row — the calendar no longer sits inline unconditionally, so a
    /// template with several date fields doesn't stack several full
    /// calendar grids in the window at once.
    private func dateField(for field: InputField) -> some View {
        let binding = dateBinding(for: field.label)
        let isExpanded = expandedFieldLabel == field.label

        return VStack(alignment: .leading, spacing: 6) {
            Text(field.label)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.primary)
            HStack(spacing: 6) {
                Text(Self.dateDisplayFormatter.string(from: binding.wrappedValue))
                    .font(.system(size: 14))
                    .foregroundColor(.primary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 8)
                    .frame(height: 24)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .strokeBorder(Color(nsColor: .separatorColor), lineWidth: 1)
                    )

                Button {
                    expandedFieldLabel = isExpanded ? nil : field.label
                } label: {
                    // Same fix as the contact button: styling + contentShape
                    // live inside the label so the whole swatch is one
                    // tappable button, not just the glyph's own pixels.
                    Image(systemName: "calendar")
                        .font(.system(size: 12))
                        .foregroundColor(.accentColor)
                        .frame(width: 22, height: 22)
                        .background(Color.accentColor.opacity(0.12))
                        .clipShape(RoundedRectangle(cornerRadius: 5))
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .focused($focusedLabel, equals: field.label)
            }

            if isExpanded {
                DatePicker("", selection: binding, displayedComponents: .date)
                    .datePickerStyle(.graphical)
                    .labelsHidden()
                    .padding(10)
                    .frame(maxWidth: .infinity)
                    .background(Color(nsColor: .textBackgroundColor))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .strokeBorder(Color(nsColor: .separatorColor), lineWidth: 1)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .onChange(of: binding.wrappedValue) { _, _ in
                        expandedFieldLabel = nil
                    }
            }
        }
    }

    private func textBinding(for label: String) -> Binding<String> {
        Binding(
            get: { textValues[label] ?? "" },
            set: { textValues[label] = $0 }
        )
    }

    private func dateBinding(for label: String) -> Binding<Date> {
        Binding(
            get: { dateValues[label] ?? Date() },
            set: { dateValues[label] = $0 }
        )
    }

    private func advanceOrSubmit() {
        guard let currentLabel = focusedLabel,
              let currentIndex = fields.firstIndex(where: { $0.label == currentLabel }) else {
            submit()
            return
        }

        let nextIndex = currentIndex + 1
        if nextIndex < fields.count {
            focusedLabel = fields[nextIndex].label
        } else {
            submit()
        }
    }

    private func submit() {
        // Built fresh from `fields`, not from `textValues` directly — a text
        // field the user never touched has no entry in `textValues` at all
        // (its TextField binding only writes on edit), which left
        // substituteInputValues with no value to substitute and no way to
        // tell "blank" from "never asked", so it fell back to leaving the
        // raw {{INPUT:label}} tag in the pasted text. Explicitly defaulting
        // every field here guarantees a real (blank, if untouched) value for
        // every label, so no tag can ever leak into the output.
        var result: [String: String] = [:]

        let formatter = DateFormatter()
        formatter.dateStyle = .long
        formatter.timeStyle = .none

        for field in fields {
            switch field.kind {
            case .text:
                result[field.label] = textValues[field.label] ?? ""
            case .date:
                result[field.label] = formatter.string(from: dateValues[field.label] ?? Date())
            }
        }

        onComplete(result)
    }
}
