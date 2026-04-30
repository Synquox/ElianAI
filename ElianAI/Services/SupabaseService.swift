import Foundation
import Supabase
import AuthenticationServices
import CryptoKit

/// Service for Supabase authentication (Google Sign-In) and cloud data sync
@MainActor @Observable
final class SupabaseService {
    static let shared = SupabaseService()
    
    let client: SupabaseClient
    
    private(set) var currentUser: User?
    private(set) var isLoading = false
    private(set) var isSignedIn = false
    
    private init() {
        client = SupabaseClient(
            supabaseURL: URL(string: SupabaseConfig.projectURL)!,
            supabaseKey: SupabaseConfig.anonKey
        )
        
        // Check for existing session
        Task {
            await restoreSession()
        }
    }
    
    // MARK: - Session
    
    /// Restore existing auth session on launch
    private func restoreSession() async {
        do {
            let session = try await client.auth.session
            await MainActor.run {
                currentUser = session.user
                isSignedIn = true
            }
        } catch {
            await MainActor.run {
                currentUser = nil
                isSignedIn = false
            }
        }
    }
    
    // MARK: - Google Sign-In via Supabase OAuth
    
    /// Sign in with Google using Supabase's built-in OAuth flow
    @MainActor
    func signInWithGoogle() async throws {
        isLoading = true
        defer { isLoading = false }
        
        // Use Supabase's OAuth which opens a browser for Google login
        try await client.auth.signInWithOAuth(
            provider: .google,
            redirectTo: URL(string: "elianai://auth/callback")
        )
        
        // After OAuth redirect, refresh session
        try await refreshSession()
    }
    
    /// Handle the OAuth callback URL (from deep link)
    func handleAuthCallback(url: URL) async throws {
        try await client.auth.session(from: url)
        await refreshSession()
    }
    
    /// Refresh and sync the current session state
    @MainActor
    private func refreshSession() async throws {
        let session = try await client.auth.session
        currentUser = session.user
        isSignedIn = true
    }
    
    // MARK: - Sign Out
    
    @MainActor
    func signOut() async throws {
        isLoading = true
        defer { isLoading = false }
        
        try await client.auth.signOut()
        currentUser = nil
        isSignedIn = false
    }
    
    // MARK: - Cloud Sync (Homework)
    
    /// Push local homework entries to Supabase
    func syncHomeworkToCloud(entries: [HomeworkEntry]) async throws {
        guard isSignedIn, let userId = currentUser?.id.uuidString else { return }
        
        for entry in entries {
            let payload: [String: String] = [
                "user_id": userId,
                "title": entry.title,
                "description": entry.descriptionText,
                "source": entry.source.rawValue,
                "is_checked": entry.isCheckedOff ? "true" : "false",
                "created_at": ISO8601DateFormatter().string(from: entry.createdAt),
                "local_id": entry.id.uuidString
            ]
            
            try await client.from("homework")
                .upsert(payload, onConflict: "local_id, user_id")
                .execute()
        }
    }
    
    /// Fetch homework entries from cloud
    func fetchHomeworkFromCloud() async throws -> [[String: Any]] {
        guard isSignedIn, let userId = currentUser?.id.uuidString else { return [] }
        
        let response = try await client.from("homework")
            .select()
            .eq("user_id", value: userId)
            .execute()
        
        // Return raw data for the caller to process
        guard let json = try? JSONSerialization.jsonObject(with: response.data) as? [[String: Any]] else {
            return []
        }
        return json
    }
    
    // MARK: - User Display Info
    
    var userDisplayName: String {
        currentUser?.userMetadata["full_name"]?.value as? String
            ?? currentUser?.email
            ?? "User"
    }
    
    var userEmail: String {
        currentUser?.email ?? ""
    }
    
    var userAvatarURL: URL? {
        guard let urlString = currentUser?.userMetadata["avatar_url"]?.value as? String else {
            return nil
        }
        return URL(string: urlString)
    }
}
