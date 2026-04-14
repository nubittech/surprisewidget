import SwiftUI

// MARK: - Neo-Brutalism Design Tokens
private enum NB {
    static let bg          = Color(hex: "#FFF5FF")
    static let primary     = Color(hex: "#9D6BFF")
    static let primaryBox  = Color(hex: "#CBB3FF")
    static let secondary   = Color(hex: "#00C985")
    static let secondaryBox = Color(hex: "#98FFD9")
    static let tertiary    = Color(hex: "#FFB800")
    static let tertiaryBox = Color(hex: "#FFD666")
    static let outline     = Color(hex: "#2D1E5F")
    static let muted       = Color(hex: "#6A5E8E")
    static let error       = Color(hex: "#FF3B6B")
    static let errorBox    = Color(hex: "#FF6B8B")
    static let surfaceLow  = Color(hex: "#FFF0FA")
    static let white       = Color.white

    static let borderW: CGFloat = 4
    static let borderSm: CGFloat = 3
    static let radius: CGFloat = 24
    static let radiusLg: CGFloat = 40
}

// MARK: - Neo-brutalism Modifier
struct NeoBrutalism: ViewModifier {
    var radius: CGFloat = NB.radius
    var borderWidth: CGFloat = NB.borderW
    var shadowOffset: CGFloat = 4

    func body(content: Content) -> some View {
        content
            .clipShape(RoundedRectangle(cornerRadius: radius))
            .overlay(
                RoundedRectangle(cornerRadius: radius)
                    .stroke(NB.outline, lineWidth: borderWidth)
            )
            .shadow(color: NB.outline, radius: 0, x: shadowOffset, y: shadowOffset)
    }
}

extension View {
    func neoBrutalism(radius: CGFloat = NB.radius, border: CGFloat = NB.borderW, shadow: CGFloat = 4) -> some View {
        modifier(NeoBrutalism(radius: radius, borderWidth: border, shadowOffset: shadow))
    }

    func neoBrutalismSm(radius: CGFloat = NB.radius) -> some View {
        modifier(NeoBrutalism(radius: radius, borderWidth: NB.borderSm, shadowOffset: 3))
    }
}

// MARK: - HomeView

struct HomeView: View {
    @Environment(AuthManager.self) private var auth
    @Environment(\.scenePhase) private var scenePhase

    @State private var pairStatus: PairStatus?
    @State private var friends: [Friend] = []
    @State private var limits: LimitsStatus?
    @State private var latestCard: Card?
    @State private var inviteInput = ""
    @State private var acceptLoading = false
    @State private var loading = true
    @State private var alertMsg = ""
    @State private var showAlert = false
    @State private var showInviteCode = false
    @State private var isFloating = false
    @State private var showWidgetSetup = false
    @State private var widgetSetupPartnerName = ""
    @State private var widgetSetupIsNewPairing = false
    @State private var showPartnerProfile = false
    @State private var partnerNickname = ""
    @State private var selectedRelationship = ""
    @State private var generatedInviteCode: String? = nil
    @State private var isGeneratingCode = false
    @State private var showPremium = false

    var partnerName: String? { friends.first?.displayName }

    var body: some View {
        NavigationStack {
            ZStack {
                NB.bg.ignoresSafeArea()

                if loading {
                    ProgressView().tint(NB.primary)
                } else {
                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 28) {
                            heroCard
                            circleSection
                            inviteSection
                            if let card = latestCard {
                                latestCardSection(card)
                            }
                            dailySection
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 10)
                        .padding(.bottom, 120)
                    }
                    .safeAreaInset(edge: .top) {
                        headerPill
                            .padding(.horizontal, 20)
                            .padding(.vertical, 10)
                            .background(NB.bg)
                    }
                    .refreshable { await loadData() }
                }
            }
            .navigationBarHidden(true)
            .alert("Bilgi", isPresented: $showAlert) {
                Button("Tamam") {}
            } message: { Text(alertMsg) }
            .sheet(isPresented: $showInviteCode) { inviteCodeSheet }
            .sheet(isPresented: $showPartnerProfile) { partnerProfileSheet }
            .fullScreenCover(isPresented: $showWidgetSetup) {
                WidgetSetupView(
                    partnerName: widgetSetupPartnerName,
                    isNewPairing: widgetSetupIsNewPairing
                )
                .environment(auth)
            }
        }
        .task { await loadData() }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                isFloating = true
            }
        }
        .onChange(of: scenePhase) { _, newPhase in
            // Refresh data & widgets whenever the app comes to foreground
            if newPhase == .active {
                Task { await loadData() }
            }
        }
    }

    // MARK: - Header Pill

    var headerPill: some View {
        HStack {
            // Avatar
            Circle()
                .fill(NB.primaryBox)
                .frame(width: 40, height: 40)
                .overlay(
                    Text(String((auth.user?.name.prefix(1) ?? "?").uppercased()))
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundStyle(NB.outline)
                )
                .overlay(Circle().stroke(NB.outline, lineWidth: NB.borderSm))

            Text("Surprise!")
                .font(.system(size: 20, weight: .heavy, design: .rounded))
                .foregroundStyle(NB.primary)
                .tracking(-0.5)

            Spacer()

            // Premium gift button
            Button(action: { showPremium = true }) {
                HStack(spacing: 8) {
                    Text("Unlock all features")
                        .font(.system(size: 12, weight: .heavy, design: .rounded))
                        .foregroundStyle(NB.outline)

                    Circle()
                        .fill(NB.tertiaryBox)
                        .frame(width: 36, height: 36)
                        .overlay(
                            Image(systemName: "gift.fill")
                                .font(.system(size: 16))
                                .foregroundStyle(NB.outline)
                        )
                        .overlay(Circle().stroke(NB.outline, lineWidth: NB.borderSm))
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(NB.white)
        .neoBrutalismSm(radius: 999)
        .sheet(isPresented: $showPremium) {
            PremiumView()
        }
    }

    // MARK: - Hero Card

    var heroCard: some View {
        ZStack(alignment: .bottomTrailing) {
            // Card body (clipped separately)
            VStack(alignment: .leading, spacing: 0) {
                // Badge
                HStack(spacing: 6) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 10, weight: .black))
                    Text("NEW MAGIC!")
                        .font(.system(size: 10, weight: .black, design: .rounded))
                        .tracking(1)
                }
                .foregroundStyle(NB.white)
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background(NB.secondary)
                .clipShape(Capsule())
                .overlay(Capsule().stroke(NB.outline, lineWidth: NB.borderSm))
                .padding(.bottom, 16)

                Text("Create a\nMoment of Joy!")
                    .font(.system(size: 34, weight: .heavy, design: .rounded))
                    .foregroundStyle(NB.white)
                    .lineSpacing(2)
                    .padding(.bottom, 10)

                Text("Make a custom card and\nsurprise your besties!")
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundStyle(NB.white.opacity(0.9))
                    .lineSpacing(4)
                    .padding(.bottom, 20)

                NavigationLink(destination: CreateCardWrapperView()) {
                    HStack(spacing: 8) {
                        Text("Let's Go!")
                            .font(.system(size: 20, weight: .heavy, design: .rounded))
                        Image(systemName: "paperplane.fill")
                            .font(.system(size: 16, weight: .bold))
                    }
                    .foregroundStyle(NB.primary)
                    .padding(.horizontal, 28)
                    .padding(.vertical, 14)
                    .background(NB.white)
                    .clipShape(Capsule())
                    .overlay(Capsule().stroke(NB.outline, lineWidth: NB.borderW))
                    .shadow(color: NB.outline, radius: 0, x: 4, y: 4)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(24)
            .padding(.trailing, 60)
            .background(NB.primary)
            .clipShape(RoundedRectangle(cornerRadius: NB.radiusLg))
            .overlay(
                RoundedRectangle(cornerRadius: NB.radiusLg)
                    .stroke(NB.outline, lineWidth: NB.borderW)
            )
            .shadow(color: NB.outline, radius: 0, x: 5, y: 5)

            // Floating mascot — top layer, bouncing animation
            Circle()
                .fill(NB.tertiaryBox)
                .frame(width: 90, height: 90)
                .overlay(MascotFace().frame(width: 52, height: 52))
                .overlay(Circle().stroke(NB.outline, lineWidth: NB.borderW))
                .shadow(color: NB.outline, radius: 0, x: 3, y: 3)
                .offset(x: 12, y: isFloating ? -2 : 12)
                .animation(.easeInOut(duration: 1.8).repeatForever(autoreverses: true), value: isFloating)
                .zIndex(1)
        }
        .rotationEffect(.degrees(-1))
    }

    // MARK: - Circle Section

    var circleSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Your Circle")
                        .font(.system(size: 28, weight: .heavy, design: .rounded))
                        .foregroundStyle(NB.outline)
                    Text("Your favorite people! ✨")
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(NB.muted)
                }
                Spacer()
                Text("\(friends.count) kişi")
                    .font(.system(size: 12, weight: .black, design: .rounded))
                    .foregroundStyle(NB.outline)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 10)
                    .background(NB.secondaryBox)
                    .neoBrutalismSm(radius: 999)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 18) {
                    // Add New
                    Button(action: { showInviteCode = true }) {
                        VStack(spacing: 12) {
                            Circle()
                                .fill(NB.primaryBox)
                                .frame(width: 56, height: 56)
                                .overlay(
                                    Image(systemName: "plus")
                                        .font(.system(size: 26, weight: .bold))
                                        .foregroundStyle(NB.outline)
                                )
                                .overlay(Circle().stroke(NB.outline, lineWidth: NB.borderSm))
                            Text("Add New")
                                .font(.system(size: 14, weight: .bold, design: .rounded))
                                .foregroundStyle(NB.outline)
                        }
                        .frame(width: 120, height: 160)
                        .background(NB.white)
                        .clipShape(RoundedRectangle(cornerRadius: NB.radius))
                        .overlay(RoundedRectangle(cornerRadius: NB.radius).stroke(NB.outline, lineWidth: NB.borderW))
                        .shadow(color: NB.outline, radius: 0, x: 4, y: 4)
                    }

                    // Friend cards
                    if friends.isEmpty {
                        VStack(spacing: 12) {
                            Circle()
                                .fill(Color(hex: "#E0E0E0"))
                                .frame(width: 56, height: 56)
                                .overlay(
                                    Image(systemName: "person.fill.questionmark")
                                        .font(.system(size: 24))
                                        .foregroundStyle(NB.muted)
                                )
                                .overlay(Circle().stroke(NB.outline, lineWidth: NB.borderSm))
                            Text("No friends yet")
                                .font(.system(size: 13, weight: .bold, design: .rounded))
                                .foregroundStyle(NB.muted)
                        }
                        .frame(width: 120, height: 160)
                        .background(NB.white)
                        .clipShape(RoundedRectangle(cornerRadius: NB.radius))
                        .overlay(RoundedRectangle(cornerRadius: NB.radius).stroke(NB.outline, lineWidth: NB.borderW))
                        .shadow(color: NB.outline, radius: 0, x: 4, y: 4)
                        .opacity(0.6)
                    } else {
                        ForEach(Array(friends.enumerated()), id: \.element.id) { idx, friend in
                            friendCard(friend: friend, tilt: idx % 2 == 0 ? 1.0 : -1.0)
                        }
                    }
                }
                .padding(.bottom, 16)
                .padding(.trailing, 16)
                .padding(.leading, 4)
                .padding(.top, 4)
            }
        }
    }

    func friendCard(friend: Friend, tilt: Double) -> some View {
        VStack(spacing: 0) {
            // Tapping the avatar / name opens CreateCardView with this friend preselected
            NavigationLink(destination: CreateCardWrapperView(preselectedFriend: friend)) {
                VStack(spacing: 8) {
                    ZStack(alignment: .bottomTrailing) {
                        Circle()
                            .fill(NB.secondaryBox)
                            .frame(width: 56, height: 56)
                            .overlay(
                                Text(String(friend.partner_name.prefix(1)).uppercased())
                                    .font(.system(size: 22, weight: .bold, design: .rounded))
                                    .foregroundStyle(NB.outline)
                            )
                            .overlay(Circle().stroke(NB.outline, lineWidth: NB.borderW))
                        Circle()
                            .fill(NB.secondary)
                            .frame(width: 18, height: 18)
                            .overlay(Circle().fill(NB.white).frame(width: 6, height: 6))
                            .overlay(Circle().stroke(NB.outline, lineWidth: NB.borderSm))
                            .offset(x: 3, y: 3)
                    }
                    Text(friend.displayName)
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(NB.outline)
                        .lineLimit(1)
                    if let rel = friend.relationship {
                        Text(rel)
                            .font(.system(size: 10, weight: .medium, design: .rounded))
                            .foregroundStyle(NB.muted)
                            .lineLimit(1)
                    }
                }
            }
            .buttonStyle(.plain)

            Spacer()

            // Widget Ekle button
            Button(action: {
                widgetSetupPartnerName = friend.displayName
                widgetSetupIsNewPairing = false
                showWidgetSetup = true
            }) {
                HStack(spacing: 4) {
                    Image(systemName: "plus.square.fill")
                        .font(.system(size: 10, weight: .bold))
                    Text("Widget")
                        .font(.system(size: 10, weight: .black, design: .rounded))
                }
                .foregroundStyle(NB.white)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(NB.primary)
                .clipShape(Capsule())
                .overlay(Capsule().stroke(NB.outline, lineWidth: 2))
            }
        }
        .padding(.vertical, 14)
        .frame(width: 120, height: 170)
        .background(NB.white)
        .clipShape(RoundedRectangle(cornerRadius: NB.radius))
        .overlay(RoundedRectangle(cornerRadius: NB.radius).stroke(NB.outline, lineWidth: NB.borderW))
        .shadow(color: NB.outline, radius: 0, x: 4, y: 4)
        .rotationEffect(.degrees(tilt))
    }

    // MARK: - Invite Section

    var inviteSection: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Secret Code?")
                        .font(.system(size: 26, weight: .heavy, design: .rounded))
                        .foregroundStyle(NB.outline)
                    Text("Unlock new friends! 🗝️")
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(NB.muted)
                }
                Spacer()
                Text("SPARKLE")
                    .font(.system(size: 10, weight: .black, design: .rounded))
                    .tracking(2)
                    .foregroundStyle(NB.outline)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(NB.tertiary)
                    .neoBrutalismSm(radius: 16)
                    .rotationEffect(.degrees(3))
            }

            // Input
            HStack(spacing: 12) {
                Image(systemName: "key.fill")
                    .font(.system(size: 20))
                    .foregroundStyle(NB.outline)
                TextField("Enter code here...", text: $inviteInput)
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.characters)
            }
            .padding(.horizontal, 16)
            .frame(height: 56)
            .background(NB.white)
            .neoBrutalism(radius: NB.radius, border: NB.borderW, shadow: 0)

            // Button
            Button(action: acceptInvite) {
                Group {
                    if acceptLoading {
                        ProgressView().tint(NB.outline)
                    } else {
                        Text("Paste Magic Code")
                            .font(.system(size: 18, weight: .heavy, design: .rounded))
                            .foregroundStyle(NB.outline)
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(NB.primaryBox)
                .neoBrutalism(radius: NB.radius)
            }
            .disabled(acceptLoading)
        }
        .padding(24)
        .background(NB.surfaceLow)
        .neoBrutalism(radius: NB.radius)
    }

    // MARK: - Latest Card

    func latestCardSection(_ card: Card) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Son Kart 💌")
                .font(.system(size: 28, weight: .heavy, design: .rounded))
                .foregroundStyle(NB.outline)

            CardPreviewView(card: card)
                .frame(height: 200)
                .neoBrutalism(radius: 20)
        }
    }

    // MARK: - Daily Fun

    var dailySection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Daily Fun! 🍭")
                .font(.system(size: 28, weight: .heavy, design: .rounded))
                .foregroundStyle(NB.outline)

            HStack(spacing: 16) {
                dailyCard(
                    bg: NB.secondary, icon: "lightbulb.fill", iconFg: NB.white,
                    title: "Coffee\nSurprise!",
                    subtitle: "Send a virtual latte to \(partnerName ?? "a friend")!",
                    tilt: 1
                )
                dailyCard(
                    bg: NB.tertiary, icon: "party.popper.fill", iconFg: NB.outline,
                    title: "Big\nMilestone!",
                    subtitle: "\(limits?.used ?? 0) cards sent this week! Wow!",
                    tilt: -1
                )
            }
        }
    }

    func dailyCard(bg: Color, icon: String, iconFg: Color, title: String, subtitle: String, tilt: Double) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Circle()
                .fill(bg)
                .frame(width: 48, height: 48)
                .overlay(
                    Image(systemName: icon)
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(iconFg)
                )
                .overlay(Circle().stroke(NB.outline, lineWidth: NB.borderSm))

            Text(title)
                .font(.system(size: 16, weight: .heavy, design: .rounded))
                .foregroundStyle(NB.outline)
                .lineSpacing(2)

            Text(subtitle)
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundStyle(NB.muted)
                .lineSpacing(3)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .frame(height: 180)
        .background(NB.white)
        .neoBrutalism(radius: NB.radius)
        .rotationEffect(.degrees(tilt))
    }

    // MARK: - Invite Code Sheet

    var inviteCodeSheet: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Text("Davet Kodu")
                    .font(.system(size: 28, weight: .heavy, design: .rounded))
                    .foregroundStyle(NB.outline)
                Text("Share this code with your friend:")
                    .font(.system(size: 16, weight: .medium, design: .rounded))
                    .foregroundStyle(NB.muted)

                if isGeneratingCode {
                    ProgressView().tint(NB.primary)
                } else if let code = generatedInviteCode ?? pairStatus?.invite_code {
                    Text(code)
                        .font(.system(size: 36, weight: .black, design: .monospaced))
                        .foregroundStyle(NB.primary)
                        .padding(24)
                        .frame(maxWidth: .infinity)
                        .background(NB.primaryBox.opacity(0.4))
                        .neoBrutalism(radius: 20)

                    Button(action: { UIPasteboard.general.string = code }) {
                        Label("Kopyala", systemImage: "doc.on.doc")
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .foregroundStyle(NB.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 52)
                            .background(NB.primary)
                            .neoBrutalism(radius: 999)
                    }
                } else {
                    ProgressView().tint(NB.primary)
                }
                Spacer()
            }
            .padding(24)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Kapat") { showInviteCode = false }
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                }
            }
        }
        .presentationDetents([.medium])
        .onAppear {
            generateInviteCode()
        }
    }

    // MARK: - Partner Profile Sheet

    private let relationships = ["My Love 💕", "My Bestie 🤝", "Bestiem ✨", "My Sibling 👫", "My Dear 💖"]

    var partnerProfileSheet: some View {
        NavigationStack {
            VStack(spacing: 24) {
                // Title
                VStack(spacing: 8) {
                    Text("🎉 Connected!")
                        .font(.system(size: 28, weight: .heavy, design: .rounded))
                        .foregroundStyle(NB.outline)
                    Text("\(widgetSetupPartnerName) için bir profil oluştur")
                        .font(.system(size: 15, weight: .medium, design: .rounded))
                        .foregroundStyle(NB.muted)
                }

                // Nickname input
                VStack(alignment: .leading, spacing: 8) {
                    Text("Name")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundStyle(NB.outline)
                    TextField("Bir takma ad ver...", text: $partnerNickname)
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .padding(16)
                        .background(NB.white)
                        .neoBrutalism(radius: NB.radius, border: NB.borderW, shadow: 0)
                }

                // Relationship selector
                VStack(alignment: .leading, spacing: 12) {
                    Text("Ben senin neyinim?")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundStyle(NB.outline)

                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                        ForEach(relationships, id: \.self) { rel in
                            Button(action: { selectedRelationship = rel }) {
                                Text(rel)
                                    .font(.system(size: 15, weight: .bold, design: .rounded))
                                    .foregroundStyle(selectedRelationship == rel ? NB.white : NB.outline)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 48)
                                    .background(selectedRelationship == rel ? NB.primary : NB.white)
                                    .clipShape(RoundedRectangle(cornerRadius: 16))
                                    .overlay(RoundedRectangle(cornerRadius: 16).stroke(NB.outline, lineWidth: NB.borderSm))
                            }
                        }
                    }
                }

                Spacer()

                // Continue button
                Button(action: completePartnerProfile) {
                    HStack(spacing: 8) {
                        Text("Widget Ekle")
                            .font(.system(size: 18, weight: .heavy, design: .rounded))
                        Image(systemName: "arrow.right")
                            .font(.system(size: 16, weight: .bold))
                    }
                    .foregroundStyle(NB.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(selectedRelationship.isEmpty ? NB.muted : NB.primary)
                    .clipShape(Capsule())
                    .overlay(Capsule().stroke(NB.outline, lineWidth: NB.borderW))
                    .shadow(color: NB.outline, radius: 0, x: 4, y: 4)
                }
                .disabled(selectedRelationship.isEmpty)
            }
            .padding(24)
            .background(NB.bg)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Atla") {
                        showPartnerProfile = false
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            widgetSetupIsNewPairing = true
                            showWidgetSetup = true
                        }
                    }
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                }
            }
        }
        .presentationDetents([.large])
    }

    // MARK: - Actions

    func loadData() async {
        do {
            async let statusTask: PairStatus = APIService.shared.get("/pairs/status")
            async let limitsTask: LimitsStatus = APIService.shared.get("/limits/status")
            let (status, lims) = try await (statusTask, limitsTask)
            pairStatus = status
            friends = status.friends ?? []
            limits = lims
            // Save friends to App Group for widget
            SharedDataManager.shared.saveFriends(friends)

            // Sync ALL friends' latest cards to App Group so widgets stay fresh.
            // Without this, a newly received card never reaches the widget until
            // WidgetSetupView is opened manually.
            if !friends.isEmpty {
                var newestOverall: Card? = nil
                var newestDate: String = ""
                for friend in friends {
                    struct LatestCardResp: Decodable { let card: Card? }
                    if let resp: LatestCardResp = try? await APIService.shared.get("/cards/latest?pair_id=\(friend.pair_id)"),
                       let card = resp.card {
                        SharedDataManager.shared.saveCard(card, forPairId: friend.pair_id)
                        if (card.created_at ?? "") > newestDate {
                            newestDate = card.created_at ?? ""
                            newestOverall = card
                        }
                    }
                }
                latestCard = newestOverall
                // Tell WidgetKit to refresh all placed widgets with new data
                SharedDataManager.shared.reloadWidgets()
            }
        } catch {}
        loading = false
    }

    func acceptInvite() {
        guard !inviteInput.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        acceptLoading = true
        Task {
            do {
                struct Body: Encodable { let invite_code: String }
                struct AcceptResponse: Decodable {
                    let message: String
                    let pair_id: String
                    let partner_name: String
                }
                let resp: AcceptResponse = try await APIService.shared.post(
                    "/pairs/accept-invite",
                    body: Body(invite_code: inviteInput.trimmingCharacters(in: .whitespaces))
                )
                inviteInput = ""
                generatedInviteCode = nil
                await auth.refreshUser()
                await loadData()
                // Save friends to widget right away
                SharedDataManager.shared.saveFriends(friends)
                SharedDataManager.shared.reloadWidgets()
                // Go straight to widget setup
                widgetSetupPartnerName = resp.partner_name.isEmpty ? "Friend" : resp.partner_name
                widgetSetupIsNewPairing = true
                showWidgetSetup = true
            } catch {
                alertMsg = error.localizedDescription
                showAlert = true
            }
            acceptLoading = false
        }
    }

    func generateInviteCode() {
        // Skip if we already have a code ready to show
        if generatedInviteCode != nil || pairStatus?.invite_code != nil { return }
        isGeneratingCode = true
        Task {
            do {
                let resp: InviteCodeResponse = try await APIService.shared.post(
                    "/pairs/create-invite",
                    body: EmptyBody()
                )
                generatedInviteCode = resp.invite_code
            } catch {
                alertMsg = error.localizedDescription
                showAlert = true
            }
            isGeneratingCode = false
        }
    }

    func completePartnerProfile() {
        showPartnerProfile = false
        // Delay to let sheet dismiss animation finish before presenting fullScreenCover
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            widgetSetupIsNewPairing = true
            showWidgetSetup = true
        }
    }
}

// MARK: - Card Preview

struct CardPreviewView: View {
    let card: Card
    private let baseSize: Double = 300.0

    var body: some View {
        GeometryReader { geo in
            // Matches the widget's aspect-fill rendering so the home preview
            // reflects exactly what the user will see on their widget.
            let fillScale = max(geo.size.width / baseSize,
                                geo.size.height / baseSize)
            let rendered = baseSize * fillScale
            let offsetX = (geo.size.width - rendered) / 2
            let offsetY = (geo.size.height - rendered) / 2

            ZStack(alignment: .topLeading) {
                // Background: PNG image or solid color
                if card.background.hasPrefix("img:") {
                    Image(String(card.background.dropFirst(4)))
                        .resizable()
                        .scaledToFill()
                        .frame(width: geo.size.width, height: geo.size.height)
                        .clipped()
                } else {
                    Color(hex: card.background)
                }
                ForEach(card.elements) { el in
                    if el.type == "text" {
                        Text(el.content)
                            .font(.system(size: (el.fontSize ?? 20) * fillScale,
                                          weight: .semibold, design: .rounded))
                            .foregroundStyle(Color(hex: el.color ?? "#1F2937"))
                            .rotationEffect(.degrees(el.rotation ?? 0))
                            .position(x: el.x * fillScale + offsetX,
                                      y: el.y * fillScale + offsetY)
                    } else if el.type == "image" {
                        Image(el.content)
                            .resizable()
                            .scaledToFit()
                            .frame(width: (el.size ?? 40) * fillScale,
                                   height: (el.size ?? 40) * fillScale)
                            .rotationEffect(.degrees(el.rotation ?? 0))
                            .position(x: el.x * fillScale + offsetX,
                                      y: el.y * fillScale + offsetY)
                    } else {
                        Text(el.content)
                            .font(.system(size: (el.size ?? 40) * fillScale))
                            .rotationEffect(.degrees(el.rotation ?? 0))
                            .position(x: el.x * fillScale + offsetX,
                                      y: el.y * fillScale + offsetY)
                    }
                }
                if let sender = card.sender_name, !sender.isEmpty {
                    VStack {
                        Spacer()
                        HStack {
                            Spacer()
                            Text("💌 \(sender)")
                                .font(.system(size: 11, weight: .medium, design: .rounded))
                                .foregroundStyle(.white.opacity(0.95))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(.black.opacity(0.25))
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                                .padding(8)
                        }
                    }
                }
            }
            .clipped()
        }
    }
}


// MARK: - Custom Mascot Face (neo-brutalism, all shapes)

struct MascotFace: View {
    var color: Color = Color(hex: "#2D1E5F")

    var body: some View {
        Canvas { ctx, size in
            let w = size.width
            let h = size.height

            // --- Left eye (filled circle) ---
            let leftEye = CGRect(x: w * 0.22, y: h * 0.22, width: w * 0.18, height: h * 0.18)
            ctx.fill(Path(ellipseIn: leftEye), with: .color(color))

            // Left eye shine (small white dot)
            let leftShine = CGRect(x: w * 0.27, y: h * 0.24, width: w * 0.07, height: w * 0.07)
            ctx.fill(Path(ellipseIn: leftShine), with: .color(.white))

            // --- Right eye (filled circle) ---
            let rightEye = CGRect(x: w * 0.60, y: h * 0.22, width: w * 0.18, height: h * 0.18)
            ctx.fill(Path(ellipseIn: rightEye), with: .color(color))

            // Right eye shine
            let rightShine = CGRect(x: w * 0.65, y: h * 0.24, width: w * 0.07, height: w * 0.07)
            ctx.fill(Path(ellipseIn: rightShine), with: .color(.white))

            // --- Smile (thick arc) ---
            var smile = Path()
            smile.addArc(
                center: CGPoint(x: w * 0.5, y: h * 0.52),
                radius: w * 0.30,
                startAngle: .degrees(20),
                endAngle: .degrees(160),
                clockwise: false
            )
            ctx.stroke(
                smile,
                with: .color(color),
                style: StrokeStyle(lineWidth: w * 0.11, lineCap: .round)
            )

            // --- Rosy cheeks (soft circles, slightly transparent) ---
            let leftCheek = CGRect(x: w * 0.06, y: h * 0.50, width: w * 0.20, height: h * 0.14)
            ctx.fill(Path(ellipseIn: leftCheek), with: .color(color.opacity(0.18)))

            let rightCheek = CGRect(x: w * 0.74, y: h * 0.50, width: w * 0.20, height: h * 0.14)
            ctx.fill(Path(ellipseIn: rightCheek), with: .color(color.opacity(0.18)))
        }
    }
}

// Wrapper to show CreateCardView from navigation
struct CreateCardWrapperView: View {
    var preselectedFriend: Friend? = nil
    var body: some View {
        CreateCardView(preselectedFriend: preselectedFriend)
            .navigationBarHidden(true)
    }
}
