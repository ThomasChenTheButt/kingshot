import Foundation

/// Tiny persistence layer for the player's progress.
final class ProgressStore {
    static let shared = ProgressStore()

    private let defaults: UserDefaults
    private enum Key {
        static let level = "kingshot.level"
        static let coins = "kingshot.coins"
        static let bestLevel = "kingshot.bestLevel"
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    var level: Int {
        get { max(1, defaults.integer(forKey: Key.level)) }
        set {
            defaults.set(max(1, newValue), forKey: Key.level)
            if newValue > bestLevel { bestLevel = newValue }
        }
    }

    var coins: Int {
        get { defaults.integer(forKey: Key.coins) }
        set { defaults.set(max(0, newValue), forKey: Key.coins) }
    }

    var bestLevel: Int {
        get { max(1, defaults.integer(forKey: Key.bestLevel)) }
        set { defaults.set(max(1, newValue), forKey: Key.bestLevel) }
    }
}
