//
//  MailServerManager.swift
//  Exertia
//
//  Every public method fetches the current Cloudflare tunnel URL fresh from the
//  `mail_url` Supabase table before making its HTTP call.
//  This means the URL is NEVER stored in the app — if you update the tunnel URL
//  in the DB, the very next request will automatically use the new one.
//

import Foundation

enum MailServerError: LocalizedError {
    case noURLConfigured
    case serverError(String)
    case networkError(Error)

    var errorDescription: String? {
        switch self {
        case .noURLConfigured:     return "Mail server URL is not configured in the database."
        case .serverError(let m):  return m
        case .networkError(let e): return e.localizedDescription
        }
    }
}

struct MailServerManager {

    // MARK: - Private response models
    private struct SendResponse:   Decodable { let success: Bool; let message: String? }
    private struct VerifyResponse: Decodable { let valid: Bool;   let message: String? }
    private struct ResetResponse:  Decodable { let success: Bool; let message: String? }

    // MARK: - Public API (no baseURL param — always fetched fresh)

    /// Sends a 6-digit OTP email. `purpose` = "register" | "reset"
    static func sendOTP(to email: String, purpose: String) async throws {
        let baseURL = try await freshBaseURL()
        let resp: SendResponse = try await post(
            path: "/send-otp",
            body: ["email": email, "purpose": purpose],
            baseURL: baseURL
        )
        guard resp.success else {
            throw MailServerError.serverError(resp.message ?? "Failed to send OTP.")
        }
    }

    /// Verifies the OTP the user typed. Throws with a descriptive message on failure.
    @discardableResult
    static func verifyOTP(email: String, otp: String) async throws -> Bool {
        let baseURL = try await freshBaseURL()
        let resp: VerifyResponse = try await post(
            path: "/verify-otp",
            body: ["email": email, "otp": otp],
            baseURL: baseURL
        )
        guard resp.valid else {
            throw MailServerError.serverError(resp.message ?? "Incorrect code.")
        }
        return true
    }

    /// Resets the password. Requires /verify-otp to have passed first (reset flow only).
    static func resetPassword(email: String, newPassword: String) async throws {
        let baseURL = try await freshBaseURL()
        let resp: ResetResponse = try await post(
            path: "/reset-password",
            body: ["email": email, "newPassword": newPassword],
            baseURL: baseURL
        )
        guard resp.success else {
            throw MailServerError.serverError(resp.message ?? "Failed to reset password.")
        }
    }

    // MARK: - Private helpers

    /// Always hits Supabase to get the latest tunnel URL — never cached.
    private static func freshBaseURL() async throws -> String {
        do {
            return try await SupabaseManager.shared.fetchMailServerURL()
        } catch {
            throw MailServerError.noURLConfigured
        }
    }

    private static func post<T: Decodable>(path: String,
                                            body: [String: String],
                                            baseURL: String) async throws -> T {
        let trimmed = baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: trimmed + path) else {
            throw MailServerError.noURLConfigured
        }
        var request        = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 15

        do {
            request.httpBody  = try JSONSerialization.data(withJSONObject: body)
            let (data, _)     = try await URLSession.shared.data(for: request)
            return try JSONDecoder().decode(T.self, from: data)
        } catch let e as MailServerError {
            throw e
        } catch {
            throw MailServerError.networkError(error)
        }
    }
}
