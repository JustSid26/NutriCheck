import Foundation
import SwiftData

@Model
final class ChatMessage {
    var id: UUID = UUID()
    var date: Date = Date.now
    var roleRaw: String = ChatRole.user.rawValue
    var text: String = ""
    var actionsData: Data?

    init(role: ChatRole, text: String, actions: [AssistantAction] = [], date: Date = .now) {
        self.id = UUID()
        self.date = date
        self.roleRaw = role.rawValue
        self.text = text
        self.actionsData = actions.isEmpty ? nil : try? JSONEncoder().encode(actions)
    }
}

extension ChatMessage {
    var role: ChatRole { ChatRole(rawValue: roleRaw) ?? .user }

    var actions: [AssistantAction] {
        get {
            guard let actionsData else { return [] }
            return (try? JSONDecoder().decode([AssistantAction].self, from: actionsData)) ?? []
        }
        set {
            actionsData = newValue.isEmpty ? nil : try? JSONEncoder().encode(newValue)
        }
    }

    /// Text sent back to the model as history, including what happened to proposed actions.
    var textForModel: String {
        let acts = actions
        guard role == .assistant, !acts.isEmpty else { return text }
        let notes = acts.map { action in
            "[Proposed action: \(action.summary). Status: \(action.status?.rawValue ?? "not yet confirmed")]"
        }
        return text + "\n" + notes.joined(separator: "\n")
    }
}
