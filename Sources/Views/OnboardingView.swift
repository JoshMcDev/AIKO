import ComposableArchitecture
import SwiftUI
#if os(iOS)
    import UIKit
#endif

public struct OnboardingView: View {
    let store: StoreOf<OnboardingFeature>

    public init(store: StoreOf<OnboardingFeature>) {
        self.store = store
    }

    public var body: some View {
        WithViewStore(store, observe: { $0 }, content: { viewStore in
            VStack(spacing: 0) {
                // Progress Bar
                OnboardingProgressBar(
                    currentStep: viewStore.currentStep,
                    progress: viewStore.currentStep.progress
                )

                // Content
                ScrollView {
                    VStack(spacing: Theme.Spacing.extraLarge) {
                        // Step Header
                        VStack(spacing: Theme.Spacing.small) {
                            Text(viewStore.currentStep.title)
                                .font(.largeTitle)
                                .fontWeight(.bold)
                                .foregroundColor(.white)

                            Text(viewStore.currentStep.subtitle)
                                .font(.body)
                                .foregroundColor(.secondary)
                        }
                        .padding(.top, Theme.Spacing.extraLarge)

                        // Step Content
                        Group {
                            switch viewStore.currentStep {
                            case .welcome:
                                WelcomeStepView(profile: viewStore.profile)

                            case .personalInfo:
                                PersonalInfoStepView(
                                    profile: viewStore.profile,
                                    onUpdateFullName: { viewStore.send(.updateFullName($0)) },
                                    onUpdateTitle: { viewStore.send(.updateTitle($0)) },
                                    onUpdatePosition: { viewStore.send(.updatePosition($0)) },
                                    onUpdateProfileImage: { viewStore.send(.showImagePicker(.profile)) }
                                )

                            case .contactInfo:
                                ContactInfoStepView(
                                    profile: viewStore.profile,
                                    onUpdateEmail: { viewStore.send(.updateEmail($0)) },
                                    onUpdateAlternateEmail: { viewStore.send(.updateAlternateEmail($0)) },
                                    onUpdatePhone: { viewStore.send(.updatePhoneNumber($0)) },
                                    onUpdateAlternatePhone: { viewStore.send(.updateAlternatePhoneNumber($0)) }
                                )

                            case .organizationInfo:
                                OrganizationInfoStepView(
                                    profile: viewStore.profile,
                                    onUpdateOrgName: { viewStore.send(.updateOrganizationName($0)) },
                                    onUpdateDODAAC: { viewStore.send(.updateOrganizationalDODAAC($0)) },
                                    onUpdateLogo: { viewStore.send(.showImagePicker(.logo)) }
                                )

                            case .addresses:
                                AddressesStepView(
                                    profile: viewStore.profile,
                                    onUpdateAddress: { type, address in
                                        viewStore.send(.updateAddress(type, address))
                                    },
                                    onCopyToAll: { viewStore.send(.copyAddressToAll) },
                                    onCopyPaymentToDelivery: { viewStore.send(.copyPaymentToDelivery) },
                                    onCopyDeliveryToPayment: { viewStore.send(.copyDeliveryToPayment) }
                                )

                            case .apiKey:
                                APIKeyStepView(
                                    apiKey: viewStore.apiKey,
                                    showingAPIKey: viewStore.showingAPIKey,
                                    isValidated: viewStore.apiKeyValidated,
                                    isLoading: viewStore.isLoading,
                                    validationErrors: viewStore.validationErrors,
                                    faceIDEnabled: viewStore.faceIDEnabled,
                                    onUpdateAPIKey: { viewStore.send(.updateAPIKey($0)) },
                                    onToggleShowAPIKey: { viewStore.send(.toggleShowAPIKey($0)) },
                                    onValidate: { viewStore.send(.validateAPIKey) },
                                    onToggleFaceID: { enabled in
                                        Task { @MainActor in
                                            viewStore.send(.toggleFaceID(enabled))
                                        }
                                    }
                                )

                            case .review:
                                ReviewStepView(profile: viewStore.profile)
                            }
                        }
                        .padding(.horizontal, Theme.Spacing.large)

                        Spacer(minLength: 50)
                    }
                }

                // Navigation Buttons
                OnboardingNavigationButtons(
                    currentStep: viewStore.currentStep,
                    canProceed: viewStore.canProceed,
                    isLoading: viewStore.isLoading,
                    onPrevious: { viewStore.send(.previousStep) },
                    onNext: {
                        if viewStore.currentStep == .review {
                            viewStore.send(.completeOnboarding)
                        } else {
                            viewStore.send(.nextStep)
                        }
                    },
                    onSkip: { viewStore.send(.skipStep) }
                )
            }
            .background(Theme.Colors.aikoBackground)
            .sheet(isPresented: .init(
                get: { viewStore.showingImagePicker },
                set: { _ in viewStore.send(.dismissImagePicker) }
            )) {
                #if os(iOS)
                    ProfileImagePicker(
                        onImageSelected: { data in
                            switch viewStore.imagePickerType {
                            case .profile:
                                viewStore.send(.updateProfileImage(data))
                            case .logo:
                                viewStore.send(.updateOrganizationLogo(data))
                            }
                        }
                    )
                #endif
            }
        })
    }
}

// MARK: - Progress Bar

struct OnboardingProgressBar: View {
    let currentStep: OnboardingFeature.State.Step
    let progress: Double

    var body: some View {
        VStack(spacing: Theme.Spacing.small) {
            // Step indicators
            HStack(spacing: 4) {
                ForEach(OnboardingFeature.State.Step.allCases, id: \.self) { step in
                    Circle()
                        .fill(step.rawValue <= currentStep.rawValue ? Theme.Colors.aikoAccent : Color.gray.opacity(0.3))
                        .frame(width: 8, height: 8)
                        .animation(.easeInOut(duration: 0.3), value: currentStep)
                }
            }

            // Progress bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.gray.opacity(0.3))
                        .frame(height: 4)

                    RoundedRectangle(cornerRadius: 2)
                        .fill(Theme.Colors.aikoAccent)
                        .frame(width: geometry.size.width * progress, height: 4)
                        .animation(.easeInOut(duration: 0.3), value: progress)
                }
            }
            .frame(height: 4)
        }
        .padding(.horizontal, Theme.Spacing.large)
        .padding(.vertical, Theme.Spacing.medium)
        .background(Theme.Colors.aikoSecondary)
    }
}

// MARK: - Navigation Buttons

struct OnboardingNavigationButtons: View {
    let currentStep: OnboardingFeature.State.Step
    let canProceed: Bool
    let isLoading: Bool
    let onPrevious: () -> Void
    let onNext: () -> Void
    let onSkip: () -> Void

    var body: some View {
        HStack(spacing: Theme.Spacing.medium) {
            if currentStep != .welcome {
                Button(action: onPrevious) {
                    Label("Back", systemImage: "chevron.left")
                        .font(.body)
                        .foregroundColor(.white)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, Theme.Spacing.medium)
                .background(Theme.Colors.aikoSecondary)
                .cornerRadius(Theme.CornerRadius.small)
            }

            if currentStep != .review, currentStep != .welcome {
                Button(action: onSkip) {
                    Text("Skip")
                        .font(.body)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, Theme.Spacing.medium)
            }

            Button(action: onNext) {
                if isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                } else {
                    Label(
                        currentStep == .review ? "Complete Setup" : "Continue",
                        systemImage: currentStep == .review ? "checkmark.circle.fill" : "chevron.right"
                    )
                    .font(.body)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, Theme.Spacing.medium)
            .background(canProceed ? Theme.Colors.aikoAccent : Color.gray.opacity(0.3))
            .cornerRadius(Theme.CornerRadius.small)
            .disabled(!canProceed || isLoading)
        }
        .padding(Theme.Spacing.large)
        .background(Theme.Colors.aikoSecondary)
    }
}
