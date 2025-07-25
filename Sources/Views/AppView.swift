import AppCore
import ComposableArchitecture
import SwiftUI

// Platform imports removed - views are now in main module

/// Main AppView that delegates to platform-specific implementations
public struct AppView: View {
    let store: StoreOf<AppFeature>

    public init(store: StoreOf<AppFeature>) {
        self.store = store
    }

    public var body: some View {
        #if os(iOS)
            IOSAppView(store: store)
        #elseif os(macOS)
            MacOSAppView(store: store)
        #endif
    }
}

#if DEBUG
    struct AppView_Previews: PreviewProvider {
        static var previews: some View {
            var state = AppFeature.State()
            state.isOnboardingCompleted = true
            state.isAuthenticated = true

            return AppView(
                store: Store(
                    initialState: state
                ) {
                    AppFeature()
                        .dependency(\.biometricAuthenticationService, .previewValue)
                        .dependency(\.settingsManager, .previewValue)
                }
            )
            .preferredColorScheme(.dark)
        }
    }
#endif
