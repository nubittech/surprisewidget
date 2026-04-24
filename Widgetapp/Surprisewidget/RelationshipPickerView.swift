import SwiftUI

// MARK: - Relationship Picker (post-add intermezzo)
//
// Shown right after a user accepts an invite. Lets them:
//   1. Pick a nickname for the new friend (freeform)
//   2. Pick a relationship label from a grid of preset cards
//
// Zero emojis, zero SF Symbols — all icons are hand-drawn via Canvas/Path.

struct RelationshipOption: Identifiable, Hashable {
    let id: String
    let label: String
    let bg: Color
}

struct RelationshipPickerView: View {
    // Design tokens — mirror of HomeView's NB palette
    private enum RP {
        static let bg           = Color(hex: "#FFF5FF")
        static let primary      = Color(hex: "#9D6BFF")
        static let primaryBox   = Color(hex: "#CBB3FF")
        static let tertiary     = Color(hex: "#FFB800")
        static let surfaceLow   = Color(hex: "#FFF0FA")
        static let outline      = Color(hex: "#2D1E5F")
        static let muted        = Color(hex: "#6A5E8E")
        static let white        = Color.white
        static let borderW: CGFloat = 4
        static let borderSm: CGFloat = 3
        static let radius: CGFloat = 24
    }

    let partnerName: String
    let pairId: String
    /// Called once the user confirms. Parent decides where to route next.
    let onComplete: (_ nickname: String?, _ relationship: String?) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var nickname: String = ""
    @State private var selectedRelationship: RelationshipOption? = nil
    @State private var saving = false
    @FocusState private var nicknameFocused: Bool

    private let options: [RelationshipOption] = [
        .init(id: "My Love",        label: "My Love",        bg: Color(hex: "#FFD1E0")),
        .init(id: "My Best Friend", label: "My Best Friend", bg: Color(hex: "#D1F5E6")),
        .init(id: "My BFF",         label: "My BFF",         bg: Color(hex: "#FFE9B3")),
        .init(id: "My Sibling",     label: "My Sibling",     bg: Color(hex: "#D4E4FF")),
        .init(id: "My Dear",        label: "My Dear",        bg: Color(hex: "#FFCFE6")),
        .init(id: "My Person",      label: "My Person",      bg: Color(hex: "#E8D4FF")),
    ]

    var body: some View {
        ZStack {
            RP.bg.ignoresSafeArea()
            ScrollView(showsIndicators: false) {
                VStack(spacing: 24) {
                    header
                    nicknameCard
                    relationshipSection
                    continueButton
                }
                .padding(.horizontal, 20)
                .padding(.top, 40)
                .padding(.bottom, 40)
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .onTapGesture { nicknameFocused = false }
    }

    // MARK: - Header

    private var header: some View {
        VStack(spacing: 12) {
            // Custom-drawn confetti — no emojis
            ConfettiRow()
                .frame(maxWidth: .infinity)
                .frame(height: 44)

            Text("You added\n\(partnerName)!")
                .font(.system(size: 32, weight: .heavy, design: .rounded))
                .foregroundStyle(RP.outline)
                .multilineTextAlignment(.center)

            Text("Make this bond a little more personal.")
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundStyle(RP.muted)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .padding(.horizontal, 20)
        .background(RP.tertiary)
        .clipShape(RoundedRectangle(cornerRadius: RP.radius))
        .overlay(RoundedRectangle(cornerRadius: RP.radius).stroke(RP.outline, lineWidth: RP.borderW))
        .shadow(color: RP.outline, radius: 0, x: 4, y: 4)
    }

    // MARK: - Nickname card

    private var nicknameCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("What do you call them?")
                .font(.system(size: 18, weight: .heavy, design: .rounded))
                .foregroundStyle(RP.outline)
            Text("A cute pet name shows on your widget instead of their username.")
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(RP.muted)
                .lineSpacing(2)

            // ZStack tap-catcher pattern (same as HomeView Secret Code input)
            ZStack {
                Rectangle()
                    .fill(RP.white)
                    .contentShape(Rectangle())
                    .onTapGesture { nicknameFocused = true }

                HStack(spacing: 12) {
                    // Custom tag-heart glyph — hand-drawn, no SF Symbol
                    NicknameGlyph()
                        .frame(width: 24, height: 24)
                        .allowsHitTesting(false)
                    TextField("e.g. Sunshine, Lovebug, Boo…", text: $nickname)
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .focused($nicknameFocused)
                        .submitLabel(.done)
                        .onSubmit { nicknameFocused = false }
                }
                .padding(.horizontal, 16)
            }
            .frame(height: 56)
            .frame(maxWidth: .infinity)
            .clipShape(RoundedRectangle(cornerRadius: RP.radius))
            .overlay(RoundedRectangle(cornerRadius: RP.radius).stroke(RP.outline, lineWidth: RP.borderW))

            Text("Optional — you can set this later in Profile.")
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundStyle(RP.muted)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RP.surfaceLow)
        .clipShape(RoundedRectangle(cornerRadius: RP.radius))
        .overlay(RoundedRectangle(cornerRadius: RP.radius).stroke(RP.outline, lineWidth: RP.borderW))
        .shadow(color: RP.outline, radius: 0, x: 4, y: 4)
    }

    // MARK: - Relationship grid

    private var relationshipSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Who are they to you?")
                .font(.system(size: 18, weight: .heavy, design: .rounded))
                .foregroundStyle(RP.outline)
            Text("Pick one — it helps us personalize your experience later.")
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(RP.muted)
                .lineSpacing(2)

            LazyVGrid(
                columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)],
                spacing: 12
            ) {
                ForEach(options) { opt in
                    relationshipCard(opt)
                }
            }
        }
    }

    private func relationshipCard(_ opt: RelationshipOption) -> some View {
        let selected = selectedRelationship?.id == opt.id
        return Button {
            nicknameFocused = false
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                selectedRelationship = (selected ? nil : opt)
            }
        } label: {
            VStack(spacing: 8) {
                // Custom Canvas icon — no emojis, no SF Symbols
                RelationshipIcon(id: opt.id)
                    .frame(width: 48, height: 48)
                Text(opt.label)
                    .font(.system(size: 14, weight: .heavy, design: .rounded))
                    .foregroundStyle(RP.outline)
                    .multilineTextAlignment(.center)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 110)
            .background(selected ? RP.primaryBox : opt.bg)
            .clipShape(RoundedRectangle(cornerRadius: RP.radius))
            .overlay(
                RoundedRectangle(cornerRadius: RP.radius)
                    .stroke(RP.outline, lineWidth: selected ? RP.borderW + 1 : RP.borderSm)
            )
            .shadow(color: RP.outline, radius: 0, x: selected ? 2 : 4, y: selected ? 2 : 4)
            .offset(x: selected ? 2 : 0, y: selected ? 2 : 0)
            .overlay(alignment: .topTrailing) {
                if selected {
                    // Hand-drawn check ring — no SF Symbol
                    CheckRing()
                        .frame(width: 26, height: 26)
                        .padding(8)
                        .transition(.scale.combined(with: .opacity))
                }
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: - Continue button

    private var continueButton: some View {
        Button(action: confirm) {
            ZStack {
                if saving {
                    ProgressView().tint(RP.white)
                } else {
                    Text("Let's Go!")
                        .font(.system(size: 20, weight: .heavy, design: .rounded))
                        .foregroundStyle(RP.white)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 62)
            .background(RP.primary)
            .clipShape(RoundedRectangle(cornerRadius: RP.radius))
            .overlay(RoundedRectangle(cornerRadius: RP.radius).stroke(RP.outline, lineWidth: RP.borderW))
            .shadow(color: RP.outline, radius: 0, x: 4, y: 4)
        }
        .disabled(saving)
        .padding(.top, 8)
    }

    // MARK: - Action

    private func confirm() {
        nicknameFocused = false
        saving = true
        let trimmed = nickname.trimmingCharacters(in: .whitespaces)
        let finalNickname: String? = trimmed.isEmpty ? nil : trimmed
        let finalRelationship: String? = selectedRelationship?.id

        // Cache the user's choice locally immediately. If the backend write
        // below fails (endpoint unavailable, offline, etc.) we still want the
        // UI to honor the nickname across app restarts — HomeView.loadData
        // overlays these locals onto any friend whose backend nickname is nil.
        LocalNicknameCache.set(nickname: finalNickname, relationship: finalRelationship, forPairId: pairId)

        Task {
            struct Body: Encodable {
                let pair_id: String
                let partner_nickname: String?
                let relationship: String?
            }
            struct Ack: Decodable { let message: String? }
            let _: Ack? = try? await APIService.shared.post(
                "/pairs/update-label",
                body: Body(pair_id: pairId, partner_nickname: finalNickname, relationship: finalRelationship)
            )
            await MainActor.run {
                saving = false
                onComplete(finalNickname, finalRelationship)
            }
        }
    }
}

// MARK: ─── Custom Glyphs — Canvas/Path only, zero stock icons ───────────────

// Routes to the correct drawn icon per relationship type
private struct RelationshipIcon: View {
    let id: String
    var body: some View {
        switch id {
        case "My Love":        LoveIcon()
        case "My Best Friend": BestFriendIcon()
        case "My BFF":         BFFIcon()
        case "My Sibling":     SiblingIcon()
        case "My Dear":        DearIcon()
        default:               PersonIcon()
        }
    }
}

// ── My Love ── two overlapping hearts ────────────────────────────────────────
private struct LoveIcon: View {
    var body: some View {
        Canvas { ctx, size in
            let w = size.width, h = size.height
            let ol = Color(hex: "#2D1E5F")

            func heartPath(cx: CGFloat, cy: CGFloat, s: CGFloat) -> Path {
                var p = Path()
                p.move(to: CGPoint(x: cx, y: cy + s * 0.35))
                p.addCurve(
                    to: CGPoint(x: cx - s * 0.5, y: cy - s * 0.08),
                    control1: CGPoint(x: cx - s * 0.18, y: cy + s * 0.22),
                    control2: CGPoint(x: cx - s * 0.5, y: cy + s * 0.12)
                )
                p.addArc(center: CGPoint(x: cx - s * 0.25, y: cy - s * 0.22),
                          radius: s * 0.25, startAngle: .degrees(180), endAngle: .degrees(0), clockwise: false)
                p.addArc(center: CGPoint(x: cx + s * 0.25, y: cy - s * 0.22),
                          radius: s * 0.25, startAngle: .degrees(180), endAngle: .degrees(0), clockwise: false)
                p.addCurve(
                    to: CGPoint(x: cx, y: cy + s * 0.35),
                    control1: CGPoint(x: cx + s * 0.5, y: cy + s * 0.12),
                    control2: CGPoint(x: cx + s * 0.18, y: cy + s * 0.22)
                )
                return p
            }

            // Big back heart
            let big = heartPath(cx: w * 0.54, cy: h * 0.54, s: w * 0.66)
            ctx.fill(big, with: .color(Color(hex: "#FF6B9D")))
            ctx.stroke(big, with: .color(ol), lineWidth: 2.5)

            // Small front heart
            let small = heartPath(cx: w * 0.38, cy: h * 0.38, s: w * 0.36)
            ctx.fill(small, with: .color(Color(hex: "#FF3B6B")))
            ctx.stroke(small, with: .color(ol), lineWidth: 2)
        }
    }
}

// ── My Best Friend ── two interlocked friendship rings ───────────────────────
private struct BestFriendIcon: View {
    var body: some View {
        Canvas { ctx, size in
            let w = size.width, h = size.height
            let ol = Color(hex: "#2D1E5F")
            let r: CGFloat = w * 0.29
            let cy = h * 0.5

            // Left ring (green-teal)
            var left = Path()
            left.addArc(center: CGPoint(x: w * 0.36, y: cy), radius: r,
                         startAngle: .degrees(0), endAngle: .degrees(360), clockwise: false)
            ctx.fill(left, with: .color(Color(hex: "#00C985").opacity(0.82)))
            ctx.stroke(left, with: .color(ol), lineWidth: 2.5)

            // Right ring (purple) — drawn second so it overlaps on the right side
            var right = Path()
            right.addArc(center: CGPoint(x: w * 0.64, y: cy), radius: r,
                          startAngle: .degrees(0), endAngle: .degrees(360), clockwise: false)
            ctx.fill(right, with: .color(Color(hex: "#9D6BFF").opacity(0.82)))
            ctx.stroke(right, with: .color(ol), lineWidth: 2.5)

            // Small dot where rings meet — signals the bond
            var dot = Path()
            dot.addArc(center: CGPoint(x: w * 0.5, y: cy), radius: w * 0.07,
                        startAngle: .degrees(0), endAngle: .degrees(360), clockwise: false)
            ctx.fill(dot, with: .color(Color(hex: "#FFB800")))
            ctx.stroke(dot, with: .color(ol), lineWidth: 2)
        }
    }
}

// ── My BFF ── three 4-pointed sparkle stars ───────────────────────────────────
private struct BFFIcon: View {
    var body: some View {
        Canvas { ctx, size in
            let w = size.width, h = size.height
            let ol = Color(hex: "#2D1E5F")

            func sparkle(cx: CGFloat, cy: CGFloat, r: CGFloat) -> Path {
                var p = Path()
                for i in 0..<8 {
                    let angle = CGFloat(i) * 45.0 - 90.0
                    let rad = angle * .pi / 180.0
                    let dist = i % 2 == 0 ? r : r * 0.38
                    let pt = CGPoint(x: cx + cos(rad) * dist, y: cy + sin(rad) * dist)
                    if i == 0 { p.move(to: pt) } else { p.addLine(to: pt) }
                }
                p.closeSubpath()
                return p
            }

            // Large center star
            let big = sparkle(cx: w * 0.5, cy: h * 0.55, r: w * 0.30)
            ctx.fill(big, with: .color(Color(hex: "#FFB800")))
            ctx.stroke(big, with: .color(ol), lineWidth: 2.5)

            // Upper-left small star
            let mid = sparkle(cx: w * 0.2, cy: h * 0.32, r: w * 0.15)
            ctx.fill(mid, with: .color(Color(hex: "#FF6B9D")))
            ctx.stroke(mid, with: .color(ol), lineWidth: 2)

            // Upper-right tiny star
            let sm = sparkle(cx: w * 0.82, cy: h * 0.28, r: w * 0.11)
            ctx.fill(sm, with: .color(Color(hex: "#9D6BFF")))
            ctx.stroke(sm, with: .color(ol), lineWidth: 1.5)
        }
    }
}

// ── My Sibling ── two person silhouettes side by side ─────────────────────────
private struct SiblingIcon: View {
    var body: some View {
        Canvas { ctx, size in
            let w = size.width, h = size.height
            let ol = Color(hex: "#2D1E5F")

            // ── Left person (pink) ──
            var head1 = Path()
            let h1cy = h * 0.26
            head1.addArc(center: CGPoint(x: w * 0.33, y: h1cy), radius: w * 0.13,
                          startAngle: .degrees(0), endAngle: .degrees(360), clockwise: false)
            ctx.fill(head1, with: .color(Color(hex: "#FFD1E0")))
            ctx.stroke(head1, with: .color(ol), lineWidth: 2)

            let bt1 = h1cy + w * 0.13 + 2
            var body1 = Path()
            body1.move(to: CGPoint(x: w * 0.14, y: bt1))
            body1.addLine(to: CGPoint(x: w * 0.52, y: bt1))
            body1.addLine(to: CGPoint(x: w * 0.47, y: h * 0.96))
            body1.addLine(to: CGPoint(x: w * 0.19, y: h * 0.96))
            body1.closeSubpath()
            ctx.fill(body1, with: .color(Color(hex: "#FF6B9D")))
            ctx.stroke(body1, with: .color(ol), lineWidth: 2)

            // ── Right person (blue) ──
            var head2 = Path()
            let h2cy = h * 0.29
            head2.addArc(center: CGPoint(x: w * 0.67, y: h2cy), radius: w * 0.13,
                          startAngle: .degrees(0), endAngle: .degrees(360), clockwise: false)
            ctx.fill(head2, with: .color(Color(hex: "#D4E4FF")))
            ctx.stroke(head2, with: .color(ol), lineWidth: 2)

            let bt2 = h2cy + w * 0.13 + 2
            var body2 = Path()
            body2.move(to: CGPoint(x: w * 0.48, y: bt2))
            body2.addLine(to: CGPoint(x: w * 0.86, y: bt2))
            body2.addLine(to: CGPoint(x: w * 0.81, y: h * 0.96))
            body2.addLine(to: CGPoint(x: w * 0.53, y: h * 0.96))
            body2.closeSubpath()
            ctx.fill(body2, with: .color(Color(hex: "#4A90FF")))
            ctx.stroke(body2, with: .color(ol), lineWidth: 2)
        }
    }
}

// ── My Dear ── heart with radiating sparkle lines ─────────────────────────────
private struct DearIcon: View {
    var body: some View {
        Canvas { ctx, size in
            let w = size.width, h = size.height
            let ol = Color(hex: "#2D1E5F")

            // Heart
            let cx = w * 0.5, cy = h * 0.56, s = w * 0.60
            var heart = Path()
            heart.move(to: CGPoint(x: cx, y: cy + s * 0.35))
            heart.addCurve(
                to: CGPoint(x: cx - s * 0.5, y: cy - s * 0.08),
                control1: CGPoint(x: cx - s * 0.18, y: cy + s * 0.22),
                control2: CGPoint(x: cx - s * 0.5, y: cy + s * 0.12)
            )
            heart.addArc(center: CGPoint(x: cx - s * 0.25, y: cy - s * 0.22),
                          radius: s * 0.25, startAngle: .degrees(180), endAngle: .degrees(0), clockwise: false)
            heart.addArc(center: CGPoint(x: cx + s * 0.25, y: cy - s * 0.22),
                          radius: s * 0.25, startAngle: .degrees(180), endAngle: .degrees(0), clockwise: false)
            heart.addCurve(
                to: CGPoint(x: cx, y: cy + s * 0.35),
                control1: CGPoint(x: cx + s * 0.5, y: cy + s * 0.12),
                control2: CGPoint(x: cx + s * 0.18, y: cy + s * 0.22)
            )
            ctx.fill(heart, with: .color(Color(hex: "#FF3B6B")))
            ctx.stroke(heart, with: .color(ol), lineWidth: 2.5)

            // Sparkle rays around top-right corner
            let sc = CGPoint(x: w * 0.8, y: h * 0.16)
            let rayAngles: [(CGFloat, Bool)] = [(0,true),(45,false),(90,true),(135,false),(180,true),(225,false),(270,true),(315,false)]
            for (angleDeg, isLong) in rayAngles {
                let rad = angleDeg * .pi / 180
                let len: CGFloat = isLong ? 8 : 5
                var ray = Path()
                ray.move(to: CGPoint(x: sc.x + cos(rad) * 3, y: sc.y + sin(rad) * 3))
                ray.addLine(to: CGPoint(x: sc.x + cos(rad) * (3 + len), y: sc.y + sin(rad) * (3 + len)))
                ctx.stroke(ray, with: .color(Color(hex: "#FFB800")), lineWidth: 2.5)
            }
        }
    }
}

// ── My Person ── silhouette with a crown ──────────────────────────────────────
private struct PersonIcon: View {
    var body: some View {
        Canvas { ctx, size in
            let w = size.width, h = size.height
            let ol = Color(hex: "#2D1E5F")

            // Crown
            let cl = w * 0.2, cr = w * 0.8
            let cBot = h * 0.26, cTop = h * 0.06
            var crown = Path()
            crown.move(to: CGPoint(x: cl, y: cBot))
            crown.addLine(to: CGPoint(x: cl + (cr-cl) * 0.12, y: cTop))
            crown.addLine(to: CGPoint(x: cl + (cr-cl) * 0.3, y: cBot - (cBot-cTop)*0.45))
            crown.addLine(to: CGPoint(x: cl + (cr-cl) * 0.5, y: cTop))
            crown.addLine(to: CGPoint(x: cl + (cr-cl) * 0.7, y: cBot - (cBot-cTop)*0.45))
            crown.addLine(to: CGPoint(x: cl + (cr-cl) * 0.88, y: cTop))
            crown.addLine(to: CGPoint(x: cr, y: cBot))
            crown.closeSubpath()
            ctx.fill(crown, with: .color(Color(hex: "#FFB800")))
            ctx.stroke(crown, with: .color(ol), lineWidth: 2)

            // Head
            let headCY = h * 0.46
            var head = Path()
            head.addArc(center: CGPoint(x: w * 0.5, y: headCY), radius: w * 0.16,
                         startAngle: .degrees(0), endAngle: .degrees(360), clockwise: false)
            ctx.fill(head, with: .color(Color(hex: "#FFD1E0")))
            ctx.stroke(head, with: .color(ol), lineWidth: 2)

            // Body
            let bodyTop = headCY + w * 0.16 + 2
            var body = Path()
            body.move(to: CGPoint(x: w * 0.28, y: bodyTop))
            body.addLine(to: CGPoint(x: w * 0.72, y: bodyTop))
            body.addLine(to: CGPoint(x: w * 0.63, y: h * 0.96))
            body.addLine(to: CGPoint(x: w * 0.37, y: h * 0.96))
            body.closeSubpath()
            ctx.fill(body, with: .color(Color(hex: "#9D6BFF")))
            ctx.stroke(body, with: .color(ol), lineWidth: 2)
        }
    }
}

// ── Header confetti — geometric pieces, no emojis ────────────────────────────
private struct ConfettiRow: View {
    private struct Piece {
        let xRatio: CGFloat, yRatio: CGFloat
        let angle: CGFloat      // degrees
        let pw: CGFloat, ph: CGFloat
        let colorIdx: Int
        let isDiamond: Bool
    }

    private let pieces: [Piece] = [
        .init(xRatio: 0.06, yRatio: 0.38, angle: -38, pw: 10, ph:  5, colorIdx: 0, isDiamond: false),
        .init(xRatio: 0.17, yRatio: 0.68, angle:  22, pw:  8, ph:  4, colorIdx: 1, isDiamond: false),
        .init(xRatio: 0.28, yRatio: 0.22, angle:  52, pw:  6, ph: 12, colorIdx: 2, isDiamond: false),
        .init(xRatio: 0.38, yRatio: 0.55, angle: -16, pw:  9, ph:  5, colorIdx: 3, isDiamond: false),
        .init(xRatio: 0.47, yRatio: 0.28, angle:  30, pw:  7, ph:  4, colorIdx: 4, isDiamond: false),
        .init(xRatio: 0.57, yRatio: 0.72, angle: -48, pw:  7, ph:  7, colorIdx: 5, isDiamond: true ),
        .init(xRatio: 0.65, yRatio: 0.28, angle:  62, pw: 10, ph:  5, colorIdx: 0, isDiamond: false),
        .init(xRatio: 0.74, yRatio: 0.62, angle: -22, pw:  8, ph:  4, colorIdx: 1, isDiamond: false),
        .init(xRatio: 0.83, yRatio: 0.34, angle:  42, pw:  6, ph: 12, colorIdx: 2, isDiamond: false),
        .init(xRatio: 0.92, yRatio: 0.66, angle: -32, pw:  9, ph:  5, colorIdx: 3, isDiamond: false),
        .init(xRatio: 0.22, yRatio: 0.44, angle:   0, pw:  7, ph:  7, colorIdx: 4, isDiamond: true ),
        .init(xRatio: 0.75, yRatio: 0.46, angle:   0, pw:  7, ph:  7, colorIdx: 5, isDiamond: true ),
    ]

    private let palette: [Color] = [
        Color(hex: "#FF3B6B"),
        Color(hex: "#9D6BFF"),
        Color(hex: "#00C985"),
        Color(hex: "#FFB800"),
        Color(hex: "#FF6B9D"),
        Color(hex: "#4A90FF"),
    ]

    var body: some View {
        Canvas { ctx, size in
            let ol = Color(hex: "#2D1E5F")
            for p in pieces {
                let cx = size.width  * p.xRatio
                let cy = size.height * p.yRatio
                let color = palette[p.colorIdx]
                let angleRad = p.angle * .pi / 180

                let path: Path
                if p.isDiamond {
                    // Diamond (rotated square)
                    let s = p.pw / 2
                    var d = Path()
                    d.move(to: CGPoint(x:  0, y: -s))
                    d.addLine(to: CGPoint(x:  s, y:  0))
                    d.addLine(to: CGPoint(x:  0, y:  s))
                    d.addLine(to: CGPoint(x: -s, y:  0))
                    d.closeSubpath()
                    path = d.applying(CGAffineTransform(translationX: cx, y: cy))
                } else {
                    // Rectangle
                    let rect = CGRect(x: -p.pw/2, y: -p.ph/2, width: p.pw, height: p.ph)
                    path = Path(rect).applying(
                        CGAffineTransform(translationX: cx, y: cy).rotated(by: angleRad)
                    )
                }
                ctx.fill(path, with: .color(color))
                ctx.stroke(path, with: .color(ol), lineWidth: 1.5)
            }
        }
    }
}

// ── Nickname field glyph ── hand-drawn tag with a heart ───────────────────────
private struct NicknameGlyph: View {
    var body: some View {
        Canvas { ctx, size in
            let ol = Color(hex: "#2D1E5F")
            let w = size.width, h = size.height

            // Tag body
            var tag = Path()
            tag.move(to: CGPoint(x: w * 0.30, y: h * 0.18))
            tag.addLine(to: CGPoint(x: w * 0.92, y: h * 0.18))
            tag.addQuadCurve(to: CGPoint(x: w * 0.92, y: h * 0.82),
                              control: CGPoint(x: w, y: h * 0.5))
            tag.addLine(to: CGPoint(x: w * 0.30, y: h * 0.82))
            tag.addLine(to: CGPoint(x: w * 0.08, y: h * 0.5))
            tag.closeSubpath()
            ctx.fill(tag, with: .color(Color(hex: "#FFB800")))
            ctx.stroke(tag, with: .color(ol), lineWidth: 2)

            // Heart on tag
            let hx = w * 0.62, hy = h * 0.5, hs = w * 0.28
            var heart = Path()
            heart.move(to: CGPoint(x: hx, y: hy + hs * 0.3))
            heart.addCurve(
                to: CGPoint(x: hx - hs * 0.5, y: hy - hs * 0.1),
                control1: CGPoint(x: hx - hs * 0.2, y: hy + hs * 0.2),
                control2: CGPoint(x: hx - hs * 0.5, y: hy + hs * 0.1)
            )
            heart.addArc(center: CGPoint(x: hx - hs * 0.25, y: hy - hs * 0.2),
                          radius: hs * 0.25, startAngle: .degrees(180), endAngle: .degrees(0), clockwise: false)
            heart.addArc(center: CGPoint(x: hx + hs * 0.25, y: hy - hs * 0.2),
                          radius: hs * 0.25, startAngle: .degrees(180), endAngle: .degrees(0), clockwise: false)
            heart.addCurve(
                to: CGPoint(x: hx, y: hy + hs * 0.3),
                control1: CGPoint(x: hx + hs * 0.5, y: hy + hs * 0.1),
                control2: CGPoint(x: hx + hs * 0.2, y: hy + hs * 0.2)
            )
            ctx.fill(heart, with: .color(Color(hex: "#FF3B6B")))
            ctx.stroke(heart, with: .color(ol), lineWidth: 1.5)
        }
    }
}

// ── Checkmark ring ── hand-drawn selected indicator ───────────────────────────
private struct CheckRing: View {
    var body: some View {
        ZStack {
            Circle()
                .fill(Color(hex: "#9D6BFF"))
                .overlay(Circle().stroke(Color(hex: "#2D1E5F"), lineWidth: 3))
            Path { p in
                p.move(to: CGPoint(x: 7, y: 14))
                p.addLine(to: CGPoint(x: 11.5, y: 18))
                p.addLine(to: CGPoint(x: 19, y: 9))
            }
            .stroke(Color.white, style: StrokeStyle(lineWidth: 3.5, lineCap: .round, lineJoin: .round))
        }
    }
}

// MARK: - LocalNicknameCache
//
// A thin wrapper around the App Group UserDefaults that lets us persist the
// user's typed nickname + relationship per pair_id. Used as a fallback when
// the backend /pairs/update-label write fails or when the backend simply
// hasn't returned the stored nickname yet (e.g. stale cache in flight).
// HomeView.loadData overlays these onto any friend whose backend
// partner_nickname is nil, so the user-facing label is always in sync with
// what was last typed.

enum LocalNicknameCache {
    private static let appGroupId = "group.com.nubittech.surprisewidget"
    private static var defaults: UserDefaults? {
        UserDefaults(suiteName: appGroupId)
    }

    private static func nicknameKey(_ pairId: String) -> String { "local_nickname_\(pairId)" }
    private static func relationshipKey(_ pairId: String) -> String { "local_relationship_\(pairId)" }

    static func set(nickname: String?, relationship: String?, forPairId pairId: String) {
        let d = defaults ?? UserDefaults.standard
        if let n = nickname, !n.isEmpty { d.set(n, forKey: nicknameKey(pairId)) }
        else { d.removeObject(forKey: nicknameKey(pairId)) }
        if let r = relationship, !r.isEmpty { d.set(r, forKey: relationshipKey(pairId)) }
        // Note: we intentionally don't clear relationship when nil — relationship
        // may be set from other surfaces in the future.
    }

    static func nickname(forPairId pairId: String) -> String? {
        let d = defaults ?? UserDefaults.standard
        let v = d.string(forKey: nicknameKey(pairId))
        return (v?.isEmpty == false) ? v : nil
    }

    static func relationship(forPairId pairId: String) -> String? {
        let d = defaults ?? UserDefaults.standard
        let v = d.string(forKey: relationshipKey(pairId))
        return (v?.isEmpty == false) ? v : nil
    }

    static func clear(forPairId pairId: String) {
        let d = defaults ?? UserDefaults.standard
        d.removeObject(forKey: nicknameKey(pairId))
        d.removeObject(forKey: relationshipKey(pairId))
    }
}
