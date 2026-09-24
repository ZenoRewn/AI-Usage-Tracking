// Author: Zeno Ren
import SwiftUI

/// Menu surfaces follow the original design study, with readable light-mode equivalents.
enum MenuPalette {
    static let background = color(light:0xF8F8FA,dark:0x1C1D21)
    static let card = color(light:0xFFFFFF,dark:0x26272D)
    static let text = color(light:0x202127,dark:0xF2F2F5)
    static let muted = color(light:0x646773,dark:0xA9ABB7)
    static let line = color(light:0xE1E2E8,dark:0x393B44)
    static let track = color(light:0xE4E5EC,dark:0x3C3E47)
    static let accent = color(light:0x6953CE,dark:0xB2A1FF)
    static let good = color(light:0x187664,dark:0x70CBB5)
    static let warning = color(light:0xA35C14,dark:0xF4B161)
    static let critical = color(light:0xB44145,dark:0xFF8585)

    private static func color(light: UInt32, dark: UInt32) -> Color {
        Color(nsColor:NSColor(name:nil) { appearance in
            let value = appearance.bestMatch(from:[.darkAqua,.aqua]) == .darkAqua ? dark : light
            return NSColor(srgbRed:Double((value >> 16) & 255) / 255,
                           green:Double((value >> 8) & 255) / 255,
                           blue:Double(value & 255) / 255,alpha:1)
        })
    }
}
