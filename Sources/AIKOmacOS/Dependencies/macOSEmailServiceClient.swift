#if os(macOS)
    import AppCore
    import ComposableArchitecture
    import Foundation

    public extension EmailServiceClient {
        static let macOSLive = Self(
            canSendEmail: {
                MacOSEmailService().canSendEmail
            },
            sendEmail: { recipients, subject, body, isHTML, attachments in
                await withCheckedContinuation { continuation in
                    let configuration = EmailConfiguration(
                        recipients: recipients,
                        subject: subject,
                        body: body,
                        isHTML: isHTML,
                        attachments: attachments
                    )
                    MacOSEmailService().sendEmail(
                        configuration: configuration
                    ) { success in
                        continuation.resume(returning: success)
                    }
                }
            },
            showEmailComposer: { recipients, subject, body in
                await withCheckedContinuation { continuation in
                    let configuration = EmailComposerConfiguration(
                        recipients: recipients,
                        subject: subject,
                        body: body
                    )
                    MacOSEmailService().showEmailComposer(
                        configuration: configuration
                    ) { result in
                        continuation.resume(returning: result)
                    }
                }
            }
        )
    }

    // Convenience static accessor
    public enum MacOSEmailServiceClient {
        public static let live = EmailServiceClient.macOSLive
    }#endif
