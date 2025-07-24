import AppCore
import ComposableArchitecture
import SwiftUI

// MARK: - Enhanced Menu View

struct EnhancedMenuView: View {
    let store: StoreOf<AppFeature>
    @Binding var isShowing: Bool
    @Binding var selectedMenuItem: AppFeature.MenuItem?

    @State private var profileImage: AppCore.PlatformImage?
    @State private var menuOffset: CGFloat = 300
    @Dependency(\.hapticManager) var hapticManager
    @Dependency(\.screenService) var screenService

    var body: some View {
        HStack(spacing: 0) {
            // Backdrop
            Color.clear
                .frame(width: screenService.mainScreenWidth() - 300)
                .contentShape(Rectangle())
                .onTapGesture {
                    withAnimation(AnimationSystem.Spring.smooth) {
                        isShowing = false
                    }
                }

            // Menu content with glassmorphism
            GlassmorphicView {
                VStack(spacing: 0) {
                    // Profile section
                    EnhancedProfileSection(profileImage: $profileImage)
                        .padding(Theme.Spacing.large)

                    Divider()
                        .background(Color.gray.opacity(0.3))

                    // Menu items with enhanced styling
                    ScrollView {
                        VStack(alignment: .leading, spacing: Theme.Spacing.small) {
                            WithViewStore(store, observe: { $0 }) { viewStore in
                                ForEach(AppFeature.MenuItem.allCases, id: \.self) { item in
                                    EnhancedMenuItemRow(
                                        item: item,
                                        isSelected: selectedMenuItem == item,
                                        action: {
                                            hapticManager.selection()
                                            withAnimation(AnimationSystem.Spring.smooth) {
                                                viewStore.send(.selectMenuItem(item))
                                                isShowing = false
                                            }
                                        }
                                    )
                                }
                            }
                        }
                        .padding(Theme.Spacing.medium)
                    }

                    Spacer()

                    // Footer with version info
                    VStack(alignment: .leading, spacing: Theme.Spacing.small) {
                        Divider()
                            .background(Color.gray.opacity(0.3))

                        HStack {
                            VStack(alignment: .leading) {
                                ResponsiveText(content: "AIKO v1.0.0", style: .caption2)
                                    .foregroundColor(.secondary)
                                ResponsiveText(
                                    content: "AI Contract Intelligence Officer",
                                    style: .caption2
                                )
                                .foregroundColor(.secondary)
                            }

                            Spacer()

                            // Theme toggle
                            Image(systemName: "moon.stars.fill")
                                .font(.title3)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(Theme.Spacing.large)
                }
            }
            .frame(width: 300)
            .offset(x: menuOffset)
            .onAppear {
                withAnimation(AnimationSystem.Spring.smooth) {
                    menuOffset = 0
                }
            }
            .onDisappear {
                menuOffset = 300
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Navigation Menu")
        .accessibilityAddTraits(.isModal)
    }
}

// MARK: - Enhanced Profile Section

struct EnhancedProfileSection: View {
    @Binding var profileImage: AppCore.PlatformImage?
    @Dependency(\.imageLoader) var imageLoader

    var body: some View {
        VStack(spacing: Theme.Spacing.medium) {
            // Profile image with animation
            ZStack {
                Circle()
                    .fill(
                        Theme.Colors.aikoPrimary.opacity(0.3)
                    )
                    .frame(width: 80, height: 80)

                if let profileImage {
                    imageLoader.createImage(profileImage)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 80, height: 80)
                        .clipShape(Circle())
                } else {
                    Image(systemName: "person.circle.fill")
                        .font(.system(size: 40))
                        .foregroundColor(.white)
                }
            }
            .shadow(color: Theme.Colors.aikoPrimary.opacity(0.3), radius: 8, y: 4)

            // User info
            VStack(spacing: 4) {
                ResponsiveText(content: "User", style: .title3)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)

                ResponsiveText(content: "user@example.com", style: .caption)
                    .foregroundColor(.secondary)
            }

            // Quick stats
            HStack(spacing: Theme.Spacing.extraLarge) {
                VStack {
                    ResponsiveText(content: "12", style: .title2)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                    ResponsiveText(content: "Projects", style: .caption2)
                        .foregroundColor(.secondary)
                }

                Divider()
                    .frame(height: 30)

                VStack {
                    ResponsiveText(content: "48", style: .title2)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                    ResponsiveText(content: "Documents", style: .caption2)
                        .foregroundColor(.secondary)
                }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Profile section")
    }
}

// MARK: - Enhanced Menu Item Row

struct EnhancedMenuItemRow: View {
    let item: AppFeature.MenuItem
    let isSelected: Bool
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        AnimatedButton(action: action) {
            HStack(spacing: Theme.Spacing.medium) {
                // Icon with animation
                Image(systemName: item.icon)
                    .font(.title3)
                    .foregroundColor(isSelected ? .white : .gray)
                    .frame(width: 24, height: 24)
                    .rotationEffect(.degrees(isHovered ? 10 : 0))

                // Label
                ResponsiveText(content: item.rawValue, style: .body)
                    .fontWeight(isSelected ? .medium : .regular)
                    .foregroundColor(isSelected ? .white : .gray)

                Spacer()

                // Selection indicator
                if isSelected {
                    Rectangle()
                        .fill(Theme.Colors.aikoPrimary)
                        .frame(width: 3)
                        .transition(.asymmetric(
                            insertion: .move(edge: .trailing).combined(with: .opacity),
                            removal: .opacity
                        ))
                }
            }
            .padding(.horizontal, Theme.Spacing.medium)
            .padding(.vertical, Theme.Spacing.small)
            .background(
                RoundedRectangle(cornerRadius: Theme.CornerRadius.md)
                    .fill(isSelected ? Theme.Colors.aikoPrimary.opacity(0.2) : Color.clear)
                    .animation(AnimationSystem.Spring.smooth, value: isSelected)
            )
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(AnimationSystem.microScale) {
                isHovered = hovering
            }
        }
        .accessibilityElement(
            label: item.rawValue,
            hint: isSelected ? "Currently selected" : "Tap to select",
            traits: [.isButton, isSelected ? .isSelected : []].reduce([]) { $0.union($1) }
        )
    }
}
