import Cocoa
import SwiftUI

class BreakOverlayWindow: NSWindow {
    private var coverWindows: [NSWindow] = []
    
    init(timerManager: TimerManager) {
        let mainScreen = NSScreen.main ?? NSScreen.screens[0]
        
        super.init(
            contentRect: mainScreen.frame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        
        self.level = .screenSaver
        self.backgroundColor = NSColor.clear
        self.isOpaque = false
        self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        
        let breakView = BreakOverlayView(timerManager: timerManager)
        self.contentView = NSHostingView(rootView: breakView)
        
        self.ignoresMouseEvents = false
        self.isReleasedWhenClosed = false
    }
    
    func show() {
        print("🟢 BreakOverlayWindow.show() called")
        
        for screen in NSScreen.screens where screen != NSScreen.main {
            let coverWindow = NSWindow(
                contentRect: screen.frame,
                styleMask: [.borderless],
                backing: .buffered,
                defer: false
            )
            coverWindow.level = .screenSaver
            coverWindow.backgroundColor = NSColor.black
            coverWindow.isOpaque = true
            coverWindow.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
            coverWindow.ignoresMouseEvents = false
            coverWindow.isReleasedWhenClosed = false
            
            coverWindows.append(coverWindow)
        }
        
        self.orderFrontRegardless()
        for window in coverWindows {
            window.orderFrontRegardless()
        }
        
        NSApp.activate(ignoringOtherApps: true)
        print("🟢 Break window displayed")
    }
    
    func forceClose() {
        print("🔴 forceClose() - NUCLEAR OPTION")
        
        self.contentView = nil
        
        for window in coverWindows {
            window.contentView = nil
            window.orderOut(nil)
            window.close()
        }
        coverWindows.removeAll()
        
        self.orderOut(nil)
        self.orderBack(nil)
        
        self.alphaValue = 0
        self.isOpaque = true
        self.backgroundColor = .clear
        
        self.level = .normal
        
        super.close()
        
        print("🔴 forceClose() completed")
    }
    
    override func close() {
        print("🔴 BreakOverlayWindow.close() called")
        forceClose()
    }
    
    deinit {
        print("🔴 BreakOverlayWindow deallocated")
    }
}

struct BreakOverlayView: View {
    @ObservedObject var timerManager: TimerManager
    @State private var remainingTime: TimeInterval = 0
    @State private var progress: CGFloat = 1.0
    @State private var pulseScale: CGFloat = 1.0
    
    let timer = Timer.publish(every: 0.1, on: .main, in: .common).autoconnect()
    
    var body: some View {
        ZStack {
            // ALWAYS DARK background
            Color.black
                .ignoresSafeArea()
            
            VStack(spacing: 30) {
                Image(systemName: "eye.fill")
                    .font(.system(size: 80))
                    .foregroundColor(.white)
                    .scaleEffect(pulseScale)
                    .animation(
                        .easeInOut(duration: 2.0)
                        .repeatForever(autoreverses: true),
                        value: pulseScale
                    )
                
                Text(timerManager.breakMessage)
                    .font(.system(size: 48, weight: .bold))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
                
                Text("Look away from your screen")
                    .font(.system(size: 24))
                    .foregroundColor(.white.opacity(0.7))
                
                Spacer()
                    .frame(height: 40)
                
                ZStack {
                    Circle()
                        .stroke(Color.white.opacity(0.2), lineWidth: 12)
                        .frame(width: 200, height: 200)
                    
                    Circle()
                        .trim(from: 0, to: progress)
                        .stroke(
                            AngularGradient(
                                gradient: Gradient(colors: gradientColors),
                                center: .center,
                                startAngle: .degrees(0),
                                endAngle: .degrees(353)
                            ),
                            style: StrokeStyle(lineWidth: 12, lineCap: .round)
                        )
                        .frame(width: 200, height: 200)
                        .rotationEffect(.degrees(-90))
                        .animation(.linear(duration: 0.1), value: progress)
                    
                    if remainingTime <= 5 {
                        Circle()
                            .trim(from: 0, to: progress)
                            .stroke(
                                Color.cyan.opacity(0.3),
                                style: StrokeStyle(lineWidth: 20, lineCap: .round)
                            )
                            .frame(width: 200, height: 200)
                            .rotationEffect(.degrees(-90))
                            .blur(radius: 8)
                            .animation(.linear(duration: 0.1), value: progress)
                    }
                    
                    Text("\(Int(ceil(max(0, remainingTime))))")
                        .font(.system(size: 60, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .contentTransition(.numericText())
                        .animation(.easeInOut(duration: 0.3), value: Int(remainingTime))
                }
            }
            .padding()
        }
        .onReceive(timer) { _ in
            let newTime = timerManager.getRemainingBreakTime()
            remainingTime = newTime
            
            let totalDuration = timerManager.breakDuration
            if totalDuration > 0 {
                progress = CGFloat(newTime / totalDuration)
            } else {
                progress = 0
            }
        }
        .onAppear {
            remainingTime = timerManager.getRemainingBreakTime()
            let totalDuration = timerManager.breakDuration
            if totalDuration > 0 {
                progress = CGFloat(remainingTime / totalDuration)
            }
            
            pulseScale = 1.05
            
            print("🟢 BreakOverlayView appeared with time: \(remainingTime)")
        }
    }
    
    var gradientColors: [Color] {
        // Always use cyan for dark mode
        return [.cyan, .cyan.opacity(0.7), .cyan, .cyan.opacity(0.8)]
    }
}
