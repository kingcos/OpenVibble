import SwiftUI
import Combine

enum AppLanguage: String, CaseIterable, Identifiable {
    case system
    case english = "en"
    case chineseSimplified = "zh-Hans"

    var id: String { rawValue }

    var titleKey: LocalizedStringKey {
        switch self {
        case .system: return "desktop.lang.system"
        case .english: return "desktop.lang.en"
        case .chineseSimplified: return "desktop.lang.zh"
        }
    }
}

@MainActor
final class LocalizationManager: ObservableObject {
    static let shared = LocalizationManager()
    private static let storageKey = "ovd.language"

    @Published private(set) var language: AppLanguage
    @Published private(set) var bundle: Bundle

    private init() {
        let stored = UserDefaults.standard.string(forKey: Self.storageKey) ?? AppLanguage.system.rawValue
        let lang = AppLanguage(rawValue: stored) ?? .system
        self.language = lang
        self.bundle = Self.resolveBundle(for: lang)
    }

    func set(_ language: AppLanguage) {
        self.language = language
        UserDefaults.standard.set(language.rawValue, forKey: Self.storageKey)
        self.bundle = Self.resolveBundle(for: language)
    }

    private static func resolveBundle(for language: AppLanguage) -> Bundle {
        let main = Bundle.main
        let code: String
        switch language {
        case .system:
            return main
        case .english:
            code = "en"
        case .chineseSimplified:
            code = "zh-Hans"
        }
        if let path = main.path(forResource: code, ofType: "lproj"),
           let override = Bundle(path: path) {
            return override
        }
        return main
    }
}

private struct LocalizationBundleKey: EnvironmentKey {
    static let defaultValue: Bundle = .main
}

extension EnvironmentValues {
    var localizationBundle: Bundle {
        get { self[LocalizationBundleKey.self] }
        set { self[LocalizationBundleKey.self] = newValue }
    }
}

struct LText: View {
    @Environment(\.localizationBundle) private var bundle
    let key: String
    let args: [CVarArg]

    init(_ key: String, _ args: CVarArg...) {
        self.key = key
        self.args = args
    }

    var body: some View {
        Text(resolved)
    }

    private var resolved: String {
        let format = bundle.localizedString(forKey: key, value: key, table: nil)
        if args.isEmpty { return format }
        return String(format: format, arguments: args)
    }
}

extension Bundle {
    func l(_ key: String, _ args: CVarArg...) -> String {
        let format = localizedString(forKey: key, value: key, table: nil)
        if args.isEmpty { return format }
        return String(format: format, arguments: args)
    }
}
