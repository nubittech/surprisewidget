import SwiftUI

extension Notification.Name {
    static let premiumDidCompleteNavigateHome = Notification.Name("premiumDidCompleteNavigateHome")
}

struct ContentView: View {
    @Environment(AuthManager.self) private var auth
    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding = false
    @AppStorage("hasAskedNotificationPermission") private var hasAskedPermission = false
    // Bridge the singleton into SwiftUI's dependency tracking so the sheet
    // binding updates when `isPresenting` flips from anywhere in the app.
    @Bindable private var paywall = PaywallPresenter.shared

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
        .task {
            await auth.initialize()
            // Once we know we're authenticated, fetch the latest RevenueCat
            // CustomerInfo first, THEN mirror it to the backend. Calling
            // sync before customer info loads would push `is_active: false`
            // for real paying users and (until the backend started rejecting
            // downgrades) would silently revoke their lifetime purchase.
            if auth.isAuthenticated {
                await StoreKitManager.shared.updatePurchasedStatus()
                await auth.refreshUser()
            }
        }
        .sheet(
            isPresented: $paywall.isPresenting,
            onDismiss: {
                Analytics.paywallDismissed(converted: StoreKitManager.shared.isPurchased)
                paywall.handleDismiss()
            }
        ) {
            PremiumView()
                .onAppear { Analytics.paywallShown(trigger: paywall.currentTrigger) }
        }
        .preferredColorScheme(.light)
    }
}

struct SplashView: View {
    var body: some View {
        ZStack {
            Color(hex: "#F8F5FF").ignoresSafeArea()
            DottedBackground(dotColor: Color(hex: "#E9D5FF"))
            VStack(spacing: 0) {
                Image("logo_text")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 280)
                    .padding(.vertical, -60)
                ProgressView()
                    .tint(Color(hex: "#9D6BFF"))
                    .scaleEffect(1.3)
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
                tabButton(title: "Home", icon: selectedTab == 0 ? "house.fill" : "house", isSelected: selectedTab == 0) {
                    selectedTab = 0
                }
                Spacer()
                centerTabButton(title: "Create Card", icon: "plus", isSelected: false) {
                    showCreateCard = true
                }
                Spacer()
                centerTabButton(title: "Profile", icon: "person.fill", isSelected: selectedTab == 2, circleColor: Color(hex: "#FFD666")) {
                    selectedTab = 2
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
            .background(Color.white)
            .clipShape(Capsule())
            .overlay(Capsule().stroke(Color(hex: "#2D1E5F"), lineWidth: 4))
            .shadow(color: Color(hex: "#2D1E5F"), radius: 0, x: 4, y: 4)
            .frame(maxWidth: UIDevice.current.userInterfaceIdiom == .pad ? 420 : .infinity)
            .padding(.horizontal, 20)
            .padding(.bottom, 8)
        }
        .fullScreenCover(isPresented: $showCreateCard) {
            CreateCardView()
        }
        .onReceive(NotificationCenter.default.publisher(for: .premiumDidCompleteNavigateHome)) { _ in
            showCreateCard = false
            selectedTab = 0
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
