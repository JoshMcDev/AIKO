import ComposableArchitecture
import SwiftUI

struct SAMGovLookupView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var searchResults: [EntityDetail] = []
    @State private var errorMessage: String?
    @State private var showingAPIKeyAlert = false

    // Multiple search entries
    @State private var searchEntries: [SearchEntry] = [
        SearchEntry(),
        SearchEntry(),
        SearchEntry(),
    ]

    @Dependency(\.samGovService) var samGovService
    @Dependency(\.settingsManager) var settingsManager

    struct SearchEntry: Identifiable {
        let id = UUID()
        var text: String = ""
        var type: SearchType = .cage
        var isSearching: Bool = false
        var result: EntityDetail?
    }

    enum SearchType: String, CaseIterable {
        case cage = "CAGE Code"
        case companyName = "Company Name"
        case uei = "UEI"

        var placeholder: String {
            switch self {
            case .companyName: "Enter company name..."
            case .uei: "Enter UEI (12 characters)..."
            case .cage: "Enter CAGE code..."
            }
        }

        var icon: String {
            switch self {
            case .companyName: "building.2"
            case .uei: "number"
            case .cage: "barcode"
            }
        }
    }

    var body: some View {
        SwiftUI.NavigationView {
            VStack(spacing: 0) {
                // Header with SAM icon
                VStack(spacing: Theme.Spacing.small) {
                    if let samIcon = loadSAMIcon() {
                        samIcon
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 60, height: 60)
                    }

                    Text("Search SAM.gov")
                        .font(.title2)
                        .bold()
                        .foregroundStyle(
                            LinearGradient(
                                colors: [
                                    Color(red: 0.698, green: 0.132, blue: 0.203),
                                    Color.white,
                                    Color(red: 0.0, green: 0.125, blue: 0.698),
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                }
                .padding(.top)

                // Search Section
                ScrollView {
                    VStack(spacing: Theme.Spacing.large) {
                        // Search entries
                        ForEach(searchEntries.indices, id: \.self) { index in
                            SearchEntryView(
                                entry: $searchEntries[index],
                                onSearch: { performSearch(for: index) },
                                onRemove: index > 0 ? { // Show X on all cards except the first one
                                    searchEntries.remove(at: index)
                                } : nil
                            )
                        }

                        // Add more button
                        Button(action: {
                            searchEntries.append(SearchEntry())
                        }, label: {
                            HStack {
                                Image(systemName: "plus.circle.fill")
                                    .font(.title2)
                                    .foregroundColor(Theme.Colors.aikoPrimary)
                                Text("Add Another Search")
                                    .fontWeight(.medium)
                                    .foregroundColor(Theme.Colors.aikoPrimary)
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(
                                RoundedRectangle(cornerRadius: Theme.CornerRadius.small)
                                    .stroke(Theme.Colors.aikoPrimary, style: StrokeStyle(lineWidth: 2, dash: [5]))
                            )
                        })
                        .padding(.horizontal)

                        // Search all button
                        Button(action: performAllSearches) {
                            HStack {
                                if searchEntries.contains(where: \.isSearching) {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                        .scaleEffect(0.8)
                                } else {
                                    Image(systemName: "magnifyingglass")
                                }
                                Text("Search All")
                                    .fontWeight(.semibold)
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Theme.Colors.aikoPrimary)
                            .cornerRadius(Theme.CornerRadius.small)
                        }
                        .disabled(searchEntries.allSatisfy(\.text.isEmpty) || searchEntries.contains(where: \.isSearching))
                        .padding(.horizontal)
                    }
                    .padding(.vertical)

                    Divider()

                    // Results Section
                    if !searchResults.isEmpty {
                        Divider()
                        Text("Search Results")
                            .font(.headline)
                            .padding(.horizontal)
                            .padding(.top)

                        ForEach(searchResults, id: \.entityName) { result in
                            EntityDetailView(entity: result)
                                .padding()
                        }
                    } else if let error = errorMessage {
                        SAMGovErrorView(message: error)
                            .padding()
                    }
                }
            }
            #if os(iOS)
            .navigationBarHidden(true)
            #endif
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .alert("API Key Required", isPresented: $showingAPIKeyAlert) {
            Button("Go to Settings") {
                // Navigate to settings
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Please configure your SAM.gov API key in Settings to use this feature.")
        }
    }

    private func loadSAMIcon() -> Image? {
        guard let url = Bundle.module.url(forResource: "SAMIcon", withExtension: "png") else {
            return nil
        }

        #if os(iOS)
            guard let uiImage = UIImage(contentsOfFile: url.path) else {
                return nil
            }
            return Image(uiImage: uiImage)
        #elseif os(macOS)
            guard let nsImage = NSImage(contentsOfFile: url.path) else {
                return nil
            }
            return Image(nsImage: nsImage)
        #endif
    }

    private func performSearch(for index: Int) {
        guard index < searchEntries.count else { return }
        let entry = searchEntries[index]

        guard !entry.text.isEmpty else { return }

        searchEntries[index].isSearching = true
        searchEntries[index].result = nil

        Task {
            do {
                let result: EntityDetail?

                switch entry.type {
                case .companyName:
                    let searchResults = try await samGovService.searchEntity(entry.text)
                    guard let firstEntity = searchResults.entities.first else {
                        throw SAMGovError.entityNotFound
                    }
                    result = try await samGovService.getEntityByUEI(firstEntity.ueiSAM)
                case .uei:
                    result = try await samGovService.getEntityByUEI(entry.text)
                case .cage:
                    result = try await samGovService.getEntityByCAGE(entry.text)
                }

                await MainActor.run {
                    searchEntries[index].isSearching = false
                    searchEntries[index].result = result
                    if let result {
                        if !searchResults.contains(where: { $0.entityName == result.entityName }) {
                            searchResults.append(result)
                        }
                    }
                }
            } catch {
                await MainActor.run {
                    searchEntries[index].isSearching = false
                    errorMessage = error.localizedDescription
                }
            }
        }
    }

    private func performAllSearches() {
        for index in searchEntries.indices {
            if !searchEntries[index].text.isEmpty, !searchEntries[index].isSearching {
                performSearch(for: index)
            }
        }
    }
}

// MARK: - Search Entry View

struct SearchEntryView: View {
    @Binding var entry: SAMGovLookupView.SearchEntry
    let onSearch: () -> Void
    let onRemove: (() -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.small) {
            // Search type filter buttons
            HStack {
                ForEach(SAMGovLookupView.SearchType.allCases, id: \.self) { type in
                    Button(action: { entry.type = type }, label: {
                        HStack(spacing: 4) {
                            Image(systemName: type.icon)
                                .font(.caption)
                            Text(type.rawValue)
                                .font(.caption)
                                .fontWeight(entry.type == type ? .semibold : .regular)
                        }
                        .foregroundColor(entry.type == type ? .white : .gray)
                        .padding(.horizontal, Theme.Spacing.small)
                        .padding(.vertical, 6)
                        .background(
                            entry.type == type ? Theme.Colors.aikoPrimary : Color.clear
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: Theme.CornerRadius.small)
                                .stroke(entry.type == type ? Color.clear : Color.gray.opacity(0.3), lineWidth: 1)
                        )
                        .cornerRadius(Theme.CornerRadius.small)
                    })
                }

                Spacer()

                if let onRemove {
                    Button(action: onRemove) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                            .font(.title3)
                    }
                }
            }

            // Search field
            HStack {
                TextField(entry.type.placeholder, text: $entry.text)
                    .textFieldStyle(PlainTextFieldStyle())
                #if os(iOS)
                    .autocapitalization(entry.type == .cage || entry.type == .uei ? .allCharacters : .words)
                    .disableAutocorrection(true)
                    .submitLabel(.search)
                #endif
                    .onSubmit {
                        onSearch()
                    }

                if !entry.text.isEmpty {
                    Button(action: { entry.text = "" }, label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    })
                }

                // Search button with magnifying glass
                Button(action: onSearch) {
                    if entry.isSearching {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: Theme.Colors.aikoPrimary))
                            .scaleEffect(0.8)
                    } else {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(Theme.Colors.aikoPrimary)
                            .font(.title3)
                    }
                }
                .disabled(entry.text.isEmpty || entry.isSearching)
            }
            .padding()
            .background(Theme.Colors.aikoSecondary)
            .cornerRadius(Theme.CornerRadius.small)

            // Result display
            if let result = entry.result {
                VStack(alignment: .leading, spacing: Theme.Spacing.extraSmall) {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                            .font(.caption)
                        Text("Found: \(result.entityName)")
                            .font(.caption)
                            .foregroundColor(.green)
                            .lineLimit(1)
                    }
                    Text("UEI: \(result.ueiSAM)")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: Theme.CornerRadius.medium)
                .fill(Theme.Colors.aikoCard)
        )
        .padding(.horizontal)
    }
}

// MARK: - Entity Detail View

struct EntityDetailView: View {
    let entity: EntityDetail

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.medium) {
            // Active Exclusions Warning (if applicable)
            if entity.hasActiveExclusions {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.white)
                        .font(.headline)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("ACTIVE EXCLUSIONS")
                            .font(.headline)
                            .foregroundColor(.white)

                        Text("This entity is excluded from receiving federal contracts, grants, and benefits")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.9))
                    }

                    Spacer()
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: Theme.CornerRadius.small)
                        .fill(Color.red)
                )
            }

            // Status Badge
            HStack {
                Image(systemName: entity.registrationStatus == "Active" ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                    .foregroundColor(entity.registrationStatus == "Active" ? .green : .orange)

                Text(entity.registrationStatus)
                    .font(.headline)
                    .foregroundColor(entity.registrationStatus == "Active" ? .green : .orange)

                Spacer()
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: Theme.CornerRadius.small)
                    .fill(entity.registrationStatus == "Active" ? Color.green.opacity(0.1) : Color.orange.opacity(0.1))
            )

            // Basic Information
            VStack(alignment: .leading, spacing: Theme.Spacing.small) {
                InfoRow(label: "Legal Name", value: entity.legalBusinessName)
                InfoRow(label: "UEI", value: entity.ueiSAM)
                if let cage = entity.cageCode {
                    InfoRow(label: "CAGE Code", value: cage)
                }
            }
            .padding()
            .background(Theme.Colors.aikoCard)
            .cornerRadius(Theme.CornerRadius.small)

            // Registration Dates
            VStack(alignment: .leading, spacing: Theme.Spacing.small) {
                Text("Registration Information")
                    .font(.headline)
                    .padding(.bottom, 4)

                if let regDate = entity.registrationDate {
                    InfoRow(label: "Registration Date", value: formatDate(regDate))
                }

                if let expDate = entity.expirationDate {
                    InfoRow(label: "Expiration Date", value: formatDate(expDate))

                    // Days until expiration
                    let daysUntil = Calendar.current.dateComponents([.day], from: Date(), to: expDate).day ?? 0
                    if daysUntil > 0 {
                        HStack {
                            Image(systemName: "clock")
                                .foregroundColor(daysUntil < 30 ? .orange : .green)
                            Text("\(daysUntil) days until expiration")
                                .foregroundColor(daysUntil < 30 ? .orange : .green)
                                .font(.caption)
                        }
                        .padding(.top, 4)
                    }
                }
            }
            .padding()
            .background(Theme.Colors.aikoCard)
            .cornerRadius(Theme.CornerRadius.small)

            // Business Types
            if !entity.businessTypes.isEmpty {
                VStack(alignment: .leading, spacing: Theme.Spacing.small) {
                    Text("Business Types")
                        .font(.headline)
                        .padding(.bottom, 4)

                    ForEach(entity.businessTypes, id: \.self) { type in
                        HStack {
                            Image(systemName: "checkmark.circle")
                                .foregroundColor(.green)
                                .font(.caption)
                            Text(type)
                                .font(.caption)
                        }
                    }
                }
                .padding()
                .background(Theme.Colors.aikoCard)
                .cornerRadius(Theme.CornerRadius.small)
            }

            // NAICS Codes
            if !entity.naicsCodes.isEmpty {
                VStack(alignment: .leading, spacing: Theme.Spacing.small) {
                    Text("NAICS Codes")
                        .font(.headline)
                        .padding(.bottom, 4)

                    ForEach(entity.naicsCodes, id: \.code) { naics in
                        HStack(alignment: .top, spacing: Theme.Spacing.extraSmall) {
                            Text(naics.code)
                                .font(.caption.monospaced())
                                .foregroundColor(.secondary)
                                .frame(width: 60, alignment: .leading)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(naics.description)
                                    .font(.caption)
                                    .fixedSize(horizontal: false, vertical: true)
                                if naics.isPrimary {
                                    Text("PRIMARY")
                                        .font(.caption2)
                                        .fontWeight(.bold)
                                        .foregroundColor(.blue)
                                }
                            }

                            Spacer()
                        }
                    }
                }
                .padding()
                .background(Theme.Colors.aikoCard)
                .cornerRadius(Theme.CornerRadius.small)
            }

            // Certifications
            if entity.isSmallBusiness || entity.isVeteranOwned || entity.isWomanOwned || entity.is8aProgram || entity.isHUBZone {
                VStack(alignment: .leading, spacing: Theme.Spacing.small) {
                    Text("Certifications")
                        .font(.headline)
                        .padding(.bottom, 4)

                    if entity.isSmallBusiness {
                        Label("Small Business", systemImage: "checkmark.circle.fill")
                            .font(.caption)
                            .foregroundColor(.green)
                    }
                    if entity.isVeteranOwned {
                        Label("Veteran-Owned", systemImage: "checkmark.circle.fill")
                            .font(.caption)
                            .foregroundColor(.green)
                    }
                    if entity.isServiceDisabledVeteranOwned {
                        Label("Service-Disabled Veteran-Owned", systemImage: "checkmark.circle.fill")
                            .font(.caption)
                            .foregroundColor(.green)
                    }
                    if entity.isWomanOwned {
                        Label("Woman-Owned", systemImage: "checkmark.circle.fill")
                            .font(.caption)
                            .foregroundColor(.green)
                    }
                    if entity.is8aProgram {
                        Label("8(a) Program", systemImage: "checkmark.circle.fill")
                            .font(.caption)
                            .foregroundColor(.green)
                    }
                    if entity.isHUBZone {
                        Label("HUBZone", systemImage: "checkmark.circle.fill")
                            .font(.caption)
                            .foregroundColor(.green)
                    }
                }
                .padding()
                .background(Theme.Colors.aikoCard)
                .cornerRadius(Theme.CornerRadius.small)
            }

            // Section 889 Compliance
            if let section889 = entity.section889Certifications {
                VStack(alignment: .leading, spacing: Theme.Spacing.small) {
                    Text("Section 889 Compliance")
                        .font(.headline)
                        .padding(.bottom, 4)

                    if let doesNotProvide = section889.doesNotProvideProhibitedTelecom {
                        HStack {
                            Image(systemName: doesNotProvide ? "checkmark.circle.fill" : "xmark.circle.fill")
                                .foregroundColor(doesNotProvide ? .green : .red)
                                .font(.caption)
                            Text("Does not provide prohibited telecommunications equipment/services")
                                .font(.caption)
                        }
                    }

                    if let doesNotUse = section889.doesNotUseProhibitedTelecom {
                        HStack {
                            Image(systemName: doesNotUse ? "checkmark.circle.fill" : "xmark.circle.fill")
                                .foregroundColor(doesNotUse ? .green : .red)
                                .font(.caption)
                            Text("Does not use prohibited telecommunications equipment/services")
                                .font(.caption)
                        }
                    }

                    if section889.doesNotProvideProhibitedTelecom == nil, section889.doesNotUseProhibitedTelecom == nil {
                        HStack {
                            Image(systemName: "exclamationmark.triangle")
                                .foregroundColor(.orange)
                                .font(.caption)
                            Text("Section 889 certification status not available")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .padding()
                .background(Theme.Colors.aikoCard)
                .cornerRadius(Theme.CornerRadius.small)
            }

            // Foreign Government Entities
            if !entity.foreignGovtEntities.isEmpty {
                VStack(alignment: .leading, spacing: Theme.Spacing.small) {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.orange)
                        Text("Foreign Government Interests")
                            .font(.headline)
                            .foregroundColor(.orange)
                    }
                    .padding(.bottom, 4)

                    ForEach(entity.foreignGovtEntities, id: \.name) { fge in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Image(systemName: "flag.fill")
                                    .font(.caption)
                                    .foregroundColor(.orange)
                                Text(fge.country)
                                    .font(.caption)
                                    .fontWeight(.semibold)
                            }

                            Text(fge.name)
                                .font(.caption)
                                .padding(.leading, 20)

                            if let interestType = fge.interestType {
                                Text("Interest Type: \(interestType)")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                    .padding(.leading, 20)
                            }

                            if let ownership = fge.ownershipPercentage {
                                Text("Ownership: \(ownership)")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                    .padding(.leading, 20)
                            }

                            if let control = fge.controlDescription {
                                Text("Control: \(control)")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                    .padding(.leading, 20)
                            }
                        }
                        .padding(.vertical, 4)

                        if fge != entity.foreignGovtEntities.last {
                            Divider()
                        }
                    }
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: Theme.CornerRadius.small)
                        .fill(Color.orange.opacity(0.1))
                        .overlay(
                            RoundedRectangle(cornerRadius: Theme.CornerRadius.small)
                                .stroke(Color.orange, lineWidth: 1)
                        )
                )
            }

            // Responsibility & Qualification
            if let responsibility = entity.responsibilityInformation {
                VStack(alignment: .leading, spacing: Theme.Spacing.small) {
                    Text("Responsibility & Qualification")
                        .font(.headline)
                        .padding(.bottom, 4)

                    // Financial Responsibility
                    if let hasDebt = responsibility.hasDelinquentFederalDebt {
                        HStack {
                            Image(systemName: hasDebt ? "xmark.circle.fill" : "checkmark.circle.fill")
                                .foregroundColor(hasDebt ? .red : .green)
                                .font(.caption)
                            Text(hasDebt ? "Has delinquent federal debt" : "No delinquent federal debt")
                                .font(.caption)
                        }
                    }

                    if let hasTax = responsibility.hasUnpaidTaxLiability {
                        HStack {
                            Image(systemName: hasTax ? "xmark.circle.fill" : "checkmark.circle.fill")
                                .foregroundColor(hasTax ? .red : .green)
                                .font(.caption)
                            Text(hasTax ? "Has unpaid tax liability" : "No unpaid tax liability")
                                .font(.caption)
                        }
                    }

                    // Integrity Records (FAPIIS)
                    if !responsibility.integrityRecords.isEmpty {
                        Text("Integrity Records")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(.orange)
                            .padding(.top, 4)

                        ForEach(responsibility.integrityRecords, id: \.proceedingDescription) { record in
                            VStack(alignment: .leading, spacing: 2) {
                                if let type = record.proceedingType {
                                    Text(type)
                                        .font(.caption2)
                                        .fontWeight(.semibold)
                                }
                                if let desc = record.proceedingDescription {
                                    Text(desc)
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                                if let agency = record.agency {
                                    Text("Agency: \(agency)")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                            }
                            .padding(.leading)
                        }
                    }
                }
                .padding()
                .background(Theme.Colors.aikoCard)
                .cornerRadius(Theme.CornerRadius.small)
            }

            // Architect-Engineer Qualifications
            if let aeInfo = entity.architectEngineerQualifications,
               aeInfo.hasArchitectEngineerResponses
            {
                VStack(alignment: .leading, spacing: Theme.Spacing.small) {
                    Text("Architect-Engineer Qualifications")
                        .font(.headline)
                        .padding(.bottom, 4)

                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                            .font(.caption)
                        Text(aeInfo.hasSF330Filed ? "SF 330 Filed" : "A-E Qualifications on file")
                            .font(.caption)
                    }

                    if !aeInfo.disciplines.isEmpty {
                        Text("Disciplines:")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .padding(.top, 4)

                        ForEach(aeInfo.disciplines, id: \.self) { discipline in
                            HStack {
                                Text("•")
                                    .font(.caption)
                                Text(discipline)
                                    .font(.caption)
                            }
                            .padding(.leading)
                        }
                    }
                }
                .padding()
                .background(Theme.Colors.aikoCard)
                .cornerRadius(Theme.CornerRadius.small)
            }

            // Address
            if let address = entity.physicalAddress {
                VStack(alignment: .leading, spacing: Theme.Spacing.small) {
                    Text("Physical Address")
                        .font(.headline)
                        .padding(.bottom, 4)

                    if let street = address.streetAddress {
                        Text(street)
                            .font(.caption)
                    }
                    if let city = address.city, let state = address.state, let zip = address.zipCode {
                        Text("\(city), \(state) \(zip)")
                            .font(.caption)
                    }
                }
                .padding()
                .background(Theme.Colors.aikoCard)
                .cornerRadius(Theme.CornerRadius.small)
            }
        }
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .long
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }
}

// MARK: - Helper Views

struct InfoRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .font(.caption)
                .fontWeight(.medium)
        }
    }
}

struct SAMGovEmptyStateView: View {
    var body: some View {
        VStack(spacing: Theme.Spacing.large) {
            Image(systemName: "building.2.crop.circle")
                .font(.system(size: 60))
                .foregroundColor(.secondary)

            Text("Search SAM.gov")
                .font(.headline)

            Text("Enter a company name, UEI, or CAGE code to verify registration status")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .padding(.vertical, Theme.Spacing.xxl)
    }
}

struct SAMGovErrorView: View {
    let message: String

    var body: some View {
        VStack(spacing: Theme.Spacing.medium) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 40))
                .foregroundColor(Theme.Colors.aikoError)

            Text("Search Failed")
                .font(.headline)

            Text(message)
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: Theme.CornerRadius.small)
                .fill(Theme.Colors.aikoError.opacity(0.1))
        )
    }
}
