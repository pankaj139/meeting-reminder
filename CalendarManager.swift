import Foundation
import EventKit

struct Meeting: Identifiable, Equatable {
    let id: String
    var title: String
    var startDate: Date
    var endDate: Date
    var videoURL: URL?
    var notes: String?
    var isAllDay: Bool
    var isMock: Bool = false
    var isRecurring: Bool = false
    var attendees: [String] = []
}

struct DayGroup: Identifiable {
    let id: String
    let date: Date
    var meetings: [Meeting]
}

class CalendarManager: ObservableObject {
    let eventStore = EKEventStore()
    @Published var authorizationStatus: EKAuthorizationStatus = .notDetermined
    @Published var meetings: [Meeting] = []
    @Published var mockMeetings: [Meeting] = []
    @Published var displayedMeetings: [Meeting] = []
    @Published var isMuted: Bool {
        didSet { UserDefaults.standard.set(isMuted, forKey: "isMuted") }
    }
    
    @Published var alertOffset: TimeInterval {
        didSet { UserDefaults.standard.set(alertOffset, forKey: "alertOffset") }
    }
    @Published var selectedTheme: String {
        didSet { UserDefaults.standard.set(selectedTheme, forKey: "selectedTheme") }
    }
    @Published var isPaused: Bool {
        didSet {
            UserDefaults.standard.set(isPaused, forKey: "isPaused")
            NotificationCenter.default.post(name: .pauseStateChanged, object: nil)
        }
    }
    @Published var alertOpacity: Double {
        didSet { UserDefaults.standard.set(alertOpacity, forKey: "alertOpacity") }
    }
    @Published var backgroundImagePath: String? {
        didSet {
            if let path = backgroundImagePath {
                UserDefaults.standard.set(path, forKey: "backgroundImagePath")
            } else {
                UserDefaults.standard.removeObject(forKey: "backgroundImagePath")
            }
        }
    }
    @Published var backgroundImageOpacity: Double {
        didSet { UserDefaults.standard.set(backgroundImageOpacity, forKey: "backgroundImageOpacity") }
    }
    @Published var selectedAlarmSound: String {
        didSet { UserDefaults.standard.set(selectedAlarmSound, forKey: "selectedAlarmSound") }
    }

    init() {
        let storedOffset = UserDefaults.standard.double(forKey: "alertOffset")
        self.alertOffset = storedOffset == 0 ? 10 : storedOffset
        self.selectedTheme = UserDefaults.standard.string(forKey: "selectedTheme") ?? "Cyberpunk"
        self.isPaused = UserDefaults.standard.bool(forKey: "isPaused")
        self.isMuted = UserDefaults.standard.bool(forKey: "isMuted")

        let storedOpacity = UserDefaults.standard.double(forKey: "alertOpacity")
        self.alertOpacity = storedOpacity == 0 ? 0.6 : storedOpacity

        self.backgroundImagePath = UserDefaults.standard.string(forKey: "backgroundImagePath")

        let storedImgOpacity = UserDefaults.standard.double(forKey: "backgroundImageOpacity")
        self.backgroundImageOpacity = storedImgOpacity == 0 ? 0.3 : storedImgOpacity

        self.selectedAlarmSound = UserDefaults.standard.string(forKey: "selectedAlarmSound") ?? "Sosumi"
        
        authorizationStatus = EKEventStore.authorizationStatus(for: .event)
        if authorizationStatus == .authorized || authorizationStatus.rawValue == 3 {
            fetchUpcomingMeetings()
        } else {
            sortMeetings()
        }
    }
    
    func requestAccess() {
        if #available(macOS 14.0, *) {
            eventStore.requestFullAccessToEvents { [weak self] granted, error in
                DispatchQueue.main.async {
                    guard let self = self else { return }
                    self.authorizationStatus = EKEventStore.authorizationStatus(for: .event)
                    if granted {
                        self.fetchUpcomingMeetings()
                    }
                }
            }
        } else {
            eventStore.requestAccess(to: .event) { [weak self] granted, error in
                DispatchQueue.main.async {
                    guard let self = self else { return }
                    self.authorizationStatus = EKEventStore.authorizationStatus(for: .event)
                    if granted {
                        self.fetchUpcomingMeetings()
                    }
                }
            }
        }
    }
    
    func fetchUpcomingMeetings() {
        let calendars = eventStore.calendars(for: .event)
        let now = Date()
        let calendar = Calendar.current
        
        // Start: 15 minutes ago to capture active meetings
        let start = now.addingTimeInterval(-900)
        // End: 7 days in the future
        let end = calendar.date(byAdding: .day, value: 7, to: start)!
        
        let predicate = eventStore.predicateForEvents(withStart: start, end: end, calendars: calendars)
        let events = eventStore.events(matching: predicate)
        
        let parsed = events.map { event -> Meeting in
            let videoURL = extractVideoURL(from: event)
            return Meeting(
                id: event.eventIdentifier,
                title: event.title ?? "No Title",
                startDate: event.startDate,
                endDate: event.endDate,
                videoURL: videoURL,
                notes: event.notes,
                isAllDay: event.isAllDay,
                isRecurring: event.hasRecurrenceRules,
                attendees: event.attendees?.compactMap { $0.name } ?? []
            )
        }
        .filter { !$0.isAllDay }
        
        DispatchQueue.main.async {
            self.meetings = parsed
            self.sortMeetings()
        }
    }
    
    func addMockMeeting(title: String, delaySeconds: TimeInterval, durationMinutes: TimeInterval = 30, videoURL: String = "https://meet.google.com/abc-defg-hij", isRecurring: Bool = false) {
        let start = Date().addingTimeInterval(delaySeconds)
        addMockMeeting(title: title, startDate: start, durationMinutes: durationMinutes, videoURL: videoURL, isRecurring: isRecurring)
    }
    
    func addMockMeeting(title: String, startDate: Date, durationMinutes: TimeInterval = 30, videoURL: String = "", isRecurring: Bool = false) {
        let id = UUID().uuidString
        let end = startDate.addingTimeInterval(durationMinutes * 60)
        let url = videoURL.isEmpty ? nil : URL(string: videoURL)
        let sampleAttendees = ["Bharat Singh", "Tanya Patel", "Arjun Kumar", "Aditi Wagh", "Bhavin Kapadia", "Ishan", "Riya Mehta", "Kunal Shah"]
        let newMeeting = Meeting(id: id, title: title, startDate: startDate, endDate: end, videoURL: url, notes: "Mock test meeting", isAllDay: false, isMock: true, isRecurring: isRecurring, attendees: sampleAttendees)
        
        mockMeetings.append(newMeeting)
        sortMeetings()
    }
    
    func removeMockMeeting(id: String) {
        mockMeetings.removeAll { $0.id == id }
        sortMeetings()
    }
    
    func sortMeetings() {
        var all = meetings.filter { !$0.isMock } + mockMeetings
        let fiveMinutesAgo = Date().addingTimeInterval(-300)
        all = all.filter { $0.endDate > fiveMinutesAgo }
        all.sort { $0.startDate < $1.startDate }
        
        // Slice to next 10 meetings
        let nextTen = Array(all.prefix(10))
        
        DispatchQueue.main.async {
            self.displayedMeetings = nextTen
        }
    }
    
    private func extractVideoURL(from event: EKEvent) -> URL? {
        if let url = event.url, isVideoCallURL(url.absoluteString) {
            return url
        }
        if let location = event.location, let url = extractFirstURL(from: location) {
            return url
        }
        if let notes = event.notes, let url = extractFirstURL(from: notes) {
            return url
        }
        return nil
    }
    
    private func isVideoCallURL(_ urlString: String) -> Bool {
        let platforms = ["zoom.us", "meet.google.com", "teams.microsoft.com", "teams.live.com", "webex.com", "skype.com", "discord.gg", "bluejeans.com", "around.co", "whereby.com", "facetime.apple.com"]
        for platform in platforms {
            if urlString.localizedCaseInsensitiveContains(platform) {
                return true
            }
        }
        return false
    }
    
    private func extractFirstURL(from text: String) -> URL? {
        let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue)
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        var foundURL: URL? = nil
        
        detector?.enumerateMatches(in: text, options: [], range: range) { result, _, stop in
            if let url = result?.url {
                if isVideoCallURL(url.absoluteString) {
                    foundURL = url
                    stop.pointee = true
                }
            }
        }
        return foundURL
    }
    
    var ongoingMeetings: [Meeting] {
        let now = Date()
        return displayedMeetings.filter { $0.startDate <= now && $0.endDate > now }
    }
    
    var groupedUpcomingMeetings: [DayGroup] {
        let now = Date()
        let upcoming = displayedMeetings.filter { $0.startDate > now }
        
        let calendar = Calendar.current
        var groups: [String: [Meeting]] = [:]
        var dayDates: [String: Date] = [:]
        
        for meeting in upcoming {
            let dayStart = calendar.startOfDay(for: meeting.startDate)
            let key = dayHeader(for: meeting.startDate)
            groups[key, default: []].append(meeting)
            dayDates[key] = dayStart
        }
        
        return groups.map { (key, meetings) -> DayGroup in
            DayGroup(id: key, date: dayDates[key]!, meetings: meetings.sorted { $0.startDate < $1.startDate })
        }
        .sorted { $0.date < $1.date }
    }
    
    private func dayHeader(for date: Date) -> String {
        let calendar = Calendar.current
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMM d"
        let formattedDate = formatter.string(from: date)
        
        if calendar.isDateInToday(date) {
            return "Today — \(formattedDate)"
        } else if calendar.isDateInTomorrow(date) {
            return "Tomorrow — \(formattedDate)"
        } else {
            return formattedDate
        }
    }
}
