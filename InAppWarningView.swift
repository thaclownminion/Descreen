import SwiftUI

struct InAppWarningView: View {
    let minutesRemaining: Int?
    let secondsRemaining: Int?
    @State private var opacity: Double = 0
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: showingCountdown ? "timer" : "eye.fill")
                .font(.system(size: 24))
                .foregroundColor(showingCountdown ? .orange : .cyan)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(titleText)
                    .font(.headline)
                    .foregroundColor(.white)
                
                Text(subtitleText)
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.8))
            }
            
            if showingCountdown {
                Spacer()
                
                // Countdown display
                Text("\(secondsRemaining ?? 0)")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundColor(secondsRemaining ?? 0 <= 10 ? .red : .orange)
                    .frame(width: 50)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.black.opacity(0.85))
                .shadow(color: .black.opacity(0.3), radius: 10, x: 0, y: 5)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(showingCountdown ? Color.orange.opacity(0.5) : Color.cyan.opacity(0.3), lineWidth: 2)
        )
        .opacity(opacity)
        .onAppear {
            withAnimation(.easeIn(duration: 0.3)) {
                opacity = 1
            }
        }
    }
    
    var showingCountdown: Bool {
        return secondsRemaining != nil && secondsRemaining! <= 60
    }
    
    var titleText: String {
        if showingCountdown {
            return "Break Starting Soon!"
        } else if minutesRemaining != nil {
            return "Break Coming Soon"
        }
        return "Break Alert"
    }
    
    var subtitleText: String {
        if showingCountdown {
            return "Get ready to rest your eyes"
        } else if let minutes = minutesRemaining {
            return "\(minutes) minute\(minutes == 1 ? "" : "s") remaining"
        }
        return "Break time approaching"
    }
}
