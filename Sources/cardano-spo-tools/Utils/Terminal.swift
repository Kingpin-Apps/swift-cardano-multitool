@preconcurrency import Noora

@globalActor
actor TerminalActor {
    static let shared = TerminalActor()
}

@TerminalActor
class Terminal {
    static let shared = Terminal()
    
    private init() {}
    
    nonisolated func noora() async throws -> Noora {
        return Noora(theme: Style.theme, content: Style.content)
    }
}
