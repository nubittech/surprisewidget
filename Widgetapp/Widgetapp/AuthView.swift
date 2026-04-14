import SwiftUI
import AuthenticationServices

struct AuthView: View {
    @Environment(AuthManager.self) private var auth
    
    @State private var isLogin = true
    @State private var email = ""
    @State private var password = ""
    @State private var name = ""
    @State private var loading = false
    @State private var errorMsg = ""
    @State private var showForgotPassword = false
    
    // Neo-Brutalist Colors
    let bgColor = Color(hex: "#F8F5FF") // Soft light purple background
    let darkStroke = Color(hex: "#2D1E5F") // Dark purple stroke
    let primaryPurple = Color(hex: "#9D6BFF") // Main vibrant purple
    let inputBgColor = Color(hex: "#F3E8FF") // Soft pastel purple for inputs
    let textDark = Color(hex: "#2D1E5F")
    
    var body: some View {
        ZStack {
            bgColor.ignoresSafeArea()
            DottedBackground(dotColor: Color(hex: "#E9D5FF"))

            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {

                    Spacer().frame(height: 20)

                    // "Ready for a" above logo
                    Text("Ready for a")
                        .font(.system(size: 42, weight: .heavy, design: .rounded))
                        .foregroundStyle(textDark)

                    // Logo image (no badge here)
                    Image("logo_text")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 312)
                        .padding(.vertical, -65)

                    Text("Create your secret vault and start sending\nmagical cards to your favorite people!")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(textDark.opacity(0.7))
                        .multilineTextAlignment(.center)
                        .padding(.bottom, 16)
                        .padding(.horizontal, 32)

                    // Main Card — "HI THERE!" badge on top-right corner
                    ZStack(alignment: .topTrailing) {
                        VStack(spacing: 18) {

                            if !isLogin {
                                BrutalistTextField(
                                    label: "Full Name",
                                    icon: "person.fill",
                                    placeholder: "Your Name",
                                    text: $name,
                                    strokeColor: darkStroke,
                                    inputBg: inputBgColor
                                )
                            }

                            BrutalistTextField(
                                label: "Email",
                                icon: "envelope.fill",
                                placeholder: "yourname@sparkle.com",
                                text: $email,
                                keyboardType: .emailAddress,
                                strokeColor: darkStroke,
                                inputBg: inputBgColor
                            )

                        // Password field with inline Forgot? button
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                HStack(spacing: 6) {
                                    Image(systemName: "lock.fill")
                                        .font(.system(size: 12, weight: .black))
                                    Text("Password")
                                        .font(.system(size: 14, weight: .black, design: .rounded))
                                }
                                .foregroundColor(darkStroke)
                                .padding(.leading, 8)

                                Spacer()

                                if isLogin {
                                    Button(action: { showForgotPassword = true }) {
                                        Text("Forgot?")
                                            .font(.system(size: 13, weight: .black, design: .rounded))
                                            .foregroundColor(primaryPurple)
                                            .padding(.horizontal, 10)
                                            .padding(.vertical, 4)
                                            .background(primaryPurple.opacity(0.1))
                                            .clipShape(Capsule())
                                    }
                                }
                            }

                            SecureField("••••••••", text: $password)
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(darkStroke)
                                .padding(.horizontal, 20)
                                .frame(height: 56)
                                .background(inputBgColor)
                                .clipShape(Capsule())
                        }

                        if !errorMsg.isEmpty {
                            Text(errorMsg)
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(Color(hex: "#DC2626"))
                                .multilineTextAlignment(.center)
                        }

                        // Submit Button
                        Button(action: handleSubmit) {
                            HStack {
                                if loading {
                                    ProgressView().tint(.white)
                                } else {
                                    Text(isLogin ? "Let's Go!" : "Get Started!")
                                }
                            }
                            .font(.system(size: 20, weight: .heavy, design: .rounded))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 60)
                            .background(primaryPurple)
                            .clipShape(Capsule())
                            .overlay(Capsule().stroke(darkStroke, lineWidth: 4))
                            .shadow(color: darkStroke, radius: 0, x: 0, y: 6)
                        }
                        .disabled(loading)
                        .padding(.top, 6)
                    }
                        .padding(28)
                        .background(Color.white)
                        .clipShape(RoundedRectangle(cornerRadius: 40, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 40, style: .continuous).stroke(darkStroke, lineWidth: 5))
                        .shadow(color: darkStroke, radius: 0, x: 8, y: 10)

                        // HI THERE! badge on top-right of card
                        Text("HI THERE!")
                            .font(.system(size: 11, weight: .black, design: .rounded))
                            .foregroundColor(darkStroke)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(Color(hex: "#FFB7C5"))
                            .clipShape(Capsule())
                            .overlay(Capsule().stroke(darkStroke, lineWidth: 1.5))
                            .rotationEffect(.degrees(8))
                            .offset(x: -20, y: -10)
                    }
                    .padding(.horizontal, 24)

                    Spacer(minLength: 24)

                    // OR JOIN VIA divider + Apple button
                    VStack(spacing: 14) {
                        HStack(spacing: 10) {
                            Rectangle().frame(height: 1).foregroundColor(darkStroke.opacity(0.15))
                            Text("OR JOIN VIA")
                                .font(.system(size: 11, weight: .black, design: .rounded))
                                .foregroundColor(darkStroke.opacity(0.4))
                                .fixedSize()
                            Rectangle().frame(height: 1).foregroundColor(darkStroke.opacity(0.15))
                        }
                        .padding(.horizontal, 24)

                        SignInWithAppleButton(
                            onRequest: { request in
                                request.requestedScopes = [.fullName, .email]
                            },
                            onCompletion: { result in
                                handleAppleSignIn(result: result)
                            }
                        )
                        .signInWithAppleButtonStyle(.white)
                        .frame(height: 56)
                        .clipShape(Capsule())
                        .overlay(Capsule().stroke(darkStroke, lineWidth: 3))
                        .shadow(color: darkStroke, radius: 0, x: 0, y: 5)
                        .padding(.horizontal, 24)
                    }

                    // Bottom toggle
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.25)) {
                            isLogin.toggle()
                            errorMsg = ""
                        }
                    }) {
                        HStack(spacing: 4) {
                            Text(isLogin ? "Don't have an account?" : "Already have an account?")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(textDark)
                            Text(isLogin ? "Sign Up Now!" : "Log In!")
                                .font(.system(size: 15, weight: .black, design: .rounded))
                                .foregroundColor(primaryPurple)
                        }
                    }
                    .padding(.top, 20)
                    .padding(.bottom, 36)
                }
            }
        }
        .sheet(isPresented: $showForgotPassword) {
            ForgotPasswordView()
        }
    }

    func handleAppleSignIn(result: Result<ASAuthorization, Error>) {
        switch result {
        case .success(let authorization):
            guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential else { return }
            loading = true
            errorMsg = ""
            Task {
                do {
                    try await auth.loginWithApple(credential: credential)
                } catch {
                    errorMsg = error.localizedDescription
                }
                loading = false
            }
        case .failure(let error):
            // User cancelled — don't show error
            if (error as NSError).code != ASAuthorizationError.canceled.rawValue {
                errorMsg = error.localizedDescription
            }
        }
    }

    func handleSubmit() {
        errorMsg = ""
        guard !email.isEmpty, !password.isEmpty else {
            errorMsg = "Please fill in all fields."
            return
        }
        if !isLogin && name.isEmpty {
            errorMsg = "Please enter your name."
            return
        }
        loading = true
        Task {
            do {
                if isLogin {
                    try await auth.login(email: email, password: password)
                } else {
                    try await auth.register(email: email, password: password, name: name)
                }
            } catch {
                errorMsg = error.localizedDescription
            }
            loading = false
        }
    }
}

// MARK: - Brutalist TextField Component
struct BrutalistTextField: View {
    let label: String
    let icon: String
    let placeholder: String
    @Binding var text: String
    var keyboardType: UIKeyboardType = .default
    var isSecure = false
    
    let strokeColor: Color
    let inputBg: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Label
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .black))
                Text(label)
                    .font(.system(size: 14, weight: .black, design: .rounded))
            }
            .foregroundColor(strokeColor)
            .padding(.leading, 8)
            
            // Input Field
            Group {
                if isSecure {
                    SecureField(placeholder, text: $text)
                        .autocorrectionDisabled()
                } else {
                    TextField(placeholder, text: $text)
                        .keyboardType(keyboardType)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(keyboardType == .emailAddress ? .never : .words)
                }
            }
            .font(.system(size: 16, weight: .bold))
            .foregroundColor(strokeColor)
            .padding(.horizontal, 20)
            .frame(height: 56)
            .background(inputBg)
            // Note: In the image fields don't have thick borders, just the pastel bg
            .clipShape(Capsule())
        }
    }
}

// MARK: - Forgot Password View
struct ForgotPasswordView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var email = ""
    @State private var loading = false
    @State private var sent = false
    @State private var errorMsg = ""

    private let dark = Color(hex: "#2D1E5F")
    private let purple = Color(hex: "#9D6BFF")
    private let inputBg = Color(hex: "#F3E8FF")
    private let bg = Color(hex: "#F8F5FF")

    var body: some View {
        ZStack {
            bg.ignoresSafeArea()
            DottedBackground(dotColor: Color(hex: "#E9D5FF"))

            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    Spacer().frame(height: 48)

                    // Icon + title
                    VStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(purple.opacity(0.15))
                                .frame(width: 100, height: 100)
                                .overlay(Circle().stroke(dark, lineWidth: 3))
                                .shadow(color: dark, radius: 0, x: 4, y: 4)
                            Text("🔑")
                                .font(.system(size: 48))
                        }

                        Text("Forgot Password?")
                            .font(.system(size: 28, weight: .black, design: .rounded))
                            .foregroundStyle(dark)

                        Text(sent
                             ? "Check your inbox and follow\nthe link we sent you."
                             : "Enter your email and we'll send\nyou a reset link.")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(dark.opacity(0.6))
                            .multilineTextAlignment(.center)
                    }
                    .padding(.bottom, 32)

                    // Card
                    VStack(spacing: 20) {
                        if sent {
                            // Success state
                            VStack(spacing: 20) {
                                Text("✅")
                                    .font(.system(size: 56))
                                Text("Email Sent!")
                                    .font(.system(size: 22, weight: .black, design: .rounded))
                                    .foregroundStyle(dark)

                                Button(action: { dismiss() }) {
                                    Text("Got it!")
                                        .font(.system(size: 18, weight: .heavy, design: .rounded))
                                        .foregroundColor(.white)
                                        .frame(maxWidth: .infinity)
                                        .frame(height: 56)
                                        .background(purple)
                                        .clipShape(Capsule())
                                        .overlay(Capsule().stroke(dark, lineWidth: 3))
                                        .shadow(color: dark, radius: 0, x: 0, y: 5)
                                }
                            }
                            .padding(.vertical, 8)
                        } else {
                            BrutalistTextField(
                                label: "Email",
                                icon: "envelope.fill",
                                placeholder: "yourname@sparkle.com",
                                text: $email,
                                keyboardType: .emailAddress,
                                strokeColor: dark,
                                inputBg: inputBg
                            )

                            if !errorMsg.isEmpty {
                                Text(errorMsg)
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundColor(Color(hex: "#DC2626"))
                                    .multilineTextAlignment(.center)
                            }

                            Button(action: handleReset) {
                                HStack {
                                    if loading { ProgressView().tint(.white) }
                                    else { Text("Send Reset Link") }
                                }
                                .font(.system(size: 18, weight: .heavy, design: .rounded))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .frame(height: 56)
                                .background(purple)
                                .clipShape(Capsule())
                                .overlay(Capsule().stroke(dark, lineWidth: 3))
                                .shadow(color: dark, radius: 0, x: 0, y: 5)
                            }
                            .disabled(loading)
                        }
                    }
                    .padding(28)
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 36, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 36, style: .continuous).stroke(dark, lineWidth: 4))
                    .shadow(color: dark, radius: 0, x: 6, y: 8)
                    .padding(.horizontal, 24)

                    Spacer(minLength: 32)

                    Button(action: { dismiss() }) {
                        Text("← Back to Login")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(dark.opacity(0.45))
                    }
                    .padding(.bottom, 40)
                }
            }
        }
    }

    func handleReset() {
        guard !email.isEmpty else { errorMsg = "Please enter your email."; return }
        loading = true
        errorMsg = ""
        Task {
            do {
                struct Body: Encodable { let email: String }
                struct Resp: Decodable { let message: String }
                let _: Resp = try await APIService.shared.post(
                    "/auth/forgot-password", body: Body(email: email))
                sent = true
            } catch {
                errorMsg = error.localizedDescription
            }
            loading = false
        }
    }
}

// MARK: - Surprise Widget Logo
struct SurpriseWidgetLogo: View {
    private let dark = Color(hex: "#2D1E5F")
    private let purple = Color(hex: "#9D6BFF")
    private let yellow = Color(hex: "#FADB5F")
    private let white = Color.white

    var body: some View {
        VStack(spacing: 14) {
            // ── Icon ────────────────────────────────────────────────────
            ZStack {
                // Widget shape
                RoundedRectangle(cornerRadius: 30, style: .continuous)
                    .fill(purple)
                    .frame(width: 120, height: 120)
                    .overlay(
                        RoundedRectangle(cornerRadius: 30, style: .continuous)
                            .stroke(dark, lineWidth: 4)
                    )
                    .shadow(color: dark, radius: 0, x: 6, y: 6)

                // Gift + sparkles (Canvas)
                Canvas { ctx, size in
                    let cx = size.width / 2
                    let cy = size.height / 2 + 4

                    // Gift body
                    let body = Path(roundedRect: CGRect(x: cx - 24, y: cy - 4, width: 48, height: 30), cornerRadius: 5)
                    ctx.fill(body, with: .color(white))

                    // Gift lid
                    let lid = Path(roundedRect: CGRect(x: cx - 27, y: cy - 16, width: 54, height: 14), cornerRadius: 5)
                    ctx.fill(lid, with: .color(yellow))

                    // Ribbon vertical
                    ctx.fill(Path(CGRect(x: cx - 4, y: cy - 16, width: 8, height: 44)), with: .color(yellow.opacity(0.7)))

                    // Bow left loop
                    var bowL = Path()
                    bowL.move(to: CGPoint(x: cx, y: cy - 16))
                    bowL.addCurve(to: CGPoint(x: cx - 20, y: cy - 16),
                                  control1: CGPoint(x: cx - 6,  y: cy - 34),
                                  control2: CGPoint(x: cx - 20, y: cy - 30))
                    bowL.addCurve(to: CGPoint(x: cx, y: cy - 16),
                                  control1: CGPoint(x: cx - 16, y: cy - 6),
                                  control2: CGPoint(x: cx - 4,  y: cy - 12))
                    ctx.fill(bowL, with: .color(yellow))

                    // Bow right loop
                    var bowR = Path()
                    bowR.move(to: CGPoint(x: cx, y: cy - 16))
                    bowR.addCurve(to: CGPoint(x: cx + 20, y: cy - 16),
                                  control1: CGPoint(x: cx + 6,  y: cy - 34),
                                  control2: CGPoint(x: cx + 20, y: cy - 30))
                    bowR.addCurve(to: CGPoint(x: cx, y: cy - 16),
                                  control1: CGPoint(x: cx + 16, y: cy - 6),
                                  control2: CGPoint(x: cx + 4,  y: cy - 12))
                    ctx.fill(bowR, with: .color(yellow))

                    // 4-point sparkle helper
                    func sparkle(x: CGFloat, y: CGFloat, r: CGFloat) -> Path {
                        var p = Path()
                        p.move(to: CGPoint(x: x, y: y - r))
                        p.addLine(to: CGPoint(x: x + r * 0.28, y: y - r * 0.28))
                        p.addLine(to: CGPoint(x: x + r, y: y))
                        p.addLine(to: CGPoint(x: x + r * 0.28, y: y + r * 0.28))
                        p.addLine(to: CGPoint(x: x, y: y + r))
                        p.addLine(to: CGPoint(x: x - r * 0.28, y: y + r * 0.28))
                        p.addLine(to: CGPoint(x: x - r, y: y))
                        p.addLine(to: CGPoint(x: x - r * 0.28, y: y - r * 0.28))
                        p.closeSubpath()
                        return p
                    }

                    ctx.fill(sparkle(x: cx - 36, y: cy - 28, r: 7), with: .color(white.opacity(0.95)))
                    ctx.fill(sparkle(x: cx + 38, y: cy - 22, r: 5), with: .color(white.opacity(0.85)))
                    ctx.fill(sparkle(x: cx + 32, y: cy + 24, r: 6), with: .color(white.opacity(0.9)))
                    ctx.fill(sparkle(x: cx - 32, y: cy + 26, r: 4), with: .color(white.opacity(0.8)))
                }
                .frame(width: 120, height: 120)
            }

        }
    }
}

// MARK: - Background Dotted Pattern
struct DottedBackground: View {
    let dotColor: Color
    
    var body: some View {
        Canvas { context, size in
            let spacing: CGFloat = 36
            let dotSize: CGFloat = 4
            
            for x in stride(from: 0, through: size.width, by: spacing) {
                for y in stride(from: 0, through: size.height, by: spacing) {
                    let rect = CGRect(x: x, y: y, width: dotSize, height: dotSize)
                    context.fill(Path(ellipseIn: rect), with: .color(dotColor))
                }
            }
        }
    }
}
