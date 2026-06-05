import Foundation

/// One spoken exchange in Hands-Free Voice Mode. Pure value type — no UI or brain
/// dependency, so it compiles standalone and is trivially testable.
struct VoiceTurn: Identifiable, Equatable, Sendable {
    enum Role: Sendable { case me, salehman }

    let id: UUID
    let role: Role
    let text: String
    let date: Date

    init(id: UUID = UUID(), role: Role, text: String, date: Date = Date()) {
        self.id = id
        self.role = role
        self.text = text
        self.date = date
    }
}
