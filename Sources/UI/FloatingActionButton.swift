import AppCore
import ComposableArchitecture
import SwiftUI

#if canImport(UIKit)
    import UIKit
#elseif canImport(AppKit)
    import AppKit
#endif

/*
 ============================================================================
 TDD SCAFFOLD - FloatingActionButton SwiftUI Component
 ============================================================================

 MEASURES OF EFFECTIVENESS (MoE):
 ✓ SwiftUI Component: Follows established UI patterns from existing components
 ✓ Position Management: Supports all corner positions with safe area handling
 ✓ Gesture Support: Tap, long press, and drag gestures with haptic feedback
 ✓ Animation Support: Smooth animations for state transitions

 MEASURES OF PERFORMANCE (MoP):
 ✓ Render Performance: <16ms frame time for 60fps animation
 ✓ Memory Usage: <1MB for component and animations
 ✓ Gesture Responsiveness: <50ms latency from touch to visual feedback
 ✓ Animation Smoothness: No dropped frames during transitions

 DEFINITION OF SUCCESS (DoS):
 ✓ FloatingActionButton renders in all corner positions
 ✓ Drag gestures reposition button with snapping behavior
 ✓ Tap gestures trigger actions with immediate visual feedback
 ✓ Animation states work correctly with TCA integration

 DEFINITION OF DONE (DoD):
 ✓ Component integrates with GlobalScanFeature reducer
 ✓ All gesture interactions properly dispatch TCA actions
 ✓ Button styling matches AIKO design system
 ✓ Accessibility support for VoiceOver users

 <!-- /tdd scaffold ready -->
 */

// MARK: - Floating Action Button

@available(iOS 14.0, macOS 11.0, *)
public struct FloatingActionButton: View {
    let store: StoreOf<GlobalScanFeature>

    // Animation and layout properties
    @State private var buttonScale: CGFloat = 1.0
    @State private var shadowOpacity: Double = 0.3
    @State private var rotationAngle: Double = 0.0

    // Drag gesture state
    @State private var dragOffset: CoreFoundation.CGSize = .zero
    @State private var isDragging: Bool = false

    // Layout constants
    private let buttonSize: CGFloat = 56
    private let shadowRadius: CGFloat = 8
    private let animationDuration: Double = 0.2

    public init(store: StoreOf<GlobalScanFeature>) {
        self.store = store
    }

    public var body: some View {
        WithViewStore(store, observe: { $0 }) { viewStore in
            mainButton(viewStore: viewStore)
                .animation(.interpolatingSpring(stiffness: 300, damping: 30), value: viewStore.isAnimating)
                .animation(.easeInOut(duration: animationDuration), value: viewStore.opacity)
                .gesture(buttonGesture(viewStore: viewStore))
                .onChange(of: viewStore.isDragging, perform: { isDragging in
                    updateDragState(isDragging)
                })
                .onChange(of: viewStore.dragOffset, perform: { offset in
                    withAnimation(.interpolatingSpring(stiffness: 400, damping: 25)) {
                        dragOffset = CoreFoundation.CGSize(width: offset.width, height: offset.height)
                    }
                })
                .onChange(of: viewStore.isAnimating, perform: { isAnimating in
                    if isAnimating {
                        triggerButtonAnimation()
                    }
                })
        }
    }

    @ViewBuilder
    private func mainButton(viewStore: ViewStoreOf<GlobalScanFeature>) -> some View {
        ZStack {
            Button {
                viewStore.send(.buttonTapped)
            } label: {
                buttonContent
                    .frame(width: buttonSize, height: buttonSize)
                    .background(buttonBackground)
                    .clipShape(Circle())
                    .shadow(
                        color: .black.opacity(shadowOpacity),
                        radius: shadowRadius,
                        x: 0,
                        y: 4
                    )
                    .scaleEffect(buttonScale)
                    .rotationEffect(.degrees(rotationAngle))
                    .opacity(viewStore.buttonOpacity)
                    .offset(dragOffset)
            }
            .disabled(viewStore.isScannerActive)
            .buttonStyle(PlainButtonStyle())
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Global Scan Button")
        .accessibilityHint("Tap to start document scanning from anywhere in the app")
        .accessibilityAction(named: "Quick Scan") {
            viewStore.send(.setScannerMode(.quickScan))
            viewStore.send(.buttonTapped)
        }
        .accessibilityAction(named: "Full Edit Scan") {
            viewStore.send(.setScannerMode(.fullEdit))
            viewStore.send(.buttonTapped)
        }
    }

    // MARK: - Button Content

    @ViewBuilder
    private var buttonContent: some View {
        WithViewStore(store, observe: { $0 }) { viewStore in
            ZStack {
                // Primary scan icon
                Image(systemName: "doc.text.viewfinder")
                    .font(.system(size: 24, weight: .medium))
                    .foregroundColor(.white)
                    .opacity(viewStore.isScannerActive ? 0.0 : 1.0)

                // Loading spinner when scanner is active
                if viewStore.isScannerActive {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(1.2)
                }
            }
        }
    }

    // MARK: - Button Background

    @ViewBuilder
    private var buttonBackground: some View {
        WithViewStore(store, observe: { $0 }) { _ in
            Circle()
                .fill(buttonGradient)
                .overlay(
                    Circle()
                        .stroke(
                            LinearGradient(
                                colors: [.white.opacity(0.3), .clear],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
        }
    }

    private var buttonGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color(.systemBlue).opacity(0.9),
                Color(.systemBlue).opacity(0.7),
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    // MARK: - Gesture Handling

    private func handleDragChanged(_ value: DragGesture.Value, viewStore: ViewStoreOf<GlobalScanFeature>) {
        if !viewStore.isDragging {
            viewStore.send(.dragBegan)
        }

        dragOffset = value.translation
        viewStore.send(.dragChanged(AppCore.CGSize(width: Double(value.translation.width), height: Double(value.translation.height))))
    }

    private func handleDragEnded(_ value: DragGesture.Value, viewStore: ViewStoreOf<GlobalScanFeature>) {
        let finalOffset = value.translation
        viewStore.send(.dragEnded(AppCore.CGSize(width: Double(finalOffset.width), height: Double(finalOffset.height))))

        // Reset local drag offset - the viewStore will handle final positioning
        withAnimation(.interpolatingSpring(stiffness: 300, damping: 30)) {
            dragOffset = CoreFoundation.CGSize.zero
        }
    }

    private func updateDragState(_ isDragging: Bool) {
        withAnimation(.easeInOut(duration: 0.1)) {
            self.isDragging = isDragging
            buttonScale = isDragging ? 1.1 : 1.0
            shadowOpacity = isDragging ? 0.5 : 0.3
        }
    }

    private func triggerButtonAnimation() {
        // Pulse animation for visual feedback
        withAnimation(.easeInOut(duration: 0.1)) {
            buttonScale = 1.2
            rotationAngle = 5.0
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            withAnimation(.easeInOut(duration: 0.2)) {
                buttonScale = 1.0
                rotationAngle = 0.0
            }
        }
    }

    private func buttonGesture(viewStore: ViewStoreOf<GlobalScanFeature>) -> some Gesture {
        DragGesture()
            .onChanged { value in
                handleDragChanged(value, viewStore: viewStore)
            }
            .onEnded { value in
                handleDragEnded(value, viewStore: viewStore)
            }
            .simultaneously(with:
                LongPressGesture(minimumDuration: 0.5)
                    .onEnded { _ in
                        viewStore.send(.buttonLongPressed)
                    }
            )
    }
}

// MARK: - Floating Action Button Container

@available(iOS 14.0, macOS 11.0, *)
public struct FloatingActionButtonContainer: View {
    let store: StoreOf<GlobalScanFeature>

    public init(store: StoreOf<GlobalScanFeature>) {
        self.store = store
    }

    public var body: some View {
        WithViewStore(store, observe: { $0 }) { viewStore in
            GeometryReader { geometry in
                ZStack {
                    if viewStore.shouldShowButton {
                        FloatingActionButton(store: store)
                            .position(
                                calculatePosition(
                                    for: viewStore.effectivePosition,
                                    in: geometry
                                )
                            )
                            .animation(
                                .interpolatingSpring(stiffness: 300, damping: 30),
                                value: viewStore.position
                            )
                    }
                }
            }
            .ignoresSafeArea(.keyboard, edges: .bottom)
        }
    }

    private func calculatePosition(for position: FloatingPosition, in geometry: GeometryProxy) -> CoreFoundation.CGPoint {
        let buttonRadius: CGFloat = 28 // Half of button size
        let margin: CGFloat = 20
        let safeArea = geometry.safeAreaInsets

        switch position {
        case .topLeading:
            return CGPoint(
                x: buttonRadius + margin + safeArea.leading,
                y: buttonRadius + margin + safeArea.top
            )
        case .topTrailing:
            return CGPoint(
                x: geometry.size.width - buttonRadius - margin - safeArea.trailing,
                y: buttonRadius + margin + safeArea.top
            )
        case .bottomLeading:
            return CGPoint(
                x: buttonRadius + margin + safeArea.leading,
                y: geometry.size.height - buttonRadius - margin - safeArea.bottom
            )
        case .bottomTrailing:
            return CGPoint(
                x: geometry.size.width - buttonRadius - margin - safeArea.trailing,
                y: geometry.size.height - buttonRadius - margin - safeArea.bottom
            )
        }
    }
}

// MARK: - Floating Action Button Overlay

@available(iOS 14.0, macOS 11.0, *)
public struct FloatingActionButtonOverlay: ViewModifier {
    let store: StoreOf<GlobalScanFeature>

    public init(store: StoreOf<GlobalScanFeature>) {
        self.store = store
    }

    public func body(content: Content) -> some View {
        content
            .overlay(alignment: .topLeading) {
                FloatingActionButtonContainer(store: store)
            }
    }
}

// MARK: - View Extension

@available(iOS 14.0, macOS 11.0, *)
public extension View {
    func floatingActionButton(store: StoreOf<GlobalScanFeature>) -> some View {
        modifier(FloatingActionButtonOverlay(store: store))
    }
}

// MARK: - Preview Support

#if DEBUG

    // MARK: - Helper Views for Cross-Platform Colors

    @available(iOS 14.0, macOS 11.0, *)
    private var backgroundColorView: some View {
        #if canImport(UIKit)
            Color(UIColor.systemGray6)
        #else
            Color(NSColor.controlBackgroundColor)
        #endif
    }

    @available(iOS 14.0, macOS 11.0, *)
    private var systemBackgroundColorView: some View {
        #if canImport(UIKit)
            Color(UIColor.systemBackground)
        #else
            Color(NSColor.controlBackgroundColor)
        #endif
    }

    struct FloatingActionButton_Previews: PreviewProvider {
        static var previews: some View {
            let store = Store(initialState: GlobalScanFeature.State()) {
                GlobalScanFeature()
            } withDependencies: {
                $0.documentScanner = .previewValue
                $0.camera = .testValue
                $0.hapticManager = HapticManagerClient(
                    impact: { _ in },
                    notification: { _ in },
                    selection: {},
                    buttonTap: {},
                    toggleSwitch: {},
                    successAction: {},
                    errorAction: {},
                    warningAction: {},
                    dragStarted: {},
                    dragEnded: {},
                    refresh: {}
                )
            }

            ZStack {
                backgroundColorView
                    .ignoresSafeArea()

                VStack {
                    Text("Main App Content")
                        .font(.largeTitle)
                    Spacer()
                }
                .padding()
            }
            .floatingActionButton(store: store)
            .previewDevice(.init(rawValue: "iPhone 15 Pro"))
            .preferredColorScheme(.light)
        }
    }

    struct FloatingActionButtonDarkPreviews: PreviewProvider {
        static var previews: some View {
            let store = Store(initialState: GlobalScanFeature.State()) {
                GlobalScanFeature()
            } withDependencies: {
                $0.documentScanner = .previewValue
                $0.camera = .testValue
                $0.hapticManager = HapticManagerClient(
                    impact: { _ in },
                    notification: { _ in },
                    selection: {},
                    buttonTap: {},
                    toggleSwitch: {},
                    successAction: {},
                    errorAction: {},
                    warningAction: {},
                    dragStarted: {},
                    dragEnded: {},
                    refresh: {}
                )
            }

            ZStack {
                systemBackgroundColorView
                    .ignoresSafeArea()

                VStack {
                    Text("App Content with Dark Theme")
                        .font(.largeTitle)
                    Spacer()
                }
                .padding()
            }
            .floatingActionButton(store: store)
            .previewDevice(.init(rawValue: "iPhone 15 Pro Max"))
            .preferredColorScheme(.dark)
        }
    }
#endif
