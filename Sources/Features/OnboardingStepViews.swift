import AppCore
import ComposableArchitecture
import SwiftUI

// MARK: - Welcome Step

struct WelcomeStepView: View {
    let profile: UserProfile

    var body: some View {
        VStack(spacing: Theme.Spacing.extraLarge) {
            Image(systemName: "doc.text.fill")
                .font(.system(size: 80))
                .foregroundColor(Theme.Colors.aikoAccent)
                .padding(.bottom, Theme.Spacing.extraLarge)

            VStack(spacing: Theme.Spacing.medium) {
                Text("Welcome to AIKO")
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundColor(.white)

                Text("Your AI Contract Intelligence Officer")
                    .font(.headline)
                    .foregroundColor(Theme.Colors.aikoAccent)
            }

            VStack(alignment: .leading, spacing: Theme.Spacing.large) {
                FeatureRow(
                    icon: "sparkles",
                    title: "AI-Powered Document Generation",
                    description: "Create compliant contracting documents in seconds"
                )

                FeatureRow(
                    icon: "shield.fill",
                    title: "FAR Compliance Built-In",
                    description: "All documents follow Federal Acquisition Regulations"
                )

                FeatureRow(
                    icon: "person.fill",
                    title: "Personalized to You",
                    description: "Your profile data auto-fills in all documents"
                )

                FeatureRow(
                    icon: "clock.fill",
                    title: "Save Hours of Work",
                    description: "Generate complete contract packages instantly"
                )
            }
            .padding(.vertical, Theme.Spacing.extraLarge)

            Text("Let's set up your profile to get started")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
    }
}

struct FeatureRow: View {
    let icon: String
    let title: String
    let description: String

    var body: some View {
        HStack(alignment: .top, spacing: Theme.Spacing.medium) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(Theme.Colors.aikoAccent)
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                    .foregroundColor(.white)

                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
}

// MARK: - Personal Info Step

struct PersonalInfoStepView: View {
    let profile: UserProfile
    let onUpdateFullName: (String) -> Void
    let onUpdateTitle: (String) -> Void
    let onUpdatePosition: (String) -> Void
    let onUpdateProfileImage: () -> Void

    @State private var fullName: String = ""
    @State private var title: String = ""
    @State private var position: String = ""
    @Dependency(\.imageLoader) var imageLoader

    var body: some View {
        VStack(spacing: Theme.Spacing.extraLarge) {
            // Profile Image
            Button(action: onUpdateProfileImage) {
                ZStack {
                    if let imageData = profile.profileImageData,
                       let image = imageLoader.loadImage(imageData) {
                        image
                            .resizable()
                            .scaledToFill()
                            .frame(width: 120, height: 120)
                            .clipShape(Circle())
                    } else {
                        Circle()
                            .fill(Theme.Colors.aikoSecondary)
                            .frame(width: 120, height: 120)
                            .overlay(
                                VStack {
                                    Image(systemName: "camera.fill")
                                        .font(.title2)
                                        .foregroundColor(.white.opacity(0.7))
                                    Text("Add Photo")
                                        .font(.caption)
                                        .foregroundColor(.white.opacity(0.7))
                                }
                            )
                    }
                }
            }
            .padding(.bottom, Theme.Spacing.large)

            VStack(spacing: Theme.Spacing.large) {
                OnboardingTextField(
                    title: "Full Name",
                    placeholder: "John Smith",
                    text: $fullName,
                    isRequired: true,
                    onCommit: onUpdateFullName
                )

                OnboardingTextField(
                    title: "Title",
                    placeholder: "Mr. / Mrs.",
                    text: $title,
                    isRequired: false,
                    onCommit: onUpdateTitle
                )

                OnboardingTextField(
                    title: "Position",
                    placeholder: "Contracting Officer",
                    text: $position,
                    isRequired: false,
                    onCommit: onUpdatePosition
                )
            }

            InfoBox(
                icon: "sparkles",
                text: "Complete your profile to save time! Your information automatically fills into all generated documents, so you won't need to enter the same details repeatedly."
            )
        }
        .onAppear {
            fullName = profile.fullName
            title = profile.title
            position = profile.position
        }
    }
}

// MARK: - Contact Info Step

struct ContactInfoStepView: View {
    let profile: UserProfile
    let onUpdateEmail: (String) -> Void
    let onUpdateAlternateEmail: (String) -> Void
    let onUpdatePhone: (String) -> Void
    let onUpdateAlternatePhone: (String) -> Void

    @State private var email: String = ""
    @State private var alternateEmail: String = ""
    @State private var phone: String = ""
    @State private var alternatePhone: String = ""

    var body: some View {
        VStack(spacing: Theme.Spacing.large) {
            OnboardingTextField(
                title: "Email",
                placeholder: "john.smith@agency.gov",
                text: $email,
                isRequired: true,
                onCommit: onUpdateEmail
            )

            OnboardingTextField(
                title: "Alternate Email",
                placeholder: "john.smith@contractor.com",
                text: $alternateEmail,
                onCommit: onUpdateAlternateEmail
            )

            OnboardingTextField(
                title: "Phone Number",
                placeholder: "(202) 555-1234",
                text: $phone,
                isRequired: false,
                onCommit: onUpdatePhone
            )

            OnboardingTextField(
                title: "Alternate Phone",
                placeholder: "(202) 555-5678",
                text: $alternatePhone,
                onCommit: onUpdateAlternatePhone
            )

            InfoBox(
                icon: "info.circle.fill",
                text: "Your contact information is used in document generation."
            )
        }
        .onAppear {
            email = profile.email
            alternateEmail = profile.alternateEmail
            phone = profile.phoneNumber
            alternatePhone = profile.alternatePhoneNumber
        }
    }
}

// MARK: - Organization Info Step

struct OrganizationInfoStepView: View {
    let profile: UserProfile
    let onUpdateOrgName: (String) -> Void
    let onUpdateDODAAC: (String) -> Void
    let onUpdateLogo: () -> Void

    @State private var orgName: String = ""
    @State private var dodaac: String = ""
    @Dependency(\.imageLoader) var imageLoader

    var body: some View {
        VStack(spacing: Theme.Spacing.large) {
            OnboardingTextField(
                title: "Organization Name",
                placeholder: "Department of Defense",
                text: $orgName,
                isRequired: false,
                onCommit: onUpdateOrgName
            )

            OnboardingTextField(
                title: "DODAAC",
                placeholder: "ABC123",
                text: $dodaac,
                isRequired: false,
                characterLimit: 6,
                onCommit: onUpdateDODAAC
            )

            // Organization Logo
            VStack(alignment: .leading, spacing: Theme.Spacing.small) {
                Text("Organization Logo")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Button(action: onUpdateLogo) {
                    if let logoData = profile.organizationLogoData,
                       let image = imageLoader.loadImage(logoData) {
                        image
                            .resizable()
                            .scaledToFit()
                            .frame(height: 80)
                            .cornerRadius(Theme.CornerRadius.small)
                    } else {
                        RoundedRectangle(cornerRadius: Theme.CornerRadius.small)
                            .fill(Theme.Colors.aikoSecondary)
                            .frame(height: 80)
                            .overlay(
                                VStack {
                                    Image(systemName: "building.2")
                                        .font(.title)
                                        .foregroundColor(.white.opacity(0.5))
                                    Text("Add Logo")
                                        .font(.caption)
                                        .foregroundColor(.white.opacity(0.5))
                                }
                            )
                    }
                }
            }

            InfoBox(
                icon: "info.circle.fill",
                text: "DODAAC (Department of Defense Activity Address Code) is a 6-character code that identifies your organization. This information populates automatically in all your contracting documents."
            )
        }
        .onAppear {
            orgName = profile.organizationName
            dodaac = profile.organizationalDODAAC
        }
    }
}

// MARK: - Addresses Step

struct AddressesStepView: View {
    let profile: UserProfile
    let onUpdateAddress: (ProfileFeature.State.AddressType, Address) -> Void
    let onCopyToAll: () -> Void
    let onCopyPaymentToDelivery: () -> Void
    let onCopyDeliveryToPayment: () -> Void

    @State private var selectedTab: ProfileFeature.State.AddressType = .administeredBy

    var body: some View {
        VStack(spacing: Theme.Spacing.large) {
            // Tab selector
            HStack(spacing: 0) {
                ForEach(ProfileFeature.State.AddressType.allCases, id: \.self) { type in
                    Button(action: { selectedTab = type }, label: {
                        Text(type.rawValue)
                            .font(.caption)
                            .fontWeight(selectedTab == type ? .semibold : .regular)
                            .foregroundColor(selectedTab == type ? .white : .secondary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, Theme.Spacing.small)
                            .background(
                                selectedTab == type ? Theme.Colors.aikoAccent : Color.clear
                            )
                    })
                }
            }
            .background(Theme.Colors.aikoSecondary)
            .cornerRadius(Theme.CornerRadius.small)

            // Address form
            OnboardingAddressForm(
                address: getAddress(for: selectedTab),
                isRequired: false,
                onUpdate: { address in
                    onUpdateAddress(selectedTab, address)
                }
            )

            // Copy buttons
            if selectedTab == .administeredBy {
                Button(action: onCopyToAll) {
                    Label("Copy to Payment & Delivery", systemImage: "doc.on.doc")
                        .font(.caption)
                        .foregroundColor(.blue)
                }
                .frame(maxWidth: .infinity, alignment: .trailing)
            } else if selectedTab == .payment {
                Button(action: onCopyPaymentToDelivery) {
                    Label("Copy to Delivery", systemImage: "doc.on.doc")
                        .font(.caption)
                        .foregroundColor(.blue)
                }
                .frame(maxWidth: .infinity, alignment: .trailing)
            } else if selectedTab == .delivery {
                Button(action: onCopyDeliveryToPayment) {
                    Label("Copy to Payment", systemImage: "doc.on.doc")
                        .font(.caption)
                        .foregroundColor(.blue)
                }
                .frame(maxWidth: .infinity, alignment: .trailing)
            }

            InfoBox(
                icon: "info.circle.fill",
                text: "All addresses are optional. These addresses automatically populate in your documents when needed. You can use the description field for special instructions."
            )
        }
    }

    func getAddress(for type: ProfileFeature.State.AddressType) -> Address {
        switch type {
        case .administeredBy:
            profile.defaultAdministeredByAddress
        case .payment:
            profile.defaultPaymentAddress
        case .delivery:
            profile.defaultDeliveryAddress
        }
    }
}

// MARK: - Review Step

struct ReviewStepView: View {
    let profile: UserProfile
    @Dependency(\.imageLoader) var imageLoader

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.extraLarge) {
            // Profile summary
            HStack(spacing: Theme.Spacing.large) {
                if let imageData = profile.profileImageData,
                   let image = imageLoader.loadImage(imageData) {
                    image
                        .resizable()
                        .scaledToFill()
                        .frame(width: 60, height: 60)
                        .clipShape(Circle())
                } else {
                    Circle()
                        .fill(Theme.Colors.aikoSecondary)
                        .frame(width: 60, height: 60)
                        .overlay(
                            Image(systemName: "person.fill")
                                .foregroundColor(.white.opacity(0.5))
                        )
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(profile.fullName.isEmpty ? "Name not set" : profile.fullName)
                        .font(.headline)
                        .foregroundColor(.white)

                    Text(profile.position.isEmpty ? "Position not set" : profile.position)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }

                Spacer()
            }

            // Review sections
            ReviewSection(title: "Contact Information") {
                ReviewRow(label: "Email", value: profile.email)
                ReviewRow(label: "Phone", value: profile.phoneNumber)
                if !profile.alternateEmail.isEmpty {
                    ReviewRow(label: "Alt Email", value: profile.alternateEmail)
                }
                if !profile.alternatePhoneNumber.isEmpty {
                    ReviewRow(label: "Alt Phone", value: profile.alternatePhoneNumber)
                }
            }

            ReviewSection(title: "Organization") {
                ReviewRow(label: "Name", value: profile.organizationName)
                ReviewRow(label: "DODAAC", value: profile.organizationalDODAAC)
            }

            ReviewSection(title: "Default Addresses") {
                if profile.defaultAdministeredByAddress.isComplete {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Administered By")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(profile.defaultAdministeredByAddress.formatted)
                            .font(.caption)
                            .foregroundColor(.white)
                    }
                }

                if profile.defaultPaymentAddress.isComplete {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Payment")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(profile.defaultPaymentAddress.formatted)
                            .font(.caption)
                            .foregroundColor(.white)
                    }
                }

                if profile.defaultDeliveryAddress.isComplete {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Delivery")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(profile.defaultDeliveryAddress.formatted)
                            .font(.caption)
                            .foregroundColor(.white)
                    }
                }
            }

            // Completion status
            ProfileCompletionView(profile: profile)

            Text("You can edit your profile anytime from the menu")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
        }
    }
}

// MARK: - API Key Step

struct APIKeyStepView: View {
    let apiKey: String
    let showingAPIKey: Bool
    let isValidated: Bool
    let isLoading: Bool
    let validationErrors: [String]
    let faceIDEnabled: Bool
    let onUpdateAPIKey: (String) -> Void
    let onToggleShowAPIKey: (Bool) -> Void
    let onValidate: () -> Void
    let onToggleFaceID: @Sendable (Bool) -> Void

    @State private var localAPIKey: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.extraLarge) {
            // Instructions
            VStack(alignment: .leading, spacing: Theme.Spacing.medium) {
                Text("To generate documents with AI, you'll need an Anthropic API key.")
                    .font(.body)
                    .foregroundColor(.white)

                Text("You can get your API key from:")
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                if let apiURL = URL(string: "https://console.anthropic.com/api") {
                    Link(destination: apiURL) {
                    HStack {
                        Image(systemName: "link")
                        Text("console.anthropic.com/api")
                        Image(systemName: "arrow.up.right.square")
                    }
                    .font(.subheadline)
                    .foregroundColor(Theme.Colors.aikoAccent)
                    }
                    .padding(.vertical, Theme.Spacing.extraSmall)
                }
            }

            // API Key Input
            VStack(alignment: .leading, spacing: Theme.Spacing.small) {
                HStack {
                    Text("API Key")
                        .font(.headline)
                        .foregroundColor(.white)

                    Text("(Required)")
                        .font(.caption)
                        .foregroundColor(Theme.Colors.aikoError)
                }

                HStack {
                    Group {
                        if showingAPIKey {
                            TextField("sk-ant-...", text: Binding(
                                get: { localAPIKey },
                                set: { newValue in
                                    localAPIKey = newValue
                                    onUpdateAPIKey(newValue)
                                }
                            ))
                        } else {
                            SecureField("sk-ant-...", text: Binding(
                                get: { localAPIKey },
                                set: { newValue in
                                    localAPIKey = newValue
                                    onUpdateAPIKey(newValue)
                                }
                            ))
                        }
                    }
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .disabled(isLoading)

                    Button(action: { onToggleShowAPIKey(!showingAPIKey) }, label: {
                        Image(systemName: showingAPIKey ? "eye.slash" : "eye")
                            .foregroundColor(.secondary)
                    })

                    Button(action: onValidate) {
                        if isLoading {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .scaleEffect(0.8)
                        } else {
                            Text("Validate")
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(localAPIKey.isEmpty || isLoading)
                }

                if isValidated {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text("API key validated successfully")
                            .font(.caption)
                            .foregroundColor(.green)
                    }
                }

                ForEach(validationErrors, id: \.self) { error in
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(Theme.Colors.aikoError)
                        Text(error)
                            .font(.caption)
                            .foregroundColor(Theme.Colors.aikoError)
                    }
                }

                Text("Your API key is stored securely in the system keychain")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            // Info box
            VStack(alignment: .leading, spacing: Theme.Spacing.small) {
                HStack {
                    Image(systemName: "info.circle")
                        .foregroundColor(Theme.Colors.aikoAccent)
                    Text("Why do I need an API key?")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                }

                Text("AIKO uses Claude AI to analyze requirements and generate compliant contract documents. The API key allows secure communication with Anthropic's services.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: Theme.CornerRadius.medium)
                    .fill(Theme.Colors.aikoSecondary.opacity(0.3))
            )

            // Face ID Section
            faceIDSection(isEnabled: faceIDEnabled, onToggle: onToggleFaceID)
        }
        .onAppear {
            localAPIKey = apiKey
        }
    }
}

// Extension to add Face ID section
extension APIKeyStepView {
    @ViewBuilder
    func faceIDSection(isEnabled: Bool, onToggle: @escaping @Sendable (Bool) -> Void) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.small) {
            HStack {
                Image(systemName: "faceid")
                    .font(.title2)
                    .foregroundColor(Theme.Colors.aikoAccent)
                Text("Face ID Authentication")
                    .font(.headline)
                    .foregroundColor(.white)
            }

            Toggle("Enable Face ID for app access", isOn: Binding(
                get: { isEnabled },
                set: onToggle
            ))
            .toggleStyle(SwitchToggleStyle(tint: Theme.Colors.aikoAccent))

            Text("Use Face ID to quickly and securely access AIKO")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: Theme.CornerRadius.medium)
                .fill(Theme.Colors.aikoSecondary.opacity(0.3))
        )
    }
}

// MARK: - Supporting Views

struct OnboardingTextField: View {
    let title: String
    let placeholder: String
    @Binding var text: String
    var isRequired: Bool = false
    var keyboardType: PlatformKeyboardType = .default
    var characterLimit: Int?
    let onCommit: (String) -> Void
    @Dependency(\.keyboardService) var keyboardService

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)

                if isRequired {
                    Text("*")
                        .font(.caption)
                        .foregroundColor(.red)
                }

                Spacer()

                if let limit = characterLimit {
                    Text("\(text.count)/\(limit)")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }

            TextField("", text: $text, prompt: Text("...").foregroundColor(.gray))
                .textFieldStyle(PlainTextFieldStyle())
                .font(.body)
                .foregroundColor(.white)
                .padding(Theme.Spacing.medium)
                .background(
                    RoundedRectangle(cornerRadius: Theme.CornerRadius.small)
                        .fill(Theme.Colors.aikoSecondary)
                )
                .keyboardConfiguration(keyboardType, supportsTypes: keyboardService.supportsKeyboardTypes())
                .onChange(of: text) { newValue in
                    if let limit = characterLimit, newValue.count > limit {
                        text = String(newValue.prefix(limit))
                    }
                    onCommit(text)
                }
        }
    }
}

struct OnboardingTextEditor: View {
    let title: String
    let placeholder: String
    @Binding var text: String
    let onCommit: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)

            ZStack(alignment: .topLeading) {
                if text.isEmpty {
                    Text("...")
                        .font(.body)
                        .foregroundColor(.gray)
                        .padding(Theme.Spacing.medium)
                }

                TextEditor(text: $text)
                    .font(.body)
                    .foregroundColor(.white)
                    .scrollContentBackground(.hidden)
                    .padding(Theme.Spacing.small)
                    .frame(minHeight: 100)
            }
            .background(
                RoundedRectangle(cornerRadius: Theme.CornerRadius.sm)
                    .fill(Theme.Colors.aikoSecondary)
            )
            .onChange(of: text) { _ in
                onCommit(text)
            }
        }
    }
}

struct OnboardingAddressForm: View {
    let address: Address
    let isRequired: Bool
    let onUpdate: (Address) -> Void

    @State private var freeText: String = ""
    @State private var street1: String = ""
    @State private var street2: String = ""
    @State private var city: String = ""
    @State private var state: String = ""
    @State private var zipCode: String = ""
    @State private var country: String = "United States"
    @State private var phone: String = ""
    @State private var email: String = ""

    var body: some View {
        VStack(spacing: Theme.Spacing.medium) {
            OnboardingTextEditor(
                title: "Address Description",
                placeholder: "Enter any special instructions or notes about this address...",
                text: $freeText,
                onCommit: { _ in updateAddress() }
            )

            OnboardingTextField(
                title: "Street Address 1",
                placeholder: "123 Main Street",
                text: $street1,
                isRequired: false,
                onCommit: { _ in updateAddress() }
            )

            OnboardingTextField(
                title: "Street Address 2",
                placeholder: "Suite 100",
                text: $street2,
                onCommit: { _ in updateAddress() }
            )

            HStack(spacing: Theme.Spacing.medium) {
                OnboardingTextField(
                    title: "City",
                    placeholder: "Washington",
                    text: $city,
                    isRequired: false,
                    onCommit: { _ in updateAddress() }
                )

                OnboardingTextField(
                    title: "State",
                    placeholder: "DC",
                    text: $state,
                    isRequired: false,
                    characterLimit: 2,
                    onCommit: { _ in updateAddress() }
                )
                .frame(maxWidth: 80)
            }

            HStack(spacing: Theme.Spacing.medium) {
                OnboardingTextField(
                    title: "ZIP Code",
                    placeholder: "20001",
                    text: $zipCode,
                    isRequired: false,
                    characterLimit: 10,
                    onCommit: { _ in updateAddress() }
                )
                .frame(maxWidth: 120)

                OnboardingTextField(
                    title: "Country",
                    placeholder: "United States",
                    text: $country,
                    onCommit: { _ in updateAddress() }
                )
            }

            OnboardingTextField(
                title: "Phone Number",
                placeholder: "Different from profile phone",
                text: $phone,
                isRequired: false,
                onCommit: { _ in updateAddress() }
            )

            OnboardingTextField(
                title: "Email Address",
                placeholder: "Different from profile email",
                text: $email,
                isRequired: false,
                keyboardType: .email,
                onCommit: { _ in updateAddress() }
            )
        }
        .onAppear {
            freeText = address.freeText
            street1 = address.street1
            street2 = address.street2
            city = address.city
            state = address.state
            zipCode = address.zipCode
            country = address.country
            phone = address.phone
            email = address.email
        }
    }

    func updateAddress() {
        let newAddress = Address(
            freeText: freeText,
            street1: street1,
            street2: street2,
            city: city,
            state: state,
            zipCode: zipCode,
            country: country,
            phone: phone,
            email: email
        )
        onUpdate(newAddress)
    }
}

struct ReviewSection<Content: View>: View {
    let title: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.small) {
            Text(title)
                .font(.headline)
                .foregroundColor(.white)

            VStack(alignment: .leading, spacing: Theme.Spacing.small) {
                content()
            }
            .padding(Theme.Spacing.medium)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: Theme.CornerRadius.small)
                    .fill(Theme.Colors.aikoSecondary)
            )
        }
    }
}

struct ReviewRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)

            Spacer()

            Text(value.isEmpty ? "-" : value)
                .font(.caption)
                .foregroundColor(.white)
        }
    }
}

struct InfoBox: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: Theme.Spacing.small) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundColor(.blue)

            Text(text)
                .font(.caption)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(Theme.Spacing.medium)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: Theme.CornerRadius.small)
                .fill(Color.blue.opacity(0.1))
        )
    }
}
