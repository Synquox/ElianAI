import Foundation
import UIKit
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
            currentUser = session.user
            isSignedIn = true
        } catch {
            currentUser = nil
            isSignedIn = false
        }
    }
    
    // MARK: - Google Sign-In via Supabase OAuth
    
    /// Sign in with Google using Supabase's OAuth flow (opens secure auth session)
    func signInWithGoogle() async throws {
        isLoading = true
        defer { isLoading = false }
        
        let url = try await client.auth.getOAuthSignInURL(
            provider: .google,
            redirectTo: URL(string: "elianai://auth")
        )
        
        // Use ASWebAuthenticationSession for a native sign-in experience
        return try await withCheckedThrowingContinuation { continuation in
            let session = ASWebAuthenticationSession(
                url: url,
                callbackURLScheme: "elianai"
            ) { callbackURL, error in
                if let error = error {
                    if (error as NSError).code == ASWebAuthenticationSessionError.canceledLogin.rawValue {
                        continuation.resume(throwing: CancellationError())
                    } else {
                        continuation.resume(throwing: error)
                    }
                    return
                }
                
                guard let callbackURL = callbackURL else {
                    continuation.resume(throwing: URLError(.badURL))
                    return
                }
                
                Task {
                    do {
                        try await self.handleAuthCallback(url: callbackURL)
                        continuation.resume()
                    } catch {
                        continuation.resume(throwing: error)
                    }
                }
            }
            
            session.presentationContextProvider = AuthPresentationContext.shared
            session.prefersEphemeralWebBrowserSession = false // Allow Google to remember accounts
            session.start()
        }
    }
    
    /// Handle the OAuth callback URL (from deep link)
    func handleAuthCallback(url: URL) async throws {
        try await client.auth.session(from: url)
        try await refreshSession()
    }
    
    /// Refresh and sync the current session state
    private func refreshSession() async throws {
        let session = try await client.auth.session
        currentUser = session.user
        isSignedIn = true
    }
    
    // MARK: - Sign Out
    
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
        }
    }
    
    /// Fetch homework entries from cloud
    func fetchHomeworkFromCloud() async throws -> [[String: Any]] {
        guard isSignedIn, let userId = currentUser?.id.uuidString else { return [] }
        
        let response = try await client.from("homework")
            .select()
            .eq("user_id", value: userId)
        
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

/// Helper for ASWebAuthenticationSession presentation
@MainActor
class AuthPresentationContext: NSObject, ASWebAuthenticationPresentationContextProviding {
    static let shared = AuthPresentationContext()
    
    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = scene.windows.first else {
            return ASPresentationAnchor()
        }
        return window
    }
}
