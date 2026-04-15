import SwiftUI

struct OnboardingView: View {
    @Binding var hasSeenOnboarding: Bool
    @State private var currentTab = 0
    
    // UI Colors
    let bgColor = Color(hex: "#F8F9FB")    // Soft off-white
    let accentPurple = Color(hex: "#9D6BFF") // Primary button color
    let textDark = Color(hex: "#1F2937")     // Dark gray for headers
    let textGray = Color(hex: "#6B7280")     // Body text
    
    var body: some View {
        ZStack {
            bgColor.ignoresSafeArea()
            
            VStack(spacing: 0) {
                topBar
                
                TabView(selection: $currentTab) {
                    slide1.tag(0)
                    slide2.tag(1)
                }
                .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
                .animation(.easeInOut, value: currentTab)
                
                Spacer(minLength: 0)
                
                bottomArea
            }
        }
    }
    
    // MARK: - Top Nav Bar
    var topBar: some View {
        HStack {
            // Fake profile avatar
            ZStack {
                Circle()
                    .fill(Color(hex: "#1F2937"))
                    .frame(width: 44, height: 44)
                Image(systemName: "person.fill")
                    .foregroundColor(.white)
                    .font(.system(size: 20))
            }
            
            Spacer()
            
            Text("Surprise!")
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundColor(accentPurple)
            
            Spacer()
            
            Image(systemName: "gift")
                .foregroundColor(accentPurple)
                .font(.system(size: 24))
        }
        .padding(.horizontal, 24)
        .padding(.top, 10)
    }
    
    // MARK: - Slide 1 (Hero)
    var slide1: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 16)
            
            // Hero Graphic
            ZStack {
                // Background Glow
                Circle()
                    .fill(accentPurple.opacity(0.1))
                    .frame(width: 250, height: 250)
                
                // Phones illustration
                HStack(spacing: -30) {
                    phoneShape(rotation: -10, color: Color(hex: "#374151"))
                    phoneShape(rotation: 10, color: Color(hex: "#1F2937"))
                        .offset(y: 20)
                }
                
                // Floating Widget Box
                VStack(spacing: 8) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 30))
                        .foregroundColor(accentPurple)
                        .padding(12)
                        .background(Color(hex: "#F3E8FF"))
                        .clipShape(Circle())
                    
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color(hex: "#E5E7EB"))
                        .frame(width: 60, height: 6)
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color(hex: "#E5E7EB"))
                        .frame(width: 40, height: 6)
                }
                .padding(20)
                .background(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 24))
                .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 5)
                .offset(x: -10, y: 10)
                
                // Green Heart
                Circle()
                    .fill(Color(hex: "#6EE7B7"))
                    .frame(width: 50, height: 50)
                    .overlay(Image(systemName: "heart.fill").foregroundColor(Color(hex: "#047857")))
                    .offset(x: 90, y: -90)
            }
            .frame(height: 300)
            
            Spacer(minLength: 24)
            
            // Text Content
            VStack(spacing: 16) {
                Text("Surprise messages\non their home screen")
                    .font(.system(size: 32, weight: .heavy, design: .rounded))
                    .foregroundColor(textDark)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)

                Text("Share surprise cards with loved ones right on their widget.")
                    .font(.system(size: 16, weight: .regular))
                    .foregroundColor(textGray)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)

                // Feature Tag
                HStack(spacing: 8) {
                    Image(systemName: "star.fill")
                        .font(.system(size: 12))
                    Text("New: Animated Cards")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                }
                .foregroundColor(Color(hex: "#92400E"))
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(Color(hex: "#FCD34D"))
                .clipShape(Capsule())
                .padding(.top, 10)
            }
            Spacer(minLength: 20)
        }
    }
    
    // MARK: - Slide 2 (Features 1, 2, & 3)
    var slide2: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 16)
            
            VStack(spacing: 8) {
                Text("How It Works")
                    .font(.system(size: 32, weight: .heavy, design: .rounded))
                    .foregroundColor(textDark)

                Text("The sweetest way to connect with the ones you love.")
                    .font(.system(size: 16))
                    .foregroundColor(textGray)
                    .multilineTextAlignment(.center)
            }
            
            Spacer(minLength: 16)
            
            VStack(spacing: 12) {
                featureCard(
                    step: "STEP 1",
                    title: "Add Someone",
                    desc: "Invite a friend, partner, or family member in seconds.",
                    icon: "person.badge.plus",
                    iconColor: Color(hex: "#6EE7B7"),
                    iconBg: Color(hex: "#D1FAE5")
                )

                featureCard(
                    step: "STEP 2",
                    title: "Add the Widget",
                    desc: "Place the Surprise Widget on your home screen.",
                    icon: "square.grid.2x2.fill",
                    iconColor: accentPurple,
                    iconBg: Color(hex: "#F3E8FF")
                )

                featureCard(
                    step: "STEP 3",
                    title: "Receive Surprises",
                    desc: "Cards from loved ones appear right on your screen!",
                    icon: "sparkles",
                    iconColor: Color(hex: "#F59E0B"),
                    iconBg: Color(hex: "#FEF3C7")
                )
            }
            .padding(.horizontal, 24)
            
            Spacer(minLength: 20)
        }
    }
    
    // MARK: - Bottom Area (Buttons & Indicators)
    var bottomArea: some View {
        VStack(spacing: 20) {
            // Dots
            HStack(spacing: 8) {
                ForEach(0..<2) { index in
                    Capsule()
                        .fill(index == currentTab ? accentPurple : Color(hex: "#E5E7EB"))
                        .frame(width: index == currentTab ? 24 : 8, height: 8)
                        .animation(.spring(), value: currentTab)
                }
            }
            
            // Main Button
            Button(action: {
                if currentTab < 1 {
                    withAnimation { currentTab += 1 }
                } else {
                    // Finish onboarding
                    withAnimation { hasSeenOnboarding = true }
                }
            }) {
                HStack {
                    Text(currentTab == 0 ? "Next" : "Log In / Sign Up")
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                    if currentTab > 0 {
                        Image(systemName: "arrow.right")
                            .font(.system(size: 16, weight: .bold))
                    }
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(accentPurple)
                .clipShape(Capsule())
            }
            .padding(.horizontal, 24)
            
            // Subtext for step 2
            if currentTab == 1 {
                Text("Start now, don't miss the surprises!")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(textGray)
            } else {
                Text(" ").font(.system(size: 13)) // layout placeholder
            }
        }
        .padding(.bottom, 32)
    }
    
    // MARK: - Helpers
    func phoneShape(rotation: Double, color: Color) -> some View {
        RoundedRectangle(cornerRadius: 24)
            .fill(color)
            .frame(width: 130, height: 260)
            .overlay(
                RoundedRectangle(cornerRadius: 24)
                    .stroke(Color.white, lineWidth: 6)
            )
            .rotationEffect(.degrees(rotation))
    }
    
    func featureCard(step: String, title: String, desc: String, icon: String, iconColor: Color, iconBg: Color) -> some View {
        HStack(alignment: .top, spacing: 16) {
            Circle()
                .fill(iconBg)
                .frame(width: 56, height: 56)
                .overlay(Image(systemName: icon).foregroundColor(iconColor).font(.system(size: 24)))
            
            VStack(alignment: .leading, spacing: 4) {
                Text(step)
                    .font(.system(size: 12, weight: .black, design: .rounded))
                    .foregroundColor(accentPurple)
                Text(title)
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundColor(textDark)
                Text(desc)
                    .font(.system(size: 14))
                    .foregroundColor(textGray)
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true) // Prevents text truncation issues
            }
            Spacer(minLength: 0)
        }
        .padding(20)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .shadow(color: .black.opacity(0.04), radius: 10, x: 0, y: 4)
    }
}
