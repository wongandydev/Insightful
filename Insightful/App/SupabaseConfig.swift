import Foundation

/// Reads Supabase endpoint + anon key from a bundled `SupabaseConfig.plist`.
///
/// The plist is a regular resource — separate from `Info.plist` so app metadata
/// stays clean and we can later swap it per scheme/configuration without
/// touching Apple's reserved keys.
///
/// `fatalError` on missing values is intentional: better a launch crash than a
/// confusing chain of 401s.
enum SupabaseConfig {
    private static let plist: [String: Any] = {
        guard let url = Bundle.main.url(forResource: "SupabaseConfig", withExtension: "plist"),
              let data = try? Data(contentsOf: url),
              let dict = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any]
        else {
            fatalError("SupabaseConfig.plist missing from app bundle. Verify it's in the Insightful target's Resources.")
        }
        return dict
    }()

    static let url: URL = {
        guard let raw = plist["url"] as? String, let url = URL(string: raw) else {
            fatalError("SupabaseConfig.plist missing or invalid `url`.")
        }
        return url
    }()

    static let anonKey: String = {
        guard let key = plist["anonKey"] as? String, !key.isEmpty else {
            fatalError("SupabaseConfig.plist missing `anonKey`.")
        }
        return key
    }()
}
