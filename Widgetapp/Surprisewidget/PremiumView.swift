import SwiftUI
import StoreKit

struct PremiumView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AuthManager.self) private var auth
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

    var hasPremium: Bool {
        PaywallPresenter.shared.hasPremium
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

                    if hasPremium {
                        Button(action: {
                            PaywallPresenter.shared.cancelPendingAction()
                            NotificationCenter.default.post(name: .premiumDidCompleteNavigateHome, object: nil)
                            dismiss()
                        }) {
                            HStack(spacing: 10) {
                                Image(systemName: "checkmark.seal.fill")
                                    .font(.system(size: 18, weight: .bold))
                                Text("Premium Active · Go Home")
                                    .font(.system(size: 18, weight: .heavy, design: .rounded))
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.78)
                            }
                            .foregroundStyle(navy)
                            .frame(maxWidth: .infinity)
                            .frame(height: 60)
                            .background(greenBox)
                            .clipShape(Capsule())
                            .overlay(Capsule().stroke(navy, lineWidth: 4))
                            .shadow(color: navy, radius: 0, x: 4, y: 4)
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 20)
                    } else {
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
                                        .lineLimit(1)
                                        .minimumScaleFactor(0.72)
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
                    }

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
                .frame(maxWidth: UIDevice.current.userInterfaceIdiom == .pad ? 560 : .infinity)
                .frame(maxWidth: .infinity)
            }

            if showSuccess {
                PremiumPurchaseSuccessView {
                    PaywallPresenter.shared.cancelPendingAction()
                    NotificationCenter.default.post(name: .premiumDidCompleteNavigateHome, object: nil)
                    dismiss()
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
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

private struct PremiumPurchaseSuccessView: View {
    let onContinue: () -> Void

    private let navy = Color(hex: "#2D1E5F")
    private let purple = Color(hex: "#9D6BFF")
    private let purpleBox = Color(hex: "#CBB3FF")
    private let yellowBox = Color(hex: "#FFD666")
    private let greenBox = Color(hex: "#98FFD9")
    private let white = Color.white

    var body: some View {
        ZStack {
            Color(hex: "#FFF5FF").ignoresSafeArea()

            VStack(spacing: 28) {
                Spacer(minLength: 24)

                ZStack {
                    Circle()
                        .fill(greenBox)
                        .frame(width: 122, height: 122)
                        .overlay(Circle().stroke(navy, lineWidth: 5))
                        .shadow(color: navy, radius: 0, x: 6, y: 6)

                    Image(systemName: "checkmark")
                        .font(.system(size: 54, weight: .black, design: .rounded))
                        .foregroundStyle(navy)
                }

                VStack(spacing: 10) {
                    Text("Premium Activated")
                        .font(.system(size: 31, weight: .heavy, design: .rounded))
                        .foregroundStyle(navy)
                        .multilineTextAlignment(.center)

                    Text("All stickers, backgrounds, friends, and future features are now unlocked.")
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .foregroundStyle(navy.opacity(0.68))
                        .multilineTextAlignment(.center)
                        .lineSpacing(3)
                        .padding(.horizontal, 12)
                }

                VStack(spacing: 12) {
                    successRow(icon: "infinity", text: "Unlimited cards")
                    successRow(icon: "paintbrush.pointed.fill", text: "Premium design tools")
                    successRow(icon: "person.3.fill", text: "More friends and sharing")
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 18)
                .background(white)
                .clipShape(RoundedRectangle(cornerRadius: 18))
                .overlay(RoundedRectangle(cornerRadius: 18).stroke(navy, lineWidth: 3))
                .shadow(color: navy, radius: 0, x: 4, y: 4)
                .padding(.horizontal, 22)

                Spacer(minLength: 16)

                Button(action: onContinue) {
                    HStack(spacing: 10) {
                        Image(systemName: "house.fill")
                            .font(.system(size: 18, weight: .bold))
                        Text("Go to Home")
                            .font(.system(size: 18, weight: .heavy, design: .rounded))
                    }
                    .foregroundStyle(navy)
                    .frame(maxWidth: .infinity)
                    .frame(height: 60)
                    .background(yellowBox)
                    .clipShape(Capsule())
                    .overlay(Capsule().stroke(navy, lineWidth: 4))
                    .shadow(color: navy, radius: 0, x: 4, y: 4)
                }
                .padding(.horizontal, 22)
                .padding(.bottom, 28)
            }
            .frame(maxWidth: UIDevice.current.userInterfaceIdiom == .pad ? 560 : .infinity)
        }
    }

    private func successRow(icon: String, text: String) -> some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 10)
                .fill(purpleBox)
                .frame(width: 38, height: 38)
                .overlay(
                    Image(systemName: icon)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(navy)
                )
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(navy, lineWidth: 2))

            Text(text)
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundStyle(navy)

            Spacer()

            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 21, weight: .bold))
                .foregroundStyle(purple)
        }
    }
}

#Preview {
    PremiumView()
}
