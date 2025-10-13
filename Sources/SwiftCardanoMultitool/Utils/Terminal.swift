@preconcurrency import Noora

@globalActor
actor TerminalActor {
    static let shared = TerminalActor()
}

@TerminalActor
class Terminal {
    static let shared = Terminal()
    
    static let noora = Noora(theme: Style.theme, content: Style.content)
    
    private init() {}
    
    nonisolated func noora() async throws -> Noora {
        return Noora(theme: Style.theme, content: Style.content)
    }
}

let noora = Noora(theme: Style.theme, content: Style.content)

func spacedPrint(_ text: TerminalText) {
    print(
        noora.format(text),
        terminator: "\n\n"
    )
}
    
