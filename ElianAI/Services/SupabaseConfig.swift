import Foundation

/// Supabase project configuration
enum SupabaseConfig {
    static let projectURL = "https://ghckuhxmqhrtpcqhymts.supabase.co"
    static let anonKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImdoY2t1aHhtcWhydHBjcWh5bXRzIiwicm9sZSI6ImFub24iLCJpYXQiOjE3Nzc1NDAxNTcsImV4cCI6MjA5MzExNjE1N30.VkjEwBjt6hK8lN_CVLpvLMfbCjd6hkRn4um_dCvj4n8"
    
    // Google OAuth — Client ID from Google Cloud Console
    // You'll need to set this up in Google Cloud Console and Supabase Auth settings
    static let googleClientID = "466368787691-7ii1r9duc8742p1ptod725foguv9p4he.apps.googleusercontent.com" // TODO: Add your Google OAuth Client ID
}
