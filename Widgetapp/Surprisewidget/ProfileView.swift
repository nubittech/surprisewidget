import SwiftUI

struct ProfileView: View {
    @Environment(AuthManager.self) private var auth

    init() {
        let attrs: [NSAttributedString.Key: Any] = [
            .foregroundColor: UIColor(red: 44/255, green: 26/255, blue: 77/255, alpha: 1)
        ]
        UINavigationBar.appearance().largeTitleTextAttributes = attrs
        UINavigationBar.appearance().titleTextAttributes = attrs
    }

    @State private var showSettings = false
    @State private var friends: [Friend] = []
    @State private var loadingFriends = true
    @State private var unpairTarget: Friend? = nil
    @State private var showUnpairAlert = false
    @State private var errorMsg = ""
    @State private var showError = false
    @State private var inviteCode: String?
    @State private var showInviteSheet = false

    private let cBg = Color(hex: "#FFF5FA")
    private let cPurple = Color(hex: "#A774FF")
    private let cPurpleLight = Color(hex: "#C4A4F9")
    private let cPurpleBorder = Color(hex: "#2C1A4D")
    private let cYellow = Color(hex: "#FADB5F")
    private let cGreen = Color(hex: "#00D170")
    private let cWhite = Color.white
    private let cTextMain = Color(hex: "#2C1A4D")
    private let cTextMuted = Color(hex: "#8A7A9A")

    var body: some View {
        NavigationStack {
            ZStack {
                cBg.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        // Page title
                        Text("Profile")
                            .font(.system(size: 34, weight: .black, design: .rounded))
                            .foregroundStyle(cPurpleBorder)

                        // Profile Card
                        VStack(spacing: 16) {
                            Circle()
                                .fill(cPurpleLight)
                                .frame(width: 80, height: 80)
                                .overlay(
                                    Text(String((auth.user?.name.prefix(1) ?? "?").uppercased()))
                                        .font(.system(size: 32, weight: .black, design: .rounded))
                                        .foregroundStyle(cPurpleBorder)
                                )
                                .overlay(Circle().stroke(cPurpleBorder, lineWidth: 3))

                            VStack(spacing: 4) {
                                Text(auth.user?.name ?? "User")
                                    .font(.system(size: 24, weight: .black, design: .rounded))
                                    .foregroundStyle(cPurpleBorder)
                                    
                                Text(auth.user?.email ?? "")
                                    .font(.system(size: 15, weight: .bold))
                                    .foregroundStyle(cTextMuted)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(24)
                        .background(cWhite)
                        .clipShape(RoundedRectangle(cornerRadius: 24))
                        .overlay(RoundedRectangle(cornerRadius: 24).stroke(cPurpleBorder, lineWidth: 4))
                        .shadow(color: cPurpleBorder, radius: 0, x: 0, y: 6)

                        // Friends Section
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Text("Friends")
                                    .font(.system(size: 20, weight: .black, design: .rounded))
                                    .foregroundStyle(cPurpleBorder)
                                Spacer()
                                Button(action: {
                                    // Free tier is capped at 2 friends total (self-pair
                                    // from onboarding counts). Once full, tapping "Add"
                                    // goes straight to the paywall instead of the invite
                                    // sheet — the invite sheet would just produce a code
                                    // the backend now refuses to hand out.
                                    if !StoreKitManager.shared.isPurchased && friends.count >= 2 {
                                        PaywallPresenter.shared.gate { showInviteSheet = true }
                                    } else {
                                        showInviteSheet = true
                                    }
                                }) {
                                    Label("Add", systemImage: "plus")
                                        .font(.system(size: 14, weight: .black))
                                        .foregroundStyle(cPurpleBorder)
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 8)
                                        .background(cYellow)
                                        .clipShape(Capsule())
                                        .overlay(Capsule().stroke(cPurpleBorder, lineWidth: 2))
                                        .shadow(color: cPurpleBorder, radius: 0, x: 2, y: 2)
                                }
                            }

                            if loadingFriends {
                                ProgressView().tint(cPurpleBorder).frame(maxWidth: .infinity)
                            } else if friends.isEmpty {
                                Text("No friends yet. Tap + Add to get started!")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundStyle(cTextMuted)
                                    .frame(maxWidth: .infinity, alignment: .center)
                                    .padding()
                            } else {
                                ForEach(friends) { friend in
                                    HStack(spacing: 16) {
                                        Circle()
                                            .fill(cPurple)
                                            .frame(width: 48, height: 48)
                                            .overlay(
                                                Text(String(friend.displayName.prefix(1)).uppercased())
                                                    .font(.system(size: 20, weight: .black, design: .rounded))
                                                    .foregroundStyle(cWhite)
                                            )
                                            .overlay(Circle().stroke(cPurpleBorder, lineWidth: 2))
                                            
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(friend.displayName)
                                                .font(.system(size: 16, weight: .black, design: .rounded))
                                                .foregroundStyle(cPurpleBorder)
                                            if let rel = friend.relationship {
                                                Text(rel)
                                                    .font(.system(size: 13, weight: .bold))
                                                    .foregroundStyle(cTextMuted)
                                            } else {
                                                Text("Connected ❤️")
                                                    .font(.system(size: 13, weight: .bold))
                                                    .foregroundStyle(cTextMuted)
                                            }
                                        }
                                        Spacer()
                                        Button(action: {
                                            unpairTarget = friend
                                            showUnpairAlert = true
                                        }) {
                                            Image(systemName: "heart.slash.fill")
                                                .foregroundStyle(Color(hex: "#FB7185"))
                                                .font(.system(size: 16))
                                                .padding(8)
                                                .background(cWhite)
                                                .clipShape(Circle())
                                                .overlay(Circle().stroke(cPurpleBorder, lineWidth: 2))
                                        }
                                    }
                                    .padding(16)
                                    .background(cWhite)
                                    .clipShape(RoundedRectangle(cornerRadius: 16))
                                    .overlay(RoundedRectangle(cornerRadius: 16).stroke(cPurpleBorder, lineWidth: 3))
                                    .shadow(color: cPurpleBorder, radius: 0, x: 0, y: 4)
                                }
                            }
                        }

                        // Actions
                        Button(action: { auth.logout() }) {
                            Label("Log Out", systemImage: "arrow.right.square.fill")
                                .font(.system(size: 18, weight: .black, design: .rounded))
                                .foregroundStyle(cPurpleBorder)
                                .frame(maxWidth: .infinity)
                                .frame(height: 56)
                                .background(cWhite)
                                .clipShape(Capsule())
                                .overlay(Capsule().stroke(cPurpleBorder, lineWidth: 3))
                                .shadow(color: cPurpleBorder, radius: 0, x: 0, y: 4)
                        }
                    }
                    .padding(20)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(cBg, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: { showSettings = true }) {
                        Image(systemName: "gearshape.fill")
                            .font(.system(size: 20))
                            .foregroundStyle(cPurpleBorder)
                            .frame(width: 36, height: 36)
                            .background(Color.clear)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .tint(.clear)
                }
            }
            .navigationDestination(isPresented: $showSettings) {
                SettingsView()
                    .environment(auth)
            }
            .alert("Remove Friend", isPresented: $showUnpairAlert) {
                Button("Cancel", role: .cancel) {}
                Button("Remove", role: .destructive) {
                    if let f = unpairTarget { unpair(friend: f) }
                }
            } message: {
                Text("\(unpairTarget?.displayName ?? "This person") are you sure you want to remove this friend?")
            }
            .alert("Error", isPresented: $showError) {
                Button("OK") {}
            } message: { Text(errorMsg) }
            .sheet(isPresented: $showInviteSheet) { inviteCodeSheet }
            .task { await loadFriends() }
        }
    }

    var inviteCodeSheet: some View {
        NavigationStack {
            ZStack {
                cBg.ignoresSafeArea()
                VStack(spacing: 24) {
                    Text("Invite Code")
                        .font(.system(size: 28, weight: .black, design: .rounded))
                        .foregroundStyle(cPurpleBorder)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    Text("Share this code with your friend!")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(cTextMuted)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    if let code = inviteCode {
                        Text(code)
                            .font(.system(size: 36, weight: .black, design: .monospaced))
                            .foregroundStyle(cPurpleBorder)
                            .padding(24)
                            .frame(maxWidth: .infinity)
                            .background(cPurpleLight)
                            .clipShape(RoundedRectangle(cornerRadius: 20))
                            .overlay(RoundedRectangle(cornerRadius: 20).stroke(cPurpleBorder, lineWidth: 3))
                            .shadow(color: cPurpleBorder, radius: 0, x: 4, y: 6)

                        Button(action: { UIPasteboard.general.string = code }) {
                            Label("Copy", systemImage: "doc.on.doc.fill")
                                .font(.system(size: 18, weight: .black))
                                .foregroundStyle(cWhite)
                                .frame(maxWidth: .infinity)
                                .frame(height: 56)
                                .background(cPurple)
                                .clipShape(Capsule())
                                .overlay(Capsule().stroke(cPurpleBorder, lineWidth: 3))
                                .shadow(color: cPurpleBorder, radius: 0, x: 0, y: 4)
                        }
                    } else {
                        ProgressView().tint(cPurpleBorder).scaleEffect(1.5)
                    }
                    Spacer()
                }
                .padding(24)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button { showInviteSheet = false } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 16, weight: .black))
                                .foregroundStyle(cPurpleBorder)
                                .frame(width: 36, height: 36)
                                .background(cWhite)
                                .clipShape(Circle())
                                .overlay(Circle().stroke(cPurpleBorder, lineWidth: 2))
                                .shadow(color: cPurpleBorder, radius: 0, x: 1, y: 2)
                        }
                    }
                }
            }
        }
        .presentationDetents([.medium])
        .onAppear { fetchInviteCode() }
    }

    func loadFriends() async {
        loadingFriends = true
        if let status: PairStatus = try? await APIService.shared.get("/pairs/status") {
            friends = status.friends ?? []
            // Keep the App Group in sync — this also purges orphaned
            // card_* keys for any pair that was removed.
            SharedDataManager.shared.saveFriends(friends)
        }
        loadingFriends = false
    }

    func fetchInviteCode() {
        Task {
            let status: PairStatus? = try? await APIService.shared.get("/pairs/status")
            if let code = status?.invite_code {
                inviteCode = code
            } else {
                // Generate new one
                let resp: InviteCodeResponse? = try? await APIService.shared.post("/pairs/create-invite", body: EmptyBody())
                inviteCode = resp?.invite_code
            }
        }
    }

    func unpair(friend: Friend) {
        Task {
            do {
                struct Empty: Decodable {}
                let _: Empty = try await APIService.shared.post(
                    "/pairs/unpair",
                    body: UnpairRequest(pair_id: friend.pair_id)
                )
                // Nuke the cached card for this pair right away so the
                // widget can't show a ghost card between now and its next
                // timeline refresh.
                SharedDataManager.shared.clearCard(forPairId: friend.pair_id)
                // Also drop any locally-cached nickname/relationship so a
                // future re-pair with the same person starts from a clean slate.
                LocalNicknameCache.clear(forPairId: friend.pair_id)
                await auth.refreshUser()
                await loadFriends()
                // saveFriends inside loadFriends will also run purgeOrphanCards,
                // but we reload widgets explicitly so the removal is visible now.
                SharedDataManager.shared.reloadWidgets()
            } catch {
                errorMsg = error.localizedDescription
                showError = true
            }
        }
    }
}
