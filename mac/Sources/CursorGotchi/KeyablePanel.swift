import AppKit

/// Borderless panels cannot receive keyboard input unless they can become key.
final class KeyablePanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}
