import Foundation

/// Maps thrown errors to user-friendly strings, keeping internal details out of the UI.
func friendlyMessage(for error: Error) -> String {
    let desc = error.localizedDescription.lowercased()
    if desc.contains("cancel") || desc.contains("dismiss") {
        return "Operation was cancelled."
    }
    if desc.contains("network") || desc.contains("internet") ||
       desc.contains("offline") || desc.contains("connection") {
        return "No internet connection. Please check your network and try again."
    }
    if desc.contains("invalid") || desc.contains("unauthorized") ||
       desc.contains("credential") || desc.contains("token") {
        return "Sign-in failed. Please try again."
    }
    return "Something went wrong. Please try again."
}
