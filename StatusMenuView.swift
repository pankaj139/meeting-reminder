import SwiftUI
import EventKit

struct StatusMenuView: View {
    @ObservedObject var calendarManager: CalendarManager
    var onAddTest: () -> Void
    var onQuit: () -> Void
    
    @State private var showAddMeeting = false
    @State private var showSettings = false
    @State private var selectedFilter = "all" // Filter state: "today" | "all"
    @State private var newTitle = ""
    @State private var newStartTime = Date().addingTimeInterval(300)
    @State private var newLink = ""
    @State private var newIsRecurring = false
    
    var filteredUpcomingGroups: [DayGroup] {
        let groups = calendarManager.groupedUpcomingMeetings
        if selectedFilter == "today" {
            return groups.filter { Calendar.current.isDateInToday($0.date) }
        } else {
            return groups
        }
    }

    var nextMeetingID: String? {
        let now = Date()
        return calendarManager.displayedMeetings.first { $0.startDate > now }?.id
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // App Header
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "eye.fill")
                        .foregroundColor(.orange)
                    Text("In Your Face")
                        .font(.system(size: 14, weight: .bold))
                }
                Spacer()
                
                // Toggle Settings Panel
                Button(action: { showSettings.toggle() }) {
                    Image(systemName: showSettings ? "list.bullet" : "gearshape.fill")
                        .foregroundColor(showSettings ? .orange : .secondary)
                        .font(.system(size: 13, weight: .medium))
                }
                .buttonStyle(PlainButtonStyle())
                .help(showSettings ? "Show Meetings List" : "Show Settings")
                
                // Pause/Unpause Alerts button
                Button(action: { calendarManager.isPaused.toggle() }) {
                    Image(systemName: calendarManager.isPaused ? "bell.slash.fill" : "bell.fill")
                        .foregroundColor(calendarManager.isPaused ? .orange : .green)
                        .font(.system(size: 13, weight: .medium))
                }
                .buttonStyle(PlainButtonStyle())
                .help(calendarManager.isPaused ? "Resume Alerts" : "Pause Alerts")
                .padding(.leading, 8)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color.white.opacity(0.05))
            
            Divider()
            
            if showSettings {
                // Settings View
                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        SettingsCard(title: "ALERTS", icon: "bell.badge.fill") {
                            SettingsRow(icon: "pause.fill", iconColor: .orange, title: "Pause takeovers") {
                                Toggle("", isOn: $calendarManager.isPaused)
                                    .toggleStyle(.switch)
                                    .controlSize(.mini)
                                    .labelsHidden()
                            }

                            Divider().opacity(0.4)

                            SettingsRow(icon: "speaker.slash.fill", iconColor: .red, title: "Mute alarm sound") {
                                Toggle("", isOn: $calendarManager.isMuted)
                                    .toggleStyle(.switch)
                                    .controlSize(.mini)
                                    .labelsHidden()
                            }

                            Divider().opacity(0.4)

                            SettingsRow(icon: "music.note", iconColor: .pink, title: "Alarm sound") {
                                Picker("", selection: $calendarManager.selectedAlarmSound) {
                                    ForEach(AlarmManager.shared.availableSounds, id: \.self) { sound in
                                        Text(sound).tag(sound)
                                    }
                                }
                                .pickerStyle(MenuPickerStyle())
                                .labelsHidden()
                                .controlSize(.small)
                                .frame(width: 125)
                                .disabled(calendarManager.isMuted)
                            }

                            Divider().opacity(0.4)

                            SettingsRow(icon: "clock.fill", iconColor: .blue, title: "Alert timing") {
                                Picker("", selection: $calendarManager.alertOffset) {
                                    Text("At start").tag(TimeInterval(0))
                                    Text("30 sec before").tag(TimeInterval(30))
                                    Text("1 min before").tag(TimeInterval(60))
                                    Text("2 min before").tag(TimeInterval(120))
                                    Text("5 min before").tag(TimeInterval(300))
                                }
                                .pickerStyle(MenuPickerStyle())
                                .labelsHidden()
                                .controlSize(.small)
                                .frame(width: 125)
                            }
                        }

                        SettingsCard(title: "TAKEOVER APPEARANCE", icon: "paintbrush.fill") {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Theme")
                                    .font(.system(size: 12))

                                HStack(spacing: 0) {
                                    ThemeSwatch(name: "Cyberpunk", label: "Cyberpunk", colors: [Color(red: 0.35, green: 0.1, blue: 0.6), Color(red: 0.0, green: 0.3, blue: 0.7)], selection: $calendarManager.selectedTheme)
                                    ThemeSwatch(name: "High Alert", label: "High Alert", colors: [.red, .orange], selection: $calendarManager.selectedTheme)
                                    ThemeSwatch(name: "Forest", label: "Forest", colors: [Color(red: 0.1, green: 0.4, blue: 0.2), Color(red: 0.25, green: 0.6, blue: 0.3)], selection: $calendarManager.selectedTheme)
                                    ThemeSwatch(name: "Classic Dark", label: "Classic", colors: [Color(white: 0.4), Color(white: 0.15)], selection: $calendarManager.selectedTheme)
                                }
                            }

                            Divider().opacity(0.4)

                            VStack(spacing: 6) {
                                SettingsRow(icon: "circle.lefthalf.filled", iconColor: .purple, title: "Overlay opacity") {
                                    Text("\(Int(calendarManager.alertOpacity * 100))%")
                                        .font(.system(size: 11, weight: .bold))
                                        .foregroundColor(.secondary)
                                }
                                Slider(value: $calendarManager.alertOpacity, in: 0.2...1.0)
                                    .controlSize(.small)
                            }

                            Divider().opacity(0.4)

                            VStack(spacing: 6) {
                                SettingsRow(icon: "photo.fill", iconColor: .teal, title: "Background image") {
                                    if calendarManager.backgroundImagePath != nil {
                                        Button("Remove") {
                                            calendarManager.backgroundImagePath = nil
                                        }
                                        .buttonStyle(.borderless)
                                        .foregroundColor(.red)
                                        .font(.system(size: 11))
                                    } else {
                                        Button("Choose…") {
                                            chooseBackgroundImage()
                                        }
                                        .buttonStyle(.bordered)
                                        .controlSize(.small)
                                    }
                                }

                                if let bgPath = calendarManager.backgroundImagePath {
                                    HStack {
                                        Text(URL(fileURLWithPath: bgPath).lastPathComponent)
                                            .font(.system(size: 10))
                                            .foregroundColor(.secondary)
                                            .lineLimit(1)
                                            .truncationMode(.middle)
                                        Spacer()
                                        Text("\(Int(calendarManager.backgroundImageOpacity * 100))%")
                                            .font(.system(size: 10, weight: .bold))
                                            .foregroundColor(.secondary)
                                    }
                                    Slider(value: $calendarManager.backgroundImageOpacity, in: 0.05...1.0)
                                        .controlSize(.mini)
                                }
                            }
                        }
                    }
                    .padding(12)
                }
            } else {
                // Calendar Permission Section
                if calendarManager.authorizationStatus == .notDetermined {
                    VStack(spacing: 8) {
                        Text("Calendar Access Required")
                            .font(.system(size: 12, weight: .semibold))
                        Text("Sync your actual meetings automatically.")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                        Button("Grant Permission") {
                            calendarManager.requestAccess()
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                    }
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.blue.opacity(0.08))
                } else if calendarManager.authorizationStatus == .denied || calendarManager.authorizationStatus == .restricted {
                    VStack(spacing: 6) {
                        Text("Calendar Access Denied")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.red)
                        Text("Please enable access in Settings -> Privacy & Security -> Calendars to fetch meetings.")
                            .font(.system(size: 9))
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.red.opacity(0.08))
                }
                
                // Meeting List
                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        // 1. Ongoing Meetings Section (Only show if not empty)
                        let ongoing = calendarManager.ongoingMeetings
                        if !ongoing.isEmpty {
                            VStack(alignment: .leading, spacing: 6) {
                                HStack(spacing: 6) {
                                    Circle()
                                        .fill(Color.red)
                                        .frame(width: 6, height: 6)
                                    Text("ONGOING")
                                        .font(.system(size: 9, weight: .black))
                                        .foregroundColor(.red)
                                        .tracking(1)
                                }
                                .padding(.bottom, 2)
                                
                                ForEach(ongoing) { meeting in
                                    MeetingRow(meeting: meeting, isOngoing: true)
                                        .padding(4)
                                        .background(Color.red.opacity(0.06))
                                        .cornerRadius(8)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 8)
                                                .stroke(Color.red.opacity(0.15), lineWidth: 1)
                                        )
                                }
                            }
                            .padding(.bottom, 4)
                        }
                        
                        // 2. Upcoming Meetings Sections (grouped by day, header always visible)
                        let groups = filteredUpcomingGroups
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Text("UPCOMING EVENTS")
                                    .font(.system(size: 9, weight: .black))
                                    .foregroundColor(.secondary)
                                    .tracking(1)
                                Spacer()
                                
                                // today / all filter pills
                                HStack(spacing: 0) {
                                    Text("today")
                                        .font(.system(size: 9, weight: selectedFilter == "today" ? .bold : .medium))
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 2)
                                        .foregroundColor(selectedFilter == "today" ? .white : .primary)
                                        .background(selectedFilter == "today" ? Color.orange : Color.clear)
                                        .cornerRadius(4)
                                        .onTapGesture { selectedFilter = "today" }
                                    
                                    Text("all")
                                        .font(.system(size: 9, weight: selectedFilter == "all" ? .bold : .medium))
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 2)
                                        .foregroundColor(selectedFilter == "all" ? .white : .primary)
                                        .background(selectedFilter == "all" ? Color.orange : Color.clear)
                                        .cornerRadius(4)
                                        .onTapGesture { selectedFilter = "all" }
                                }
                                .padding(2)
                                .background(Color.black.opacity(0.12))
                                .cornerRadius(6)
                            }
                            
                            if groups.isEmpty {
                                VStack(spacing: 8) {
                                    Image(systemName: "calendar.badge.checkmark")
                                        .font(.system(size: 30))
                                        .foregroundColor(.secondary.opacity(0.5))
                                    Text("You're all clear")
                                        .font(.system(size: 12, weight: .semibold))
                                    Text(selectedFilter == "today" ? "No more meetings today." : "No meetings in the next 7 days.")
                                        .font(.system(size: 10))
                                        .foregroundColor(.secondary)
                                }
                                .padding(.vertical, 36)
                                .frame(maxWidth: .infinity, alignment: .center)
                            } else {
                                ForEach(groups) { group in
                                    VStack(alignment: .leading, spacing: 8) {
                                        // Custom styled Day Header outside the card
                                        HStack(spacing: 6) {
                                            let isToday = group.id.contains("Today")
                                            let isTomorrow = group.id.contains("Tomorrow")
                                            
                                            Image(systemName: isToday ? "calendar.day.timeline.today" : (isTomorrow ? "calendar.badge.clock" : "calendar"))
                                                .font(.system(size: 11, weight: .semibold))
                                                .foregroundColor(isToday ? .orange : (isTomorrow ? .blue : .secondary))
                                            
                                            Text(group.id)
                                                .font(.system(size: 11, weight: .bold))
                                                .foregroundColor(isToday ? .orange : (isTomorrow ? .blue : .primary))
                                            
                                            Spacer()
                                            
                                            Text("\(group.meetings.count) \(group.meetings.count == 1 ? "event" : "events")")
                                                .font(.system(size: 9, weight: .medium))
                                                .foregroundColor(.secondary)
                                                .padding(.horizontal, 6)
                                                .padding(.vertical, 2)
                                                .background(Color.white.opacity(0.06))
                                                .cornerRadius(10)
                                        }
                                        .padding(.horizontal, 4)
                                        .padding(.bottom, 2)
                                        
                                        // Day card with meetings list inside
                                        VStack(spacing: 0) {
                                            ForEach(group.meetings) { meeting in
                                                MeetingRow(meeting: meeting, isNext: meeting.id == nextMeetingID)
                                                if meeting != group.meetings.last {
                                                    Divider()
                                                        .opacity(0.3)
                                                        .padding(.horizontal, 6)
                                                }
                                            }
                                        }
                                        .padding(.vertical, 4)
                                        .background(Color.white.opacity(0.03))
                                        .cornerRadius(8)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 8)
                                                .stroke(Color.white.opacity(0.06), lineWidth: 1)
                                        )
                                    }
                                    .padding(.bottom, 12)
                                }
                            }
                        }
                    }
                    .padding(12)
                }
                
                Spacer()
            }
            
            // Add Custom Meeting Section (only show if not in settings)
            if showAddMeeting && !showSettings {
                VStack(spacing: 8) {
                    TextField("Meeting Title", text: $newTitle)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                    
                    DatePicker("Starts At", selection: $newStartTime, displayedComponents: [.hourAndMinute])
                        .font(.system(size: 12))
                    
                    TextField("Meeting Link (e.g. Zoom/Meet)", text: $newLink)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                    
                    Toggle("Recurring Meeting", isOn: $newIsRecurring)
                        .toggleStyle(.checkbox)
                        .font(.system(size: 11))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 2)
                    
                    HStack {
                        Button("Cancel") {
                            showAddMeeting = false
                        }
                        .buttonStyle(.borderless)
                        
                        Spacer()
                        
                        Button("Add Event") {
                            if !newTitle.isEmpty {
                                calendarManager.addMockMeeting(title: newTitle, startDate: newStartTime, videoURL: newLink, isRecurring: newIsRecurring)
                                newTitle = ""
                                newLink = ""
                                newIsRecurring = false
                                showAddMeeting = false
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                        .disabled(newTitle.isEmpty)
                    }
                }
                .padding(12)
                .background(Color.black.opacity(0.08))
            }
            
            Divider()
            
            // Footer Action Bar
            HStack {
                if !showAddMeeting && !showSettings {
                    Button(action: { showAddMeeting = true }) {
                        HStack(spacing: 4) {
                            Image(systemName: "plus.circle.fill")
                            Text("Custom")
                        }
                        .font(.system(size: 11))
                    }
                    .buttonStyle(.borderless)
                }
                
                Spacer()
                
                Button(action: onAddTest) {
                    HStack(spacing: 4) {
                        Image(systemName: "timer")
                        Text("Test (15s)")
                    }
                    .font(.system(size: 11))
                }
                .buttonStyle(.borderless)
                
                Spacer()
                
                Button(action: onQuit) {
                    Text("Quit")
                        .font(.system(size: 11))
                        .foregroundColor(.red)
                }
                .buttonStyle(.borderless)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Color.white.opacity(0.02))
        }
        .frame(width: 340, height: 440)
    }
    
    private func chooseBackgroundImage() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowedFileTypes = ["png", "jpg", "jpeg", "heic", "tiff"]
        
        if panel.runModal() == .OK {
            if let url = panel.url {
                calendarManager.backgroundImagePath = url.path
            }
        }
    }
}

struct SettingsCard<Content: View>: View {
    let title: String
    let icon: String
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.system(size: 9, weight: .bold))
                Text(title)
                    .font(.system(size: 9, weight: .black))
                    .tracking(1)
            }
            .foregroundColor(.secondary)
            .padding(.horizontal, 4)

            VStack(spacing: 10) {
                content
            }
            .padding(10)
            .background(Color.white.opacity(0.04))
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.white.opacity(0.06), lineWidth: 1)
            )
        }
    }
}

struct SettingsRow<Control: View>: View {
    let icon: String
    let iconColor: Color
    let title: String
    @ViewBuilder var control: Control

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(.white)
                .frame(width: 22, height: 22)
                .background(RoundedRectangle(cornerRadius: 6).fill(iconColor.gradient))

            Text(title)
                .font(.system(size: 12))

            Spacer()

            control
        }
    }
}

struct ThemeSwatch: View {
    let name: String
    let label: String
    let colors: [Color]
    @Binding var selection: String

    private var isSelected: Bool { selection == name }

    var body: some View {
        Button(action: { selection = name }) {
            VStack(spacing: 5) {
                ZStack {
                    Circle()
                        .fill(LinearGradient(gradient: Gradient(colors: colors), startPoint: .topLeading, endPoint: .bottomTrailing))
                        .frame(width: 30, height: 30)
                    if isSelected {
                        Image(systemName: "checkmark")
                            .font(.system(size: 10, weight: .black))
                            .foregroundColor(.white)
                    }
                }
                .overlay(
                    Circle().stroke(isSelected ? Color.orange : Color.white.opacity(0.2), lineWidth: isSelected ? 2 : 1)
                )

                Text(label)
                    .font(.system(size: 8, weight: isSelected ? .bold : .medium))
                    .foregroundColor(isSelected ? .primary : .secondary)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct MeetingRow: View {
    let meeting: Meeting
    var isOngoing: Bool = false
    var isNext: Bool = false
    @State private var isHovered = false
    @State private var animateLive = false

    private var accentColor: Color {
        if isOngoing { return .red }
        if isNext { return .orange }
        return Color(red: 0.45, green: 0.72, blue: 0.74)
    }

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            // Start time column
            VStack(alignment: .trailing, spacing: 0) {
                Text(timeString(meeting.startDate, format: "h:mm"))
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundColor(.primary)
                Text(timeString(meeting.startDate, format: "a"))
                    .font(.system(size: 9, weight: .medium))
                    .foregroundColor(.secondary)
            }
            .frame(width: 40, alignment: .trailing)

            RoundedRectangle(cornerRadius: 2)
                .fill(accentColor)
                .frame(width: 3, height: 30)

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 5) {
                    Text(meeting.title)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.primary)
                        .lineLimit(1)

                    if meeting.isRecurring {
                        Image(systemName: "repeat")
                            .font(.system(size: 9))
                            .foregroundColor(.orange.opacity(0.8))
                            .help("Recurring meeting")
                    }

                    if meeting.isMock {
                        Text("TEST")
                            .font(.system(size: 7, weight: .black))
                            .foregroundColor(.green)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(Color.green.opacity(0.12))
                            .cornerRadius(3)
                    }
                }

                HStack(spacing: 5) {
                    if isOngoing {
                        Circle()
                            .fill(Color.red)
                            .frame(width: 5, height: 5)
                            .opacity(animateLive ? 1.0 : 0.3)
                            .animation(Animation.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: animateLive)
                        Text("Ends at \(timeString(meeting.endDate, format: "h:mm a"))")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.red)
                    } else {
                        Text(durationString)
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                        if isNext {
                            Text("· starts \(relativeStartString)")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundColor(.orange)
                        }
                    }
                }
            }

            Spacer()

            if let url = meeting.videoURL {
                Button(action: {
                    NSWorkspace.shared.open(url)
                }) {
                    Image(systemName: "video.fill")
                        .font(.system(size: 10))
                        .foregroundColor(isHovered ? .white : .blue)
                        .padding(6)
                        .background(isHovered ? Color.blue : Color.blue.opacity(0.1))
                        .clipShape(Circle())
                }
                .buttonStyle(PlainButtonStyle())
                .help("Join video call")
            }
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(isHovered ? Color.primary.opacity(0.09) : Color.clear)
        )
        .contentShape(Rectangle())
        .animation(.easeOut(duration: 0.12), value: isHovered)
        .onHover { hovering in
            isHovered = hovering
        }
        .onAppear {
            if isOngoing { animateLive = true }
        }
    }

    private var durationString: String {
        let minutes = max(Int(meeting.endDate.timeIntervalSince(meeting.startDate)) / 60, 1)
        if minutes < 60 {
            return "\(minutes) min"
        }
        let hours = minutes / 60
        let rest = minutes % 60
        return rest == 0 ? "\(hours) hr" : "\(hours) hr \(rest) min"
    }

    private var relativeStartString: String {
        let seconds = Int(meeting.startDate.timeIntervalSinceNow)
        if seconds < 60 { return "in <1 min" }
        let minutes = seconds / 60
        if minutes < 60 { return "in \(minutes) min" }
        let hours = minutes / 60
        if hours < 24 {
            let rest = minutes % 60
            return rest == 0 ? "in \(hours) hr" : "in \(hours) hr \(rest) min"
        }
        return "in \(hours / 24)d"
    }

    private func timeString(_ date: Date, format: String) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = format
        return formatter.string(from: date)
    }
}
