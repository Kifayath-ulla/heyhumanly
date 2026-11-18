import SwiftUI
import AppKit

// MARK: - Palette (light and dark are designed as a pair)

extension Color {
    static func adaptive(light: NSColor, dark: NSColor) -> Color {
        Color(nsColor: NSColor(name: nil) { $0.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? dark : light })
    }
    private static func rgb(_ r: Double, _ g: Double, _ b: Double, _ a: Double = 1) -> NSColor { NSColor(srgbRed: r, green: g, blue: b, alpha: a) }

    /// Graphite and silver accent (matches the icon).
    static let brand = adaptive(light: rgb(0.075, 0.075, 0.086), dark: rgb(0.949, 0.949, 0.953))
    static let brandSoft = adaptive(light: rgb(0, 0, 0, 0.06), dark: rgb(1, 1, 1, 0.12))
    /// Neutral canvas (light grey / navy-black).
    static let canvas = adaptive(light: rgb(0.969, 0.965, 0.953), dark: rgb(0.027, 0.027, 0.031))
    /// Main content panel and cards (cards are a soft tint on the panel).
    static let panel = adaptive(light: rgb(1, 1, 1), dark: rgb(0.055, 0.055, 0.063))
    static let cardFill = adaptive(light: rgb(0.976, 0.976, 0.973), dark: rgb(0.098, 0.098, 0.110))
    /// Cards.
    static let surface = adaptive(light: .white, dark: rgb(0.055, 0.055, 0.063))
    static let surfaceSunken = adaptive(light: rgb(0.953, 0.953, 0.957), dark: rgb(0.075, 0.075, 0.086))
    static let hairline = adaptive(light: rgb(0, 0, 0, 0.075), dark: rgb(1, 1, 1, 0.075))
    static let ink = adaptive(light: rgb(0.067, 0.067, 0.067), dark: rgb(0.925, 0.925, 0.941))
    static let added = adaptive(light: rgb(0.10, 0.50, 0.30), dark: rgb(0.45, 0.82, 0.58))
    static let removed = adaptive(light: rgb(0.86, 0.24, 0.26), dark: rgb(1.0, 0.48, 0.48))
    /// Pale status colours (Lexicon-style): soft background plus readable text.
    static let paleGreenBG = adaptive(light: rgb(0.929, 0.953, 0.925), dark: rgb(0.10, 0.18, 0.12))
    static let paleGreenText = adaptive(light: rgb(0.204, 0.396, 0.220), dark: rgb(0.55, 0.85, 0.62))
    static let paleRedBG = adaptive(light: rgb(0.992, 0.922, 0.925), dark: rgb(0.24, 0.11, 0.12))
    static let paleRedText = adaptive(light: rgb(0.624, 0.184, 0.176), dark: rgb(1.0, 0.55, 0.55))
    static let paleYellowBG = adaptive(light: rgb(0.984, 0.953, 0.859), dark: rgb(0.22, 0.18, 0.08))
    static let paleYellowText = adaptive(light: rgb(0.584, 0.392, 0), dark: rgb(0.95, 0.80, 0.45))
    static let paleBlueBG = adaptive(light: rgb(0.882, 0.953, 0.996), dark: rgb(0.08, 0.17, 0.25))
    static let paleBlueText = adaptive(light: rgb(0.122, 0.424, 0.624), dark: rgb(0.55, 0.78, 0.98))
    /// Text on accent-filled buttons.
    static let onAccent = adaptive(light: .white, dark: rgb(0.075, 0.075, 0.086))
    /// Neutral grey, used for Teach Me and the italic accent words.
    static let teach = adaptive(light: rgb(0.20, 0.20, 0.20), dark: rgb(0.85, 0.85, 0.85))
    static let shadow = adaptive(light: rgb(0, 0, 0, 0.05), dark: rgb(0, 0, 0, 0.5))

    /// Hero sky: daylight in light mode, dusk in dark mode.
    static let sky1 = adaptive(light: rgb(0.06, 0.06, 0.06), dark: rgb(0.12, 0.12, 0.12))
    static let sky2 = adaptive(light: rgb(0.20, 0.20, 0.20), dark: rgb(0.20, 0.20, 0.20))
    static let sky3 = adaptive(light: rgb(0.45, 0.45, 0.45), dark: rgb(0.34, 0.34, 0.34))
}

extension Font {
    /// Editorial serif for headlines (New York).
    static func serif(_ size: CGFloat, weight: Font.Weight = .regular) -> Font { .custom("Newsreader16pt-Regular", size: size).weight(weight) }
    /// Small mono label font (JetBrains Mono), falls back to the system mono.
    static func label(_ size: CGFloat, weight: Font.Weight = .medium) -> Font { .custom("JetBrainsMono-Regular", size: size).weight(weight) }
}

// MARK: - Building blocks

struct CardBackground: ViewModifier {
    var padding: CGFloat = 20
    var radius: CGFloat = 20
    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(Color.cardFill, in: RoundedRectangle(cornerRadius: radius, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: radius, style: .continuous).strokeBorder(Color.hairline, lineWidth: 0.5))
    }
}

extension View {
    func card(padding: CGFloat = 20, radius: CGFloat = 20) -> some View { modifier(CardBackground(padding: padding, radius: radius)) }
}

/// Small tracked-out label above a headline ("HOW IT WORKS").
struct Eyebrow: View {
    let text: String
    var color: Color = .brand
    var body: some View {
        Text(text.uppercased()).font(.label(10.5, weight: .medium)).tracking(1.2).foregroundStyle(color)
    }
}

/// Serif headline where one word can be set in lavender italics.
struct Headline: View {
    let before: String
    var italic: String = ""
    var after: String = ""
    var size: CGFloat = 34
    var color: Color = .ink
    var accent: Color = .teach
    var body: some View {
        (Text(before) + Text(italic).font(.custom("Newsreader16pt-Italic", size: size)).foregroundColor(accent) + Text(after))
            .font(.serif(size))
            .foregroundStyle(color)
            .accessibilityElement(children: .combine)
    }
}

/// HeyHumanly's mascot: a friendly speech bubble with round eyes and a smile. Original artwork drawn with shapes.
struct Mascot: View {
    var size: CGFloat = 44
    var mood: Mood = .happy
    enum Mood { case happy, thinking, proud }
    var body: some View {
        ZStack {
            BubbleShape()
                .fill(LinearGradient(colors: [Color(white: 0.99), Color(white: 0.86)], startPoint: .top, endPoint: .bottom))
                .overlay(BubbleShape().stroke(Color.black.opacity(0.08), lineWidth: max(0.5, size * 0.015)))
                .shadow(color: .black.opacity(0.16), radius: size * 0.07, y: size * 0.04)
            HStack(spacing: size * 0.2) { eye; eye }
                .offset(y: -size * 0.1)
            Group {
                if mood == .thinking {
                    Circle().stroke(Color(white: 0.12), lineWidth: size * 0.04).frame(width: size * 0.1)
                } else {
                    SmileShape().stroke(Color(white: 0.12), style: StrokeStyle(lineWidth: size * 0.045, lineCap: .round))
                        .frame(width: size * (mood == .proud ? 0.3 : 0.24), height: size * (mood == .proud ? 0.13 : 0.09))
                }
            }
            .offset(y: size * 0.1)
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
    private var eye: some View {
        ZStack {
            Ellipse().fill(Color(white: 0.12)).frame(width: size * 0.115, height: size * 0.16)
            Circle().fill(Color.white).frame(width: size * 0.04).offset(x: size * 0.015, y: -size * 0.035)
        }
    }
}

struct SmileShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.minX, y: rect.minY))
        p.addQuadCurve(to: CGPoint(x: rect.maxX, y: rect.minY), control: CGPoint(x: rect.midX, y: rect.maxY * 2))
        return p
    }
}

/// Rounded square bubble with a small tail at the bottom left.
struct BubbleShape: Shape {
    func path(in rect: CGRect) -> Path {
        let r = rect.width * 0.28
        let body = CGRect(x: rect.minX, y: rect.minY, width: rect.width, height: rect.height * 0.86)
        var p = Path(roundedRect: body, cornerRadius: r, style: .continuous)
        p.move(to: CGPoint(x: body.minX + rect.width * 0.18, y: body.maxY - 1))
        p.addLine(to: CGPoint(x: body.minX + rect.width * 0.10, y: rect.maxY))
        p.addLine(to: CGPoint(x: body.minX + rect.width * 0.36, y: body.maxY - 1))
        p.closeSubpath()
        return p
    }
}

/// App mark used in small places.
struct BrandMark: View {
    var size: CGFloat = 26
    var body: some View {
        // The app icon (the leaf), so the brand is the same in the Dock, the menu bar and the window.
        Image(nsImage: NSApp.applicationIconImage).resizable().interpolation(.high)
            .frame(width: size * 1.15, height: size * 1.15).accessibilityHidden(true)
    }
}

/// A single keyboard key.
struct KeyCap: View {
    let key: String
    var size: CGFloat = 13
    var glass = false
    var body: some View {
        Text(key)
            .font(.system(size: size, weight: .medium, design: .rounded))
            .foregroundStyle(glass ? Color.white : Color.ink)
            .padding(.horizontal, key.count > 1 ? size * 0.6 : 0)
            .frame(minWidth: size * 2, minHeight: size * 2)
            .background(glass ? AnyShapeStyle(Color.white.opacity(0.18)) : AnyShapeStyle(Color.surface),
                        in: RoundedRectangle(cornerRadius: size * 0.5, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: size * 0.5, style: .continuous)
                .strokeBorder(glass ? Color.white.opacity(0.45) : Color.hairline, lineWidth: glass ? 1 : 0.8))
            .shadow(color: .black.opacity(glass ? 0.12 : 0.10), radius: 0, x: 0, y: size * 0.12)
    }
}

/// Splits a shortcut label such as "⌃⌥Space" into key caps: one per modifier, then the key.
struct ShortcutKeys: View {
    let label: String
    var size: CGFloat = 13
    var glass = false
    var body: some View {
        HStack(spacing: size * 0.35) { ForEach(Array(Self.keys(label).enumerated()), id: \.offset) { KeyCap(key: $0.element, size: size, glass: glass) } }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Shortcut \(label)")
    }
    static func keys(_ label: String) -> [String] {
        let mods: Set<Character> = ["⌃", "⌥", "⇧", "⌘"]
        var caps: [String] = []; var rest = ""
        for ch in label { if mods.contains(ch) && rest.isEmpty { caps.append(String(ch)) } else { rest.append(ch) } }
        if !rest.isEmpty { caps.append(rest) }
        return caps
    }
}

struct ModeBadge: View {
    let mode: CoachMode
    var body: some View {
        Label(mode == .teach ? "Teach Me" : "Quick Fix", systemImage: mode == .teach ? "graduationcap.fill" : "bolt.fill")
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(mode == .teach ? Color.teach : Color.brand)
            .padding(.horizontal, 9).padding(.vertical, 4)
            .background((mode == .teach ? Color.teach : Color.brand).opacity(0.12), in: Capsule())
    }
}

struct StatusDot: View {
    let color: Color
    var body: some View { Circle().fill(color).frame(width: 8, height: 8).overlay(Circle().stroke(color.opacity(0.25), lineWidth: 3)) }
}

/// Glossy blue pill, like a native "Download" button.
struct PrimaryButtonStyle: ButtonStyle {
    var tint: Color = .brand
    var large = false
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: large ? 15 : 13, weight: .semibold))
            .foregroundStyle(Color.onAccent)
            .padding(.horizontal, large ? 22 : 16).padding(.vertical, large ? 11 : 8)
            .background(
                Capsule().fill(LinearGradient(colors: [tint.opacity(0.88), tint], startPoint: .top, endPoint: .bottom))
                    .overlay(Capsule().strokeBorder(LinearGradient(colors: [Color.white.opacity(0.45), Color.white.opacity(0.05)], startPoint: .top, endPoint: .bottom), lineWidth: 1))
            )
            .shadow(color: tint.opacity(configuration.isPressed ? 0.15 : 0.35), radius: configuration.isPressed ? 3 : 8, y: configuration.isPressed ? 1 : 4)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

/// White pill with a soft shadow (dark: raised navy).
struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .medium))
            .foregroundStyle(Color.ink)
            .padding(.horizontal, 14).padding(.vertical, 7)
            .background(Capsule().fill(Color.surface))
            .overlay(Capsule().strokeBorder(Color.hairline, lineWidth: 0.8))
            .shadow(color: .shadow, radius: configuration.isPressed ? 2 : 6, y: configuration.isPressed ? 1 : 3)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

/// White pill on the hero sky.
struct GlassButtonStyle: ButtonStyle {
    var filled = true
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(filled ? Color(red: 0.07, green: 0.09, blue: 0.16) : Color.white)
            .padding(.horizontal, 20).padding(.vertical, 10)
            .background(Capsule().fill(filled ? Color.white : Color.white.opacity(0.18)))
            .overlay(Capsule().strokeBorder(Color.white.opacity(filled ? 0 : 0.5), lineWidth: 1))
            .shadow(color: .black.opacity(0.15), radius: 8, y: 4)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
    }
}

/// Soft sky gradient with blurred "clouds".
struct SkyBackground: View {
    var body: some View {
        ZStack {
            LinearGradient(colors: [.sky1, .sky2, .sky3], startPoint: .topLeading, endPoint: .bottomTrailing)
            GeometryReader { g in
                Circle().fill(Color.white.opacity(0.35)).frame(width: g.size.width * 0.5).blur(radius: 60)
                    .offset(x: g.size.width * 0.55, y: -g.size.height * 0.35)
                Circle().fill(Color.white.opacity(0.25)).frame(width: g.size.width * 0.4).blur(radius: 50)
                    .offset(x: -g.size.width * 0.1, y: g.size.height * 0.45)
                Ellipse().fill(Color.white.opacity(0.22)).frame(width: g.size.width * 0.35, height: 60).blur(radius: 20)
                    .offset(x: g.size.width * 0.12, y: g.size.height * 0.18)
            }
        }
    }
}

/// NSVisualEffectView for translucent panels.
struct VisualEffect: NSViewRepresentable {
    var material: NSVisualEffectView.Material = .popover
    func makeNSView(context: Context) -> NSVisualEffectView {
        let v = NSVisualEffectView(); v.material = material; v.blendingMode = .behindWindow; v.state = .active; return v
    }
    func updateNSView(_ v: NSVisualEffectView, context: Context) { v.material = material }
}

// MARK: - Word diff

enum WordDiff {
    enum Kind { case same, added, removed }
    struct Piece {
        let text: String; let kind: Kind
        /// For `.same` pieces: the original token, which may differ from `text` in punctuation only.
        var old: String? = nil
    }

    /// Word-level LCS diff. Whitespace is kept attached to the preceding word.
    static func diff(_ old: String, _ new: String) -> [Piece] {
        let a = tokens(old), b = tokens(new)
        guard a.count * b.count < 400_000 else { return [Piece(text: new, kind: .same)] }
        let n = a.count, m = b.count
        var lcs = Array(repeating: Array(repeating: 0, count: m + 1), count: n + 1)
        for i in stride(from: n - 1, through: 0, by: -1) {
            for j in stride(from: m - 1, through: 0, by: -1) {
                lcs[i][j] = norm(a[i]) == norm(b[j]) ? lcs[i + 1][j + 1] + 1 : max(lcs[i + 1][j], lcs[i][j + 1])
            }
        }
        // Walk the table; inside each run of changes emit all removed words, then all added words,
        // so "thung" → "thing" reads as one replacement instead of interleaved fragments.
        var out: [Piece] = []; var removed: [Piece] = []; var added: [Piece] = []
        func flush() { out += removed; out += added; removed = []; added = [] }
        var i = 0, j = 0
        while i < n || j < m {
            if i < n, j < m, norm(a[i]) == norm(b[j]) { flush(); out.append(Piece(text: b[j], kind: .same, old: a[i])); i += 1; j += 1 }
            else if i < n, j == m || lcs[i + 1][j] >= lcs[i][j + 1] { removed.append(Piece(text: a[i], kind: .removed)); i += 1 }
            else { added.append(Piece(text: b[j], kind: .added)); j += 1 }
        }
        flush()
        return out
    }

    static func changeCount(_ old: String, _ new: String) -> Int {
        // Count runs of changes, so "thung → thing" is one change.
        var count = 0; var inChange = false
        for p in diff(old, new) { if p.kind == .same { inChange = false } else if !inChange { count += 1; inChange = true } }
        return count
    }

    static func attributed(_ old: String, _ new: String, showRemoved: Bool = true) -> AttributedString {
        var result = AttributedString()
        for piece in diff(old, new) {
            switch piece.kind {
            case .same:
                if let old = piece.old, old.trimmingCharacters(in: .whitespacesAndNewlines) != piece.text.trimmingCharacters(in: .whitespacesAndNewlines) {
                    // Punctuation-only change on a matched word: highlight it as added.
                    var s = AttributedString(piece.text.trimmingCharacters(in: .whitespaces))
                    s.foregroundColor = .added; s.backgroundColor = Color.added.opacity(0.14)
                    result += s
                    if piece.text.last?.isWhitespace == true { result += AttributedString(" ") }
                } else {
                    result += AttributedString(piece.text)
                }
            case .added:
                var s = AttributedString(piece.text.trimmingCharacters(in: .whitespaces))
                s.foregroundColor = .added; s.backgroundColor = Color.added.opacity(0.14)
                result += s
                if piece.text.last?.isWhitespace == true { result += AttributedString(" ") }
            case .removed:
                guard showRemoved else { continue }
                var s = AttributedString(piece.text.trimmingCharacters(in: .whitespaces))
                s.foregroundColor = .removed; s.strikethroughStyle = .single
                result += s
                result += AttributedString(" ")
            }
        }
        return result
    }

    private static func tokens(_ s: String) -> [String] {
        var out: [String] = []; var cur = ""
        for ch in s {
            if ch.isWhitespace { cur.append(ch) }
            else { if let last = cur.last, last.isWhitespace { out.append(cur); cur = "" }; cur.append(ch) }
        }
        if !cur.isEmpty { out.append(cur) }
        return out
    }
    /// Words match when they differ only by surrounding punctuation ("yesterday," vs "yesterday;"); case still counts.
    private static func norm(_ s: String) -> String { s.trimmingCharacters(in: .whitespacesAndNewlines.union(.punctuationCharacters)) }
}
