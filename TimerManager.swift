import Foundation
import UserNotifications

class TimerManager: ObservableObject {
    @Published var workInterval: TimeInterval = 20 * 60
    @Published var breakDuration: TimeInterval = 20
    @Published var focusDuration: TimeInterval = 60 * 60
    @Published var isFocusModeActive: Bool = false
    @Published var breakMessage: String = "Time for a break!"
    @Published var currentTheme: AppTheme = .system  // Only for settings window
    
    // Weekly schedule
    @Published var scheduleEnabled: Bool = false
    @Published var mondayEnabled: Bool = true
    @Published var tuesdayEnabled: Bool = true
    @Published var wednesdayEnabled: Bool = true
    @Published var thursdayEnabled: Bool = true
    @Published var fridayEnabled: Bool = true
    @Published var saturdayEnabled: Bool = false
    @Published var sundayEnabled: Bool = false
    
    // Notification settings
    @Published var notificationsEnabled: Bool = true
    @Published var notificationTiming: [Int] = [5, 2, 1]
    @Published var useSystemNotifications: Bool = true

    private var notificationSent: Set<Int> = []
    private var workTimer: Timer?
    private var breakTimer: Timer?
    private var focusTimer: Timer?
    private var remainingWorkTime: TimeInterval = 0
    private var remainingBreakTime: TimeInterval = 0
    private var remainingFocusTime: TimeInterval = 0
    
    var onBreakStart: (() -> Void)?
    var onBreakEnd: (() -> Void)?
    var onTimeUpdate: ((TimeInterval) -> Void)?
    var onSettingsChange: (() -> Void)?
    var onFocusUpdate: ((TimeInterval) -> Void)?
    var onBreakWarning: ((Int) -> Void)?
    var onBreakCountdown: ((Int) -> Void)?
    var onTimerStateChange: (() -> Void)?
    
    private var isOnBreak = false
    
    init() {
        loadSettings()
        remainingWorkTime = workInterval
    }
    
    func start() {
        startWorkTimer()
    }
    
    private func isTodayEnabled() -> Bool {
        if !scheduleEnabled {
            return true
        }
        
        let calendar = Calendar.current
        let weekday = calendar.component(.weekday, from: Date())
        
        switch weekday {
        case 1: return sundayEnabled
        case 2: return mondayEnabled
        case 3: return tuesdayEnabled
        case 4: return wednesdayEnabled
        case 5: return thursdayEnabled
        case 6: return fridayEnabled
        case 7: return saturdayEnabled
        default: return true
        }
    }
    
    private func startWorkTimer() {
        workTimer?.invalidate()
        remainingWorkTime = workInterval
        notificationSent.removeAll()
        
        workTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            
            if self.isFocusModeActive || !self.isTodayEnabled() {
                self.onTimeUpdate?(self.remainingWorkTime)
                return
            }
            
            self.remainingWorkTime -= 1
            self.onTimeUpdate?(self.remainingWorkTime)
            
            self.checkAndSendNotifications()
            
            if self.remainingWorkTime <= 0 {
                self.startBreak()
            }
        }
    }
    
    private func checkAndSendNotifications() {
        guard notificationsEnabled else { return }
        
        let minutesRemaining = Int(remainingWorkTime / 60)
        let secondsRemaining = Int(remainingWorkTime)
        let secondsInMinute = Int(remainingWorkTime.truncatingRemainder(dividingBy: 60))
        
        if secondsInMinute <= 1 {
            for timing in notificationTiming {
                if minutesRemaining == timing && !notificationSent.contains(timing) {
                    notificationSent.insert(timing)
                    sendBreakNotification(minutesRemaining: timing)
                }
            }
        }
        
        if !useSystemNotifications && secondsRemaining <= 60 && secondsRemaining > 0 {
            onBreakCountdown?(secondsRemaining)
        }
        
        if remainingWorkTime == workInterval {
            notificationSent.removeAll()
        }
    }

    private func sendBreakNotification(minutesRemaining: Int) {
        if useSystemNotifications {
            let content = UNMutableNotificationContent()
            content.title = "Break Coming Soon"
            content.body = "Your eye break will start in \(minutesRemaining) minute\(minutesRemaining == 1 ? "" : "s")"
            content.sound = .default
            
            // Note: System notifications cannot show live countdowns
            // They are static once sent
            
            let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
            UNUserNotificationCenter.current().add(request)
            
            print("📬 System notification sent: \(minutesRemaining) min remaining")
        } else {
            print("📱 In-app notification: \(minutesRemaining) min remaining")
            onBreakWarning?(minutesRemaining)
        }
    }
    
    private func startBreak() {
        print("⏰ BREAK STARTING - Duration: \(breakDuration) seconds")
        workTimer?.invalidate()
        workTimer = nil
        isOnBreak = true
        remainingBreakTime = breakDuration
        
        DispatchQueue.main.async {
            self.onBreakStart?()
        }
        
        breakTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] timer in
            guard let self = self else {
                timer.invalidate()
                return
            }
            
            self.remainingBreakTime -= 1
            print("⏱️ Break remaining: \(self.remainingBreakTime) seconds")
            
            if self.remainingBreakTime <= 0 {
                print("✅ BREAK ENDING - Timer hit 0")
                timer.invalidate()
                self.breakTimer = nil
                self.forceEndBreak()
            }
        }
    }
    
    private func forceEndBreak() {
        print("🔴 forceEndBreak() called")
        
        breakTimer?.invalidate()
        breakTimer = nil
        
        isOnBreak = false
        remainingBreakTime = 0
        
        print("🔴 Calling onBreakEnd callback NOW")
        
        DispatchQueue.main.async {
            self.onBreakEnd?()
            print("🔴 onBreakEnd callback executed (attempt 1)")
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.onBreakEnd?()
            print("🔴 onBreakEnd callback executed (attempt 2)")
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            print("🔄 Restarting work timer")
            self.startWorkTimer()
        }
    }
    
    func triggerBreakNow() {
        if !isOnBreak && !isFocusModeActive && isTodayEnabled() {
            workTimer?.invalidate()
            startBreak()
        }
    }
    
    func getRemainingBreakTime() -> TimeInterval {
        return max(0, remainingBreakTime)
    }
    
    func getRemainingWorkTime() -> TimeInterval {
        return max(0, remainingWorkTime)
    }
    
    func startFocusMode() {
        isFocusModeActive = true
        remainingFocusTime = focusDuration
        
        onTimerStateChange?()
        
        focusTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            self.remainingFocusTime -= 1
            self.onFocusUpdate?(self.remainingFocusTime)
            
            if self.remainingFocusTime <= 0 {
                self.endFocusMode()
            }
        }
        
        onSettingsChange?()
    }
    
    func endFocusMode() {
        focusTimer?.invalidate()
        isFocusModeActive = false
        remainingFocusTime = 0
        onFocusUpdate?(0)
        
        // Save the time when focus mode ended (for cooldown)
        UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: "lastFocusModeEnd")
        
        startWorkTimer()
        
        onSettingsChange?()
        onTimerStateChange?()
    }
    
    func getRemainingFocusTime() -> TimeInterval {
        return remainingFocusTime
    }
    
    func updateSettings(work: TimeInterval, breakTime: TimeInterval, focusTime: TimeInterval, message: String, theme: AppTheme) {
        workInterval = work
        breakDuration = breakTime
        focusDuration = focusTime
        breakMessage = message
        currentTheme = theme
        
        saveSettings()
        
        onTimerStateChange?()
        
        onSettingsChange?()
        
        if !isOnBreak {
            startWorkTimer()
        }
    }
    
    func updateScheduleSettings() {
        saveScheduleSettings()
        onSettingsChange?()
    }
    
    func saveSettings() {
        UserDefaults.standard.set(workInterval, forKey: "workInterval")
        UserDefaults.standard.set(breakDuration, forKey: "breakDuration")
        UserDefaults.standard.set(focusDuration, forKey: "focusDuration")
        UserDefaults.standard.set(notificationsEnabled, forKey: "notificationsEnabled")
        UserDefaults.standard.set(useSystemNotifications, forKey: "useSystemNotifications")
        UserDefaults.standard.set(notificationTiming, forKey: "notificationTiming")
        UserDefaults.standard.set(breakMessage, forKey: "breakMessage")
        
        // Save theme
        if let themeData = try? JSONEncoder().encode(currentTheme) {
            UserDefaults.standard.set(themeData, forKey: "currentTheme")
        }
    }
    
    func saveScheduleSettings() {
        UserDefaults.standard.set(scheduleEnabled, forKey: "scheduleEnabled")
        UserDefaults.standard.set(mondayEnabled, forKey: "mondayEnabled")
        UserDefaults.standard.set(tuesdayEnabled, forKey: "tuesdayEnabled")
        UserDefaults.standard.set(wednesdayEnabled, forKey: "wednesdayEnabled")
        UserDefaults.standard.set(thursdayEnabled, forKey: "thursdayEnabled")
        UserDefaults.standard.set(fridayEnabled, forKey: "fridayEnabled")
        UserDefaults.standard.set(saturdayEnabled, forKey: "saturdayEnabled")
        UserDefaults.standard.set(sundayEnabled, forKey: "sundayEnabled")
    }
    
    private func loadSettings() {
        let savedWork = UserDefaults.standard.double(forKey: "workInterval")
        let savedBreak = UserDefaults.standard.double(forKey: "breakDuration")
        let savedFocus = UserDefaults.standard.double(forKey: "focusDuration")
        
        if savedWork > 0 { workInterval = savedWork }
        if savedBreak > 0 { breakDuration = savedBreak }
        if savedFocus > 0 { focusDuration = savedFocus }
        
        notificationsEnabled = UserDefaults.standard.object(forKey: "notificationsEnabled") as? Bool ?? true
        useSystemNotifications = UserDefaults.standard.object(forKey: "useSystemNotifications") as? Bool ?? true
        if let savedTiming = UserDefaults.standard.array(forKey: "notificationTiming") as? [Int], !savedTiming.isEmpty {
            notificationTiming = savedTiming
        }
        
        breakMessage = UserDefaults.standard.string(forKey: "breakMessage") ?? "Time for a break!"
        
        // Load theme
        if let themeData = UserDefaults.standard.data(forKey: "currentTheme"),
           let theme = try? JSONDecoder().decode(AppTheme.self, from: themeData) {
            currentTheme = theme
        }
        
        scheduleEnabled = UserDefaults.standard.bool(forKey: "scheduleEnabled")
        if UserDefaults.standard.object(forKey: "mondayEnabled") != nil {
            mondayEnabled = UserDefaults.standard.bool(forKey: "mondayEnabled")
            tuesdayEnabled = UserDefaults.standard.bool(forKey: "tuesdayEnabled")
            wednesdayEnabled = UserDefaults.standard.bool(forKey: "wednesdayEnabled")
            thursdayEnabled = UserDefaults.standard.bool(forKey: "thursdayEnabled")
            fridayEnabled = UserDefaults.standard.bool(forKey: "fridayEnabled")
            saturdayEnabled = UserDefaults.standard.bool(forKey: "saturdayEnabled")
            sundayEnabled = UserDefaults.standard.bool(forKey: "sundayEnabled")
        }
    }
}
