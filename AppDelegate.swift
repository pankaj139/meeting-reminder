import AppKit
import SwiftUI

enum EventState {
    case idle
    case snoozed(until: Date)
    case dismissed
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
            button.image = NSImage(systemSymbolName: "eye.fill", accessibilityDescription: "In Your Face")
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
            button.image = NSImage(systemSymbolName: "eye.slash.fill", accessibilityDescription: "In Your Face (Paused)")
            button.title = " PAUSED"
            return
        } else {
            button.image = NSImage(systemSymbolName: "eye.fill", accessibilityDescription: "In Your Face")
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
