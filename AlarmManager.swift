import AppKit

class AlarmManager {
    static let shared = AlarmManager()
    private var currentSound: NSSound?
    
    let availableSounds = [
        "Sosumi",
        "Hero",
        "Submarine",
        "Glass",
        "Blow",
        "Ping",
        "Tink",
        "Purr"
    ]
    
    func playAlarm(soundName: String, loop: Bool = true) {
        stopAlarm()
        
        guard let sound = NSSound(named: soundName) else {
            if let fallback = NSSound(named: "Sosumi") {
                fallback.loops = loop
                fallback.play()
                currentSound = fallback
            }
            return
        }
        
        sound.loops = loop
        sound.play()
        currentSound = sound
    }
    
    func stopAlarm() {
        if let sound = currentSound {
            sound.stop()
            currentSound = nil
        }
    }
}
