import SwiftUI

struct SyncBannerMessage: Equatable {
    let text: String
    let isError: Bool
    let duration: TimeInterval

    static func success() -> SyncBannerMessage {
        SyncBannerMessage(text: "Synced", isError: false, duration: 2)
    }

    static func failure(_ detail: String) -> SyncBannerMessage {
        SyncBannerMessage(text: "Sync failed: \(detail)", isError: true, duration: 4)
    }
}

struct SyncBannerView: View {
    let message: SyncBannerMessage

    var body: some View {
        Label(message.text, systemImage: message.isError ? "xmark.icloud.fill" : "checkmark.icloud.fill")
            .font(.subheadline.weight(.medium))
            .foregroundStyle(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(
                Capsule().fill(message.isError ? Color.red : Color.seasonGreen)
            )
            .shadow(color: .black.opacity(0.15), radius: 4, y: 2)
            .padding(.top, 8)
    }
}

#Preview("Success") {
    SyncBannerView(message: .success())
}

#Preview("Failure") {
    SyncBannerView(message: .failure("Network unavailable"))
}
