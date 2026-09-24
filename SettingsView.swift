import SwiftUI

struct SettingsView: View {
    @ObservedObject var timerManager: TimerManager
    weak var appDelegate: AppDelegate?
    
    @State private var workMinutes: Double
    @State private var breakSeconds: Double
    @State private var focusMinutes: Double
    @State private var breakMessage: String
    @State private var selectedTheme: AppTheme
    @State private var launchAtLogin: Bool
    
    @State private var notificationsEnabled: Bool
    @State private var useSystemNotifications: Bool
    @State private var notification5min: Bool
    @State private var notification2min: Bool
    @State private var notification1min: Bool
    
    @State private var scheduleEnabled: Bool
    @State private var mondayEnabled: Bool
    @State private var tuesdayEnabled: Bool
    @State private var wednesdayEnabled: Bool
    @State private var thursdayEnabled: Bool
    @State private var fridayEnabled: Bool
    @State private var saturdayEnabled: Bool
    @State private var sundayEnabled: Bool
    
    // NEW: Focus cooldown settings
    @State private var focusCooldownEnabled: Bool = UserDefaults.standard.bool(forKey: "focusCooldownEnabled")
    @State private var focusCooldownMinutes: Double = UserDefaults.standard.double(forKey: "focusCooldownMinutes") == 0 ? 30 : UserDefaults.standard.double(forKey: "focusCooldownMinutes")
    
    // NEW: Quit delay settings
    @State private var quitDelayEnabled: Bool = UserDefaults.standard.bool(forKey: "quitDelayEnabled")
    @State private var quitDelaySeconds: Double = UserDefaults.standard.double(forKey: "quitDelaySeconds") == 0 ? 10 : UserDefaults.standard.double(forKey: "quitDelaySeconds")
    
    // Quit countdown timer state
    @State private var quitCountdownActive: Bool = false
    @State private var quitCountdownRemaining: Int = 0
    @State private var quitTimer: Timer? = nil
    
    @State private var selectedTab: SettingsTab = .general
    
    // HARDCODED DONATION LINK - Change this URL to your donation page
    private let donationURL = "https://buymeacoffee.com/kai_rozema"
    
    let defaultBreakMessage = "Time for a break!"
    
    enum SettingsTab: String, CaseIterable {
        case general = "General"
        case timers = "Timers"
        case notifications = "Notifications"
        case schedule = "Schedule"
        case advanced = "Advanced"
    }
    
    init(timerManager: TimerManager, appDelegate: AppDelegate?) {
        self.timerManager = timerManager
        self.appDelegate = appDelegate
        _workMinutes = State(initialValue: timerManager.workInterval / 60)
        _breakSeconds = State(initialValue: timerManager.breakDuration)
        _focusMinutes = State(initialValue: timerManager.focusDuration / 60)
        _breakMessage = State(initialValue: timerManager.breakMessage)
        _selectedTheme = State(initialValue: timerManager.currentTheme)
        
        _scheduleEnabled = State(initialValue: timerManager.scheduleEnabled)
        _mondayEnabled = State(initialValue: timerManager.mondayEnabled)
        _tuesdayEnabled = State(initialValue: timerManager.tuesdayEnabled)
        _wednesdayEnabled = State(initialValue: timerManager.wednesdayEnabled)
        _thursdayEnabled = State(initialValue: timerManager.thursdayEnabled)
        _fridayEnabled = State(initialValue: timerManager.fridayEnabled)
        _saturdayEnabled = State(initialValue: timerManager.saturdayEnabled)
        _sundayEnabled = State(initialValue: timerManager.sundayEnabled)
        
        // Read real launch-at-login state from SMAppService (not UserDefaults)
        _launchAtLogin = State(initialValue: appDelegate?.isLaunchAtLoginEnabled() ?? false)
        
        _notificationsEnabled = State(initialValue: timerManager.notificationsEnabled)
        _useSystemNotifications = State(initialValue: timerManager.useSystemNotifications)
        _notification5min = State(initialValue: timerManager.notificationTiming.contains(5))
        _notification2min = State(initialValue: timerManager.notificationTiming.contains(2))
        _notification1min = State(initialValue: timerManager.notificationTiming.contains(1))
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(spacing: 8) {
                Image(systemName: "eye.fill")
                    .font(.system(size: 40))
                    .foregroundColor(.black)
                
                Text("Descreen")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Text("Settings")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .padding(.top, 20)
            .padding(.bottom, 10)
            
            Divider()
            
            // Tab selector
            Picker("", selection: $selectedTab) {
                ForEach(SettingsTab.allCases, id: \.self) { tab in
                    Text(tab.rawValue).tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
            
            // Tab content
            ScrollView {
                VStack(spacing: 0) {
                    switch selectedTab {
                    case .general:
                        generalTab
                    case .timers:
                        timersTab
                    case .notifications:
                        notificationsTab
                    case .schedule:
                        scheduleTab
                    case .advanced:
                        advancedTab
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
            }
            
            Divider()
            
            // Action buttons
            HStack(spacing: 12) {
                // Donation button
                Button(action: openDonationLink) {
                    HStack {
                        Image(systemName: "heart.fill")
                        Text("Buy me a coffee")
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.pink)
                    .foregroundColor(.white)
                    .cornerRadius(8)
                }
                .buttonStyle(.plain)
                
                Button(action: saveSettings) {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                        Text("Save Settings")
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(8)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 15)
        }
        .frame(width: 450, height: 750)
    }
    
    // MARK: - General Tab
    var generalTab: some View {
        VStack(alignment: .leading, spacing: 20) {
            SettingGroup(title: "Appearance") {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Theme")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Picker("", selection: $selectedTheme) {
                        ForEach(AppTheme.allCases, id: \.self) { theme in
                            Text(theme.rawValue).tag(theme)
                        }
                    }
                    .pickerStyle(.segmented)
                    .onChange(of: selectedTheme) { oldValue, newValue in
                        applyThemeImmediately(newValue)
                    }
                    
                    Text("Applies to settings window only")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            SettingGroup(title: "Break Message") {
                VStack(alignment: .leading, spacing: 8) {
                    TextField("Enter custom message", text: $breakMessage)
                        .textFieldStyle(.roundedBorder)
                    
                    Button(action: resetToDefaultMessage) {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.counterclockwise")
                                .font(.system(size: 11))
                            Text("Reset to default")
                                .font(.system(size: 12))
                        }
                        .foregroundColor(.blue)
                    }
                    .buttonStyle(.plain)
                    
                    Text("Displayed during break overlays")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            SettingGroup(title: "Startup") {
                VStack(alignment: .leading, spacing: 8) {
                    Toggle("Launch at Login", isOn: $launchAtLogin)
                        .onChange(of: launchAtLogin) { oldValue, newValue in
                            if newValue {
                                appDelegate?.enableLaunchAtLogin()
                            } else {
                                appDelegate?.disableLaunchAtLogin()
                            }
                        }
                    
                    Text("Start Descreen automatically when you log in")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .launchAtLoginDidChange)) { notification in
                if let enabled = notification.userInfo?["enabled"] as? Bool {
                    launchAtLogin = enabled
                }
            }
        }
        .padding(.top, 10)
    }
    
    // MARK: - Timers Tab
    var timersTab: some View {
        VStack(alignment: .leading, spacing: 20) {
            SettingGroup(title: "Work Interval") {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("\(Int(workMinutes)) minutes")
                            .font(.headline)
                        Spacer()
                    }
                    
                    Slider(value: $workMinutes, in: 1...120, step: 1)
                    
                    Text("Time between breaks")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            SettingGroup(title: "Break Duration") {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("\(Int(breakSeconds)) seconds")
                            .font(.headline)
                        Spacer()
                    }
                    
                    Slider(value: $breakSeconds, in: 10...300, step: 5)
                    
                    Text("How long each break lasts")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            SettingGroup(title: "Focus Mode Duration") {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("\(Int(focusMinutes)) minutes")
                            .font(.headline)
                        Spacer()
                    }
                    
                    Slider(value: $focusMinutes, in: 15...180, step: 5)
                    
                    Text("No breaks during focus mode")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.top, 10)
    }
    
    // MARK: - Notifications Tab
    var notificationsTab: some View {
        VStack(alignment: .leading, spacing: 20) {
            SettingGroup(title: "Break Notifications") {
                VStack(alignment: .leading, spacing: 12) {
                    Toggle("Enable Notifications", isOn: $notificationsEnabled)
                        .fontWeight(.medium)
                    
                    if notificationsEnabled {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Notification Type")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            
                            Picker("", selection: $useSystemNotifications) {
                                Text("System Notifications").tag(true)
                                Text("In-App Indicator").tag(false)
                            }
                            .pickerStyle(.segmented)
                            
                            Divider()
                            
                            Text("Notify me before break:")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            
                            Toggle("5 minutes before", isOn: $notification5min)
                            Toggle("2 minutes before", isOn: $notification2min)
                            Toggle("1 minute before", isOn: $notification1min)
                            
                            Text(useSystemNotifications ?
                                 "System notifications appear in Notification Center" :
                                    "In-app indicator shows at top-right of screen with live countdown")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.top, 5)
                        }
                    }
                }
            }
        }
        .padding(.top, 10)
    }
    
    // MARK: - Schedule Tab
    var scheduleTab: some View {
        VStack(alignment: .leading, spacing: 20) {
            SettingGroup(title: "Weekly Schedule") {
                VStack(alignment: .leading, spacing: 12) {
                    Toggle("Enable Schedule", isOn: $scheduleEnabled)
                        .fontWeight(.medium)
                        .onChange(of: scheduleEnabled) { oldValue, newValue in
                            timerManager.scheduleEnabled = newValue
                            timerManager.updateScheduleSettings()
                        }
                    
                    if scheduleEnabled {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Active Days")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            
                            Toggle("Monday", isOn: $mondayEnabled)
                                .onChange(of: mondayEnabled) { oldValue, newValue in
                                    timerManager.mondayEnabled = newValue
                                }
                            Toggle("Tuesday", isOn: $tuesdayEnabled)
                                .onChange(of: tuesdayEnabled) { oldValue, newValue in
                                    timerManager.tuesdayEnabled = newValue
                                }
                            Toggle("Wednesday", isOn: $wednesdayEnabled)
                                .onChange(of: wednesdayEnabled) { oldValue, newValue in
                                    timerManager.wednesdayEnabled = newValue
                                }
                            Toggle("Thursday", isOn: $thursdayEnabled)
                                .onChange(of: thursdayEnabled) { oldValue, newValue in
                                    timerManager.thursdayEnabled = newValue
                                }
                            Toggle("Friday", isOn: $fridayEnabled)
                                .onChange(of: fridayEnabled) { oldValue, newValue in
                                    timerManager.fridayEnabled = newValue
                                }
                            Toggle("Saturday", isOn: $saturdayEnabled)
                                .onChange(of: saturdayEnabled) { oldValue, newValue in
                                    timerManager.saturdayEnabled = newValue
                                }
                            Toggle("Sunday", isOn: $sundayEnabled)
                                .onChange(of: sundayEnabled) { oldValue, newValue in
                                    timerManager.sundayEnabled = newValue
                                }
                            
                            Text("Breaks only happen on selected days")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
        }
        .padding(.top, 10)
    }
    
    // MARK: - Advanced Tab
    var advancedTab: some View {
        VStack(alignment: .leading, spacing: 20) {
            SettingGroup(title: "Focus Mode Cooldown") {
                VStack(alignment: .leading, spacing: 12) {
                    Toggle("Enable Cooldown", isOn: $focusCooldownEnabled)
                        .fontWeight(.medium)
                    
                    if focusCooldownEnabled {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("\(Int(focusCooldownMinutes)) minutes")
                                    .font(.headline)
                                Spacer()
                            }
                            
                            Slider(value: $focusCooldownMinutes, in: 5...120, step: 5)
                            
                            Text("Wait time before enabling Focus Mode again")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            
            SettingGroup(title: "Quit Protection") {
                VStack(alignment: .leading, spacing: 12) {
                    Toggle("Enable Quit Delay", isOn: $quitDelayEnabled)
                        .fontWeight(.medium)
                    
                    if quitDelayEnabled {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("\(Int(quitDelaySeconds)) seconds")
                                    .font(.headline)
                                Spacer()
                            }
                            
                            Slider(value: $quitDelaySeconds, in: 5...60, step: 5)
                            
                            Text("Wait time before the quit button becomes enabled")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Text("Note: You can only quit from Settings, not the menu bar")
                        .font(.caption)
                        .foregroundColor(.orange)
                        .padding(.top, 5)
                }
            }
            
            SettingGroup(title: "Danger Zone") {
                VStack(alignment: .leading, spacing: 12) {
                    Button(action: handleQuitButton) {
                        HStack {
                            Image(systemName: quitCountdownActive ? "timer" : "xmark.circle.fill")
                            if quitCountdownActive {
                                Text("Wait \(quitCountdownRemaining)s to quit")
                            } else {
                                Text("Quit Descreen")
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(quitCountdownActive ? Color.gray : Color.red)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                    }
                    .buttonStyle(.plain)
                    .disabled(quitCountdownActive)
                    .opacity(quitCountdownActive ? 0.6 : 1.0)
                    
                    if quitCountdownActive {
                        ProgressView(value: Double(Int(quitDelaySeconds) - quitCountdownRemaining), total: Double(Int(quitDelaySeconds)))
                            .progressViewStyle(.linear)
                    }
                    
                    Text("Only way to quit the application")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.top, 10)
        .onAppear {
            // Start the timer when the Advanced tab appears
            if quitDelayEnabled {
                startQuitCountdown()
            }
        }
        // Remove .onDisappear if you don't want to reset the timer when leaving the tab
        // .onDisappear {
        //     cancelQuitCountdown()
        // }
    }
    
    // MARK: - Helper Functions
    func resetToDefaultMessage() {
        breakMessage = defaultBreakMessage
    }
    
    func applyThemeImmediately(_ theme: AppTheme) {
        timerManager.currentTheme = theme
        
        if let window = NSApp.windows.first(where: { $0.title == "Descreen Settings" }) {
            switch theme {
            case .system:
                window.appearance = nil
            case .light:
                window.appearance = NSAppearance(named: .aqua)
            case .dark:
                window.appearance = NSAppearance(named: .darkAqua)
            }
        }
    }
    
    func openDonationLink() {
        guard let url = URL(string: donationURL) else {
            let alert = NSAlert()
            alert.messageText = "Invalid Donation URL"
            alert.informativeText = "The donation URL is not properly configured. Please update it in the code."
            alert.alertStyle = .warning
            alert.addButton(withTitle: "OK")
            alert.runModal()
            return
        }
        
        NSWorkspace.shared.open(url)
    }
    
    // Start the countdown
    func startQuitCountdown() {
        guard quitDelayEnabled else {
            appDelegate?.allowedToQuit = true
            NSApplication.shared.terminate(nil)
            return
        }
        quitCountdownActive = true
        quitCountdownRemaining = Int(quitDelaySeconds)
        quitTimer?.invalidate()
        quitTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [self] timer in
            quitCountdownRemaining -= 1
            
            if quitCountdownRemaining <= 0 {
                timer.invalidate()
                quitTimer = nil
                quitCountdownActive = false
                // Timer completed, button is now enabled
            }
        }
    }
    
    // Handle the quit button
    func handleQuitButton() {
        if quitCountdownActive {
            return // Do nothing if countdown is active
        }
        
        if quitDelayEnabled && quitDelaySeconds > 0 && !quitCountdownActive && quitCountdownRemaining == 0 {
            // Quit immediately if timer is completed
            appDelegate?.allowedToQuit = true
            NSApplication.shared.terminate(nil)
        } else if quitDelayEnabled && quitDelaySeconds > 0 {
            // Start countdown if timer is not active
            startQuitCountdown()
        } else {
            // Quit immediately if delay is disabled
            appDelegate?.allowedToQuit = true
            NSApplication.shared.terminate(nil)
        }
    }
    
    func saveSettings() {
        print("💾 Saving settings...")
        
        let manager = timerManager
        
        var timings: [Int] = []
        if notification5min { timings.append(5) }
        if notification2min { timings.append(2) }
        if notification1min { timings.append(1) }
        manager.notificationTiming = timings.sorted(by: >)
        
        manager.notificationsEnabled = notificationsEnabled
        manager.useSystemNotifications = useSystemNotifications
        
        manager.updateSettings(
            work: workMinutes * 60,
            breakTime: breakSeconds,
            focusTime: focusMinutes * 60,
            message: breakMessage,
            theme: selectedTheme
        )
        
        manager.updateScheduleSettings()
        
        // Save focus cooldown settings
        UserDefaults.standard.set(focusCooldownEnabled, forKey: "focusCooldownEnabled")
        UserDefaults.standard.set(focusCooldownMinutes, forKey: "focusCooldownMinutes")
        
        // Save quit delay settings
        UserDefaults.standard.set(quitDelayEnabled, forKey: "quitDelayEnabled")
        UserDefaults.standard.set(Int(quitDelaySeconds), forKey: "quitDelaySeconds")
        
        let alert = NSAlert()
        alert.messageText = "Settings Saved ✅"
        alert.informativeText = "Your settings have been saved successfully."
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        alert.runModal()
        
        // Use orderOut instead of close() to avoid triggering applicationShouldTerminate
        if let window = NSApp.windows.first(where: { $0.title == "Descreen Settings" }) {
            window.orderOut(nil)
        }
        appDelegate?.settingsWindow = nil
    }
    
    // MARK: - Setting Group Component
    struct SettingGroup<Content: View>: View {
        let title: String
        let content: Content
        
        init(title: String, @ViewBuilder content: () -> Content) {
            self.title = title
            self.content = content()
        }
        
        var body: some View {
            VStack(alignment: .leading, spacing: 12) {
                Text(title)
                    .font(.headline)
                    .foregroundColor(.primary)
                
                content
            }
            .padding()
            .background(Color.secondary.opacity(0.1))
            .cornerRadius(10)
        }
    }
}
