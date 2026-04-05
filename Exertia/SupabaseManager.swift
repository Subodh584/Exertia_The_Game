//
//  SupabaseManager.swift
//  Exertia
//
//  Created by Ekansh Jindal on 13/02/26.
//

import Foundation
import UIKit
import Supabase
import AuthenticationServices

// MARK: - ISO8601 parser (handles with/without fractional seconds)
enum ISODateParser {
    private static let withFrac: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()
    private static let noFrac: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()
    static func date(from string: String) -> Date? {
        withFrac.date(from: string) ?? noFrac.date(from: string)
    }
}

// MARK: - Database Models

struct AppUser: Codable {
    let id: String
    let username: String?
    let email: String?
    let display_name: String?
    let daily_target_distance: Double?
    let daily_target_calories: Int?
    let initial_weight: Double?
    let current_weight: Double?
    let target_weight: Double?
    let current_streak: Int?
    let longest_streak: Int?
    let is_online: Bool?
    let last_seen: String?
    let last_streak_date: String?
}

struct AppSession: Codable {
    let id: String?
    let user_id: String?
    let track_id: String?
    let character_id: String?
    let duration_minutes: Int?
    let calories_burned: Int?
    let distance_covered: Double?
    let average_speed: Double?
    let total_jumps: Int?
    let total_crouches: Int?
    let total_left_leans: Int?
    let total_right_leans: Int?
    let total_steps: Int?
    let completion_status: String?
    let created_at: String?
}

extension AppSession {
    var countsTowardDailyProgress: Bool {
        let status = completion_status?.lowercased() ?? ""
        guard status == "completed" || status == "abandoned" else { return false }
        let calories = calories_burned ?? 0
        let distance = distance_covered ?? 0
        return calories > 0 || distance > 0
    }
}

struct AppUserStats: Codable {
    let total_sessions: Int
    let total_minutes: Int
    let total_calories: Int
    let total_distance: Double
    let completed_sessions: Int
    let personal_best_distance: Double
    let personal_best_calories: Int
    let friend_count: Int
}

struct AppFriendship: Codable {
    let id: String
    let requester_id: String
    let receiver_id: String
    let status: String
    let created_at: String?
}

struct AppBadge: Codable {
    let id: String
    let name: String
    let description: String
    let icon: String
    let badge_type: String
    let target_value: Double
}

struct AppUserBadge: Codable {
    let id: String
    let badge: AppBadge?
    let badge_id: String?
    let current_progress: Double
    let is_completed: Bool
    let completed_at: String?
}

struct AppDailyProgress: Codable {
    let id: String?
    let date: String
    let total_distance: Double
    let total_calories: Int
    let total_duration_mins: Int
    let target_met: Bool
}

// MARK: - Insert/Update Structs

struct UserInsert: Encodable {
    let id: String
    let username: String?
    let display_name: String
    let email: String?
    let daily_target_distance: Double?
    let daily_target_calories: Int?
}

struct SessionInsert: Encodable {
    let user_id: String
    let track_id: String
    let character_id: String
    let duration_minutes: Int
    let calories_burned: Int
    let distance_covered: Double
    let average_speed: Double?
    let total_jumps: Int
    let total_crouches: Int
    let total_left_leans: Int
    let total_right_leans: Int
    let total_steps: Int
    let completion_status: String
}

struct FriendshipInsert: Encodable {
    let requester_id: String
    let receiver_id: String
}

private struct UserStatusUpdate: Encodable {
    let is_online: Bool
    let last_seen: String
}

// MARK: - Login Error Types
enum LoginError: Error {
    case emptyUsername
    case emptyPassword
    case invalidCredentials
    case userNotFound
    case networkError
    case sessionExpired
}

// MARK: - Supabase Manager

class SupabaseManager {
    static let shared = SupabaseManager()

    let client: SupabaseClient

    private init() {
        print("🔌 INITIALIZING SUPABASE CLIENT...")
        self.client = SupabaseClient(
            supabaseURL: URL(string: "https://zdnhlvgjoaltgfdnkxrg.supabase.co")!,
            supabaseKey: "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Inpkbmhsdmdqb2FsdGdmZG5reHJnIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzA5Njc0NDUsImV4cCI6MjA4NjU0MzQ0NX0.oMF-6lLKtl0vsvuu1OcS-h0JAaMDYjUbJAZYrFClDEI",
            options: SupabaseClientOptions(
                auth: SupabaseClientOptions.AuthOptions(
                    emitLocalSessionAsInitialSession: true
                )
            )
        )
        print("✅ SUPABASE CLIENT READY")
    }

    // MARK: - Authentication

    /// Returns true if user has a valid Supabase session
    var hasSession: Bool {
        return client.auth.currentUser != nil
    }

    var currentUserId: String? {
        return client.auth.currentUser?.id.uuidString
    }

    func signUp(email: String, password: String, username: String, displayName: String) async throws -> String {
        let response = try await client.auth.signUp(email: email, password: password)
        let userId = response.user.id.uuidString

        let newUser = UserInsert(
            id: userId,
            username: username,
            display_name: displayName,
            email: email,
            daily_target_distance: 5.0,
            daily_target_calories: 300
        )
        try await client.from("users").insert(newUser).execute()
        print("✅ User created in Supabase Auth + users table. ID: \(userId)")
        return userId
    }

    func signIn(email: String, password: String) async throws -> AppUser {
        do {
            try await client.auth.signIn(email: email, password: password)
        } catch {
            let errorDesc = error.localizedDescription.lowercased()
            if errorDesc.contains("invalid") || errorDesc.contains("credentials") {
                throw LoginError.invalidCredentials
            }
            throw LoginError.networkError
        }

        guard let authUser = client.auth.currentUser else {
            throw LoginError.userNotFound
        }

        let userId = authUser.id.uuidString
        let users: [AppUser] = try await client.from("users")
            .select()
            .eq("id", value: userId)
            .execute()
            .value

        guard let user = users.first else {
            throw LoginError.userNotFound
        }

        UserDefaults.standard.set(userId, forKey: "supabaseUserID")
        print("✅ Signed in. User ID: \(userId)")
        return user
    }

    // MARK: - OAuth

    /// Opens an ASWebAuthenticationSession for Google/Apple OAuth via Supabase
    @discardableResult
    func signInWithOAuth(provider: Auth.Provider) async throws -> Session {
        let redirectURL = URL(string: "exertia://auth-callback")!
        return try await client.auth.signInWithOAuth(
            provider: provider,
            redirectTo: redirectURL
        )
    }

    /// Check if a first-time OAuth user still needs to set up their profile
    func isProfileComplete(userId: String) async throws -> Bool {
        let users: [AppUser] = try await client.from("users")
            .select()
            .eq("id", value: userId)
            .execute()
            .value
        guard let user = users.first else { return false }
        return user.username != nil && !user.username!.isEmpty
    }

    /// Create a minimal user row for first-time OAuth users (no username yet)
    func createOAuthUserRow(userId: String, email: String, displayName: String?) async throws {
        let newUser = UserInsert(
            id: userId,
            username: nil,
            display_name: displayName ?? "New Player",
            email: email,
            daily_target_distance: nil,
            daily_target_calories: nil
        )
        try await client.from("users").insert(newUser).execute()
        print("✅ Created users row for OAuth user: \(userId)")
    }

    /// Attempt to restore session on app launch. Returns the user if session is valid.
    func restoreSession() async throws -> AppUser? {
        // Supabase SDK auto-restores the session from keychain
        guard let authUser = client.auth.currentUser else {
            return nil
        }

        let userId = authUser.id.uuidString
        let users: [AppUser] = try await client.from("users")
            .select()
            .eq("id", value: userId)
            .execute()
            .value

        guard let user = users.first else { return nil }
        UserDefaults.standard.set(userId, forKey: "supabaseUserID")
        return user
    }

    func signOut() async throws {
        await setUserOffline()
        try await client.auth.signOut()
        UserDefaults.standard.removeObject(forKey: "supabaseUserID")
        print("✅ Signed out")
    }

    // MARK: - Change Password (via Supabase Auth)
    func changePassword(currentPassword: String, newPassword: String) async throws {
        guard let email = client.auth.currentUser?.email else {
            throw NSError(domain: "ChangePassword", code: -1,
                          userInfo: [NSLocalizedDescriptionKey: "No logged-in user found."])
        }

        // Verify current password first
        do {
            try await client.auth.signIn(email: email, password: currentPassword)
        } catch {
            throw NSError(domain: "ChangePassword", code: 401,
                          userInfo: [NSLocalizedDescriptionKey: "Current password is incorrect."])
        }

        // Current password correct — update to new password
        try await client.auth.update(user: .init(password: newPassword))
        print("✅ Password changed via Supabase Auth")
    }

    // MARK: - User CRUD

    func getUser(userId: String) async throws -> AppUser {
        let users: [AppUser] = try await client.from("users")
            .select()
            .eq("id", value: userId)
            .execute()
            .value
        guard let user = users.first else { throw LoginError.userNotFound }
        return user
    }

    func updateUser(userId: String, data: [String: AnyEncodable]) async throws -> AppUser {
        let users: [AppUser] = try await client.from("users")
            .update(data)
            .eq("id", value: userId)
            .select()
            .execute()
            .value
        guard let user = users.first else { throw LoginError.userNotFound }
        return user
    }

    func findUserByUsername(_ username: String) async throws -> AppUser? {
        let users: [AppUser] = try await client.from("users")
            .select()
            .ilike("username", value: username)
            .execute()
            .value
        return users.first
    }

    func getAllUsers() async throws -> [AppUser] {
        return try await client.from("users").select().execute().value
    }

    // MARK: - Online/Offline Status

    func setUserOnline() async {
        guard let id = currentUserId else { return }
        let updateData = UserStatusUpdate(is_online: true, last_seen: ISO8601DateFormatter().string(from: Date()))
        do {
            try await client.from("users").update(updateData).eq("id", value: id).execute()
            print("✅ User is now ONLINE")
        } catch {
            print("❌ Failed to set online: \(error)")
        }
    }

    func setUserOffline() async {
        guard let id = currentUserId else { return }
        let updateData = UserStatusUpdate(is_online: false, last_seen: ISO8601DateFormatter().string(from: Date()))
        do {
            try await client.from("users").update(updateData).eq("id", value: id).execute()
            print("✅ User is now OFFLINE")
        } catch {
            print("❌ Failed to set offline: \(error)")
        }
    }

    // MARK: - User Stats (RPC)

    func getUserStats(userId: String) async throws -> AppUserStats {
        return try await client.rpc("get_user_stats", params: ["p_user_id": userId])
            .execute()
            .value
    }

    // MARK: - Game Sessions

    func createSession(session: SessionInsert) async throws -> AppSession {
        let sessions: [AppSession] = try await client.from("game_sessions")
            .insert(session)
            .select()
            .execute()
            .value
        guard let created = sessions.first else { throw URLError(.badServerResponse) }
        return created
    }

    func completeSession(sessionId: String, caloriesBurned: Int) async throws {
        try await client.rpc("complete_session", params: [
            "p_session_id": sessionId,
            "p_calories": "\(caloriesBurned)"
        ]).execute()
        print("✅ Session \(sessionId) completed with \(caloriesBurned) cal")
    }

    func abandonSession(sessionId: String) async throws {
        try await client.rpc("abandon_session", params: ["p_session_id": sessionId]).execute()
    }

    /// Returns true if the user has completed at least one game session.
    func hasCompletedAnySession(userId: String) async throws -> Bool {
        let response = try await client
            .from("game_sessions")
            .select("id")
            .eq("user_id", value: userId)
            .limit(1)
            .execute(options: .init(count: .exact))
        return (response.count ?? 0) > 0
    }

    func getUserSessions(userId: String) async throws -> [AppSession] {
        return try await client.from("game_sessions")
            .select()
            .eq("user_id", value: userId)
            .order("created_at", ascending: false)
            .execute()
            .value
    }

    // MARK: - Badges

    func getAllBadges() async throws -> [AppBadge] {
        return try await client.from("badges").select().execute().value
    }

    func getUserBadges(userId: String) async throws -> [AppUserBadge] {
        return try await client.from("user_badges")
            .select("*, badge:badges(*)")
            .eq("user_id", value: userId)
            .execute()
            .value
    }

    // MARK: - Streak Calendar / Daily Progress

    func getStreakCalendar(userId: String, days: Int = 90) async throws -> [AppDailyProgress] {
        let cutoffDate = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date()
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let cutoffStr = formatter.string(from: cutoffDate)

        return try await client.from("daily_progress")
            .select()
            .eq("user_id", value: userId)
            .gte("date", value: cutoffStr)
            .order("date", ascending: true)
            .execute()
            .value
    }

    // MARK: - Live Streak Calculation

    func calculateLiveStreak(userId: String) async throws -> Int {
        let result: Int = try await client.rpc(
            "calculate_current_streak",
            params: ["p_user_id": userId]
        ).execute().value
        return result
    }

    // MARK: - Friendships

    func sendFriendRequest(requesterId: String, receiverId: String) async throws -> AppFriendship {
        let insert = FriendshipInsert(requester_id: requesterId, receiver_id: receiverId)
        let friendships: [AppFriendship] = try await client.from("friendships")
            .insert(insert)
            .select()
            .execute()
            .value
        guard let friendship = friendships.first else { throw URLError(.badServerResponse) }
        return friendship
    }

    func acceptFriendship(friendshipId: String) async throws {
        try await client.from("friendships")
            .update(["status": "accepted"])
            .eq("id", value: friendshipId)
            .execute()
    }

    func declineFriendship(friendshipId: String) async throws {
        try await client.from("friendships")
            .update(["status": "declined"])
            .eq("id", value: friendshipId)
            .execute()
    }

    func getUserFriends(userId: String) async throws -> [AppFriendship] {
        return try await client.from("friendships")
            .select()
            .eq("status", value: "accepted")
            .or("requester_id.eq.\(userId),receiver_id.eq.\(userId)")
            .execute()
            .value
    }

    // MARK: - Delete Account

    /// Returns true if the current user signed in via OAuth (Google/Apple), false for email+password
    var isOAuthUser: Bool {
        guard let user = client.auth.currentUser else { return false }
        if case let .object(meta) = user.appMetadata["provider"] {
            return false // shouldn't happen, but fallback
        }
        if case let .string(provider) = user.appMetadata["provider"] {
            return provider != "email"
        }
        return false
    }

    /// Delete account after verifying password (for email+password users)
    func deleteAccount(password: String) async throws {
        guard let user = client.auth.currentUser, let email = user.email else {
            throw NSError(domain: "DeleteAccount", code: -1,
                          userInfo: [NSLocalizedDescriptionKey: "No logged-in user found."])
        }

        // 1. Verify password by re-authenticating
        print("🔐 Verifying password before deletion...")
        do {
            try await client.auth.signIn(email: email, password: password)
        } catch {
            throw NSError(domain: "DeleteAccount", code: 401,
                          userInfo: [NSLocalizedDescriptionKey: "Incorrect password. Account was not deleted."])
        }

        // 2. Password correct — delete user data
        try await performAccountDeletion(userId: user.id)
    }

    /// Delete account after re-authenticating via OAuth (for Google/Apple users)
    func deleteAccountOAuth() async throws {
        guard let user = client.auth.currentUser else {
            throw NSError(domain: "DeleteAccount", code: -1,
                          userInfo: [NSLocalizedDescriptionKey: "No logged-in user found."])
        }

        // Re-authenticate via OAuth to verify identity
        print("🔐 Re-authenticating via OAuth before deletion...")
        try await client.auth.signInWithOAuth(
            provider: .google,
            redirectTo: URL(string: "exertia://auth-callback")!
        )

        // If we get here, user re-authenticated successfully
        try await performAccountDeletion(userId: user.id)
    }

    /// Shared deletion logic – deletes child rows first to avoid trigger conflicts
    private func performAccountDeletion(userId: UUID) async throws {
        print("🗑️ Deleting user data from database...")

        // 1. Delete child tables that reference 'users' or whose triggers
        //    could try to write back during CASCADE (e.g. trg_badge_recalc).
        let childTables = ["user_badges", "daily_progress", "game_sessions"]
        for table in childTables {
            print("   ↳ Deleting from \(table)...")
            try await client.from(table).delete().eq("user_id", value: userId).execute()
        }

        // Friendships uses requester_id / receiver_id instead of user_id
        print("   ↳ Deleting from friendships...")
        try await client.from("friendships").delete()
            .or("requester_id.eq.\(userId),receiver_id.eq.\(userId)")
            .execute()

        // 2. Now safe to delete the user row itself (remaining FKs will CASCADE cleanly)
        print("   ↳ Deleting from users...")
        try await client.from("users").delete().eq("id", value: userId).execute()

        try await client.auth.signOut()
        UserDefaults.standard.removeObject(forKey: "supabaseUserID")
        print("✅ Account deleted and logged out!")
    }

    // MARK: - Mail Server Support

    /// Fetches the current Cloudflare tunnel URL stored in the `mail_url` table.
    func fetchMailServerURL() async throws -> String {
        struct MailURLRecord: Decodable { let url: String }
        let records: [MailURLRecord] = try await client
            .from("mail_url")
            .select("url")
            .limit(1)
            .execute()
            .value
        guard let record = records.first else {
            throw NSError(domain: "SupabaseManager", code: -1,
                          userInfo: [NSLocalizedDescriptionKey: "Mail server URL not configured in database."])
        }
        return record.url
    }

    /// Returns true if the given email already has an account in `public.users`.
    func checkEmailExists(_ email: String) async throws -> Bool {
        let response = try await client
            .from("users")
            .select("id")
            .eq("email", value: email.lowercased().trimmingCharacters(in: .whitespacesAndNewlines))
            .limit(1)
            .execute(options: .init(count: .exact))
        return (response.count ?? 0) > 0
    }

    /// Returns true if the given username is already taken in `public.users`.
    func checkUsernameExists(_ username: String) async throws -> Bool {
        let response = try await client
            .from("users")
            .select("id")
            .ilike("username", value: username.trimmingCharacters(in: .whitespacesAndNewlines))
            .limit(1)
            .execute(options: .init(count: .exact))
        return (response.count ?? 0) > 0
    }

    // MARK: - Session Expired Handler
    func handleSessionExpired() {
        UserDefaults.standard.removeObject(forKey: "supabaseUserID")
        DispatchQueue.main.async {
            guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                  let window = scene.windows.first else { return }
            let sb = UIStoryboard(name: "Main", bundle: nil)
            if let loginVC = sb.instantiateViewController(withIdentifier: "LoginViewController") as? LoginViewController {
                loginVC.modalPresentationStyle = .fullScreen
                window.rootViewController = loginVC
                window.makeKeyAndVisible()
            }
        }
    }
}

// MARK: - AnyEncodable helper for dynamic dictionaries

struct AnyEncodable: Encodable {
    private let _encode: (Encoder) throws -> Void

    init<T: Encodable>(_ value: T) {
        _encode = { encoder in try value.encode(to: encoder) }
    }

    func encode(to encoder: Encoder) throws {
        try _encode(encoder)
    }
}
