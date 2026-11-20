# Clipboard Wheel

A radial clipboard picker for macOS. **Tap ⌘V** and it pastes like normal. **Hold ⌘V** and a glass wheel of your recent copies pops up at your cursor. Move toward a slice and let go to paste it.

> Status: early development. See the build order below for what's done.

## How it works

- **Tap ⌘V**: normal paste, exactly like macOS.
- **Hold ⌘V**: the wheel opens. Move the mouse toward a slice, then let go of the keys to paste it.
- **Let go in the middle** (or press **Esc**): cancel, nothing is pasted.
- **Right-click a slice** while the wheel is open: pin or unpin it. Pinned items are never overwritten.

The wheel grows one slice per item (2 items = halves, 3 = thirds, 4 = quarters…) up to a maximum you set in Settings (default 8). Once it's full, a new copy **overwrites the item you haven't used for the longest, in that same slot**, so everything else stays where your hand expects it. Copying something that's already on the wheel just refreshes it.

Text shows as a short label and images as thumbnails. Copies that password managers mark as private are never saved or shown.

### Settings

Open Settings from the wheel icon in the menu bar.

| Setting | Options |
|---|---|
| Wheel contents | History + pinned (default), history only, pinned only |
| Max slices | 2–12 (default 8) |
| Wheel position | At the cursor (default), or screen center (the mouse snaps to the middle and goes back afterward) |
| Hold delay | How long you hold ⌘V before the wheel opens |
| Feedback | Sound tick and trackpad haptic as you move between slices |
| Launch at login | On by default |

The menu bar icon also has **Pause** (hands ⌘V back to macOS), **Pin current clipboard**, **Clear history**, and **Quit**.

## Permissions

Clipboard Wheel needs **Accessibility** permission (System Settings → Privacy & Security → Accessibility) so it can see ⌘V and paste for you. It asks on first launch. If macOS asks whether Clipboard Wheel may read the clipboard, choose **Allow**.

Everything stays on your Mac: items are stored in `~/Library/Application Support/ClipboardWheel/`. Nothing is sent anywhere.

## Building from source

Requirements: macOS 14 or later and Xcode 16 or later.

```bash
git clone https://github.com/<you>/clipboard-wheel.git
cd clipboard-wheel
open ClipboardWheel.xcodeproj
```

Then press ⌘R. To keep the Accessibility permission across rebuilds, sign with your Apple ID: copy `Config/Local.xcconfig.example` to `Config/Local.xcconfig` and put your team ID in it (Xcode → Settings → Accounts shows it). Without it, the app is signed "to run locally" and macOS may ask for Accessibility again after each rebuild.

The project file is generated from `project.yml` with [XcodeGen](https://github.com/yonaskolb/XcodeGen). After changing `project.yml`, run `xcodegen generate`.

The wheel logic (slots, pinning, eviction, slice math) lives in `Packages/ClipboardWheelCore` and can be tested without Xcode:

```bash
cd Packages/ClipboardWheelCore && swift test
```

## License

MIT. See [LICENSE](LICENSE).
