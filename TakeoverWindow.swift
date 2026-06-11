import AppKit
import SwiftUI

class TakeoverWindow: NSWindow {
    
    init(calendarManager: CalendarManager, meeting: Meeting, themeName: String, onJoin: @escaping () -> Void, onSnooze: @escaping (TimeInterval) -> Void, onDismiss: @escaping () -> Void) {
        
        let screen = NSScreen.main ?? NSScreen.screens.first ?? NSScreen()
        let rect = screen.frame
        
        super.init(
            contentRect: rect,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        
        self.title = "Meeting Takeover"
        self.isOpaque = false
        self.backgroundColor = .clear
        self.isReleasedWhenClosed = false
        
        self.level = .screenSaver
        
        self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        
        self.ignoresMouseEvents = false
        
        let visualEffectView = NSVisualEffectView(frame: rect)
        visualEffectView.material = .hudWindow
        visualEffectView.blendingMode = .behindWindow
        visualEffectView.state = .active
        
        let hostingView = NSHostingView(rootView: TakeoverView(
            calendarManager: calendarManager,
            meeting: meeting,
            themeName: themeName,
            onJoin: onJoin,
            onSnooze: onSnooze,
            onDismiss: onDismiss
        ))
        hostingView.frame = rect
        
        visualEffectView.addSubview(hostingView)
        self.contentView = visualEffectView
        
        self.makeKeyAndOrderFront(nil)
        self.orderFrontRegardless()
    }
    
    override var canBecomeKey: Bool {
        return true
    }
    
    override var canBecomeMain: Bool {
        return true
    }
    
    override func keyDown(with event: NSEvent) {
        switch event.keyCode {
        case 53: // Escape -> Snooze
            NotificationCenter.default.post(name: .snoozePressed, object: nil)
        case 36: // Return -> Dismiss
            NotificationCenter.default.post(name: .dismissPressed, object: nil)
        case 49: // Space -> Join
            NotificationCenter.default.post(name: .joinPressed, object: nil)
        default:
            super.keyDown(with: event)
        }
    }
}

extension Notification.Name {
    static let snoozePressed = Notification.Name("snoozePressed")
    static let dismissPressed = Notification.Name("dismissPressed")
    static let joinPressed = Notification.Name("joinPressed")
    static let pauseStateChanged = Notification.Name("pauseStateChanged")
}
