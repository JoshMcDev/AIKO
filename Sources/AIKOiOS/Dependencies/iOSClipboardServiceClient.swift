#if os(iOS)
    import AppCore
    import ComposableArchitecture
    import Foundation

    /// iOS Clipboard Service Client using SimpleServiceTemplate
    @MainActor
    public final class IOSClipboardServiceClient: SimpleServiceTemplate {
        private lazy var service = IOSClipboardService()

        override public init() {
            super.init()
        }

        public func copyText(_ text: String) async {
            await executeMainActorOperation {
                self.service.copyText(text)
            }
        }

        public func copyData(_ data: Data, type: String) async {
            await executeMainActorOperation {
                self.service.copyData(data, type: type)
            }
        }

        public func getText() async -> String? {
            await executeMainActorOperation {
                self.service.getText()
            }
        }

        public func hasContent(ofType type: String) async -> Bool {
            await executeMainActorOperation {
                self.service.hasContent(ofType: type)
            }
        }
    }

    public extension ClipboardServiceClient {
        static let iOSLive = Self(
            copyText: { @Sendable text in
                await Task { @MainActor in
                    let client = IOSClipboardServiceClient()
                    await client.copyText(text)
                }.value
            },
            copyData: { @Sendable data, type in
                await Task { @MainActor in
                    let client = IOSClipboardServiceClient()
                    await client.copyData(data, type: type)
                }.value
            },
            getText: { @Sendable in
                await Task { @MainActor in
                    let client = IOSClipboardServiceClient()
                    return await client.getText()
                }.value
            },
            hasContent: { @Sendable type in
                await Task { @MainActor in
                    let client = IOSClipboardServiceClient()
                    return await client.hasContent(ofType: type)
                }.value
            }
        )
    }

    // Convenience static accessor
    public enum IOSClipboardServiceClientAccessor {
        @MainActor
        public static var live: ClipboardServiceClient {
            ClipboardServiceClient.iOSLive
        }
    }
#endif
