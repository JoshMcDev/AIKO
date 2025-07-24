#if os(iOS)
    import AppCore
    import ComposableArchitecture
    import Foundation

    public extension EmailServiceClient {
        static let iOSLive = Self(
            canSendEmail: {
                MainActor.assumeIsolated {
                    IOSEmailService.shared.canSendEmail
                }
            },
            sendEmail: { recipients, subject, body, isHTML, attachments in
                await withCheckedContinuation { continuation in
                    Task { @MainActor in
                        let configuration = EmailConfiguration(
                            recipients: recipients,
                            subject: subject,
                            body: body,
                            isHTML: isHTML,
                            attachments: attachments
                        )
                        IOSEmailService.shared.sendEmail(
                            configuration: configuration
                        ) { success in
                            continuation.resume(returning: success)
                        }
                    }
                }
            },
            showEmailComposer: { recipients, subject, body in
                await withCheckedContinuation { continuation in
                    Task { @MainActor in
                        let configuration = EmailComposerConfiguration(
                            recipients: recipients,
                            subject: subject,
                            body: body
                        )
                        IOSEmailService.shared.showEmailComposer(
                            configuration: configuration
                        ) { result in
                            continuation.resume(returning: result)
                        }
                    }
                }
            }
        )
    }

    // Convenience static accessor
    public enum IOSEmailServiceClient {
        public static let live = EmailServiceClient.iOSLive
    }
#endif
