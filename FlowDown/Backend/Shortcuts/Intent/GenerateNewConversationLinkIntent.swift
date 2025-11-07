import AppIntents
import Foundation

struct GenerateNewConversationLinkIntent: AppIntent {
    static var title: LocalizedStringResource {
        "Create Conversation Link"
    }

    static var description: IntentDescription {
        "Create a FlowDown deep link that starts a new conversation."
    }

    @Parameter(title: "Initial Message", default: nil, requestValueDialog: "What message should we pre-fill?")
    var message: String?

    static var parameterSummary: some ParameterSummary {
        When(\.$message, .hasAnyValue) {
            Summary("Create conversation link prefilled with \(\.$message)")
        } otherwise: {
            Summary("Create conversation link without an initial message")
        }
    }

    func perform() async throws -> some IntentResult & ReturnsValue<String> & ProvidesDialog {
        let trimmedMessage = message?.trimmingCharacters(in: .whitespacesAndNewlines)
        let initialMessage = trimmedMessage?.isEmpty == false ? trimmedMessage : nil

        let url = try ShortcutUtilities.newConversationURL(initialMessage: initialMessage)
        let link = url.absoluteString

        let dialogMessage = String(
            localized: "Use the Open URL action with \(link) to launch the app and start a conversation."
        )

        let dialog = IntentDialog(.init(stringLiteral: dialogMessage))
        return .result(value: link, dialog: dialog)
    }
}
