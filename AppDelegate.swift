import Cocoa
import SwiftUI
import ServiceManagement
import UserNotifications

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem!
    var timerManager: TimerManager!
    var breakWindow: BreakOverlayWindow?
    var settingsWindow: NSWindow?
    
    /// Set to true before calling NSApp.terminate() from Settings to bypass quit protection
    var allowedToQuit: Bool = false
    
    private var menuUpdateTimer: Timer?
    
    override init() {
        super.init()
    }
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Request notification permissions
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { granted, error in
            if granted {
                print("✅ Notification permission granted")
            } else {
                print("❌ Notification permission denied")
            }
        }
        
        // Create menu bar item
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "eye.fill", accessibilityDescription: "Descreen")
        }
        
        // Initialize timer manager
        timerManager = TimerManager()
        timerManager.onBreakStart = { [weak self] in
            DispatchQueue.main.async {
                self?.showBreakOverlay()
                print("showBreakOverlay active")
            }
        }
        timerManager.onBreakEnd = { [weak self] in
            print("🔴🔴🔴 onBreakEnd CALLBACK TRIGGERED in AppDelegate")
            DispatchQueue.main.async {
                print("🔴 About to call hideBreakOverlay")
                self?.hideBreakOverlay()
                print("🔴 hideBreakOverlay completed")
            }
        }
        timerManager.onBreakWarning = { [weak self] minutesRemaining in
            DispatchQueue.main.async {
                self?.showInAppWarning(minutesRemaining: minutesRemaining)
            }
        }
        timerManager.onBreakCountdown = { [weak self] secondsRemaining in
            DispatchQueue.main.async {
                self?.updateInAppWarning(secondsRemaining: secondsRemaining)
            }
        }
        timerManager.onTimerStateChange = { [weak self] in
            DispatchQueue.main.async {
                self?.handleTimerStateChange()
            }
        }
        
        // Create menu
        setupMenu()
        
        // Start menu update timer
        startMenuUpdateTimer()
        
        // Start timer
        timerManager.start()
        
        // Setup Command+Q override
        NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            return self?.handleKeyDown(event: event) ?? event
        }
    }
    
    // Handle Command+Q
    private func handleKeyDown(event: NSEvent) -> NSEvent? {
        // Check if Command+Q is pressed
        if event.modifierFlags.contains(.command) && event.charactersIgnoringModifiers == "q" {
            // Block Command+Q completely - can only quit from settings
            print("🚫 Command+Q blocked - use settings to quit")
            return nil // Block the event without showing an alert here
        }
        return event
    }
    
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        // If the Settings quit button authorized this, let it through
        if allowedToQuit { return .terminateNow }
        
        // Otherwise block and show protection message
        let alert = NSAlert()
        alert.messageText = "Quit Disabled"
        alert.informativeText = "To quit Descreen, please use the Quit option in Settings."
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        alert.runModal()
        
        return .terminateCancel
    }
    
    // Menu update timer
    private func startMenuUpdateTimer() {
        menuUpdateTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.updateMenuTimes()
        }
    }
    
    // Update menu times
    private func updateMenuTimes() {
        guard let menu = statusItem.menu else { return }
        
        // Update work timer item
        if let timeLeftItem = menu.items.first {
            let remaining = timerManager.getRemainingWorkTime()
            let minutes = Int(remaining) / 60
            let seconds = Int(remaining) % 60
            timeLeftItem.title = String(format: "Next break in: %d:%02d", minutes, seconds)
        }
        
        // Update focus item
        if menu.items.count > 1 {
            let focusItem = menu.items[1]
            let remaining = timerManager.getRemainingFocusTime()
            if remaining > 0 {
                let minutes = Int(remaining) / 60
                let seconds = Int(remaining) % 60
                focusItem.title = String(format: "Focus Mode: %d:%02d left", minutes, seconds)
            } else {
                focusItem.title = "Focus Mode: Off"
            }
        }
    }
    
    func setupMenu() {
        let menu = NSMenu()
        
        let timeLeftItem = NSMenuItem(title: "Next break: calculating...", action: nil, keyEquivalent: "")
        timeLeftItem.isEnabled = false
        menu.addItem(timeLeftItem)
        
        let focusItem = NSMenuItem(title: "Focus Mode: Off", action: nil, keyEquivalent: "")
        focusItem.isEnabled = false
        menu.addItem(focusItem)
        
        timerManager.onTimeUpdate = { [weak timeLeftItem] remaining in
            DispatchQueue.main.async {
                let minutes = Int(remaining) / 60
                let seconds = Int(remaining) % 60
                timeLeftItem?.title = String(format: "Next break in: %d:%02d", minutes, seconds)
            }
        }
        
        timerManager.onFocusUpdate = { [weak focusItem] remaining in
            DispatchQueue.main.async {
                if remaining > 0 {
                    let minutes = Int(remaining) / 60
                    let seconds = Int(remaining) % 60
                    focusItem?.title = String(format: "Focus Mode: %d:%02d left", minutes, seconds)
                } else {
                    focusItem?.title = "Focus Mode: Off"
                }
            }
        }
        
        menu.addItem(NSMenuItem.separator())
        
        menu.addItem(NSMenuItem(title: "Settings", action: #selector(openSettings), keyEquivalent: "s"))
        
        let focusToggleItem = NSMenuItem(title: "Enable Focus Mode", action: #selector(toggleFocusMode), keyEquivalent: "f")
        menu.addItem(focusToggleItem)
        
        menu.addItem(NSMenuItem(title: "Take Break Now", action: #selector(takeBreakNow), keyEquivalent: "b"))
        
        menu.addItem(NSMenuItem.separator())
        
        menu.addItem(NSMenuItem(title: "Send Feedback", action: #selector(openFeedback), keyEquivalent: ""))
        
        menu.addItem(NSMenuItem(title: "Credits", action: #selector(showCredits), keyEquivalent: ""))
        
        menu.addItem(NSMenuItem.separator())
        
        let launchAtLoginItem = NSMenuItem(title: "Launch at Login", action: #selector(toggleLaunchAtLogin), keyEquivalent: "")
        launchAtLoginItem.state = isLaunchAtLoginEnabled() ? .on : .off
        menu.addItem(launchAtLoginItem)
        
        statusItem.menu = menu
        
        // Update menu items based on settings
        timerManager.onSettingsChange = { [weak focusToggleItem, weak self] in
            DispatchQueue.main.async {
                if let manager = self?.timerManager {
                    if manager.isFocusModeActive {
                        focusToggleItem?.title = "Disable Focus Mode"
                    } else {
                        focusToggleItem?.title = "Enable Focus Mode"
                    }
                }
            }
        }
    }
    
    @objc func openSettings() {
        if settingsWindow == nil {
            let settingsView = SettingsView(timerManager: timerManager, appDelegate: self)
            let hostingController = NSHostingController(rootView: settingsView)
            
            settingsWindow = NSWindow(contentViewController: hostingController)
            settingsWindow?.title = "Descreen Settings"
            settingsWindow?.styleMask = [.titled, .closable, .resizable]
            settingsWindow?.setContentSize(NSSize(width: 450, height: 750))
            settingsWindow?.center()
            
            // Apply theme to window
            applyThemeToWindow(settingsWindow)
            
            settingsWindow?.delegate = self
        }
        
        settingsWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    
    func applyThemeToWindow(_ window: NSWindow?) {
        guard let window = window else { return }
        
        switch timerManager.currentTheme {
        case .system:
            window.appearance = nil
        case .light:
            window.appearance = NSAppearance(named: .aqua)
        case .dark:
            window.appearance = NSAppearance(named: .darkAqua)
        }
    }
    
    @objc func toggleFocusMode() {
        if timerManager.isFocusModeActive {
            timerManager.endFocusMode()
        } else {
            // Check cooldown
            let focusCooldownEnabled = UserDefaults.standard.bool(forKey: "focusCooldownEnabled")
            if focusCooldownEnabled {
                let lastFocusEnd = UserDefaults.standard.double(forKey: "lastFocusModeEnd")
                let cooldownMinutes = UserDefaults.standard.double(forKey: "focusCooldownMinutes")
                let cooldownSeconds = cooldownMinutes * 60
                
                if lastFocusEnd > 0 {
                    let timeSinceLastFocus = Date().timeIntervalSince1970 - lastFocusEnd
                    if timeSinceLastFocus < cooldownSeconds {
                        let remainingCooldown = cooldownSeconds - timeSinceLastFocus
                        let minutes = Int(remainingCooldown) / 60
                        let seconds = Int(remainingCooldown) % 60
                        
                        let alert = NSAlert()
                        alert.messageText = "Focus Mode Cooldown"
                        alert.informativeText = "Please wait \(minutes):\(String(format: "%02d", seconds)) before enabling Focus Mode again."
                        alert.alertStyle = .informational
                        alert.addButton(withTitle: "OK")
                        alert.runModal()
                        return
                    }
                }
            }
            
            timerManager.startFocusMode()
        }
    }
    
    @objc func takeBreakNow() {
        timerManager.triggerBreakNow()
    }
    
    func isLaunchAtLoginEnabled() -> Bool {
        if #available(macOS 13.0, *) {
            return SMAppService.mainApp.status == .enabled
        } else {
            return UserDefaults.standard.bool(forKey: "launchAtLogin")
        }
    }
    
    @objc func toggleLaunchAtLogin() {
        if isLaunchAtLoginEnabled() {
            disableLaunchAtLogin()
        } else {
            enableLaunchAtLogin()
        }
    }
    
    func enableLaunchAtLogin() {
        if #available(macOS 13.0, *) {
            do {
                try SMAppService.mainApp.register()
                updateLaunchAtLoginMenuItem()
                print("✅ Launch at login enabled")
            } catch {
                print("❌ Failed to enable launch at login: \(error)")
                showLaunchAtLoginError(enable: true)
            }
        } else {
            UserDefaults.standard.set(true, forKey: "launchAtLogin")
            updateLaunchAtLoginMenuItem()
            showLaunchAtLoginLegacyMessage()
        }
    }
    
    func disableLaunchAtLogin() {
        if #available(macOS 13.0, *) {
            do {
                try SMAppService.mainApp.unregister()
                updateLaunchAtLoginMenuItem()
                print("✅ Launch at login disabled")
            } catch {
                print("❌ Failed to disable launch at login: \(error)")
                showLaunchAtLoginError(enable: false)
            }
        } else {
            UserDefaults.standard.set(false, forKey: "launchAtLogin")
            updateLaunchAtLoginMenuItem()
            showLaunchAtLoginLegacyMessage()
        }
    }
    
    func updateLaunchAtLoginMenuItem() {
        let enabled = isLaunchAtLoginEnabled()
        if let menu = statusItem.menu,
           let item = menu.items.first(where: { $0.title == "Launch at Login" }) {
            item.state = enabled ? .on : .off
        }
        // Notify SettingsView so its toggle stays in sync
        NotificationCenter.default.post(
            name: .launchAtLoginDidChange,
            object: nil,
            userInfo: ["enabled": enabled]
        )
    }
    
    func showLaunchAtLoginError(enable: Bool) {
        let alert = NSAlert()
        alert.messageText = "Launch at Login Error"
        alert.informativeText = "Unable to \(enable ? "enable" : "disable") launch at login. Please check System Settings > General > Login Items."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
    
    func showLaunchAtLoginLegacyMessage() {
        let alert = NSAlert()
        alert.messageText = "Manual Setup Required"
        alert.informativeText = "Please add Descreen to your Login Items manually in System Preferences > Users & Groups > Login Items."
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
    
    @objc func openFeedback() {
        // Open GitHub issues page in browser
        if let url = URL(string: "https://github.com/thaclownminion/MacOS-eye-care/issues") {
            NSWorkspace.shared.open(url)
        }
    }
    
    func showBreakOverlay() {
        if breakWindow == nil {
            breakWindow = BreakOverlayWindow(timerManager: timerManager)
        }
        breakWindow?.show()
    }
    
    func hideBreakOverlay() {
        print("🔴🔴🔴 hideBreakOverlay() called in AppDelegate")
        
        // Close any warning windows
        warningWindow?.close()
        warningWindow = nil
        warningHostingController = nil
        
        guard let window = breakWindow else {
            print("⚠️ breakWindow is already nil")
            return
        }
        
        print("🔴 Step 1: Force closing window")
        window.forceClose()
        
        print("🔴 Step 2: Setting breakWindow to nil")
        breakWindow = nil
        
        print("🔴 Step 3: Forcing window list update")
        NSApp.updateWindows()
        
        print("🔴 Step 4: Hiding all app windows at screenSaver level")
        for appWindow in NSApp.windows {
            if appWindow.level == .screenSaver {
                print("🔴 Found lingering screenSaver window, forcing it out")
                appWindow.orderOut(nil)
                appWindow.close()
            }
        }
        
        print("🔴 Step 5: Activating normal windows")
        NSApp.activate(ignoringOtherApps: false)
        
        print("✅ hideBreakOverlay completed - window MUST be gone")
    }

    private var warningWindow: NSWindow?
    private var warningHostingController: NSHostingController<InAppWarningView>?

    func showInAppWarning(minutesRemaining: Int) {
        warningWindow?.close()
        
        let warningView = InAppWarningView(
            minutesRemaining: minutesRemaining,
            secondsRemaining: nil
        )
        let hostingController = NSHostingController(rootView: warningView)
        warningHostingController = hostingController
        
        let window = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 340, height: 90),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        
        window.level = .floating
        window.backgroundColor = .clear
        window.isOpaque = false
        window.hasShadow = true
        window.contentView = hostingController.view
        
        if let screen = NSScreen.main {
            let screenFrame = screen.visibleFrame
            let windowFrame = window.frame
            let x = screenFrame.maxX - windowFrame.width - 20
            let y = screenFrame.maxY - windowFrame.height - 20
            window.setFrameOrigin(NSPoint(x: x, y: y))
        }
        
        window.orderFrontRegardless()
        warningWindow = window
        
        if minutesRemaining != 1 {
            DispatchQueue.main.asyncAfter(deadline: .now() + 5) { [weak self] in
                self?.warningWindow?.close()
                self?.warningWindow = nil
                self?.warningHostingController = nil
            }
        }
    }

    func updateInAppWarning(secondsRemaining: Int) {
        guard secondsRemaining <= 60 else { return }
        
        if warningWindow == nil {
            let warningView = InAppWarningView(
                minutesRemaining: nil,
                secondsRemaining: secondsRemaining
            )
            let hostingController = NSHostingController(rootView: warningView)
            warningHostingController = hostingController
            
            let window = NSPanel(
                contentRect: NSRect(x: 0, y: 0, width: 340, height: 90),
                styleMask: [.borderless, .nonactivatingPanel],
                backing: .buffered,
                defer: false
            )
            
            window.level = .floating
            window.backgroundColor = .clear
            window.isOpaque = false
            window.hasShadow = true
            window.contentView = hostingController.view
            
            if let screen = NSScreen.main {
                let screenFrame = screen.visibleFrame
                let windowFrame = window.frame
                let x = screenFrame.maxX - windowFrame.width - 20
                let y = screenFrame.maxY - windowFrame.height - 20
                window.setFrameOrigin(NSPoint(x: x, y: y))
            }
            
            window.orderFrontRegardless()
            warningWindow = window
        } else {
            let warningView = InAppWarningView(
                minutesRemaining: nil,
                secondsRemaining: secondsRemaining
            )
            warningHostingController?.rootView = warningView
        }
        
        if secondsRemaining == 0 {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                self?.warningWindow?.close()
                self?.warningWindow = nil
                self?.warningHostingController = nil
            }
        }
    }
    
    func handleTimerStateChange() {
        // Hide popup when timer is paused/modified
        warningWindow?.close()
        warningWindow = nil
        warningHostingController = nil
    }
    
    @objc func showCredits() {
        let alert = NSAlert()
        alert.messageText = "Credits"
        alert.informativeText = """
        Descreen
        
        Created by:  Apophis        
        © \(Calendar.current.component(.year, from: Date()))
        App version: 3.2.2
        """
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        alert.addButton(withTitle: "Open GitHub")
        
        let response = alert.runModal()
        
        if response == .alertSecondButtonReturn {
            if let url = URL(string: "https://github.com/thaclownminion/Descreen") {
                NSWorkspace.shared.open(url)
            }
        }
    }
}

extension AppDelegate: NSWindowDelegate {
    func windowWillClose(_ notification: Notification) {
        if notification.object as? NSWindow == settingsWindow {
            settingsWindow = nil
        }
    }
}

extension Notification.Name {
    static let launchAtLoginDidChange = Notification.Name("launchAtLoginDidChange")
}
