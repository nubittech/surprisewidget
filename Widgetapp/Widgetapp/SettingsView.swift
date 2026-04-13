import SwiftUI

struct SettingsView: View {
    @Environment(AuthManager.self) private var auth
    @Environment(\.openURL) var openURL
    
    @State private var showDeleteAlert = false
    @State private var deleteLoading = false
    
    @AppStorage("appLanguage") private var appLanguage = "tr"

    private let cBg = Color(hex: "#FFF5FA")
    private let cPurple = Color(hex: "#A774FF")
    private let cPurpleLight = Color(hex: "#C4A4F9")
    private let cPurpleBorder = Color(hex: "#2C1A4D")
    private let cYellow = Color(hex: "#FADB5F")
    private let cWhite = Color.white
    private let cTextMuted = Color(hex: "#8A7A9A")
    private let cRed = Color(hex: "#FB7185")

    let languages = [
        ("tr", "Türkçe", "🇹🇷"),
        ("en", "English", "🇬🇧"),
        ("es", "Español", "🇪🇸")
    ]

    var body: some View {
        ZStack {
            cBg.ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 24) {
                    
                    // Dil Seçenekleri (Language)
                    VStack(alignment: .leading, spacing: 12) {
                        Text("DİL")
                            .font(.system(size: 16, weight: .black, design: .rounded))
                            .foregroundStyle(cTextMuted)
                            .padding(.horizontal, 8)
                        
                        VStack(spacing: 0) {
                            ForEach(languages, id: \.0) { lang in
                                Button(action: {
                                    appLanguage = lang.0
                                }) {
                                    HStack {
                                        Text(lang.2)
                                            .font(.system(size: 24))
                                        Text(lang.1)
                                            .font(.system(size: 18, weight: .bold, design: .rounded))
                                            .foregroundStyle(cPurpleBorder)
                                        Spacer()
                                        if appLanguage == lang.0 {
                                            Image(systemName: "checkmark.circle.fill")
                                                .font(.system(size: 22))
                                                .foregroundStyle(cPurple)
                                        }
                                    }
                                    .padding(16)
                                    .background(cWhite)
                                }
                                if lang.0 != languages.last?.0 {
                                    Divider()
                                        .background(cPurpleLight)
                                }
                            }
                        }
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .overlay(RoundedRectangle(cornerRadius: 16).stroke(cPurpleBorder, lineWidth: 3))
                        .shadow(color: cPurpleBorder, radius: 0, x: 0, y: 4)
                    }
                    
                    // Yasal Sorumluluk
                    VStack(alignment: .leading, spacing: 12) {
                        Text("YASAL")
                            .font(.system(size: 16, weight: .black, design: .rounded))
                            .foregroundStyle(cTextMuted)
                            .padding(.horizontal, 8)
                        
                        VStack(spacing: 0) {
                            Button(action: {
                                if let url = URL(string: "https://yourwebsite.com/privacy") {
                                    openURL(url)
                                }
                            }) {
                                HStack {
                                    Image(systemName: "hand.raised.fill")
                                        .font(.system(size: 20))
                                        .foregroundStyle(cPurple)
                                        .frame(width: 32)
                                    Text("Gizlilik Politikası")
                                        .font(.system(size: 18, weight: .bold, design: .rounded))
                                        .foregroundStyle(cPurpleBorder)
                                    Spacer()
                                    Image(systemName: "arrow.up.forward.square")
                                        .foregroundStyle(cTextMuted)
                                }
                                .padding(16)
                                .background(cWhite)
                            }
                            
                            Divider().background(cPurpleLight)
                            
                            Button(action: {
                                if let url = URL(string: "https://yourwebsite.com/terms") {
                                    openURL(url)
                                }
                            }) {
                                HStack {
                                    Image(systemName: "doc.text.fill")
                                        .font(.system(size: 20))
                                        .foregroundStyle(cPurple)
                                        .frame(width: 32)
                                    Text("Kullanım Koşulları")
                                        .font(.system(size: 18, weight: .bold, design: .rounded))
                                        .foregroundStyle(cPurpleBorder)
                                    Spacer()
                                    Image(systemName: "arrow.up.forward.square")
                                        .foregroundStyle(cTextMuted)
                                }
                                .padding(16)
                                .background(cWhite)
                            }
                        }
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .overlay(RoundedRectangle(cornerRadius: 16).stroke(cPurpleBorder, lineWidth: 3))
                        .shadow(color: cPurpleBorder, radius: 0, x: 0, y: 4)
                    }
                    
                    // Account
                    VStack(alignment: .leading, spacing: 12) {
                        Text("HESAP")
                            .font(.system(size: 16, weight: .black, design: .rounded))
                            .foregroundStyle(cTextMuted)
                            .padding(.horizontal, 8)
                        
                        Button(action: {
                            auth.logout()
                        }) {
                            HStack {
                                Spacer()
                                Text("Çıkış Yap")
                                    .font(.system(size: 18, weight: .black, design: .rounded))
                                    .foregroundStyle(cPurpleBorder)
                                Spacer()
                            }
                            .padding(.vertical, 16)
                            .background(cYellow)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                            .overlay(RoundedRectangle(cornerRadius: 16).stroke(cPurpleBorder, lineWidth: 3))
                            .shadow(color: cPurpleBorder, radius: 0, x: 0, y: 4)
                        }
                        
                        Button(action: {
                            showDeleteAlert = true
                        }) {
                            HStack {
                                Spacer()
                                Text("Hesabı Sil")
                                    .font(.system(size: 18, weight: .black, design: .rounded))
                                    .foregroundStyle(cWhite)
                                Spacer()
                            }
                            .padding(.vertical, 16)
                            .background(cRed)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                            .overlay(RoundedRectangle(cornerRadius: 16).stroke(cPurpleBorder, lineWidth: 3))
                            .shadow(color: cPurpleBorder, radius: 0, x: 0, y: 4)
                        }
                    }
                    .padding(.top, 8)
                }
                .padding(24)
                .padding(.bottom, 40)
            }
        }
        .navigationTitle("Ayarlar")
        .alert("Hesabı Sil", isPresented: $showDeleteAlert) {
            Button("İptal", role: .cancel) { }
            Button("Evet, Sil", role: .destructive) {
                deleteAccount()
            }
        } message: {
            Text("Hesabınızı silmek istediğinize emin misiniz? Bu işlem geri alınamaz!")
        }
    }
    
    private func deleteAccount() {
        deleteLoading = true
        Task {
            // Simulate delete API latency
            try? await Task.sleep(nanoseconds: 1_000_000_000)
            auth.logout()
        }
    }
}
