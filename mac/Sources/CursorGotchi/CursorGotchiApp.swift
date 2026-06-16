import AppKit
import Combine
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let store = PetStore()
    private let usageStore = UsageStore()
    private let settingsStore = AppSettingsStore()
    private var statusItem: NSStatusItem!
    private var statusHostingView: NSHostingView<StatusBarLabel>?
    private var panelWindow: NSPanel?
    private var refreshTimer: Timer?
    private var usageObserver: AnyCancellable?

    func applicationDidFinishLaunching(_ notification: Notification) {
        DistributedNotificationCenter.default().addObserver(
            self,
            selector: #selector(handleShowPanelNotification),
            name: SingleInstance.showPanelNotification,
            object: nil
        )
        NSApp.setActivationPolicy(.accessory)
        store.settingsStore = settingsStore
        store.requestNotifications()
        setupStatusItem()
        setupRefreshTimer()
        usageStore.startAutoRefresh(every: 60)
        observeUsageChanges()
        store.reload()
        showPanel()
        AppLogger.log("Cursor Gotchi started — panel opened")
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showPanel()
        return true
    }

    func applicationWillTerminate(_ notification: Notification) {
        SingleInstance.release()
    }

    @objc private func handleShowPanelNotification() {
        showPanel()
    }

    private func setupStatusItem() {
        let itemWidth: CGFloat = 88
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.length = itemWidth
        statusItem.isVisible = true
        guard let button = statusItem.button else { return }
        button.action = #selector(togglePanel(_:))
        button.target = self
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        button.image = nil
        button.title = ""
        button.subviews.forEach { $0.removeFromSuperview() }

        refreshStatusItemView()
    }

    private func refreshStatusItemView() {
        guard let button = statusItem.button else { return }
        statusHostingView?.removeFromSuperview()
        let hosting = NSHostingView(rootView: StatusBarLabel(store: store, usageStore: usageStore))
        hosting.translatesAutoresizingMaskIntoConstraints = false
        button.addSubview(hosting)
        NSLayoutConstraint.activate([
            hosting.leadingAnchor.constraint(equalTo: button.leadingAnchor, constant: 2),
            hosting.trailingAnchor.constraint(equalTo: button.trailingAnchor, constant: -2),
            hosting.centerYAnchor.constraint(equalTo: button.centerYAnchor),
            hosting.heightAnchor.constraint(equalToConstant: 18),
        ])
        statusHostingView = hosting
        button.toolTip = usageStore.usage?.detailLine ?? "Cursor Gotchi"
    }

    private func observeUsageChanges() {
        usageObserver = usageStore.$usage.sink { [weak self] usage in
            Task { @MainActor in
                self?.refreshStatusItemView()
                if let label = usage?.menuLabel {
                    self?.statusItem.length = max(72, CGFloat(28 + label.count * 7))
                }
                self?.checkUsageAlerts(usage)
            }
        }
    }

    private func checkUsageAlerts(_ usage: UsageSnapshot?) {
        guard let usage, let pct = usage.usedPercent else { return }
        let fired = settingsStore.recordUsageAlertIfNeeded(
            usedPercent: pct,
            billingCycleEnd: usage.billingCycleEnd
        )
        for threshold in fired {
            NotificationService.postUsageAlert(
                threshold: threshold,
                usedPercent: pct,
                resetText: usage.resetText
            )
            AppLogger.log("usage alert fired at \(threshold)% (current: \(pct)%)")
        }
    }

    private func setupRefreshTimer() {
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.store.reload()
                self?.usageStore.reload()
                self?.store.animFrame = ((self?.store.animFrame ?? 0) + 1) % 2
            }
        }
    }

    @objc func togglePanel(_ sender: AnyObject?) {
        let event = NSApp.currentEvent
        let isRightClick = event?.type == .rightMouseUp
            || (event?.modifierFlags.contains(.control) ?? false)
        if isRightClick {
            showContextMenu()
            return
        }
        if let window = panelWindow, window.isVisible {
            window.orderOut(sender)
        } else {
            showPanel()
        }
    }

    private func showContextMenu() {
        guard let button = statusItem.button else { return }
        let menu = NSMenu()

        let open = NSMenuItem(title: "Open Window", action: #selector(openPanel), keyEquivalent: "")
        open.target = self
        menu.addItem(open)

        let refresh = NSMenuItem(title: "Refresh Usage", action: #selector(refreshNow), keyEquivalent: "r")
        refresh.target = self
        menu.addItem(refresh)

        menu.addItem(.separator())

        let quit = NSMenuItem(title: "Quit Cursor Gotchi", action: #selector(quitApp), keyEquivalent: "q")
        quit.target = self
        menu.addItem(quit)

        menu.popUp(positioning: nil, at: NSPoint(x: 0, y: button.bounds.height + 4), in: button)
    }

    @objc private func openPanel() {
        showPanel()
    }

    @objc private func refreshNow() {
        Task { @MainActor in
            await usageStore.refresh()
            store.reload()
        }
    }

    @objc private func quitApp() {
        AppLogger.log("quit requested from menu")
        NSApp.terminate(nil)
    }

    func showPanel() {
        store.reload()

        if panelWindow == nil {
            let panel = NSPanel(
                contentRect: NSRect(x: 0, y: 0, width: 300, height: 480),
                styleMask: [.titled, .closable, .fullSizeContentView],
                backing: .buffered,
                defer: false
            )
            panel.title = "Cursor Gotchi"
            panel.titlebarAppearsTransparent = true
            panel.isMovableByWindowBackground = true
            panel.level = .floating
            panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
            panel.contentViewController = NSHostingController(rootView: panelView())
            panel.center()
            panelWindow = panel
        } else {
            panelWindow?.contentViewController = NSHostingController(rootView: panelView())
        }

        panelWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func panelView() -> PetPanelView {
        PetPanelView(
            store: store,
            usageStore: usageStore,
            settingsStore: settingsStore,
            onRefresh: { [weak self] in
                Task { @MainActor in
                    await self?.usageStore.refresh()
                    self?.store.reload()
                }
            },
            onQuit: { [weak self] in
                self?.quitApp()
            }
        )
    }

}

@main
enum CursorGotchiMain {
    static func main() {
        AppLogger.log("main() starting")

        guard SingleInstance.acquire() else {
            AppLogger.log("another instance running — notifying and exiting")
            exit(0)
        }

        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.run()
        SingleInstance.release()
    }
}
