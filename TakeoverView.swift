import SwiftUI

struct TakeoverView: View {
    @ObservedObject var calendarManager: CalendarManager
    let meeting: Meeting
    let themeName: String
    let onJoin: () -> Void
    let onSnooze: (TimeInterval) -> Void
    let onDismiss: () -> Void

    @State private var timeRemaining: TimeInterval = 0
    @State private var timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    @State private var animateWiggle = false

    private let amber = Color(red: 0.87, green: 0.62, blue: 0.22)
    private let teal = Color(red: 0.56, green: 0.79, blue: 0.80)

    var body: some View {
        ZStack {
            // 1. Background image (if configured)
            if let path = calendarManager.backgroundImagePath,
               let nsImage = NSImage(contentsOfFile: path) {
                Image(nsImage: nsImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .ignoresSafeArea()
                    .opacity(calendarManager.backgroundImageOpacity)
            }

            // 2. Translucent/Transparent colored theme background
            backgroundGradient
                .opacity(calendarManager.alertOpacity)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer().frame(height: 60)

                alarmIllustration

                Text("Your meeting is starting soon.")
                    .font(.system(size: 17))
                    .foregroundColor(.white.opacity(0.95))
                    .padding(.top, 18)

                Spacer()

                // Title with accent bar
                HStack(alignment: .center, spacing: 18) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(teal)
                        .frame(width: 7, height: 54)
                    Text(meeting.title)
                        .font(.system(size: 52, weight: .bold))
                        .foregroundColor(.white)
                        .lineLimit(2)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, 80)

                Text(timeRangeString)
                    .font(.system(size: 30, weight: .regular))
                    .foregroundColor(.white.opacity(0.95))
                    .padding(.top, 14)

                Text(countdownText)
                    .font(.system(size: 15))
                    .foregroundColor(countdownColor)
                    .padding(.top, 8)

                if !meeting.attendees.isEmpty {
                    attendeeRow
                        .padding(.top, 26)
                }

                Spacer().frame(height: 56)

                // Primary actions
                VStack(spacing: 16) {
                    if meeting.videoURL != nil {
                        Button(action: onJoin) {
                            HStack(spacing: 10) {
                                Image(systemName: "video.fill")
                                    .font(.system(size: 17, weight: .semibold))
                                Text("Join")
                                    .font(.system(size: 18, weight: .bold))
                            }
                            .foregroundColor(.white)
                            .frame(width: 340, height: 52)
                            .background(RoundedRectangle(cornerRadius: 12).fill(amber))
                        }
                        .buttonStyle(PressableStyle())
                        .shadow(color: amber.opacity(0.35), radius: 14, x: 0, y: 6)
                    }

                    Button(action: onDismiss) {
                        Text("Dismiss")
                            .font(.system(size: 17, weight: .semibold))
                            .frame(width: 340, height: 46)
                    }
                    .buttonStyle(OutlineStyle())
                }

                Spacer()

                // Snooze section
                VStack(spacing: 16) {
                    Text("Snooze")
                        .font(.system(size: 17))
                        .foregroundColor(.white.opacity(0.95))

                    HStack(spacing: 18) {
                        Button(action: { onSnooze(60) }) {
                            Text("1 minute")
                                .font(.system(size: 16, weight: .semibold))
                                .frame(width: 170, height: 44)
                        }
                        .buttonStyle(OutlineStyle())

                        Button(action: { onSnooze(300) }) {
                            Text("5 minutes")
                                .font(.system(size: 16, weight: .semibold))
                                .frame(width: 170, height: 44)
                        }
                        .buttonStyle(OutlineStyle())

                        if timeRemaining > 0 {
                            Button(action: { onSnooze(max(timeRemaining, 1)) }) {
                                Text("Until Event")
                                    .font(.system(size: 16, weight: .bold))
                                    .frame(width: 170, height: 44)
                            }
                            .buttonStyle(OutlineStyle())
                        }
                    }
                }

                Text("Space to join  ·  Esc to snooze  ·  Return to dismiss")
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.4))
                    .padding(.top, 28)

                Spacer().frame(height: 50)
            }
        }
        .onAppear {
            updateTimeRemaining()
            animateWiggle = true
        }
        .onReceive(timer) { _ in
            updateTimeRemaining()
        }
    }

    // MARK: - Alarm illustration

    private var alarmIllustration: some View {
        VStack(spacing: 8) {
            ZStack {
                Image(systemName: "leaf.fill")
                    .font(.system(size: 30))
                    .foregroundColor(Color(red: 0.85, green: 0.65, blue: 0.28))
                    .rotationEffect(.degrees(35))
                    .offset(x: 36, y: -6)
                Image(systemName: "cup.and.saucer.fill")
                    .font(.system(size: 22))
                    .foregroundColor(Color(red: 0.56, green: 0.42, blue: 0.47))
                    .offset(x: -42, y: 12)
                Image(systemName: "alarm.fill")
                    .font(.system(size: 48))
                    .foregroundColor(Color(red: 0.78, green: 0.36, blue: 0.30))
                    .rotationEffect(animateWiggle ? .degrees(-5) : .degrees(5))
                    .animation(Animation.easeInOut(duration: 0.5).repeatForever(autoreverses: true), value: animateWiggle)
            }
            Rectangle()
                .fill(Color(red: 0.85, green: 0.65, blue: 0.28))
                .frame(width: 130, height: 2)
        }
    }

    // MARK: - Attendees

    private var attendeeRow: some View {
        HStack(spacing: 8) {
            ForEach(Array(meeting.attendees.prefix(6).enumerated()), id: \.offset) { _, name in
                InitialsBadge(text: initials(for: name))
            }
            if meeting.attendees.count > 6 {
                InitialsBadge(text: "+\(meeting.attendees.count - 6)")
            }
        }
    }

    private func initials(for name: String) -> String {
        let parts = name.split(separator: " ").prefix(2)
        let letters = parts.compactMap { $0.first.map(String.init) }
        return letters.joined().uppercased()
    }

    // MARK: - Background

    private var backgroundGradient: some View {
        switch themeName {
        case "Cyberpunk":
            return LinearGradient(
                gradient: Gradient(colors: [Color(red: 0.1, green: 0.0, blue: 0.2), Color(red: 0.0, green: 0.1, blue: 0.3)]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case "High Alert":
            return LinearGradient(
                gradient: Gradient(colors: [Color.red.opacity(0.85), Color.orange.opacity(0.85)]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case "Forest":
            return LinearGradient(
                gradient: Gradient(colors: [Color(red: 0.05, green: 0.2, blue: 0.1), Color(red: 0.1, green: 0.35, blue: 0.15)]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        default: // Classic Dark
            return LinearGradient(
                gradient: Gradient(colors: [Color(red: 0.32, green: 0.33, blue: 0.33), Color(red: 0.26, green: 0.27, blue: 0.27)]),
                startPoint: .top,
                endPoint: .bottom
            )
        }
    }

    // MARK: - Time

    private var timeRangeString: String {
        let formatter = DateIntervalFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter.string(from: meeting.startDate, to: meeting.endDate)
    }

    private var countdownColor: Color {
        if timeRemaining <= 0 {
            return Color(red: 1.0, green: 0.55, blue: 0.45)
        }
        return .white.opacity(0.85)
    }

    private var countdownText: String {
        if timeRemaining > 0 {
            let minutes = Int(timeRemaining) / 60
            let seconds = Int(timeRemaining) % 60
            if minutes >= 2 {
                return "The event will start in \(minutes) minutes"
            } else if minutes == 1 {
                return seconds == 0 ? "The event will start in 1 minute" : "The event will start in 1 min \(seconds) sec"
            } else {
                return "The event will start in \(seconds) seconds"
            }
        } else if meeting.endDate > Date() {
            let lateMinutes = Int(-timeRemaining) / 60
            return lateMinutes < 1 ? "The event is starting now" : "The event started \(lateMinutes) min ago — you're late!"
        } else {
            return "The event has ended"
        }
    }

    private func updateTimeRemaining() {
        timeRemaining = meeting.startDate.timeIntervalSinceNow
    }
}

// MARK: - Components

struct InitialsBadge: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.system(size: 14, weight: .medium))
            .foregroundColor(.white)
            .frame(width: 40, height: 40)
            .overlay(Circle().stroke(Color.white.opacity(0.9), lineWidth: 1.5))
    }
}

struct OutlineStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundColor(.white)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.white.opacity(configuration.isPressed ? 0.25 : 0.06))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.white.opacity(0.9), lineWidth: 1.5)
            )
            .contentShape(RoundedRectangle(cornerRadius: 12))
    }
}

struct PressableStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .opacity(configuration.isPressed ? 0.85 : 1.0)
    }
}
