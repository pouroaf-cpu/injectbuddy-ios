import SwiftUI

// ─── MainShell ───────────────────────────────────────────────────────────────
// The authed container. iPhone: a custom off-canvas drawer over a NavigationStack
// (the native twin of the web .ib-calc-rail). iPad: a persistent NavigationSplitView
// sidebar. Both read NavItems as the single source of destinations.

struct MainShell: View {
    @StateObject private var navigator = ShellNavigator()
    @Environment(\.horizontalSizeClass) private var hSize

    var body: some View {
        Group {
            if hSize == .regular {
                iPadLayout
            } else {
                iPhoneLayout
            }
        }
        .environmentObject(navigator)
    }

    // MARK: iPhone — off-canvas drawer

    private var iPhoneLayout: some View {
        GeometryReader { geo in
            let drawerWidth = min(320, geo.size.width * 0.84)

            ZStack(alignment: .leading) {
                contentStack
                    // Nudge content right a touch while the drawer is open (web feel).
                    .disabled(navigator.isDrawerOpen)

                // Scrim
                if navigator.isDrawerOpen {
                    Color.black.opacity(0.35)
                        .ignoresSafeArea()
                        .transition(.opacity)
                        .onTapGesture { navigator.closeDrawer() }
                        .accessibilityLabel("Close menu")
                }

                DrawerView()
                    .frame(width: drawerWidth)
                    .frame(maxHeight: .infinity)
                    .background(Theme.background)
                    .offset(x: navigator.isDrawerOpen ? 0 : -drawerWidth)
                    .shadow(color: .black.opacity(navigator.isDrawerOpen ? 0.25 : 0), radius: 16, x: 4)
            }
            .gesture(edgeAndDragGesture(drawerWidth: drawerWidth))
        }
    }

    /// Swipe-from-left-edge to open; swipe-left on the open drawer to close.
    private func edgeAndDragGesture(drawerWidth: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 12)
            .onEnded { value in
                let dx = value.translation.width
                let startX = value.startLocation.x
                if !navigator.isDrawerOpen, startX < 24, dx > 60 {
                    navigator.openDrawer()
                } else if navigator.isDrawerOpen, dx < -60 {
                    navigator.closeDrawer()
                }
            }
    }

    private var contentStack: some View {
        NavigationStack(path: $navigator.path) {
            RouteContent(route: navigator.route)
                .navigationDestination(for: AppRoute.self) { pushed in
                    RouteContent(route: pushed, showsHamburger: false)
                }
        }
    }

    // MARK: iPad — split view

    private var iPadLayout: some View {
        NavigationSplitView {
            DrawerList(selection: Binding(
                get: { navigator.route },
                set: { navigator.select($0) }
            ))
            .navigationTitle("InjectBuddy")
        } detail: {
            NavigationStack(path: $navigator.path) {
                RouteContent(route: navigator.route, showsHamburger: false)
                    .navigationDestination(for: AppRoute.self) { pushed in
                        RouteContent(route: pushed, showsHamburger: false)
                    }
            }
        }
    }
}
