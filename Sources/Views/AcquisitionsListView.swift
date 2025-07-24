import AppCore
import ComposableArchitecture
import SwiftUI

public struct AcquisitionsListView: View {
    let store: StoreOf<AcquisitionsListFeature>

    public init(store: StoreOf<AcquisitionsListFeature>) {
        self.store = store
    }

    public var body: some View {
        WithViewStore(store, observe: \.self, content: { viewStore in
            contentView(viewStore: viewStore)
                .background(Theme.Colors.aikoBackground)
                .navigationTitle("My Acquisitions")
                .applyNavigationConfiguration()
                .onAppear {
                    viewStore.send(.onAppear)
                }
                .alert(
                    "Error",
                    isPresented: errorBinding(viewStore: viewStore),
                    presenting: viewStore.error
                ) { _ in
                    Button("OK") { viewStore.send(.clearError) }
                } message: { error in
                    Text(error)
                }
        })
    }

    // MARK: - Private Helper Views

    @ViewBuilder
    private func contentView(viewStore: ViewStore<AcquisitionsListFeature.State, AcquisitionsListFeature.Action>) -> some View {
        VStack(spacing: 0) {
            searchFilterBar(viewStore: viewStore)
            mainContent(viewStore: viewStore)
        }
    }

    @ViewBuilder
    private func searchFilterBar(viewStore: ViewStore<AcquisitionsListFeature.State, AcquisitionsListFeature.Action>) -> some View {
        SearchFilterBar(
            searchText: viewStore.binding(
                get: \.searchText,
                send: AcquisitionsListFeature.Action.searchTextChanged
            ),
            selectedStatus: viewStore.binding(
                get: \.selectedStatus,
                send: AcquisitionsListFeature.Action.statusFilterChanged
            ),
            sortOrder: viewStore.binding(
                get: \.sortOrder,
                send: AcquisitionsListFeature.Action.sortOrderChanged
            )
        )
    }

    @ViewBuilder
    private func mainContent(viewStore: ViewStore<AcquisitionsListFeature.State, AcquisitionsListFeature.Action>) -> some View {
        if viewStore.isLoading {
            loadingView
        } else if viewStore.filteredAcquisitions.isEmpty {
            EmptyAcquisitionsView(hasAcquisitions: !viewStore.acquisitions.isEmpty)
        } else {
            acquisitionsListView(viewStore: viewStore)
        }
    }

    private var loadingView: some View {
        VStack {
            Spacer()
            ProgressView("Loading acquisitions...")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            Spacer()
        }
    }

    @ViewBuilder
    private func acquisitionsListView(viewStore: ViewStore<AcquisitionsListFeature.State, AcquisitionsListFeature.Action>) -> some View {
        ScrollView {
            LazyVStack(spacing: Theme.Spacing.medium) {
                ForEach(viewStore.filteredAcquisitions, id: \.id) { acquisition in
                    acquisitionCard(
                        acquisition: acquisition,
                        viewStore: viewStore
                    )
                }
            }
            .padding(Theme.Spacing.large)
        }
    }

    @ViewBuilder
    private func acquisitionCard(
        acquisition: AppCore.Acquisition,
        viewStore: ViewStore<AcquisitionsListFeature.State, AcquisitionsListFeature.Action>
    ) -> some View {
        AcquisitionCard(
            acquisition: acquisition,
            isRenaming: viewStore.renamingAcquisitionId == acquisition.id,
            newName: newNameBinding(viewStore: viewStore),
            onOpen: { handleOpenAcquisition(acquisition: acquisition, viewStore: viewStore) },
            onDelete: { handleDeleteAcquisition(acquisition: acquisition, viewStore: viewStore) },
            onShareDocument: { handleShareDocument(acquisition: acquisition, viewStore: viewStore) },
            onShareContractFile: { handleShareContractFile(acquisition: acquisition, viewStore: viewStore) },
            onRename: { handleRenameAcquisition(acquisition: acquisition, viewStore: viewStore) },
            onDuplicate: { handleDuplicateAcquisition(acquisition: acquisition, viewStore: viewStore) },
            onConfirmRename: { viewStore.send(.confirmRename) },
            onCancelRename: { viewStore.send(.cancelRename) }
        )
    }

    // MARK: - Private Helper Methods

    private func newNameBinding(viewStore: ViewStore<AcquisitionsListFeature.State, AcquisitionsListFeature.Action>) -> Binding<String> {
        viewStore.binding(
            get: \.newAcquisitionName,
            send: AcquisitionsListFeature.Action.updateNewAcquisitionName
        )
    }

    private func errorBinding(viewStore: ViewStore<AcquisitionsListFeature.State, AcquisitionsListFeature.Action>) -> Binding<Bool> {
        viewStore.binding(
            get: { $0.error != nil },
            send: { _ in .clearError }
        )
    }

    private func handleOpenAcquisition(
        acquisition: AppCore.Acquisition,
        viewStore: ViewStore<AcquisitionsListFeature.State, AcquisitionsListFeature.Action>
    ) {
        viewStore.send(.openAcquisition(acquisition.id))
    }

    private func handleDeleteAcquisition(
        acquisition: AppCore.Acquisition,
        viewStore: ViewStore<AcquisitionsListFeature.State, AcquisitionsListFeature.Action>
    ) {
        viewStore.send(.deleteAcquisition(acquisition.id))
    }

    private func handleShareDocument(
        acquisition: AppCore.Acquisition,
        viewStore: ViewStore<AcquisitionsListFeature.State, AcquisitionsListFeature.Action>
    ) {
        viewStore.send(.shareDocument(acquisition.id))
    }

    private func handleShareContractFile(
        acquisition: AppCore.Acquisition,
        viewStore: ViewStore<AcquisitionsListFeature.State, AcquisitionsListFeature.Action>
    ) {
        viewStore.send(.shareContractFile(acquisition.id))
    }

    private func handleRenameAcquisition(
        acquisition: AppCore.Acquisition,
        viewStore: ViewStore<AcquisitionsListFeature.State, AcquisitionsListFeature.Action>
    ) {
        viewStore.send(.renameAcquisition(acquisition.id))
    }

    private func handleDuplicateAcquisition(
        acquisition: AppCore.Acquisition,
        viewStore: ViewStore<AcquisitionsListFeature.State, AcquisitionsListFeature.Action>
    ) {
        viewStore.send(.duplicateAcquisition(acquisition.id))
    }
}

// MARK: - View Extensions

extension View {
    @ViewBuilder
    func applyNavigationConfiguration() -> some View {
        #if os(iOS)
            navigationBarTitleDisplayMode(.large)
        #else
            self
        #endif
    }
}

// MARK: - Search and Filter Bar

struct SearchFilterBar: View {
    @Binding var searchText: String
    @Binding var selectedStatus: AcquisitionStatus?
    @Binding var sortOrder: AcquisitionsListFeature.SortOrder

    var body: some View {
        VStack(spacing: Theme.Spacing.small) {
            // Search field
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)

                TextField("Search acquisitions...", text: $searchText)
                    .textFieldStyle(PlainTextFieldStyle())
                    .foregroundColor(.white)

                if !searchText.isEmpty {
                    Button(action: { searchText = "" }, label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    })
                }
            }
            .padding(.horizontal, Theme.Spacing.medium)
            .padding(.vertical, Theme.Spacing.small)
            .background(Theme.Colors.aikoSecondary)
            .cornerRadius(Theme.CornerRadius.small)
            .padding(.horizontal, Theme.Spacing.large)

            // Filters
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Theme.Spacing.small) {
                    // Status filter
                    Menu {
                        Button("All Statuses") {
                            selectedStatus = nil
                        }
                        Divider()
                        ForEach(AcquisitionStatus.allCases, id: \.self) { status in
                            Button(action: { selectedStatus = status }, label: {
                                Label(status.displayName, systemImage: status.icon)
                            })
                        }
                    } label: {
                        FilterChip(
                            title: selectedStatus?.displayName ?? "All Statuses",
                            isSelected: selectedStatus != nil
                        )
                    }

                    // Sort order
                    Menu {
                        ForEach(AcquisitionsListFeature.SortOrder.allCases, id: \.self) { order in
                            Button(order.rawValue) {
                                sortOrder = order
                            }
                        }
                    } label: {
                        FilterChip(
                            title: "Sort: \(sortOrder.rawValue)",
                            isSelected: true
                        )
                    }
                }
                .padding(.horizontal, Theme.Spacing.large)
            }
        }
        .padding(.vertical, Theme.Spacing.medium)
        .background(Color.black)
    }
}

// MARK: - Filter Chip

struct FilterChip: View {
    let title: String
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 4) {
            Text(title)
                .font(.caption)
                .fontWeight(isSelected ? .semibold : .regular)

            if isSelected {
                Image(systemName: "chevron.down")
                    .font(.caption2)
            }
        }
        .foregroundColor(isSelected ? .white : .secondary)
        .padding(.horizontal, Theme.Spacing.medium)
        .padding(.vertical, Theme.Spacing.small)
        .background(
            RoundedRectangle(cornerRadius: Theme.CornerRadius.small)
                .fill(isSelected ? Theme.Colors.aikoAccent : Theme.Colors.aikoSecondary)
        )
    }
}

// MARK: - Acquisition Card

struct AcquisitionCard: View {
    let acquisition: AppCore.Acquisition
    let isRenaming: Bool
    @Binding var newName: String
    let onOpen: () -> Void
    let onDelete: () -> Void
    let onShareDocument: () -> Void
    let onShareContractFile: () -> Void
    let onRename: () -> Void
    let onDuplicate: () -> Void
    let onConfirmRename: () -> Void
    let onCancelRename: () -> Void

    @State private var showingDeleteConfirmation = false
    @FocusState private var isRenameFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.medium) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 6) {
                    // Category/Type label
                    HStack(spacing: 4) {
                        Image(systemName: "tag.fill")
                            .font(.caption2)
                            .foregroundColor(.blue)
                        Text("ACQUISITION TYPE")
                            .font(.caption2)
                            .fontWeight(.medium)
                            .foregroundColor(.blue)
                            .tracking(0.5)
                    }

                    if isRenaming {
                        HStack {
                            TextField("Acquisition Name", text: $newName)
                                .textFieldStyle(PlainTextFieldStyle())
                                .font(.headline)
                                .fontWeight(.semibold)
                                .foregroundColor(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Theme.Colors.aikoBackground)
                                .cornerRadius(Theme.CornerRadius.small)
                                .focused($isRenameFocused)
                                .onSubmit {
                                    onConfirmRename()
                                }

                            Button(action: onConfirmRename) {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                                    .font(.title3)
                            }

                            Button(action: onCancelRename) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.red)
                                    .font(.title3)
                            }
                        }
                    } else {
                        Text(getDisplayName(for: acquisition))
                            .font(.headline)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                    }

                    Text(acquisition.projectNumber ?? "No Project Number")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                StatusBadge(status: acquisition.status)
            }

            // Divider
            Divider()
                .background(Color.gray.opacity(0.3))

            // Requirements preview with label
            if !acquisition.requirements.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("ORIGINAL REQUIREMENTS")
                        .font(.caption2)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                        .tracking(0.5)

                    Text(acquisition.requirements)
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.7))
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            // Metadata
            HStack {
                // Created date
                Label(formattedDate(acquisition.createdDate), systemImage: "calendar")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Spacer()

                // Document counts
                if !acquisition.uploadedFilesArray.isEmpty {
                    Label("\(acquisition.uploadedFilesArray.count)", systemImage: "doc.fill")
                        .font(.caption)
                        .foregroundColor(.blue)
                }

                if !acquisition.generatedFilesArray.isEmpty {
                    Label("\(acquisition.generatedFilesArray.count)", systemImage: "doc.text.fill")
                        .font(.caption)
                        .foregroundColor(.green)
                }

                // Actions
                Menu {
                    Button(action: onOpen) {
                        Label("Open", systemImage: "arrow.right.circle")
                    }

                    Button(action: onRename) {
                        Label("Rename", systemImage: "pencil")
                    }

                    Button(action: onDuplicate) {
                        Label("Duplicate", systemImage: "doc.on.doc")
                    }

                    Divider()

                    Button(action: onShareDocument) {
                        Label("Share Document", systemImage: "square.and.arrow.up")
                    }

                    Button(action: onShareContractFile) {
                        Label("Share Contract File", systemImage: "square.and.arrow.up")
                    }

                    Divider()

                    Button(role: .destructive, action: { showingDeleteConfirmation = true }, label: {
                        Label("Delete", systemImage: "trash")
                    })
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .font(.title3)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(Theme.Spacing.large)
        .background(
            RoundedRectangle(cornerRadius: Theme.CornerRadius.large)
                .fill(Theme.Colors.aikoSecondary)
        )
        .confirmationDialog(
            "Delete Acquisition",
            isPresented: $showingDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                onDelete()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Are you sure you want to delete this acquisition? This action cannot be undone.")
        }
        .onChange(of: isRenaming) { newValue in
            if newValue {
                isRenameFocused = true
            }
        }
    }

    func formattedDate(_ date: Date?) -> String {
        guard let date else { return "Unknown date" }
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }

    func getDisplayName(for acquisition: AppCore.Acquisition) -> String {
        // If there's a title, use it
        if !acquisition.title.isEmpty {
            return acquisition.title
        }

        // Otherwise, generate a name from requirements
        if !acquisition.requirements.isEmpty {
            return generateNameFromRequirements(acquisition.requirements)
        }

        // Fallback
        return "Untitled Acquisition"
    }

    func generateNameFromRequirements(_ requirements: String) -> String {
        let lowercased = requirements.lowercased()
        let words = requirements.components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }

        // For "I need cloud services for data analytics"
        if lowercased.contains("cloud") && lowercased.contains("services") {
            if lowercased.contains("data") || lowercased.contains("analytics") {
                return "Cloud Services - Data Analytics"
            }
            return "Cloud Services"
        }

        // Extract key terms
        if lowercased.contains("software") {
            if lowercased.contains("development") {
                return "Software Development"
            } else if lowercased.contains("maintenance") {
                return "Software Maintenance"
            }
            return "Software Services"
        } else if lowercased.contains("equipment") || lowercased.contains("hardware") {
            if lowercased.contains("maintenance") {
                return "Equipment Maintenance"
            }
            return "Equipment Procurement"
        } else if lowercased.contains("service") || lowercased.contains("support") {
            if lowercased.contains("technical") {
                return "Technical Services"
            } else if lowercased.contains("professional") {
                return "Professional Services"
            }
            return "Services Contract"
        }

        // Try to create a name from the first few meaningful words
        let meaningfulWords = words.filter { word in
            !["i", "we", "need", "want", "require", "for", "a", "an", "the", "to", "of"].contains(word.lowercased())
        }

        if meaningfulWords.count >= 2 {
            let name = meaningfulWords.prefix(3).map(\.capitalized).joined(separator: " ")
            return name
        }

        // Last resort - use first few words
        if !words.isEmpty {
            return words.prefix(4).joined(separator: " ").capitalized
        }

        return "Contract Requirements"
    }
}

// MARK: - Status Badge

struct StatusBadge: View {
    let status: AcquisitionStatus

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: status.icon)
                .font(.caption2)

            Text(status.displayName)
                .font(.caption)
                .fontWeight(.medium)
        }
        .foregroundColor(color(for: status))
        .padding(.horizontal, Theme.Spacing.small)
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: Theme.CornerRadius.small)
                .fill(color(for: status).opacity(0.2))
        )
    }

    func color(for status: AcquisitionStatus) -> Color {
        switch status.color {
        case "gray": .gray
        case "blue": .blue
        case "orange": .orange
        case "green": .green
        case "purple": .purple
        case "red": .red
        default: .secondary
        }
    }
}

// MARK: - Empty State

struct EmptyAcquisitionsView: View {
    let hasAcquisitions: Bool

    var body: some View {
        VStack(spacing: Theme.Spacing.extraLarge) {
            Spacer()

            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 64))
                .foregroundColor(.secondary)

            VStack(spacing: Theme.Spacing.small) {
                Text(hasAcquisitions ? "No matching acquisitions" : "No acquisitions yet")
                    .font(.headline)
                    .foregroundColor(.white)

                Text(hasAcquisitions ? "Try adjusting your filters or search terms" : "Start by entering requirements or uploading documents")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }

            Spacer()
        }
        .padding(Theme.Spacing.extraLarge)
    }
}
