import ComposableArchitecture
import SwiftUI

struct DocumentExecutionView: View {
    let store: StoreOf<DocumentExecutionFeature>

    var body: some View {
        WithViewStore(store, observe: { $0 }) { viewStore in
            SwiftUI.NavigationView {
                ZStack {
                    Theme.Colors.aikoBackground
                        .ignoresSafeArea()

                    VStack(spacing: 0) {
                        // Header
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Document Generation")
                                    .font(.largeTitle)
                                    .fontWeight(.bold)
                                    .foregroundColor(.white)

                                if let category = viewStore.executingCategory {
                                    Text(category.rawValue)
                                        .font(.headline)
                                        .foregroundColor(.white.opacity(0.8))
                                }
                            }

                            Spacer()

                            Button(action: {
                                viewStore.send(.showExecutionView(false))
                            }) {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.title2)
                                    .foregroundColor(.white.opacity(0.6))
                            }
                        }
                        .padding()

                        // Content based on status
                        ScrollView {
                            VStack(spacing: Theme.Spacing.extraLarge) {
                                switch viewStore.executionStatus {
                                case .idle:
                                    EmptyView()

                                case .checkingInformation:
                                    CheckingInformationView()

                                case .gatheringInformation:
                                    // This is handled by sheet
                                    EmptyView()

                                case .generating:
                                    GeneratingDocumentsView(progress: viewStore.executionProgress)

                                case .completed:
                                    CompletedView(
                                        content: viewStore.generatedContent,
                                        onCopy: { viewStore.send(.copyToClipboard) },
                                        onDownload: { viewStore.send(.downloadDocument) },
                                        onEmail: { viewStore.send(.emailDocument) }
                                    )

                                case let .failed(error):
                                    ErrorView(error: error)
                                }
                            }
                            .padding()
                        }
                    }
                }
                #if os(iOS)
                .navigationBarHidden(true)
                #endif
            }
            .sheet(isPresented: .init(
                get: { viewStore.showingInformationGathering },
                set: { viewStore.send(.showInformationGathering($0)) }
            )) {
                InformationGatheringView(store: store)
            }
        }
    }
}

struct CheckingInformationView: View {
    var body: some View {
        VStack(spacing: Theme.Spacing.large) {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: .blue))
                .scaleEffect(1.5)

            Text("Analyzing requirements...")
                .font(.headline)
                .foregroundColor(.white)

            Text("Checking if we have sufficient information to generate the requested documents")
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.8))
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .padding(.vertical, 60)
    }
}

struct GeneratingDocumentsView: View {
    let progress: Double

    var body: some View {
        VStack(spacing: Theme.Spacing.extraLarge) {
            // Progress Circle
            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.2), lineWidth: 10)
                    .frame(width: 120, height: 120)

                Circle()
                    .trim(from: 0, to: CGFloat(progress))
                    .stroke(
                        LinearGradient(
                            gradient: Gradient(colors: [.blue, .purple]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        style: StrokeStyle(lineWidth: 10, lineCap: .round)
                    )
                    .frame(width: 120, height: 120)
                    .rotationEffect(.degrees(-90))
                    .animation(.easeInOut, value: progress)

                Text("\(Int(progress * 100))%")
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
            }

            VStack(spacing: Theme.Spacing.small) {
                Text("Generating Documents")
                    .font(.headline)
                    .foregroundColor(.white)

                Text("AIKO is creating your documents based on the requirements and information provided")
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.8))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }

            // Progress bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.white.opacity(0.2))
                        .frame(height: 8)

                    RoundedRectangle(cornerRadius: 8)
                        .fill(
                            LinearGradient(
                                gradient: Gradient(colors: [.blue, .purple]),
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geometry.size.width * CGFloat(progress), height: 8)
                        .animation(.easeInOut, value: progress)
                }
            }
            .frame(height: 8)
            .padding(.horizontal, 40)
        }
        .padding(.vertical, 40)
    }
}

struct CompletedView: View {
    let content: String
    let onCopy: () -> Void
    let onDownload: () -> Void
    let onEmail: () -> Void

    @State private var showCopiedToast = false

    var body: some View {
        VStack(spacing: Theme.Spacing.extraLarge) {
            // Success indicator
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 60))
                .foregroundColor(.green)

            Text("Documents Generated Successfully")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.white)

            // Action buttons
            HStack(spacing: Theme.Spacing.large) {
                ActionButton(
                    title: "Copy",
                    icon: "doc.on.doc",
                    action: {
                        onCopy()
                        withAnimation {
                            showCopiedToast = true
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                            withAnimation {
                                showCopiedToast = false
                            }
                        }
                    }
                )

                ActionButton(
                    title: "Download",
                    icon: "arrow.down.circle",
                    action: onDownload
                )

                ActionButton(
                    title: "Email",
                    icon: "envelope",
                    action: onEmail
                )
            }

            // Generated content preview
            VStack(alignment: .leading, spacing: Theme.Spacing.medium) {
                Text("Preview")
                    .font(.headline)
                    .foregroundColor(.white)

                DocumentRichTextView(content: content)
                    .frame(maxHeight: 400)
                    .background(
                        RoundedRectangle(cornerRadius: Theme.CornerRadius.large)
                            .fill(Color.black.opacity(0.3))
                    )
                    .cornerRadius(Theme.CornerRadius.large)
            }
        }
        .padding(.vertical, 20)
        .overlay(
            Group {
                if showCopiedToast {
                    VStack {
                        Spacer()

                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                            Text("Copied to clipboard")
                                .font(.subheadline)
                                .foregroundColor(.white)
                        }
                        .padding()
                        .background(
                            Capsule()
                                .fill(Theme.Colors.aikoSecondary)
                        )
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                    .padding(.bottom, 50)
                }
            }
        )
    }
}

struct ActionButton: View {
    let title: String
    let icon: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.title2)
                Text(title)
                    .font(.caption)
            }
            .foregroundColor(.white)
            .frame(width: 80, height: 80)
            .background(
                RoundedRectangle(cornerRadius: Theme.CornerRadius.large)
                    .fill(Theme.Colors.aikoSecondary)
            )
        }
    }
}

struct ErrorView: View {
    let error: String

    var body: some View {
        VStack(spacing: Theme.Spacing.large) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 60))
                .foregroundColor(.red)

            Text("Generation Failed")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.white)

            Text(error)
                .font(.body)
                .foregroundColor(.white.opacity(0.8))
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .padding(.vertical, 60)
    }
}
