import SwiftUI

struct ContentView: View {
    @Environment(AuthManager.self) private var auth
    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding = false
    @AppStorage("hasAskedNotificationPermission") private var hasAskedPermission = false

    var body: some View {
        Group {
            if auth.isLoading {
                SplashView()
            } else if auth.isAuthenticated {
                if !hasAskedPermission {
                    // Custom pre-permission screen — shown once after first login.
                    // Explains WHY notifications are needed before iOS dialog appears,
                    // dramatically increasing acceptance rate.
                    NotificationPermissionView {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            hasAskedPermission = true
                        }
                    }
                } else {
                    MainTabView()
                }
            } else if !hasSeenOnboarding {
                OnboardingView(hasSeenOnboarding: $hasSeenOnboarding)
            } else {
                AuthView()
            }
        }
        .task { await auth.initialize() }
    }
}

struct SplashView: View {
    var body: some View {
        ZStack {
            Color(hex: "#F3E8FF").ignoresSafeArea()
            VStack(spacing: 20) {
                Text("💌").font(.system(size: 72))
                Text("Sürpriz Kart")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(Color(hex: "#9D4CDD"))
                ProgressView()
                    .tint(Color(hex: "#9D4CDD"))
                    .scaleEffect(1.2)
            }
        }
    }
}

struct MainTabView: View {
    @State private var selectedTab = 0
    @State private var showCreateCard = false
    
    init() {
        UITabBar.appearance().isHidden = true
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            TabView(selection: $selectedTab) {
                HomeView()
                    .tag(0)
                ProfileView()
                    .tag(2)
            }
            
            // Custom Floating Tab Bar
            HStack(spacing: 0) {
                tabButton(title: "Ana Sayfa", icon: selectedTab == 0 ? "house.fill" : "house", isSelected: selectedTab == 0) { 
                    selectedTab = 0 
                }
                Spacer()
                centerTabButton(title: "Kart Oluştur", icon: "plus", isSelected: false) { 
                    showCreateCard = true
                }
                Spacer()
                centerTabButton(title: "Profil", icon: "person.fill", isSelected: selectedTab == 2, circleColor: Color(hex: "#FFD666")) { 
                    selectedTab = 2 
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
            .background(Color.white)
            .clipShape(Capsule())
            .overlay(Capsule().stroke(Color(hex: "#2D1E5F"), lineWidth: 4))
            .shadow(color: Color(hex: "#2D1E5F"), radius: 0, x: 4, y: 4)
            .padding(.horizontal, 20)
            .padding(.bottom, 8)
        }
        .fullScreenCover(isPresented: $showCreateCard) {
            CreateCardView()
        }
    }
    
    @ViewBuilder
    func tabButton(title: String, icon: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 20, weight: isSelected ? .bold : .regular))
                if isSelected {
                    Text(title)
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                }
            }
            .foregroundStyle(isSelected ? Color(hex: "#9D4CDD") : Color(hex: "#8A7A9A"))
            .padding(.horizontal, isSelected ? 16 : 8)
            .padding(.vertical, 12)
            .background(isSelected ? Color(hex: "#F3E8FF") : Color.clear)
            .clipShape(Capsule())
        }
    }
    
    @ViewBuilder
    func centerTabButton(title: String, icon: String, isSelected: Bool, circleColor: Color = Color(hex: "#2D1E5F"), action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Circle()
                    .fill(isSelected ? Color(hex: "#9D4CDD") : circleColor)
                    .frame(width: 38, height: 38)
                    .overlay(
                        Image(systemName: icon)
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(circleColor == Color(hex: "#FFD666") && !isSelected ? Color(hex: "#2D1E5F") : Color.white)
                    )
                Text(title)
                    .font(.system(size: 10, weight: isSelected ? .bold : .semibold, design: .rounded))
                    .foregroundStyle(isSelected ? Color(hex: "#9D4CDD") : Color(hex: "#8A7A9A"))
            }
        }
    }
}
