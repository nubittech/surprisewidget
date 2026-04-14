import SwiftUI
import WidgetKit

struct WidgetSetupView: View {
    @Environment(AuthManager.self) private var auth
    @Environment(\.dismiss) private var dismiss

    let partnerName: String
    let isNewPairing: Bool

    @State private var currentStep = 0
    @State private var widgetSaved = false
    @State private var pulseScale: CGFloat = 1.0
    @State private var fingerOffset: CGFloat = 0
    @State private var showPlusGlow = false
    @State private var searchProgress: CGFloat = 0
    @State private var widgetDropped = false

    private let totalSteps = 5

    var body: some View {
        ZStack {
            // Gradient background
            LinearGradient(
                colors: [Color(hex: "#FFF5FF"), Color(hex: "#F0E6FF")],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                // Top bar
                topBar
                
                // Progress dots
                progressDots
                    .padding(.top, 8)

                Spacer()

                // Step content
                Group {
                    switch currentStep {
                    case 0: step0_Congrats
                    case 1: step1_LongPress
                    case 2: step2_SearchWidget
                    case 3: step3_ConfigureFriend
                    case 4: step4_Done
                    default: EmptyView()
                    }
                }
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing).combined(with: .opacity),
                    removal: .move(edge: .leading).combined(with: .opacity)
                ))

                Spacer()

                // Bottom button
                bottomButton
                    .padding(.horizontal, 24)
                    .padding(.bottom, 40)
            }
        }
    }

    // MARK: - Top Bar

    var topBar: some View {
        HStack {
            if currentStep > 0 {
                Button(action: { withAnimation(.spring(response: 0.4)) { currentStep -= 1 } }) {
                    Image(systemName: "arrow.left")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(Color(hex: "#2D1E5F"))
                        .padding(10)
                }
            } else {
                Color.clear.frame(width: 44, height: 44)
            }
            Spacer()
            Button(action: { dismiss() }) {
                Image(systemName: "xmark")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(Color(hex: "#6A5E8E"))
                    .padding(10)
            }
        }
        .padding(.horizontal, 16)
    }

    // MARK: - Progress Dots

    var progressDots: some View {
        HStack(spacing: 8) {
            ForEach(0..<totalSteps, id: \.self) { i in
                Capsule()
                    .fill(i <= currentStep ? Color(hex: "#9D6BFF") : Color(hex: "#D4C8E8"))
                    .frame(width: i == currentStep ? 28 : 8, height: 8)
                    .animation(.spring(response: 0.3), value: currentStep)
            }
        }
    }

    // MARK: - Step 0: Large Widget Preview

    var step0_Congrats: some View {
        VStack(spacing: 24) {
            if isNewPairing {
                Text("Connected! 🎉")
                    .font(.system(size: 30, weight: .heavy, design: .rounded))
                    .foregroundStyle(Color(hex: "#2D1E5F"))
            }

            Text("Your widget will look this awesome!")
                .font(.system(size: 18, weight: .black, design: .rounded))
                .foregroundStyle(Color(hex: "#9D6BFF"))
                .multilineTextAlignment(.center)

            // Large widget preview (systemLarge size) - Neobrutalist design
            ZStack {
                // Background Gradient
                RoundedRectangle(cornerRadius: 32)
                    .fill(
                        LinearGradient(
                            colors: [Color(hex: "#E9D5FF"), Color(hex: "#F3E8FF")],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )

                VStack(spacing: 24) {
                    // Photo Placeholder Area
                    ZStack {
                        RoundedRectangle(cornerRadius: 24)
                            .stroke(Color(hex: "#9D6BFF"), style: StrokeStyle(lineWidth: 4, dash: [10]))
                            .background(Color.white.opacity(0.8).clipShape(RoundedRectangle(cornerRadius: 24)))
                            .frame(width: 140, height: 140)
                        
                        VStack(spacing: 12) {
                            Image(systemName: "photo.badge.plus.fill")
                                .font(.system(size: 46))
                                .foregroundStyle(Color(hex: "#9D6BFF"))
                                .scaleEffect(pulseScale)
                                .onAppear {
                                    withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                                        pulseScale = 1.15
                                    }
                                }
                            
                            Text("Surprise!")
                                .font(.system(size: 20, weight: .heavy, design: .rounded))
                                .foregroundStyle(Color(hex: "#9D6BFF"))
                        }
                    }

                    // Content Area
                    VStack(spacing: 12) {
                        Text("Your surprise card\nwill appear here")
                            .font(.system(size: 18, weight: .heavy, design: .rounded))
                            .foregroundStyle(Color(hex: "#2D1E5F"))
                            .multilineTextAlignment(.center)

                        // Partner badge
                        HStack(spacing: 6) {
                            Image(systemName: "heart.fill")
                                .font(.system(size: 16))
                                .foregroundStyle(Color(hex: "#FB7185"))
                            
                            Text("Kimden: \(partnerName)")
                                .font(.system(size: 14, weight: .black, design: .rounded))
                                .foregroundStyle(Color(hex: "#2D1E5F"))
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(Color.white)
                        .clipShape(Capsule())
                        .overlay(Capsule().stroke(Color(hex: "#2D1E5F"), lineWidth: 3))
                        .shadow(color: Color(hex: "#2D1E5F"), radius: 0, x: 2, y: 3)
                    }
                }
            }
            .frame(height: 340)
            .clipShape(RoundedRectangle(cornerRadius: 32))
            .overlay(
                RoundedRectangle(cornerRadius: 32)
                    .stroke(Color(hex: "#2D1E5F"), lineWidth: 5)
            )
            .shadow(color: Color(hex: "#2D1E5F"), radius: 0, x: 4, y: 6)
            .padding(.horizontal, 8)

            Text("Add this widget to your home screen\nand see surprises instantly! 🚀")
                .font(.system(size: 17, weight: .heavy, design: .rounded))
                .foregroundStyle(Color(hex: "#6A5E8E"))
                .multilineTextAlignment(.center)
                .lineSpacing(6)
        }
        .padding(.horizontal, 24)
    }

    // MARK: - Step 1: Long Press Illustration

    var step1_LongPress: some View {
        VStack(spacing: 20) {
            Text("Ana Ekrana Uzun Bas")
                .font(.system(size: 26, weight: .heavy, design: .rounded))
                .foregroundStyle(Color(hex: "#2D1E5F"))

            Text("Long-press an empty area\nuntil icons start wiggling")
                .font(.system(size: 15, weight: .medium, design: .rounded))
                .foregroundStyle(Color(hex: "#6A5E8E"))
                .multilineTextAlignment(.center)

            // Phone mockup with long press animation
            ZStack {
                // Phone frame
                RoundedRectangle(cornerRadius: 36)
                    .fill(Color.white)
                    .frame(width: 220, height: 320)
                    .overlay(
                        RoundedRectangle(cornerRadius: 36)
                            .stroke(Color(hex: "#2D1E5F"), lineWidth: 4)
                    )
                    .shadow(color: Color(hex: "#2D1E5F"), radius: 0, x: 5, y: 5)

                // Fake app icons grid
                VStack(spacing: 16) {
                    HStack(spacing: 16) {
                        fakeAppIcon(color: "#FF6B6B")
                        fakeAppIcon(color: "#4ECDC4")
                        fakeAppIcon(color: "#45B7D1")
                    }
                    HStack(spacing: 16) {
                        fakeAppIcon(color: "#96CEB4")
                        fakeAppIcon(color: "#FFEAA7")
                        fakeAppIcon(color: "#DDA0DD")
                    }
                    HStack(spacing: 16) {
                        widgetAppIcon
                        fakeAppIcon(color: "#C4A4F9")
                        Color.clear.frame(width: 44, height: 44)
                    }
                }

                // Animated finger
                Image(systemName: "hand.point.up.left.fill")
                    .font(.system(size: 40))
                    .foregroundStyle(Color(hex: "#2D1E5F").opacity(0.7))
                    .offset(x: 20, y: 60 + fingerOffset)
                    .onAppear {
                        withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) {
                            fingerOffset = -8
                        }
                    }

                // Pulse circle around press point  
                Circle()
                    .stroke(Color(hex: "#9D6BFF").opacity(0.5), lineWidth: 2)
                    .frame(width: 60, height: 60)
                    .scaleEffect(pulseScale)
                    .offset(x: 0, y: 50)
            }
        }
        .padding(.horizontal, 24)
    }

    // MARK: - Step 2: Search & Add Widget

    var step2_SearchWidget: some View {
        VStack(spacing: 20) {
            Text("Find and Add the Widget")
                .font(.system(size: 26, weight: .heavy, design: .rounded))
                .foregroundStyle(Color(hex: "#2D1E5F"))

            Text("Tap ➕ at top left,\nsearch \"Widgetapp\" and add")
                .font(.system(size: 15, weight: .medium, design: .rounded))
                .foregroundStyle(Color(hex: "#6A5E8E"))
                .multilineTextAlignment(.center)

            // Search mockup
            ZStack {
                RoundedRectangle(cornerRadius: 36)
                    .fill(Color.white)
                    .frame(width: 260, height: 340)
                    .overlay(
                        RoundedRectangle(cornerRadius: 36)
                            .stroke(Color(hex: "#2D1E5F"), lineWidth: 4)
                    )
                    .shadow(color: Color(hex: "#2D1E5F"), radius: 0, x: 5, y: 5)

                VStack(spacing: 16) {
                    // Search bar
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundStyle(Color(hex: "#9CA3AF"))
                        Text("Widgetapp")
                            .font(.system(size: 15, weight: .semibold, design: .rounded))
                            .foregroundStyle(Color(hex: "#2D1E5F"))
                        Spacer()
                    }
                    .padding(12)
                    .background(Color(hex: "#F3F4F6"))
                    .clipShape(RoundedRectangle(cornerRadius: 12))

                    // Widget result
                    HStack(spacing: 12) {
                        // App icon
                        RoundedRectangle(cornerRadius: 12)
                            .fill(
                                LinearGradient(
                                    colors: [Color(hex: "#C4A4F9"), Color(hex: "#9D6BFF")],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 48, height: 48)
                            .overlay(
                                Text("💌")
                                    .font(.system(size: 22))
                            )

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Widgetapp")
                                .font(.system(size: 16, weight: .bold, design: .rounded))
                                .foregroundStyle(Color(hex: "#2D1E5F"))
                            Text("Surprise Card Widget")
                                .font(.system(size: 12, weight: .medium, design: .rounded))
                                .foregroundStyle(Color(hex: "#6A5E8E"))
                        }
                        Spacer()
                    }
                    .padding(12)
                    .background(Color(hex: "#F8F5FF"))
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color(hex: "#9D6BFF"), lineWidth: 2)
                    )

                    // Widget size preview
                    ZStack {
                        RoundedRectangle(cornerRadius: 20)
                            .fill(
                                LinearGradient(
                                    colors: [Color(hex: "#F3E8FF"), Color(hex: "#E9D5FF")],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(height: 100)
                            .overlay(
                                RoundedRectangle(cornerRadius: 20)
                                    .stroke(Color(hex: "#9D6BFF"), style: StrokeStyle(lineWidth: 3, dash: [6]))
                            )

                        VStack(spacing: 8) {
                            Text("✨")
                                .font(.system(size: 28))
                            Text("Waiting for a surprise card...")
                                .font(.system(size: 13, weight: .bold, design: .rounded))
                                .foregroundStyle(Color(hex: "#6A5E8E"))
                        }
                    }

                    // "Widget Ekle" button mockup
                    HStack {
                        Spacer()
                        Text("Widget Ekle")
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 10)
                            .background(Color(hex: "#9D6BFF"))
                            .clipShape(Capsule())
                        Spacer()
                    }
                }
                .padding(20)
            }
        }
        .padding(.horizontal, 24)
    }

    // MARK: - Step 3: Configure Friend via Edit Widget

    var step3_ConfigureFriend: some View {
        VStack(spacing: 18) {
            Text("Select a Friend")
                .font(.system(size: 26, weight: .heavy, design: .rounded))
                .foregroundStyle(Color(hex: "#2D1E5F"))

            Text("Each widget is assigned to a different friend.\nLong-press the widget → **Edit Widget**")
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundStyle(Color(hex: "#6A5E8E"))
                .multilineTextAlignment(.center)
                .lineSpacing(3)

            // Mock widget + long-press + context menu illustration
            ZStack {
                RoundedRectangle(cornerRadius: 36)
                    .fill(Color.white)
                    .frame(width: 280, height: 340)
                    .overlay(
                        RoundedRectangle(cornerRadius: 36)
                            .stroke(Color(hex: "#2D1E5F"), lineWidth: 4)
                    )
                    .shadow(color: Color(hex: "#2D1E5F"), radius: 0, x: 5, y: 5)

                VStack(spacing: 14) {
                    // Mock widget tile with pulse
                    ZStack {
                        RoundedRectangle(cornerRadius: 20)
                            .fill(
                                LinearGradient(
                                    colors: [Color(hex: "#F3E8FF"), Color(hex: "#E9D5FF")],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 130, height: 130)
                            .overlay(
                                RoundedRectangle(cornerRadius: 20)
                                    .stroke(Color(hex: "#9D6BFF"), lineWidth: 3)
                            )
                            .scaleEffect(pulseScale)

                        VStack(spacing: 4) {
                            Text("👆").font(.system(size: 28))
                            Text("Uzun Bas")
                                .font(.system(size: 11, weight: .bold, design: .rounded))
                                .foregroundStyle(Color(hex: "#6A5E8E"))
                        }
                    }

                    // Arrow down
                    Image(systemName: "arrow.down")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(Color(hex: "#9D6BFF"))

                    // Context menu mockup
                    VStack(spacing: 0) {
                        HStack {
                            Image(systemName: "slider.horizontal.3")
                                .foregroundStyle(Color(hex: "#2D1E5F"))
                            Text("Edit Widget")
                                .font(.system(size: 13, weight: .bold, design: .rounded))
                                .foregroundStyle(Color(hex: "#2D1E5F"))
                            Spacer()
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(Color(hex: "#F3E8FF"))

                        Divider()

                        HStack {
                            Text("Friend")
                                .font(.system(size: 12, weight: .semibold, design: .rounded))
                                .foregroundStyle(Color(hex: "#6A5E8E"))
                            Spacer()
                            Text(partnerName)
                                .font(.system(size: 12, weight: .bold, design: .rounded))
                                .foregroundStyle(Color(hex: "#9D6BFF"))
                            Image(systemName: "chevron.up.chevron.down")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(Color(hex: "#9D6BFF"))
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(Color.white)
                    }
                    .frame(width: 220)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color(hex: "#2D1E5F"), lineWidth: 2)
                    )
                }
            }
        }
        .padding(.horizontal, 24)
    }

    // MARK: - Step 4: Done!

    var step4_Done: some View {
        VStack(spacing: 28) {
            if widgetSaved {
                // Success animation — single-color navy confetti
                ZStack {
                    Circle()
                        .fill(Color(hex: "#CBB3FF"))
                    confettiIcon
                }
                .frame(width: 110, height: 110)
                .clipShape(Circle())
                .overlay(Circle().stroke(Color(hex: "#2D1E5F"), lineWidth: 4))

                VStack(spacing: 8) {
                    Text("You are ready!")
                        .font(.system(size: 30, weight: .heavy, design: .rounded))
                        .foregroundStyle(Color(hex: "#2D1E5F"))

                    Text("Widget data saved.\nNow add the widget to your home screen\nand enjoy the surprises!")
                        .font(.system(size: 16, weight: .medium, design: .rounded))
                        .foregroundStyle(Color(hex: "#6A5E8E"))
                        .multilineTextAlignment(.center)
                        .lineSpacing(4)
                }

                // Quick recap
                VStack(alignment: .leading, spacing: 12) {
                    quickStep(num: "1", text: "Ana ekrana uzun bas")
                    quickStep(num: "2", text: "Top left ➕ → search \"Widgetapp\"")
                    quickStep(num: "3", text: "Choose size → Add")
                    quickStep(num: "4", text: "Long-press widget → Edit")
                    quickStep(num: "5", text: "Select your friend 💜")
                }
                .padding(20)
                .background(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 20))
                .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color(hex: "#2D1E5F"), lineWidth: 3))
                .shadow(color: Color(hex: "#2D1E5F"), radius: 0, x: 4, y: 4)

            } else {
                ProgressView()
                    .tint(Color(hex: "#9D6BFF"))
                    .scaleEffect(1.5)
                Text("Widget kaydediliyor...")
                    .font(.system(size: 16, weight: .medium, design: .rounded))
                    .foregroundStyle(Color(hex: "#6A5E8E"))
            }
        }
        .padding(.horizontal, 24)
    }

    // MARK: - Lacivert Konfeti İkonu

    var confettiIcon: some View {
        let navy = Color(hex: "#2D1E5F")
        return ZStack {
            // Küçük kare konfetiler
            Group {
                RoundedRectangle(cornerRadius: 2)
                    .frame(width: 10, height: 10)
                    .rotationEffect(.degrees(20))
                    .offset(x: -22, y: -18)
                RoundedRectangle(cornerRadius: 2)
                    .frame(width: 8, height: 8)
                    .rotationEffect(.degrees(-35))
                    .offset(x: 20, y: -22)
                RoundedRectangle(cornerRadius: 2)
                    .frame(width: 11, height: 11)
                    .rotationEffect(.degrees(50))
                    .offset(x: 26, y: 10)
                RoundedRectangle(cornerRadius: 2)
                    .frame(width: 7, height: 7)
                    .rotationEffect(.degrees(-10))
                    .offset(x: -26, y: 14)
                RoundedRectangle(cornerRadius: 2)
                    .frame(width: 9, height: 9)
                    .rotationEffect(.degrees(70))
                    .offset(x: 4, y: 28)
                RoundedRectangle(cornerRadius: 2)
                    .frame(width: 7, height: 7)
                    .rotationEffect(.degrees(-60))
                    .offset(x: -10, y: -30)
            }
            .foregroundStyle(navy)

            // Daireler (nokta konfeti)
            Group {
                Circle().frame(width: 8, height: 8).offset(x: 16, y: -30)
                Circle().frame(width: 6, height: 6).offset(x: -18, y: 26)
                Circle().frame(width: 7, height: 7).offset(x: 28, y: -8)
                Circle().frame(width: 5, height: 5).offset(x: -4, y: 30)
            }
            .foregroundStyle(navy.opacity(0.55))

            // Ortadaki yıldız / patlama
            Image(systemName: "sparkle")
                .font(.system(size: 36, weight: .black))
                .foregroundStyle(navy)
        }
    }

    func quickStep(num: String, text: String) -> some View {
        HStack(spacing: 12) {
            Text(num)
                .font(.system(size: 14, weight: .black, design: .rounded))
                .foregroundStyle(.white)
                .frame(width: 28, height: 28)
                .background(Color(hex: "#9D6BFF"))
                .clipShape(Circle())
            Text(text)
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundStyle(Color(hex: "#2D1E5F"))
        }
    }

    // MARK: - Helper Views

    func fakeAppIcon(color: String) -> some View {
        RoundedRectangle(cornerRadius: 12)
            .fill(Color(hex: color))
            .frame(width: 44, height: 44)
    }

    var widgetAppIcon: some View {
        RoundedRectangle(cornerRadius: 12)
            .fill(
                LinearGradient(
                    colors: [Color(hex: "#C4A4F9"), Color(hex: "#9D6BFF")],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .frame(width: 44, height: 44)
            .overlay(
                Text("💌")
                    .font(.system(size: 18))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color(hex: "#9D6BFF"), lineWidth: 2)
            )
    }

    // MARK: - Bottom Button

    var bottomButton: some View {
        Button(action: nextStep) {
            HStack(spacing: 10) {
                Text(buttonTitle)
                    .font(.system(size: 18, weight: .heavy, design: .rounded))
                Image(systemName: buttonIcon)
                    .font(.system(size: 16, weight: .bold))
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 60)
            .background(Color(hex: "#9D6BFF"))
            .clipShape(Capsule())
            .overlay(Capsule().stroke(Color(hex: "#2D1E5F"), lineWidth: 4))
            .shadow(color: Color(hex: "#2D1E5F"), radius: 0, x: 4, y: 4)
        }
    }

    var buttonTitle: String {
        switch currentStep {
        case 0: return "Widget Kur →"
        case 1: return "Got it, Next"
        case 2: return "Devam Et"
        case 3: return "Save & Done"
        default: return "Done"
        }
    }

    var buttonIcon: String {
        switch currentStep {
        case 0: return "arrow.right"
        case 1: return "arrow.right"
        case 2: return "arrow.right"
        case 3: return "square.and.arrow.down"
        default: return "checkmark"
        }
    }

    // MARK: - Actions

    func nextStep() {
        if currentStep < 3 {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                currentStep += 1
            }
        } else if currentStep == 3 {
            saveWidgetData()
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                currentStep = 4
            }
        } else {
            dismiss()
        }
    }

    func saveWidgetData() {
        SharedDataManager.shared.reloadWidgets()

        withAnimation {
            widgetSaved = true
        }

        // Fetch latest card for each friend and save to App Group
        Task {
            if let user = auth.user, let pairIds = user.pair_ids {
                for pairId in pairIds {
                    if let resp: [String: Card?] = try? await APIService.shared.get("/cards/latest?pair_id=\(pairId)"),
                       let card = resp["card"] as? Card {
                        SharedDataManager.shared.saveCard(card, forPairId: pairId)
                    }
                }
                SharedDataManager.shared.reloadWidgets()
            }
        }
    }
}
