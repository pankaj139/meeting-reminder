# In Your Face (macOS Meeting Takeover Alert)

`In Your Face` is a minimalist, distraction-free macOS menu bar application designed to ensure you never miss an upcoming calendar event or meeting. Inspired by classic screen-takeover utilities, it interrupts you with an unmissable full-screen overlay when a meeting is about to start, prompting you to join, snooze, or dismiss the event.

---

## Features

- **Menu Bar Status Item**: 
  - Displays a live countdown timer to your next meeting directly in the macOS menu bar.
  - Changes status icons to indicate state (e.g., active, paused).
- **Full-Screen Takeover**:
  - Displays a beautiful full-screen overlay window that captures your attention right before a meeting starts.
  - Shows the meeting title, start time, and countdown.
- **Actionable Controls**:
  - **Join Meeting**: Instantly opens the meeting link (Google Meet, Zoom, MS Teams, etc.) in your default browser and dismisses the alert.
  - **Snooze**: Postpones the takeover alert by 5 minutes.
  - **Dismiss**: Dismisses the current alert.
- **Preferences & Customization**:
  - **Alert Timing**: Customize the trigger offset (e.g., 0s, 30s, 1m, 2m, 5m before the event).
  - **Sound Alarms**: Play an optional alert sound (using system sounds like "Sosumi"). Mute/unmute sounds with a single click.
  - **Pause Alerts**: Pause all takeover popups (e.g., during presentations or deep focus sessions).
  - **Themes**: Switch between elegant custom themes (e.g., Dark Mode, Sunset Gradient, Cyberpunk Neon).
- **Test Mode**:
  - Instantly create a test meeting scheduled for 15 seconds in the future to preview the takeover and functionality.
- **Calendar Integration**:
  - Connects securely with macOS Calendar using EventKit to fetch your upcoming schedules.

---

## File Structure

The project contains the following Swift components:

- **`main.swift`**: The application entry point that initializes the `NSApplication` and configures the delegate.
- **`AppDelegate.swift`**: The core controller managing the status bar icon, timer tick loop, calendar syncs, and window triggers.
- **`CalendarManager.swift`**: Handles communication with EventKit to fetch calendars, parse meeting details (like video URLs), and maintain the local event schedule.
- **`AlarmManager.swift`**: Manages playback of alert sounds.
- **`TakeoverWindow.swift`**: The custom borderless, full-screen `NSWindow` subclass optimized for drawing over all other apps and screens.
- **`TakeoverView.swift`**: A SwiftUI view rendering the full-screen alerts, meeting countdowns, custom themes, and action buttons.
- **`StatusMenuView.swift`**: The dropdown SwiftUI menu listing upcoming meetings and application preferences.
- **`build.sh`**: A shell script to compile Swift sources and package them into a standalone macOS `.app` bundle.

---

## Requirements

- **Operating System**: macOS 14.0 (Sonoma) or newer.
- **Architecture**: Apple Silicon (`arm64`).
- **Dependencies**: Xcode Command Line Tools (`swiftc` compiler).

---

## Build and Run

To compile and package `In Your Face` manually:

1. Open your terminal in the repository directory.
2. Run the build script:
   ```bash
   chmod +x build.sh
   ./build.sh
   ```
3. A bundle named `InYourFace.app` will be created in the directory.
4. Move `InYourFace.app` to your `/Applications` directory or run it directly:
   ```bash
   open InYourFace.app
   ```

> [!IMPORTANT]
> **Calendar Permission**: On its first run, macOS will prompt you to allow `In Your Face` full access to your calendar. This is required so EventKit can retrieve your schedules. If you do not see the prompt, you can grant it manually in **System Settings > Privacy & Security > Calendars**.

---

## Setting Up Your GitHub Repository

To host this project on GitHub, follow these steps:

### 1. Initialize Git and Commit Your Code
If you haven't already committed your local changes:
```bash
# Add files to tracking (.gitignore ignores build artifacts and local DS_Store)
git add .

# Create the initial commit
git commit -m "Initial commit of In Your Face app"

# Ensure your default branch is named 'main'
git branch -M main
```

### 2. Create a Repository on GitHub
1. Go to [github.com](https://github.com) and sign in.
2. Click the **`+`** icon in the top right corner and select **New repository**.
3. Set the **Repository name** (e.g., `InYourFace` or `intelligent-hawking`).
4. Keep the repository description clear, and leave **Initialize this repository with** unchecked (since you already have a local git history).
5. Click **Create repository**.

### 3. Link Local Repository and Push
Copy the remote repository URL (either HTTPS or SSH) from the repository page, then run:
```bash
# Link the local repository to your remote GitHub repository
git remote add origin <your-github-repo-url>

# Push the code to the main branch
git push -u origin main
```
Replace `<your-github-repo-url>` with your actual URL (e.g., `https://github.com/your-username/InYourFace.git`).

---

## License

This project is licensed under the MIT License - see the LICENSE file for details.
