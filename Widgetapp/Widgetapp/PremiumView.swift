import SwiftUI
import StoreKit

struct PremiumView: View {
    @Environment(\.dismiss) private var dismiss
    private let store = StoreKitManager.shared
    @State private var showSuccess = false
    @State private var showError = false

    private let navy      = Color(hex: "#2D1E5F")
    private let purple    = Color(hex: "#9D6BFF")
    private let purpleBox = Color(hex: "#CBB3FF")
    private let yellow    = Color(hex: "#FFB800")
    private let yellowBox = Color(hex: "#FFD666")
    private let green     = Color(hex: "#00C985")
    private let greenBox  = Color(hex: "#98FFD9")
    private let bg        = Color(hex: "#FFF5FF")
    private let white     = Color.white

    private let features: [(String, String)] = [
        ("infinity",                    "Send unlimited cards"),
        ("person.3.fill",               "Add unlimited friends"),
        ("paintbrush.pointed.fill",     "All backgrounds & stickers"),
        ("bell.badge.fill",             "Instant notifications"),
        ("star.fill",                   "Priority support"),
        ("lock.open.fill",              "All future features"),
    ]

    // Formatted price from StoreKit, fallback to $5.99
    var priceString: String {
        store.priceString
    }

    var body: some View {
        ZStack {
            bg.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {

                    // Close button
                    HStack {
                        Spacer()
                        Button(action: { dismiss() }) {
                            Image(systemName: "xmark")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundStyle(navy.opacity(0.5))
                                .padding(10)
                                .background(white)
                                .clipShape(Circle())
                                .overlay(Circle().stroke(navy.opacity(0.2), lineWidth: 2))
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 16)

                    // Hero icon
                    Circle()
                        .fill(yellowBox)
                        .frame(width: 100, height: 100)
                        .overlay(
                            Image(systemName: "gift.fill")
                                .font(.system(size: 44, weight: .bold))
                                .foregroundStyle(navy)
                        )
                        .overlay(Circle().stroke(navy, lineWidth: 4))
                        .padding(.top, 8)

                    // Title
                    VStack(spacing: 8) {
                        Text("Go Premium")
                            .font(.system(size: 32, weight: .heavy, design: .rounded))
                            .foregroundStyle(navy)
                        Text("Unlimited surprises await!")
                            .font(.system(size: 16, weight: .semibold, design: .rounded))
                            .foregroundStyle(purple)
                    }
                    .padding(.top, 20)
                    .padding(.bottom, 28)

                    // Feature list
                    VStack(spacing: 14) {
                        ForEach(features, id: \.0) { icon, text in
                            HStack(spacing: 14) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 10)
                                        .fill(purpleBox)
                                        .frame(width: 36, height: 36)
                                    Image(systemName: icon)
                                        .font(.system(size: 16, weight: .bold))
                                        .foregroundStyle(navy)
                                }
                                .overlay(RoundedRectangle(cornerRadius: 10).stroke(navy, lineWidth: 2))

                                Text(text)
                                    .font(.system(size: 15, weight: .bold, design: .rounded))
                                    .foregroundStyle(navy)
                                Spacer()
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 20))
                                    .foregroundStyle(green)
                            }
                            .padding(.horizontal, 18)
                            .padding(.vertical, 12)
                            .background(white)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                            .overlay(RoundedRectangle(cornerRadius: 16).stroke(navy, lineWidth: 2.5))
                            .shadow(color: navy, radius: 0, x: 3, y: 3)
                        }
                    }
                    .padding(.horizontal, 20)

                    // Price card
                    VStack(spacing: 6) {
                        HStack(spacing: 8) {
                            Text("LIFETIME")
                                .font(.system(size: 11, weight: .black, design: .rounded))
                                .tracking(2)
                                .foregroundStyle(navy)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(yellowBox)
                                .clipShape(Capsule())
                                .overlay(Capsule().stroke(navy, lineWidth: 2))
                            Text("One-time payment")
                                .font(.system(size: 13, weight: .semibold, design: .rounded))
                                .foregroundStyle(navy.opacity(0.6))
                        }

                        // Price — dynamic from StoreKit
                        Text(priceString)
                            .font(.system(size: 52, weight: .heavy, design: .rounded))
                            .foregroundStyle(navy)

                        Text("No subscription · No hidden fees")
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .foregroundStyle(navy.opacity(0.5))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 24)
                    .padding(.horizontal, 20)
                    .background(white)
                    .clipShape(RoundedRectangle(cornerRadius: 24))
                    .overlay(RoundedRectangle(cornerRadius: 24).stroke(navy, lineWidth: 3))
                    .shadow(color: navy, radius: 0, x: 5, y: 5)
                    .padding(.horizontal, 20)
                    .padding(.top, 24)

                    // CTA — Purchase button
                    Button(action: {
                        Task {
                            await store.purchase()
                            if store.isPurchased { withAnimation { showSuccess = true } }
                            if store.errorMessage != nil { showError = true }
                        }
                    }) {
                        HStack(spacing: 10) {
                            if store.isLoading {
                                ProgressView().tint(navy)
                            } else {
                                Image(systemName: "lock.open.fill")
                                    .font(.system(size: 18, weight: .bold))
                                Text("Unlock All Features · \(priceString)")
                                    .font(.system(size: 18, weight: .heavy, design: .rounded))
                            }
                        }
                        .foregroundStyle(navy)
                        .frame(maxWidth: .infinity)
                        .frame(height: 60)
                        .background(yellowBox)
                        .clipShape(Capsule())
                        .overlay(Capsule().stroke(navy, lineWidth: 4))
                        .shadow(color: navy, radius: 0, x: 4, y: 4)
                    }
                    .disabled(store.isLoading)
                    .padding(.horizontal, 20)
                    .padding(.top, 20)

                    // Restore Purchases — required by Apple
                    Button(action: {
                        Task {
                            await store.restorePurchases()
                            if store.isPurchased { withAnimation { showSuccess = true } }
                            if store.errorMessage != nil { showError = true }
                        }
                    }) {
                        Text("Restore Purchases")
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                            .foregroundStyle(purple)
                            .underline()
                    }
                    .disabled(store.isLoading)
                    .padding(.top, 12)

                    Text("Payment is processed through the App Store.")
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundStyle(navy.opacity(0.4))
                        .multilineTextAlignment(.center)
                        .padding(.top, 8)
                        .padding(.bottom, 40)
                }
            }

            // Success overlay
            if showSuccess {
                ZStack {
                    Color.black.opacity(0.5).ignoresSafeArea()
                    VStack(spacing: 20) {
                        Text("🎉")
                            .font(.system(size: 72))
                        Text("Welcome to Premium!")
                            .font(.system(size: 26, weight: .heavy, design: .rounded))
                            .foregroundStyle(navy)
                        Text("Now you can send unlimited surprises!")
                            .font(.system(size: 16, weight: .semibold, design: .rounded))
                            .foregroundStyle(navy.opacity(0.7))
                            .multilineTextAlignment(.center)
                        Button(action: { dismiss() }) {
                            Text("Let's Go! 🚀")
                                .font(.system(size: 18, weight: .heavy, design: .rounded))
                                .foregroundStyle(navy)
                                .frame(maxWidth: .infinity)
                                .frame(height: 56)
                                .background(greenBox)
                                .clipShape(Capsule())
                                .overlay(Capsule().stroke(navy, lineWidth: 4))
                                .shadow(color: navy, radius: 0, x: 4, y: 4)
                        }
                        .padding(.horizontal, 32)
                    }
                    .padding(32)
                    .background(white)
                    .clipShape(RoundedRectangle(cornerRadius: 32))
                    .overlay(RoundedRectangle(cornerRadius: 32).stroke(navy, lineWidth: 4))
                    .shadow(color: navy, radius: 0, x: 6, y: 6)
                    .padding(.horizontal, 24)
                }
                .transition(.opacity.combined(with: .scale))
            }
        }
        .animation(.spring(response: 0.4), value: showSuccess)
        .alert("Purchase Failed", isPresented: $showError) {
            Button("OK") { store.clearError() }
        } message: {
            Text(store.errorMessage ?? "An error occurred.")
        }
        .task { await store.fetchOfferings() }
    }
}

#Preview {
    PremiumView()
}
