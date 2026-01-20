import Foundation

/// Configuration for Supabase client connection
struct SupabaseConfig: Sendable {
    let url: URL
    let anonKey: String

    /// Shared configuration instance
    static let shared = SupabaseConfig(
        url: URL(string: "https://oodhbbdwdwevdidlbsmb.supabase.co")!,
        anonKey: "sb_publishable_ztV3etQnQCBjB4wUIz-pNA_n1js-_kG"
    )

    init(url: URL, anonKey: String) {
        self.url = url
        self.anonKey = anonKey
    }

    /// Base URL for authentication endpoints
    var authURL: URL {
        url.appendingPathComponent("auth/v1")
    }

    /// Base URL for REST API endpoints
    var restURL: URL {
        url.appendingPathComponent("rest/v1")
    }

    /// Base URL for Storage API endpoints
    var storageURL: URL {
        url.appendingPathComponent("storage/v1")
    }
}
