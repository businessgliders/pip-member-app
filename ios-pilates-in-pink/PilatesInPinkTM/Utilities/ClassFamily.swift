import Foundation

/// Class families, mapped from `class_code` prefixes. Used for photos and filters only.
enum ClassFamily: String, CaseIterable, Identifiable, Hashable, Sendable {
    case sculpt, core, rise, poise, rose, jump, intro

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .sculpt: "Power in Pink Sculpt"
        case .core: "Core in Blush"
        case .rise: "Pink Rise & Strengthen"
        case .poise: "Poise & Posture Reset"
        case .rose: "Rosé Stretch & Release"
        case .jump: "Pink Power Jump"
        case .intro: "Intro Class"
        }
    }

    /// Square photo (1024×1024): tiles, list thumbnails, Home "At the Studio".
    var imageName: String { "class_\(rawValue)" }
    /// Wide photo (1536×1024): class detail hero and the wide detail pane.
    var wideImageName: String { "class_\(rawValue)_wide" }

    private var codePrefix: String {
        switch self {
        case .sculpt: "sculpt_"
        case .core: "core_"
        case .rise: "rise"
        case .poise: "poise_"
        case .rose: "rose"
        case .jump: "jump"
        case .intro: "intro"
        }
    }

    private var nameHint: String {
        switch self {
        case .sculpt: "sculpt"
        case .core: "core"
        case .rise: "rise"
        case .poise: "poise"
        case .rose: "ros"
        case .jump: "jump"
        case .intro: "intro"
        }
    }

    static func from(code: String?, name: String?) -> ClassFamily? {
        if let code = code?.lowercased(), !code.isEmpty,
           let match = allCases.first(where: { code.hasPrefix($0.codePrefix) }) {
            return match
        }
        if let name = name?.lowercased(), !name.isEmpty {
            return allCases.first { name.contains($0.nameHint) }
        }
        return nil
    }
}

extension ScheduleSession {
    var family: ClassFamily? { ClassFamily.from(code: classCode, name: className) }
    var photoName: String { family?.imageName ?? "studio_brampton" }
    var widePhotoName: String { family?.wideImageName ?? "studio_brampton" }
}
