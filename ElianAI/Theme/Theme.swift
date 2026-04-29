import SwiftUI

// MARK: - Color Palette

extension Color {
    // Background
    static let elianBackground = Color(hex: "#0A0A0F")
    static let elianSurface = Color(hex: "#12121A")
    static let elianSurfaceSecondary = Color(hex: "#1A1A26")
    static let elianSurfaceTertiary = Color(hex: "#22223A")
    
    // Accent Colors
    static let elianBlue = Color(hex: "#4A9EFF")        // Notes
    static let elianPurple = Color(hex: "#A855F7")       // Quizzes
    static let elianGreen = Color(hex: "#34D399")        // Flashcards
    static let elianOrange = Color(hex: "#FB923C")       // Chat
    static let elianPink = Color(hex: "#F472B6")         // Folders
    
    // Text
    static let elianTextPrimary = Color(hex: "#F0F0F5")
    static let elianTextSecondary = Color(hex: "#9090A8")
    static let elianTextTertiary = Color(hex: "#606078")
    
    // Status
    static let elianSuccess = Color(hex: "#22C55E")
    static let elianError = Color(hex: "#EF4444")
    static let elianWarning = Color(hex: "#F59E0B")
    
    // Borders
    static let elianBorder = Color(hex: "#2A2A3A")
    static let elianBorderLight = Color(hex: "#3A3A4A")
}

extension ShapeStyle where Self == Color {
    static var elianBackground: Color { Color.elianBackground }
    static var elianSurface: Color { Color.elianSurface }
    static var elianSurfaceSecondary: Color { Color.elianSurfaceSecondary }
    static var elianSurfaceTertiary: Color { Color.elianSurfaceTertiary }
    
    static var elianBlue: Color { Color.elianBlue }
    static var elianPurple: Color { Color.elianPurple }
    static var elianGreen: Color { Color.elianGreen }
    static var elianOrange: Color { Color.elianOrange }
    static var elianPink: Color { Color.elianPink }
    
    static var elianTextPrimary: Color { Color.elianTextPrimary }
    static var elianTextSecondary: Color { Color.elianTextSecondary }
    static var elianTextTertiary: Color { Color.elianTextTertiary }
    
    static var elianSuccess: Color { Color.elianSuccess }
    static var elianError: Color { Color.elianError }
    static var elianWarning: Color { Color.elianWarning }
    
    static var elianBorder: Color { Color.elianBorder }
    static var elianBorderLight: Color { Color.elianBorderLight }
}

// MARK: - Hex Color Initializer

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3:
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

// MARK: - View Modifiers

struct ElianCardModifier: ViewModifier {
    var cornerRadius: CGFloat = 16
    var padding: CGFloat = 16
    
    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(Color.elianSurface)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(Color.elianBorder, lineWidth: 0.5)
            )
    }
}

struct ElianGlassModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

struct ElianButtonModifier: ViewModifier {
    var color: Color = .elianBlue
    var isFullWidth: Bool = false
    
    func body(content: Content) -> some View {
        content
            .font(.system(size: 16, weight: .semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 24)
            .padding(.vertical, 14)
            .frame(maxWidth: isFullWidth ? .infinity : nil)
            .background(
                LinearGradient(
                    colors: [color, color.opacity(0.8)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .shadow(color: color.opacity(0.3), radius: 8, y: 4)
    }
}

struct ElianOutlineButtonModifier: ViewModifier {
    var color: Color = .elianBlue
    
    func body(content: Content) -> some View {
        content
            .font(.system(size: 15, weight: .medium))
            .foregroundStyle(color)
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(color.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(color.opacity(0.3), lineWidth: 1)
            )
    }
}

// MARK: - Study Tool Badge

struct StudyToolBadge: View {
    enum Tool {
        case notes, quiz, flashcards, chat
        
        var label: String {
            switch self {
            case .notes: return "Notes"
            case .quiz: return "Quiz"
            case .flashcards: return "Cards"
            case .chat: return "Chat"
            }
        }
        
        var icon: String {
            switch self {
            case .notes: return "doc.text.fill"
            case .quiz: return "questionmark.circle.fill"
            case .flashcards: return "rectangle.on.rectangle.fill"
            case .chat: return "bubble.left.and.bubble.right.fill"
            }
        }
        
        var color: Color {
            switch self {
            case .notes: return .elianBlue
            case .quiz: return .elianPurple
            case .flashcards: return .elianGreen
            case .chat: return .elianOrange
            }
        }
    }
    
    let tool: Tool
    let isSelected: Bool
    
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: tool.icon)
                .font(.system(size: 13, weight: .semibold))
            Text(tool.label)
                .font(.system(size: 13, weight: .semibold))
        }
        .foregroundStyle(isSelected ? .white : tool.color)
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(
            isSelected
                ? AnyShapeStyle(tool.color)
                : AnyShapeStyle(tool.color.opacity(0.12))
        )
        .clipShape(Capsule())
        .animation(.easeInOut(duration: 0.2), value: isSelected)
    }
}

// MARK: - View Extensions

extension View {
    func elianCard(cornerRadius: CGFloat = 16, padding: CGFloat = 16) -> some View {
        modifier(ElianCardModifier(cornerRadius: cornerRadius, padding: padding))
    }
    
    func elianGlass() -> some View {
        modifier(ElianGlassModifier())
    }
    
    func elianButton(color: Color = .elianBlue, fullWidth: Bool = false) -> some View {
        modifier(ElianButtonModifier(color: color, isFullWidth: fullWidth))
    }
    
    func elianOutlineButton(color: Color = .elianBlue) -> some View {
        modifier(ElianOutlineButtonModifier(color: color))
    }
}
