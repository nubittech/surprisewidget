import SwiftUI

struct SettingsView: View {
    @Environment(AuthManager.self) private var auth
    @Environment(\.openURL) var openURL

    @State private var showDeleteAlert = false
    @State private var deleteLoading = false
    @State private var showDeleteError = false
    @State private var deleteErrorMsg = ""

    private let cBg         = Color(hex: "#FFF5FA")
    private let cPurple     = Color(hex: "#A774FF")
    private let cPurpleLight = Color(hex: "#C4A4F9")
    private let cPurpleBorder = Color(hex: "#2C1A4D")
    private let cYellow     = Color(hex: "#FADB5F")
    private let cWhite      = Color.white
    private let cTextMuted  = Color(hex: "#8A7A9A")
    private let cRed        = Color(hex: "#FB7185")

    // GitHub Pages URLs
    private let privacyURL = URL(string: "https://nubittech.github.io/surprisewidget/privacy")!
    private let termsURL   = URL(string: "https://nubittech.github.io/surprisewidget/terms")!
    private let supportURL = URL(string: "mailto:destek@surprisewidget.app")!

    var appVersion: String {
        let v = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let b = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(v) (\(b))"
    }

    var body: some View {
        ZStack {
            cBg.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 24) {

                    // ── Yasal ───────────────────────────────────────────
                    sectionHeader("LEGAL")

                    settingsCard {
                        settingsRow(icon: "hand.raised.fill", iconColor: cPurple, title: "Privacy Policy") {
                            openURL(privacyURL)
                        }
                        Divider().background(cPurpleLight)
                        settingsRow(icon: "doc.text.fill", iconColor: cPurple, title: "Terms of Use") {
                            openURL(termsURL)
                        }
                    }

                    // ── Destek ──────────────────────────────────────────
                    sectionHeader("SUPPORT")

                    settingsCard {
                        settingsRow(icon: "envelope.fill", iconColor: Color(hex: "#2DD4BF"), title: "Contact Us") {
                            openURL(supportURL)
                        }
                        Divider().background(cPurpleLight)
                        settingsRow(icon: "star.fill", iconColor: Color(hex: "#FADB5F"), title: "Rate the App") {
                            if let url = URL(string: "itms-apps://itunes.apple.com/app/idYOUR_APP_ID?action=write-review") {
                                openURL(url)
                            }
                        }
                    }

                    // ── Uygulama Hakkında ───────────────────────────────
                    sectionHeader("ABOUT")

                    VStack(spacing: 0) {
                        infoRow(icon: "🎁", title: "Surprise Widget", value: "")
                        Divider().background(cPurpleLight)
                        infoRow(icon: "📦", title: "Version", value: appVersion)
                        Divider().background(cPurpleLight)
                        infoRow(icon: "🏢", title: "Developer", value: "Nubit Tech")
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .overlay(RoundedRectangle(cornerRadius: 16).stroke(cPurpleBorder, lineWidth: 3))
                    .shadow(color: cPurpleBorder, radius: 0, x: 0, y: 4)

                    // ── Hesap ────────────────────────────────────────────
                    sectionHeader("ACCOUNT")

                    // Çıkış Yap
                    Button(action: { auth.logout() }) {
                        HStack {
                            Image(systemName: "arrow.right.square.fill")
                                .font(.system(size: 20))
                            Text("Log Out")
                                .font(.system(size: 18, weight: .black, design: .rounded))
                        }
                        .foregroundStyle(cPurpleBorder)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(cYellow)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .overlay(RoundedRectangle(cornerRadius: 16).stroke(cPurpleBorder, lineWidth: 3))
                        .shadow(color: cPurpleBorder, radius: 0, x: 0, y: 4)
                    }

                    // Hesabı Sil
                    Button(action: { showDeleteAlert = true }) {
                        HStack {
                            if deleteLoading {
                                ProgressView().tint(.white)
                            } else {
                                Image(systemName: "trash.fill")
                                    .font(.system(size: 20))
                                Text("Delete Account Permanently")
                                    .font(.system(size: 18, weight: .black, design: .rounded))
                            }
                        }
                        .foregroundStyle(cWhite)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(cRed)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .overlay(RoundedRectangle(cornerRadius: 16).stroke(cPurpleBorder, lineWidth: 3))
                        .shadow(color: cPurpleBorder, radius: 0, x: 0, y: 4)
                    }
                    .disabled(deleteLoading)

                    // Hesap silme açıklaması
                    Text("When you delete your account, all your cards, matches, and data will be permanently deleted. This action cannot be undone.")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(cTextMuted)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 8)
                }
                .padding(24)
                .padding(.bottom, 40)
            }
        }
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.large)
        .alert("Delete Account", isPresented: $showDeleteAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Yes, Delete Permanently", role: .destructive) {
                deleteAccount()
            }
        } message: {
            Text("All your cards, matches, and data will be permanently deleted. This action cannot be undone!")
        }
        .alert("Error", isPresented: $showDeleteError) {
            Button("OK") {}
        } message: { Text(deleteErrorMsg) }
    }

    // MARK: - Helpers

    func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 13, weight: .black, design: .rounded))
            .foregroundStyle(cTextMuted)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 8)
    }

    func settingsCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(spacing: 0) { content() }
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(cPurpleBorder, lineWidth: 3))
            .shadow(color: cPurpleBorder, radius: 0, x: 0, y: 4)
    }

    func settingsRow(icon: String, iconColor: Color, title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 18))
                    .foregroundStyle(iconColor)
                    .frame(width: 28)
                Text(title)
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .foregroundStyle(cPurpleBorder)
                Spacer()
                Image(systemName: "arrow.up.forward.square")
                    .font(.system(size: 14))
                    .foregroundStyle(cTextMuted)
            }
            .padding(16)
            .background(cWhite)
        }
    }

    func infoRow(icon: String, title: String, value: String) -> some View {
        HStack(spacing: 12) {
            Text(icon)
                .font(.system(size: 18))
                .frame(width: 28)
            Text(title)
                .font(.system(size: 17, weight: .bold, design: .rounded))
                .foregroundStyle(cPurpleBorder)
            Spacer()
            if !value.isEmpty {
                Text(value)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(cTextMuted)
            }
        }
        .padding(16)
        .background(cWhite)
    }

    // MARK: - Delete Account

    private func deleteAccount() {
        deleteLoading = true
        Task {
            do {
                struct Resp: Decodable { let message: String }
                let _: Resp = try await APIService.shared.delete("/auth/account")
                auth.logout()
            } catch {
                deleteErrorMsg = error.localizedDescription
                showDeleteError = true
            }
            deleteLoading = false
        }
    }
}
