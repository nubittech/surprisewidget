import SwiftUI
import UserNotifications

// MARK: - Notification Permission View
//
// Shown once after the user logs in, before triggering iOS's native
// permission dialog. Explains WHY notifications are needed (surprise cards
// on the widget) so the user is primed to tap "Allow" on the system dialog.

struct NotificationPermissionView: View {
    var onDone: () -> Void

    private let cBg         = Color(hex: "#F3E8FF")
    private let cPurple     = Color(hex: "#A774FF")
    private let cPurpleDark = Color(hex: "#2D1E5F")
    private let cYellow     = Color(hex: "#FFD666")
    private let cGreen      = Color(hex: "#00D170")
    private let cWhite      = Color.white

    var body: some View {
        ZStack {
            cBg.ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                // ── Illustration ──────────────────────────────────────
                ZStack {
                    // Outer glow ring
                    Circle()
                        .fill(cPurple.opacity(0.12))
                        .frame(width: 220, height: 220)

                    Circle()
                        .fill(cWhite)
                        .frame(width: 170, height: 170)
                        .overlay(Circle().stroke(cPurpleDark, lineWidth: 4))
                        .shadow(color: cPurpleDark, radius: 0, x: 4, y: 5)

                    NotifBellCanvas()
                        .frame(width: 110, height: 110)
                }
                .padding(.bottom, 36)

                // ── Heading ──────────────────────────────────────────
                Text("Don't Miss\nthe Surprises! 🎁")
                    .font(.system(size: 32, weight: .heavy, design: .rounded))
                    .foregroundStyle(cPurpleDark)
                    .multilineTextAlignment(.center)
                    .padding(.bottom, 16)

                // ── Body text ────────────────────────────────────────
                Text("We need notifications so you know instantly when a friend sends you a card and your widget updates.")
                    .font(.system(size: 16, weight: .medium, design: .rounded))
                    .foregroundStyle(cPurpleDark.opacity(0.7))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 36)
                    .padding(.bottom, 32)

                // ── Feature chips ─────────────────────────────────────
                VStack(spacing: 12) {
                    featureChip(emoji: "🎁", text: "Get notified instantly for new cards")
                    featureChip(emoji: "🖼️", text: "Widget updates without opening the app")
                    featureChip(emoji: "🔕", text: "You can turn it off anytime")
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 40)

                Spacer()

                // ── CTA button ────────────────────────────────────────
                Button(action: requestPermission) {
                    HStack(spacing: 10) {
                        Text("Allow Notifications")
                            .font(.system(size: 18, weight: .black, design: .rounded))
                            .foregroundStyle(cPurpleDark)
                        Text("🔔")
                            .font(.system(size: 20))
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 58)
                    .background(cYellow)
                    .clipShape(Capsule())
                    .overlay(Capsule().stroke(cPurpleDark, lineWidth: 4))
                    .shadow(color: cPurpleDark, radius: 0, x: 4, y: 5)
                }
                .padding(.horizontal, 24)

                // ── Skip ─────────────────────────────────────────────
                Button(action: onDone) {
                    Text("Not Now")
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundStyle(cPurpleDark.opacity(0.4))
                        .padding(.vertical, 16)
                }
            }
            .padding(.bottom, 16)
        }
    }

    // ── Actions ───────────────────────────────────────────────────────

    private func requestPermission() {
        PushNotificationManager.shared.requestPermissionAndRegister()
        onDone()
    }

    // ── Sub-views ─────────────────────────────────────────────────────

    @ViewBuilder
    private func featureChip(emoji: String, text: String) -> some View {
        HStack(spacing: 14) {
            Text(emoji)
                .font(.system(size: 22))
                .frame(width: 40, height: 40)
                .background(cWhite)
                .clipShape(Circle())
                .overlay(Circle().stroke(cPurpleDark, lineWidth: 2))

            Text(text)
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundStyle(cPurpleDark)

            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(cWhite)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(cPurpleDark, lineWidth: 2))
    }
}

// MARK: - Canvas-drawn bell icon

struct NotifBellCanvas: View {
    var body: some View {
        Canvas { ctx, size in
            let w = size.width
            let h = size.height
            let navy  = Color(hex: "#2D1E5F")
            let purple = Color(hex: "#A774FF")
            let yellow = Color(hex: "#FFD666")

            // ── Bell body ──────────────────────────────────────────
            // Bell dome (semi-circle + sides)
            var bell = Path()
            let bellL = w * 0.18
            let bellR = w * 0.82
            let bellTop = h * 0.15
            let bellMid = h * 0.65

            bell.move(to: CGPoint(x: bellL, y: bellMid))
            bell.addCurve(
                to: CGPoint(x: bellR, y: bellMid),
                control1: CGPoint(x: bellL, y: bellTop),
                control2: CGPoint(x: bellR, y: bellTop)
            )
            bell.addLine(to: CGPoint(x: bellR + w * 0.04, y: bellMid + h * 0.08))
            bell.addLine(to: CGPoint(x: bellL - w * 0.04, y: bellMid + h * 0.08))
            bell.closeSubpath()
            ctx.fill(bell, with: .color(purple))
            ctx.stroke(bell, with: .color(navy),
                       style: StrokeStyle(lineWidth: w * 0.05, lineJoin: .round))

            // ── Bell handle (stem at top) ──────────────────────────
            let stemR = w * 0.07
            let stem = Path(ellipseIn: CGRect(
                x: w * 0.5 - stemR, y: bellTop - stemR * 1.8,
                width: stemR * 2, height: stemR * 2
            ))
            ctx.fill(stem, with: .color(purple))
            ctx.stroke(stem, with: .color(navy),
                       style: StrokeStyle(lineWidth: w * 0.04))

            // ── Clapper (bottom circle) ────────────────────────────
            let clapR = w * 0.09
            let clap = Path(ellipseIn: CGRect(
                x: w * 0.5 - clapR,
                y: bellMid + h * 0.05,
                width: clapR * 2, height: clapR * 2
            ))
            ctx.fill(clap, with: .color(yellow))
            ctx.stroke(clap, with: .color(navy),
                       style: StrokeStyle(lineWidth: w * 0.04))

            // ── Notification dot (top-right) ───────────────────────
            let dotR = w * 0.10
            let dot = Path(ellipseIn: CGRect(
                x: bellR - dotR * 0.5, y: bellTop - dotR * 0.5,
                width: dotR * 2, height: dotR * 2
            ))
            ctx.fill(dot, with: .color(Color(hex: "#FF4D6D")))
            ctx.stroke(dot, with: .color(navy),
                       style: StrokeStyle(lineWidth: w * 0.035))

            // ── Small sparkle lines around bell ───────────────────
            let sparkles: [(CGFloat, CGFloat, CGFloat, CGFloat)] = [
                (0.05, 0.30, 0.14, 0.22),
                (0.02, 0.48, 0.12, 0.48),
                (0.95, 0.30, 0.86, 0.22),
                (0.98, 0.48, 0.88, 0.48),
            ]
            for (x1, y1, x2, y2) in sparkles {
                var line = Path()
                line.move(to: CGPoint(x: w * x1, y: h * y1))
                line.addLine(to: CGPoint(x: w * x2, y: h * y2))
                ctx.stroke(line, with: .color(yellow),
                           style: StrokeStyle(lineWidth: w * 0.04, lineCap: .round))
            }
        }
    }
}
