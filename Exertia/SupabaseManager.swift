//
//  SupabaseManager.swift
//  Exertia
//
//  Created by Ekansh Jindal on 13/02/26.
//

import Foundation
import Supabase

// The struct that matches your 'users' table in the database
struct DBUser: Codable {
    let id: UUID
    let username: String
    let display_name: String
    let daily_target_distance: Double
    let daily_target_calories: Int
    let current_streak: Int
    let longest_streak: Int
    let is_online: Bool
}

class SupabaseManager {
    static let shared = SupabaseManager()
        
        let client: SupabaseClient
        
        private init() {
            print("🔌 INITIALIZING SUPABASE CLIENT...") // <--- ADD THIS
            
            self.client = SupabaseClient(
                supabaseURL: URL(string: "https://zdnhlvgjoaltgfdnkxrg.supabase.co")!,
                supabaseKey: "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Inpkbmhsdmdqb2FsdGdmZG5reHJnIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzA5Njc0NDUsImV4cCI6MjA4NjU0MzQ0NX0.oMF-6lLKtl0vsvuu1OcS-h0JAaMDYjUbJAZYrFClDEI",
                options: SupabaseClientOptions(
                    auth: SupabaseClientOptions.AuthOptions(
                        emitLocalSessionAsInitialSession: true
                    )
                )
            )
            print("✅ SUPABASE CLIENT READY") // <--- ADD THIS
        }
    
    // MARK: - Authentication Functions
    
    // 1. Sign Up (Creates a new Auth Account)
    func signUp(email: String, password: String) async throws -> User {
        let response = try await client.auth.signUp(
            email: email,
            password: password
        )
        
        // In the new SDK, 'user' is not optional, so we just return it directly
        return response.user
    }
    
    // 2. Sign In (Logs in an existing user)
    // FIX: Changed 'signInWithPassword' to 'signIn' for SDK v2.0+
    func signIn(email: String, password: String) async throws {
        try await client.auth.signIn(
            email: email,
            password: password
        )
    }
    
    // 3. Sign Out
    func signOut() async throws {
        print("⚡️ Logging out...")
        try await client.auth.signOut()
        print("✅ Logged out successfully!")
    }
    
    // 4. Get Current User Object (Auth)
    var currentUser: User? {
        return client.auth.currentUser
    }
    
    // 5. Get Current User ID (Helper)
    func getCurrentUserID() -> UUID? {
        return client.auth.currentUser?.id
    }
    
    // MARK: - User Status Updates
        
        // 1. Define a little struct for the update data
        struct UserStatusUpdate: Encodable {
            let is_online: Bool
            let last_seen: String
        }
        
        // Call this when the user logs in or opens the app
        func setUserOnline() async {
            guard let id = getCurrentUserID() else { return }
            
            print("🟢 Setting User ONLINE...")
            
            // FIX: Use the struct instead of a Dictionary
            let updateData = UserStatusUpdate(
                is_online: true,
                last_seen: ISO8601DateFormatter().string(from: Date())
            )
            
            do {
                try await client
                    .from("users")
                    .update(updateData) // Pass the struct here
                    .eq("id", value: id)
                    .execute()
                print("✅ User is now ONLINE in Database")
            } catch {
                print("❌ Failed to set online: \(error)")
            }
        }
        
        // Call this when the user closes the app
        func setUserOffline() async {
            guard let id = getCurrentUserID() else { return }
            
            print("Setting User OFFLINE...")
            
            // FIX: Use the struct here too
            let updateData = UserStatusUpdate(
                is_online: false,
                last_seen: ISO8601DateFormatter().string(from: Date())
            )
            
            do {
                try await client
                    .from("users")
                    .update(updateData)
                    .eq("id", value: id)
                    .execute()
                print("✅ User is now OFFLINE in Database")
            } catch {
                print("❌ Failed to set offline: \(error)")
            }
        }
    
    // MARK: - Logout and Delete
        
    func deleteAccount() async throws {
        guard let id = getCurrentUserID() else { return }
        print("🗑️ Deleting user profile from database...")
            
        // 1. Delete the user's row from the 'users' table
        try await client.from("users").delete().eq("id", value: id).execute()
            
        // 2. Log them out locally
        try await client.auth.signOut()
        print("✅ Account deleted and logged out!")
    }
}
