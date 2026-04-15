import SwiftUI

// MARK: - Draggable Element View

struct DraggableElementView: View {
    @Binding var element: CanvasElement
    let scale: CGFloat
    let isSelected: Bool
    let onSelect: () -> Void

    @GestureState private var dragTranslation: CGSize = .zero
    @GestureState private var liveScale: CGFloat = 1.0
    @GestureState private var liveRotation: Angle = .zero

    var body: some View {
        let savedRotation = Angle(degrees: element.rotation ?? 0)

        Group {
            if element.type == "text" {
                if let fname = element.fontFamily, fname != "System" {
                    Text(element.content)
                        .font(.custom(fname, size: CGFloat(element.fontSize ?? 20) * scale))
                        .fontWeight(.bold)
                        .foregroundStyle(Color(hex: element.color ?? "#1F2937"))
                } else {
                    Text(element.content)
                        .font(.system(size: CGFloat(element.fontSize ?? 20) * scale,
                                      weight: .bold, design: .rounded))
                        .foregroundStyle(Color(hex: element.color ?? "#1F2937"))
                }
            } else if element.type == "image" {
                Image(element.content)
                    .resizable()
                    .scaledToFit()
                    .frame(width: CGFloat(element.size ?? 40) * scale,
                           height: CGFloat(element.size ?? 40) * scale)
            } else {
                Text(element.content)
                    .font(.system(size: CGFloat(element.size ?? 40) * scale))
            }
        }
        .padding(4)
        .overlay(
            Group {
                if isSelected {
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(Color.orange, style: StrokeStyle(lineWidth: 2, dash: [4]))
                }
            }
        )
        .scaleEffect(liveScale)
        .rotationEffect(savedRotation + liveRotation)
        .position(
            x: CGFloat(element.x) * scale + dragTranslation.width,
            y: CGFloat(element.y) * scale + dragTranslation.height
        )
        .gesture(
            SimultaneousGesture(
                DragGesture(minimumDistance: 3)
                    .updating($dragTranslation) { value, state, _ in
                        state = value.translation
                        onSelect()
                    }
                    .onEnded { value in
                        element.x += Double(value.translation.width / scale)
                        element.y += Double(value.translation.height / scale)
                    },
                SimultaneousGesture(
                    MagnificationGesture()
                        .updating($liveScale) { value, state, _ in
                            state = value
                            onSelect()
                        }
                        .onEnded { value in
                            let factor = Double(value)
                            if element.type == "text" {
                                let current = element.fontSize ?? 20
                                element.fontSize = max(8, min(140, current * factor))
                            } else {
                                let current = element.size ?? 40
                                element.size = max(16, min(800, current * factor))
                            }
                        },
                    RotationGesture()
                        .updating($liveRotation) { value, state, _ in
                            state = value
                            onSelect()
                        }
                        .onEnded { value in
                            element.rotation = (element.rotation ?? 0) + value.degrees
                        }
                )
            )
        )
        .onTapGesture { onSelect() }
    }
}

// MARK: - Create Card View

struct CreateCardView: View {
    @Environment(AuthManager.self) private var auth
    @Environment(\.dismiss) private var dismiss

    // Optional friend preselected from HomeView (e.g. tapping a friend's avatar)
    let preselectedFriend: Friend?

    init(preselectedFriend: Friend? = nil) {
        self.preselectedFriend = preselectedFriend
    }

    @State private var background = BACKGROUNDS[0]
    @State private var elements: [CanvasElement] = []
    @State private var selectedId: String? = nil
    @State private var activeTab: ToolTab = .none
    @State private var showTextSheet = false
    @State private var textInput = ""
    @State private var textColor = TEXT_COLORS[0]
    @State private var textFont = "System"
    @State private var sending = false
    @State private var alertMsg = ""
    @State private var showAlert = false
    @State private var alertIsSuccess = false
    @State private var selectedStickerCategory: StickerCategory? = STICKER_CATEGORIES.first

    // Friend picker state
    @State private var friends: [Friend] = []
    @State private var selectedPairId: String? = nil
    @State private var showFriendPicker = false

    // Widget safe-zone overlay toggle
    @State private var showSafeZones: Bool = false

    enum ToolTab { case none, bg, sticker, text }

    var selectedFriend: Friend? {
        friends.first { $0.pair_id == selectedPairId }
    }

    private let cBg = Color(hex: "#FFF5FA")
    private let cPurple = Color(hex: "#A774FF")
    private let cPurpleLight = Color(hex: "#C4A4F9")
    private let cPurpleBorder = Color(hex: "#2C1A4D")
    private let cYellow = Color(hex: "#FADB5F")
    private let cGreen = Color(hex: "#00D170")
    private let cWhite = Color.white
    private let cTextMain = Color(hex: "#2C1A4D")
    private let cTextMuted = Color(hex: "#8A7A9A")
    
    private let FONTS = ["System", "MarkerFelt-Wide", "Noteworthy-Bold", "ChalkboardSE-Bold", "SnellRoundhand-Black"]

    var body: some View {
        GeometryReader { geo in
            let canvasSize = geo.size.width - 48
            let scale = canvasSize / 300.0

            ZStack {
                VStack(spacing: 0) {
                    topBar

                if auth.user?.pair_ids?.isEmpty != false {
                    warningBanner
                } else if friends.count > 1 {
                    recipientChip
                        .padding(.horizontal, 16)
                        .padding(.top, 4)
                }

                // Canvas
                ZStack {
                    // Background: PNG image or solid color
                    if bgIsImage(background) {
                        Image(bgAssetName(background))
                            .resizable()
                            .scaledToFill()
                            .frame(width: canvasSize, height: canvasSize)
                            .clipped()
                            .allowsHitTesting(false)
                    } else {
                        Color(hex: background)
                    }
                    ForEach($elements) { $el in
                        DraggableElementView(
                            element: $el,
                            scale: scale,
                            isSelected: selectedId == el.id,
                            onSelect: { selectedId = el.id }
                        )
                    }
                    if showSafeZones {
                        safeZoneOverlay(scale: scale)
                    }
                }
                .frame(width: canvasSize, height: canvasSize)
                .clipShape(RoundedRectangle(cornerRadius: 32))
                .overlay(
                    RoundedRectangle(cornerRadius: 32)
                        .stroke(cPurpleBorder, lineWidth: 4)
                )
                .overlay(alignment: .topTrailing) {
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            showSafeZones.toggle()
                        }
                    }) {
                        Image(systemName: showSafeZones ? "rectangle.dashed.and.paperclip" : "rectangle.dashed")
                            .font(.system(size: 14, weight: .black))
                            .foregroundStyle(showSafeZones ? cWhite : cPurpleBorder)
                            .frame(width: 36, height: 36)
                            .background(showSafeZones ? cPurple : cWhite)
                            .clipShape(Circle())
                            .overlay(Circle().stroke(cPurpleBorder, lineWidth: 2))
                            .shadow(color: cPurpleBorder, radius: 0, x: 1, y: 2)
                    }
                    .padding(12)
                }
                .background(
                    RoundedRectangle(cornerRadius: 32)
                        .fill(cPurpleBorder)
                        .offset(x: 6, y: 8)
                )
                .onTapGesture { selectedId = nil }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .frame(maxHeight: .infinity)

                // Toolbar
                toolbar(canvasSize: canvasSize)
            }
            .background(cBg)
            
            if showAlert {
                Color.black.opacity(0.35)
                    .ignoresSafeArea()
                    .onTapGesture {
                        withAnimation(.spring(response: 0.3)) {
                            if alertIsSuccess { dismiss() }
                            showAlert = false
                        }
                    }

                if alertIsSuccess {
                    // --- Custom success toast ---
                    VStack(spacing: 20) {
                        // Custom drawn celebration icon
                        ZStack {
                            Circle()
                                .fill(Color(hex: "#E8FFE8"))
                                .frame(width: 90, height: 90)
                            CelebrationIcon()
                                .frame(width: 90, height: 90)
                        }
                        .overlay(Circle().stroke(cPurpleBorder, lineWidth: 3))

                        VStack(spacing: 6) {
                            Text("Sent! 🎉")
                                .font(.system(size: 26, weight: .heavy, design: .rounded))
                                .foregroundStyle(cPurpleBorder)
                            Text("Your card is on its way!")
                                .font(.system(size: 15, weight: .semibold, design: .rounded))
                                .foregroundStyle(cTextMuted)
                        }

                        Button(action: {
                            withAnimation(.spring(response: 0.3)) {
                                showAlert = false
                                dismiss()
                            }
                        }) {
                            Text("Harika")
                                .font(.system(size: 17, weight: .black, design: .rounded))
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .frame(height: 52)
                                .background(cGreen)
                                .clipShape(Capsule())
                                .overlay(Capsule().stroke(cPurpleBorder, lineWidth: 3))
                                .shadow(color: cPurpleBorder, radius: 0, x: 3, y: 4)
                        }
                    }
                    .padding(28)
                    .frame(maxWidth: 300)
                    .background(cWhite)
                    .clipShape(RoundedRectangle(cornerRadius: 32))
                    .overlay(RoundedRectangle(cornerRadius: 32).stroke(cPurpleBorder, lineWidth: 4))
                    .shadow(color: cPurpleBorder, radius: 0, x: 5, y: 6)
                    .transition(.scale(scale: 0.8).combined(with: .opacity))
                } else {
                    // --- Error / info toast ---
                    VStack(spacing: 18) {
                        ZStack {
                            Circle()
                                .fill(Color(hex: "#FFF0E0"))
                                .frame(width: 64, height: 64)
                            WarningIcon()
                                .frame(width: 64, height: 64)
                        }
                        .overlay(Circle().stroke(cPurpleBorder, lineWidth: 3))

                        Text(alertMsg)
                            .font(.system(size: 15, weight: .bold, design: .rounded))
                            .foregroundStyle(cPurpleBorder)
                            .multilineTextAlignment(.center)

                        Button(action: {
                            withAnimation(.spring(response: 0.3)) { showAlert = false }
                        }) {
                            Text("OK")
                                .font(.system(size: 16, weight: .black, design: .rounded))
                                .foregroundStyle(cPurpleBorder)
                                .frame(maxWidth: .infinity)
                                .frame(height: 48)
                                .background(Color(hex: "#FFD666"))
                                .clipShape(Capsule())
                                .overlay(Capsule().stroke(cPurpleBorder, lineWidth: 3))
                                .shadow(color: cPurpleBorder, radius: 0, x: 2, y: 3)
                        }
                    }
                    .padding(24)
                    .frame(maxWidth: 280)
                    .background(cWhite)
                    .clipShape(RoundedRectangle(cornerRadius: 28))
                    .overlay(RoundedRectangle(cornerRadius: 28).stroke(cPurpleBorder, lineWidth: 3))
                    .shadow(color: cPurpleBorder, radius: 0, x: 4, y: 5)
                    .transition(.scale(scale: 0.8).combined(with: .opacity))
                }
            }
            } // End of ZStack
        }
        .ignoresSafeArea(edges: .bottom)
        .navigationBarHidden(true)
        .sheet(isPresented: $showTextSheet) {
            textSheet
        }
        .sheet(isPresented: $showFriendPicker) {
            friendPickerSheet
        }
        .task { await loadFriends() }
    }

    // MARK: - Load Friends

    func loadFriends() async {
        do {
            let status: PairStatus = try await APIService.shared.get("/pairs/status")
            let list = status.friends ?? []
            await MainActor.run {
                self.friends = list
                // Preselect honored first, else a single friend, else nothing
                if let pre = preselectedFriend, list.contains(where: { $0.pair_id == pre.pair_id }) {
                    self.selectedPairId = pre.pair_id
                } else if list.count == 1 {
                    self.selectedPairId = list.first?.pair_id
                } else if self.selectedPairId == nil, let first = list.first {
                    // No explicit preselect, multiple friends — leave nil so user must pick.
                    // (Fall through — user taps the chip.)
                    _ = first
                }
            }
        } catch {}
    }

    var topBar: some View {
        HStack {
            Button(action: { dismiss() }) {
                Image(systemName: "arrow.left")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(cTextMain)
                    .frame(width: 44, height: 44)
                    .background(cWhite)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(cPurpleBorder, lineWidth: 3))
            }
            Spacer()
            Text("Create Card")
                .font(.system(size: 20, weight: .black, design: .rounded))
                .foregroundStyle(cPurpleBorder)
            Spacer()
            Button(action: sendCard) {
                Group {
                    if sending {
                        ProgressView().tint(cWhite).scaleEffect(0.8)
                    } else {
                        Text("Send")
                            .font(.system(size: 16, weight: .black))
                    }
                }
                .foregroundStyle(cWhite)
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .background(cGreen)
                .clipShape(Capsule())
                .overlay(Capsule().stroke(cPurpleBorder, lineWidth: 3))
                .shadow(color: cPurpleBorder, radius: 0, x: 2, y: 4)
            }
            .disabled(sending)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }

    // MARK: - Safe Zone Overlay
    //
    // Widgets come in three aspect ratios but the design canvas is a fixed
    // 300×300 square. The widget renderer uses aspect-fill, so the design
    // fully covers each widget and overflow is clipped. The dashed guides
    // below show — in design coordinates — the region that will actually be
    // visible on each widget size, so users can keep important content
    // inside the right frame.
    //
    // Derivation (for a 300×300 canvas rendered aspect-fill into an
    // iPhone widget of approximate point dimensions):
    //   • small  (170×170)  → fill scale 0.567 → full 300×300 visible
    //   • medium (364×170)  → fill scale 1.213 → y ∈ [80, 220]  (140 tall)
    //   • large  (364×382)  → fill scale 1.273 → x ∈ [7, 293]   (286 wide)
    @ViewBuilder
    func safeZoneOverlay(scale: CGFloat) -> some View {
        // Medium widget (most constrained — wide & short) — red
        let mediumW: CGFloat = 300
        let mediumH: CGFloat = 140
        let mediumCenter = CGPoint(x: 150, y: 150)

        // Large widget (slight side crop) — orange
        let largeW: CGFloat = 286
        let largeH: CGFloat = 300
        let largeCenter = CGPoint(x: 150, y: 150)

        ZStack {
            // Large (drawn first, underneath)
            Rectangle()
                .stroke(Color(hex: "#FFA23A"),
                        style: StrokeStyle(lineWidth: 2, dash: [4, 4]))
                .frame(width: largeW * scale, height: largeH * scale)
                .position(x: largeCenter.x * scale, y: largeCenter.y * scale)
                .overlay(alignment: .topLeading) {
                    Text("Large")
                        .font(.system(size: 10, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color(hex: "#FFA23A"))
                        .clipShape(Capsule())
                        .position(x: (largeCenter.x - largeW / 2) * scale + 24,
                                  y: (largeCenter.y - largeH / 2) * scale + 12)
                }

            // Medium (on top — most important)
            Rectangle()
                .stroke(Color(hex: "#FF4D6D"),
                        style: StrokeStyle(lineWidth: 2.5, dash: [6, 4]))
                .frame(width: mediumW * scale, height: mediumH * scale)
                .position(x: mediumCenter.x * scale, y: mediumCenter.y * scale)
                .overlay(alignment: .topLeading) {
                    Text("Medium")
                        .font(.system(size: 10, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color(hex: "#FF4D6D"))
                        .clipShape(Capsule())
                        .position(x: (mediumCenter.x - mediumW / 2) * scale + 28,
                                  y: (mediumCenter.y - mediumH / 2) * scale + 12)
                }
        }
        .allowsHitTesting(false)
    }

    var warningBanner: some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(cPurpleBorder)
            Text("You need to connect with someone first")
                .font(.system(size: 13, weight: .heavy))
                .foregroundStyle(cPurpleBorder)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(cYellow)
        .clipShape(Capsule())
        .overlay(Capsule().stroke(cPurpleBorder, lineWidth: 3))
        .shadow(color: cPurpleBorder, radius: 0, x: 3, y: 4)
        .padding(.horizontal, 16)
    }

    // MARK: - Recipient Chip (only shown when user has 2+ friends)

    var recipientChip: some View {
        Button(action: { showFriendPicker = true }) {
            HStack(spacing: 10) {
                Text("Kime:")
                    .font(.system(size: 13, weight: .heavy, design: .rounded))
                    .foregroundStyle(cTextMuted)

                if let f = selectedFriend {
                    Circle()
                        .fill(cPurpleLight)
                        .frame(width: 26, height: 26)
                        .overlay(
                            Text(String(f.partner_name.prefix(1)).uppercased())
                                .font(.system(size: 13, weight: .black, design: .rounded))
                                .foregroundStyle(cPurpleBorder)
                        )
                        .overlay(Circle().stroke(cPurpleBorder, lineWidth: 2))
                    Text(f.displayName)
                        .font(.system(size: 15, weight: .black, design: .rounded))
                        .foregroundStyle(cTextMain)
                        .lineLimit(1)
                } else {
                    Text("Select Friend")
                        .font(.system(size: 15, weight: .heavy, design: .rounded))
                        .foregroundStyle(cPurple)
                }

                Spacer()
                Image(systemName: "chevron.down")
                    .font(.system(size: 12, weight: .black))
                    .foregroundStyle(cTextMuted)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(cWhite)
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(cPurpleBorder, lineWidth: 3)
            )
            .shadow(color: cPurpleBorder, radius: 0, x: 3, y: 4)
        }
    }

    // MARK: - Friend Picker Sheet

    var friendPickerSheet: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 12) {
                    ForEach(friends) { friend in
                        Button(action: {
                            selectedPairId = friend.pair_id
                            showFriendPicker = false
                        }) {
                            HStack(spacing: 14) {
                                Circle()
                                    .fill(cPurpleLight)
                                    .frame(width: 48, height: 48)
                                    .overlay(
                                        Text(String(friend.partner_name.prefix(1)).uppercased())
                                            .font(.system(size: 20, weight: .black, design: .rounded))
                                            .foregroundStyle(cPurpleBorder)
                                    )
                                    .overlay(Circle().stroke(cPurpleBorder, lineWidth: 3))

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(friend.displayName)
                                        .font(.system(size: 17, weight: .black, design: .rounded))
                                        .foregroundStyle(cTextMain)
                                    if let rel = friend.relationship {
                                        Text(rel)
                                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                                            .foregroundStyle(cTextMuted)
                                    }
                                }
                                Spacer()
                                if selectedPairId == friend.pair_id {
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.system(size: 24))
                                        .foregroundStyle(cGreen)
                                }
                            }
                            .padding(16)
                            .background(cWhite)
                            .clipShape(RoundedRectangle(cornerRadius: 20))
                            .overlay(
                                RoundedRectangle(cornerRadius: 20)
                                    .stroke(selectedPairId == friend.pair_id ? cGreen : cPurpleBorder,
                                            lineWidth: selectedPairId == friend.pair_id ? 4 : 3)
                            )
                            .shadow(color: cPurpleBorder, radius: 0, x: 3, y: 4)
                        }
                    }
                }
                .padding(20)
            }
            .background(cBg)
            .navigationTitle("Who Gets the Card?")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Close") { showFriendPicker = false }
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    func toolbar(canvasSize: CGFloat) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 4) {
                toolTabBtn(icon: "paintpalette", label: "Arkaplan", tab: .bg)
                toolTabBtn(icon: "face.smiling", label: "Sticker", tab: .sticker)
                toolTabBtn(icon: "textformat", label: "Text", tab: .text, action: {
                    activeTab = .text
                    showTextSheet = true
                })
                Button(action: deleteSelected) {
                    VStack(spacing: 2) {
                        Image(systemName: "trash")
                            .font(.system(size: 22))
                            .foregroundStyle(selectedId != nil ? Color(hex: "#FB7185") : cTextMuted)
                        Text("Delete")
                            .font(.system(size: 11, weight: .heavy))
                            .foregroundStyle(selectedId != nil ? Color(hex: "#FB7185") : cTextMuted)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                }
                .disabled(selectedId == nil)
            }
            .padding(.horizontal, 16)

            if activeTab == .bg {
                VStack(spacing: 0) {
                    // ── Row 1: Solid colors ──────────────────────────────
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            ForEach(BACKGROUNDS, id: \.self) { bg in
                                Circle()
                                    .fill(Color(hex: bg))
                                    .frame(width: 44, height: 44)
                                    .overlay(
                                        Circle().stroke(
                                            background == bg ? cPurpleBorder : .clear,
                                            lineWidth: 3
                                        )
                                    )
                                    .overlay(
                                        bg == "#FFFFFF" ? Circle().stroke(cPurpleLight, lineWidth: 3) : nil
                                    )
                                    .onTapGesture { background = bg }
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                    }
                    .frame(height: 64)

                    Divider().padding(.horizontal, 16)

                    // ── Row 2: PNG image backgrounds ─────────────────────
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            ForEach(BG_IMAGES, id: \.self) { bg in
                                Image(bgAssetName(bg))
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 52, height: 52)
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(
                                                background == bg ? cPurpleBorder : Color.clear,
                                                lineWidth: 3
                                            )
                                    )
                                    .onTapGesture { background = bg }
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                    }
                    .frame(height: 72)
                }
                .transition(.move(edge: .leading).combined(with: .opacity))
            }

            if activeTab == .sticker {
                VStack(spacing: 12) {
                    // Kategori Seçici
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(STICKER_CATEGORIES) { category in
                                let isSelected = selectedStickerCategory?.id == category.id
                                Button(action: {
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                        selectedStickerCategory = category
                                    }
                                }) {
                                    HStack(spacing: 8) {
                                        Image(systemName: category.icon)
                                            .font(.system(size: 18, weight: .bold))
                                            .foregroundStyle(isSelected ? cPurpleBorder : cTextMuted)
                                        
                                        Text(category.name)
                                            .font(.system(size: 14, weight: .black, design: .rounded))
                                            .foregroundStyle(isSelected ? cPurpleBorder : cTextMuted)
                                    }
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 8)
                                    .background(isSelected ? cWhite : Color.clear)
                                    .clipShape(Capsule())
                                    .overlay(
                                        Capsule().stroke(isSelected ? cPurpleBorder : Color.clear, lineWidth: isSelected ? 3 : 0)
                                    )
                                    .shadow(color: isSelected ? cPurpleBorder : .clear, radius: 0, x: 2, y: 3)
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 4) // extra padding for shadow
                    }
                    
                    // Sticker Listesi - Geniş Alan
                    if let category = selectedStickerCategory {
                        ScrollView(.vertical, showsIndicators: false) {
                            LazyVGrid(columns: [GridItem(.adaptive(minimum: 50))], spacing: 16) {
                                ForEach(category.items, id: \.self) { item in
                                    Button(action: { addStickerItem(item) }) {
                                        switch item {
                                        case .emoji(let e):
                                            Text(e)
                                                .font(.system(size: 36))
                                                .frame(width: 50, height: 50)
                                        case .image(let name):
                                            Image(name)
                                                .resizable()
                                                .scaledToFit()
                                                .frame(width: 50, height: 50)
                                        }
                                    }
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.bottom, 16)
                        }
                        .frame(maxHeight: 250)
                    }
                }
                .padding(.top, 10)
                .transition(.move(edge: .trailing).combined(with: .opacity))
            }
        }
        .padding(.top, 12)
        .padding(.bottom, 20)
        .background(cWhite)
        .clipShape(UnevenRoundedRectangle(topLeadingRadius: 32, topTrailingRadius: 32))
        .overlay(
            UnevenRoundedRectangle(topLeadingRadius: 32, topTrailingRadius: 32)
                .stroke(cPurpleBorder, lineWidth: 5)
        )
    }

    @ViewBuilder
    func toolTabBtn(icon: String, label: String, tab: ToolTab, action: (() -> Void)? = nil) -> some View {
        let isActive = activeTab == tab
        Button(action: {
            if let action { action() }
            else {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                    activeTab = (activeTab == tab) ? .none : tab
                }
            }
        }) {
            VStack(spacing: 2) {
                Image(systemName: icon)
                    .font(.system(size: 22))
                    .foregroundStyle(isActive ? cPurpleBorder : cTextMuted)
                Text(label)
                    .font(.system(size: 11, weight: .heavy))
                    .foregroundStyle(isActive ? cPurpleBorder : cTextMuted)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(isActive ? cPurpleLight : .clear)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(isActive ? cPurpleBorder : .clear, lineWidth: 3))
        }
    }

    var textSheet: some View {
        NavigationStack {
            VStack(spacing: 16) {
                Text("Add Text")
                    .font(.system(size: 24, weight: .black))
                    .foregroundStyle(cPurpleBorder)
                    .frame(maxWidth: .infinity, alignment: .leading)

                TextEditor(text: $textInput)
                    .font(textFont == "System" ? .system(size: 18, weight: .bold) : .custom(textFont, size: 20))
                    .foregroundStyle(cPurpleBorder)
                    .frame(height: 100)
                    .padding(12)
                    .background(cPurpleLight)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .overlay(RoundedRectangle(cornerRadius: 16).stroke(cPurpleBorder, lineWidth: 3))

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(FONTS, id: \.self) { f in
                            Button(action: { textFont = f }) {
                                Text("Aa")
                                    .font(f == "System" ? .system(size: 20, weight: .bold) : .custom(f, size: 22))
                                    .foregroundStyle(cPurpleBorder)
                                    .frame(width: 48, height: 48)
                                    .background(textFont == f ? cWhite : cBg)
                                    .clipShape(Circle())
                                    .overlay(Circle().stroke(textFont == f ? cPurpleBorder : cPurpleLight, lineWidth: 3))
                            }
                        }
                    }
                }

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(TEXT_COLORS, id: \.self) { c in
                            Circle()
                                .fill(Color(hex: c))
                                .frame(width: 36, height: 36)
                                .overlay(
                                    Circle().stroke(
                                        textColor == c ? cPurpleBorder : .clear,
                                        lineWidth: 3
                                    )
                                )
                                .overlay(
                                    c == "#FFFFFF" ? Circle().stroke(cPurpleLight, lineWidth: 3) : nil
                                )
                                .onTapGesture { textColor = c }
                        }
                    }
                }

                HStack(spacing: 12) {
                    Button(action: {
                        showTextSheet = false
                        activeTab = .none
                    }) {
                        Text("Cancel")
                            .font(.system(size: 16, weight: .heavy))
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
                    .background(cWhite)
                    .foregroundStyle(cPurpleBorder)
                    .clipShape(Capsule())
                    .overlay(Capsule().stroke(cPurpleBorder, lineWidth: 3))

                    Button(action: addText) {
                        Text("Ekle")
                            .font(.system(size: 16, weight: .heavy))
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
                    .background(cPurple)
                    .foregroundStyle(cWhite)
                    .clipShape(Capsule())
                    .overlay(Capsule().stroke(cPurpleBorder, lineWidth: 3))
                }
                Spacer()
            }
            .padding(24)
        }
        .presentationDetents([.medium])
    }

    // MARK: - Actions

    func addStickerItem(_ item: StickerItem) {
        let isLayer = item.content.hasPrefix("stk_layer_")
        let el = CanvasElement(
            id: UUID().uuidString, type: item.elementType, content: item.content,
            x: 150 + Double.random(in: -20...20),
            y: 150 + Double.random(in: -20...20),
            size: isLayer ? 320 : 160
        )
        elements.append(el)
        selectedId = el.id
    }

    func addText() {
        let trimmed = textInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let el = CanvasElement(
            id: UUID().uuidString, type: "text", content: trimmed,
            x: 40 + Double.random(in: 0...30),
            y: 110 + Double.random(in: 0...40),
            fontSize: 20, color: textColor, fontFamily: textFont
        )
        elements.append(el)
        selectedId = el.id
        textInput = ""
        showTextSheet = false
        activeTab = .none
    }

    func deleteSelected() {
        elements.removeAll { $0.id == selectedId }
        selectedId = nil
    }

    func sendCard() {
        guard (auth.user?.pair_ids?.isEmpty == false) else {
            alertIsSuccess = false
            alertMsg = "Add at least one friend to send a card"
            withAnimation(.spring(response: 0.4)) { showAlert = true }
            return
        }
        // If user has multiple friends but hasn't picked one, prompt them.
        guard let pairId = selectedPairId ?? (friends.count == 1 ? friends.first?.pair_id : nil) else {
            showFriendPicker = true
            return
        }
        guard !elements.isEmpty else {
            alertIsSuccess = false
            alertMsg = "Add at least one element to your card"
            withAnimation(.spring(response: 0.4)) { showAlert = true }
            return
        }
        sending = true
        Task {
            do {
                struct CreateBody: Encodable {
                    let pair_id: String
                    let background: String
                    let elements: [CanvasElement]
                }
                let created: Card = try await APIService.shared.post(
                    "/cards/create",
                    body: CreateBody(pair_id: pairId, background: background, elements: elements)
                )
                // Cache locally so the sender's own widget (if any) updates
                // immediately without waiting for a timeline refresh.
                SharedDataManager.shared.saveCard(created, forPairId: pairId)
                SharedDataManager.shared.reloadWidgets()

                alertIsSuccess = true
                alertMsg = ""
                withAnimation(.spring(response: 0.4)) { showAlert = true }
                elements = []
                selectedId = nil
                background = BACKGROUNDS[0]   // reset to default color
            } catch {
                alertIsSuccess = false
                alertMsg = error.localizedDescription
                withAnimation(.spring(response: 0.4)) { showAlert = true }
            }
            sending = false
        }
    }
}

// MARK: - Custom Celebration Icon (Canvas-drawn)
struct CelebrationIcon: View {
    var body: some View {
        Canvas { ctx, size in
            let w = size.width
            let h = size.height
            let navy = Color(hex: "#2D1E5F")
            let green = Color(hex: "#00D170")
            let purple = Color(hex: "#A774FF")
            let pink = Color(hex: "#FF6B9D")
            let yellow = Color(hex: "#FFB800")

            // --- Central envelope / card shape ---
            let cardW = w * 0.36
            let cardH = w * 0.30
            let cardX = w * 0.50 - cardW / 2
            let cardY = h * 0.42 - cardH / 2
            var card = Path()
            card.addRoundedRect(in: CGRect(x: cardX, y: cardY, width: cardW, height: cardH),
                                cornerSize: CGSize(width: 4, height: 4))
            ctx.fill(card, with: .color(navy))

            // Envelope flap (triangle)
            var flap = Path()
            flap.move(to: CGPoint(x: cardX, y: cardY))
            flap.addLine(to: CGPoint(x: cardX + cardW / 2, y: cardY + cardH * 0.55))
            flap.addLine(to: CGPoint(x: cardX + cardW, y: cardY))
            flap.closeSubpath()
            ctx.fill(flap, with: .color(purple))

            // Heart on envelope
            let heartSize = w * 0.08
            let heartX = w * 0.50
            let heartY = h * 0.38
            var heart = Path()
            heart.move(to: CGPoint(x: heartX, y: heartY + heartSize * 0.3))
            heart.addCurve(to: CGPoint(x: heartX, y: heartY + heartSize),
                           control1: CGPoint(x: heartX - heartSize * 0.6, y: heartY - heartSize * 0.2),
                           control2: CGPoint(x: heartX - heartSize * 0.5, y: heartY + heartSize * 0.8))
            heart.addCurve(to: CGPoint(x: heartX, y: heartY + heartSize * 0.3),
                           control1: CGPoint(x: heartX + heartSize * 0.5, y: heartY + heartSize * 0.8),
                           control2: CGPoint(x: heartX + heartSize * 0.6, y: heartY - heartSize * 0.2))
            ctx.fill(heart, with: .color(pink))

            // --- Radiating lines (burst) ---
            let burst: [(CGFloat, CGFloat, CGFloat, Color)] = [
                (0.50, 0.12, 0.10, green),
                (0.22, 0.24, 0.08, yellow),
                (0.78, 0.22, 0.09, pink),
                (0.18, 0.58, 0.08, purple),
                (0.82, 0.56, 0.07, green),
                (0.35, 0.78, 0.06, yellow),
                (0.65, 0.80, 0.07, pink),
            ]
            for (bx, by, blen, color) in burst {
                let cx = w * bx
                let cy = h * by
                let dx = cx - w * 0.50
                let dy = cy - h * 0.42
                let angle = atan2(dy, dx)
                var line = Path()
                line.move(to: CGPoint(x: cx, y: cy))
                line.addLine(to: CGPoint(x: cx + cos(angle) * w * blen,
                                         y: cy + sin(angle) * h * blen))
                ctx.stroke(line, with: .color(color),
                           style: StrokeStyle(lineWidth: w * 0.03, lineCap: .round))
            }

            // --- Confetti dots ---
            let dots: [(CGFloat, CGFloat, CGFloat, Color)] = [
                (0.15, 0.18, 0.035, green),
                (0.85, 0.15, 0.03,  yellow),
                (0.12, 0.72, 0.025, pink),
                (0.88, 0.68, 0.03,  purple),
                (0.50, 0.85, 0.025, green),
                (0.30, 0.12, 0.02,  purple),
                (0.72, 0.85, 0.02,  yellow),
            ]
            for (dx, dy, dr, color) in dots {
                let dot = Path(ellipseIn: CGRect(x: w * dx - w * dr,
                                                 y: h * dy - w * dr,
                                                 width: w * dr * 2,
                                                 height: w * dr * 2))
                ctx.fill(dot, with: .color(color))
            }

            // --- Confetti squares ---
            let squares: [(CGFloat, CGFloat, CGFloat, CGFloat, Color)] = [
                (0.25, 0.14, 0.05, 25,  navy),
                (0.75, 0.12, 0.04, -35, navy),
                (0.10, 0.45, 0.04, 50,  navy.opacity(0.5)),
                (0.90, 0.42, 0.035, -20, navy.opacity(0.5)),
                (0.42, 0.88, 0.035, 70,  navy.opacity(0.5)),
            ]
            for (sx, sy, ss, rot, color) in squares {
                let squareSize = w * ss
                var transform = CGAffineTransform.identity
                    .translatedBy(x: w * sx, y: h * sy)
                    .rotated(by: rot * .pi / 180)
                    .translatedBy(x: -squareSize / 2, y: -squareSize / 2)
                var sq = Path()
                sq.addRect(CGRect(x: 0, y: 0, width: squareSize, height: squareSize))
                ctx.fill(sq.applying(transform), with: .color(color))
            }

            // --- Small stars ---
            let starPositions: [(CGFloat, CGFloat, CGFloat)] = [
                (0.32, 0.18, 0.06),
                (0.70, 0.16, 0.05),
                (0.20, 0.65, 0.04),
                (0.80, 0.72, 0.05),
            ]
            for (stx, sty, sts) in starPositions {
                drawStar(ctx: ctx, center: CGPoint(x: w * stx, y: h * sty),
                         size: w * sts, color: yellow)
            }
        }
    }

    private func drawStar(ctx: GraphicsContext, center: CGPoint, size: CGFloat, color: Color) {
        var star = Path()
        let points = 4
        for i in 0..<(points * 2) {
            let angle = Double(i) * .pi / Double(points) - .pi / 2
            let r: Double = Double(i % 2 == 0 ? size : size * 0.35)
            let pt = CGPoint(x: center.x + CGFloat(cos(angle) * r),
                             y: center.y + CGFloat(sin(angle) * r))
            if i == 0 { star.move(to: pt) } else { star.addLine(to: pt) }
        }
        star.closeSubpath()
        ctx.fill(star, with: .color(color))
    }
}

// MARK: - Custom Warning Icon (Canvas-drawn)
struct WarningIcon: View {
    var body: some View {
        Canvas { ctx, size in
            let w = size.width
            let h = size.height
            let navy = Color(hex: "#2D1E5F")
            let yellow = Color(hex: "#FFB800")

            // Triangle
            var tri = Path()
            tri.move(to: CGPoint(x: w * 0.50, y: h * 0.18))
            tri.addLine(to: CGPoint(x: w * 0.82, y: h * 0.78))
            tri.addLine(to: CGPoint(x: w * 0.18, y: h * 0.78))
            tri.closeSubpath()
            ctx.fill(tri, with: .color(yellow))
            ctx.stroke(tri, with: .color(navy), style: StrokeStyle(lineWidth: w * 0.04, lineJoin: .round))

            // Exclamation line
            var line = Path()
            line.move(to: CGPoint(x: w * 0.50, y: h * 0.38))
            line.addLine(to: CGPoint(x: w * 0.50, y: h * 0.58))
            ctx.stroke(line, with: .color(navy), style: StrokeStyle(lineWidth: w * 0.06, lineCap: .round))

            // Exclamation dot
            let dotR = w * 0.035
            let dot = Path(ellipseIn: CGRect(x: w * 0.50 - dotR, y: h * 0.66 - dotR,
                                             width: dotR * 2, height: dotR * 2))
            ctx.fill(dot, with: .color(navy))
        }
    }
}
