import AppKit
import SwiftUI

enum EventState {
    case idle
    case snoozed(until: Date)
    case dismissed
}

// Custom-drawn menu bar icon: an eye with alert rays. Template image so it
// adapts to light/dark menu bars and the "selected" highlight automatically.
enum MenuBarIcon {
    static let normal = make(paused: false)
    static let paused = make(paused: true)

    private static func make(paused: Bool) -> NSImage {
        let image = NSImage(size: NSSize(width: 18, height: 18), flipped: false) { _ in
            NSColor.black.setStroke()
            NSColor.black.setFill()

            // Almond eye outline
            let eye = NSBezierPath()
            eye.move(to: NSPoint(x: 1.5, y: 6.5))
            eye.curve(to: NSPoint(x: 16.5, y: 6.5), controlPoint1: NSPoint(x: 5, y: 12), controlPoint2: NSPoint(x: 13, y: 12))
            eye.curve(to: NSPoint(x: 1.5, y: 6.5), controlPoint1: NSPoint(x: 13, y: 1), controlPoint2: NSPoint(x: 5, y: 1))
            eye.lineWidth = 1.5
            eye.lineJoinStyle = .round
            eye.stroke()

            // Pupil
            NSBezierPath(ovalIn: NSRect(x: 6.7, y: 4.2, width: 4.6, height: 4.6)).fill()

            if paused {
                // Diagonal slash across the eye
                let slash = NSBezierPath()
                slash.move(to: NSPoint(x: 2.5, y: 1.5))
                slash.line(to: NSPoint(x: 15.5, y: 14.5))
                slash.lineWidth = 1.8
                slash.lineCapStyle = .round
                slash.stroke()
            } else {
                // Alert rays above the eye
                let rays: [(CGFloat, CGFloat, CGFloat, CGFloat)] = [
                    (9, 12.5, 9, 15.5),
                    (4.5, 11.5, 3, 14),
                    (13.5, 11.5, 15, 14)
                ]
                for (x1, y1, x2, y2) in rays {
                    let ray = NSBezierPath()
                    ray.move(to: NSPoint(x: x1, y: y1))
                    ray.line(to: NSPoint(x: x2, y: y2))
                    ray.lineWidth = 1.5
                    ray.lineCapStyle = .round
                    ray.stroke()
                }
            }
            return true
        }
        image.isTemplate = true
        return image
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem!
    var popover: NSPopover!
    var calendarManager = CalendarManager()
    
    var takeoverWindow: TakeoverWindow?
    var activeMeeting: Meeting?
    var eventStates: [String: EventState] = [:]
    
    var tickTimer: Timer?
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Hide dock icon
        NSApp.setActivationPolicy(.accessory)
        
        // Create Status Item
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            button.image = MenuBarIcon.normal
            button.action = #selector(togglePopover(_:))
            button.target = self
        }
        
        // Create Popover
        popover = NSPopover()
        popover.contentSize = NSSize(width: 340, height: 440)
        popover.behavior = .transient
        
        let menuView = StatusMenuView(
            calendarManager: calendarManager,
            onAddTest: { [weak self] in
                self?.addTestMeeting()
            },
            onQuit: {
                NSApp.terminate(nil)
            }
        )
        
        popover.contentViewController = NSHostingController(rootView: menuView)
        
        // Listen to Takeover events from TakeoverWindow
        NotificationCenter.default.addObserver(self, selector: #selector(handleSnoozePressed), name: .snoozePressed, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(handleDismissPressed), name: .dismissPressed, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(handleJoinPressed), name: .joinPressed, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(handlePauseStateChanged), name: .pauseStateChanged, object: nil)
        
        // Start Tick Loop
        tickTimer = Timer.scheduledTimer(timeInterval: 1.0, target: self, selector: #selector(tick), userInfo: nil, repeats: true)
        
        // Initial Calendar Sync
        calendarManager.fetchUpcomingMeetings()
        
        // Fetch every 15 minutes
        Timer.scheduledTimer(withTimeInterval: 900.0, repeats: true) { [weak self] _ in
            self?.calendarManager.fetchUpcomingMeetings()
        }
    }
    
    @objc func togglePopover(_ sender: AnyObject?) {
        if let button = statusItem.button {
            if popover.isShown {
                popover.performClose(sender)
            } else {
                NSApp.activate(ignoringOtherApps: true)
                DispatchQueue.main.async {
                    self.popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
                    if let popoverWindow = self.popover.contentViewController?.view.window {
                        popoverWindow.makeKey()
                    }
                }
            }
        }
    }
    
    func addTestMeeting() {
        calendarManager.addMockMeeting(
            title: "Test Meeting",
            delaySeconds: 15,
            durationMinutes: 5,
            videoURL: "https://meet.google.com/test-meeting-url"
        )
    }
    
    @objc func tick() {
        let now = Date()
        
        // Check meetings
        for meeting in calendarManager.displayedMeetings {
            let state = eventStates[meeting.id] ?? .idle
            
            var shouldTrigger = false
            let triggerWindowStart = meeting.startDate.addingTimeInterval(-calendarManager.alertOffset)
            
            switch state {
            case .idle:
                let triggerWindowEnd = meeting.startDate.addingTimeInterval(120)
                if now >= triggerWindowStart && now <= triggerWindowEnd {
                    shouldTrigger = true
                } else if now > triggerWindowEnd {
                    // Automatically mark past meetings as dismissed so they don't prompt
                    eventStates[meeting.id] = .dismissed
                    if meeting.isMock {
                        calendarManager.removeMockMeeting(id: meeting.id)
                    }
                }
            case .snoozed(let until):
                if now >= until && now < meeting.endDate {
                    shouldTrigger = true
                }
            case .dismissed:
                break
            }
            
            if shouldTrigger && !calendarManager.isPaused {
                triggerTakeover(for: meeting)
                break
            }
        }
        
        updateMenuBarIconAndText()
    }
    
    func updateMenuBarIconAndText() {
        guard let button = statusItem.button else { return }
        
        if calendarManager.isPaused {
            button.image = MenuBarIcon.paused
            button.title = " PAUSED"
            return
        } else {
            button.image = MenuBarIcon.normal
        }
        
        let now = Date()
        let nextMeeting = calendarManager.displayedMeetings.first { meeting in
            let state = eventStates[meeting.id] ?? .idle
            if case .dismissed = state { return false }
            return meeting.endDate > now
        }
        
        if let next = nextMeeting {
            let diff = next.startDate.timeIntervalSince(now)
            if diff > 0 && diff < 3600 {
                let minutes = Int(diff) / 60
                let seconds = Int(diff) % 60
                button.title = String(format: " %02d:%02d", minutes, seconds)
            } else if diff <= 0 && now < next.endDate {
                button.title = " LIVE"
            } else {
                button.title = ""
            }
        } else {
            button.title = ""
        }
    }
    
    func triggerTakeover(for meeting: Meeting) {
        if activeMeeting?.id == meeting.id { return }
        
        activeMeeting = meeting
        takeoverWindow?.close()
        
        takeoverWindow = TakeoverWindow(
            calendarManager: calendarManager,
            meeting: meeting,
            themeName: calendarManager.selectedTheme,
            onJoin: { [weak self] in
                self?.joinMeeting(meeting)
            },
            onSnooze: { [weak self] duration in
                self?.snoozeMeeting(meeting, duration: duration)
            },
            onDismiss: { [weak self] in
                self?.dismissMeeting(meeting)
            }
        )
        
        if !calendarManager.isMuted {
            AlarmManager.shared.playAlarm(soundName: "Sosumi")
        }
        
        // Delete mock meeting immediately upon trigger so it disappears from lists
        if meeting.isMock {
            calendarManager.removeMockMeeting(id: meeting.id)
        }
    }
    
    func joinMeeting(_ meeting: Meeting) {
        if let url = meeting.videoURL {
            NSWorkspace.shared.open(url)
        }
        dismissMeeting(meeting)
    }
    
    func snoozeMeeting(_ meeting: Meeting, duration: TimeInterval) {
        eventStates[meeting.id] = .snoozed(until: Date().addingTimeInterval(duration))
        closeTakeover()
        
        // Re-add mock meeting with the future snoozed start date
        if meeting.isMock {
            calendarManager.addMockMeeting(
                title: meeting.title,
                startDate: Date().addingTimeInterval(duration),
                durationMinutes: 5,
                videoURL: meeting.videoURL?.absoluteString ?? "",
                isRecurring: meeting.isRecurring
            )
        }
    }
    
    func dismissMeeting(_ meeting: Meeting) {
        eventStates[meeting.id] = .dismissed
        closeTakeover()
        if meeting.isMock {
            calendarManager.removeMockMeeting(id: meeting.id)
        }
    }
    
    func closeTakeover() {
        AlarmManager.shared.stopAlarm()
        takeoverWindow?.close()
        takeoverWindow = nil
        activeMeeting = nil
    }
    
    @objc func handleSnoozePressed() {
        if let meeting = activeMeeting {
            snoozeMeeting(meeting, duration: 300)
        }
    }
    
    @objc func handleDismissPressed() {
        if let meeting = activeMeeting {
            dismissMeeting(meeting)
        }
    }
    
    @objc func handleJoinPressed() {
        if let meeting = activeMeeting {
            joinMeeting(meeting)
        }
    }
    
    @objc func handlePauseStateChanged() {
        updateMenuBarIconAndText()
    }
}
