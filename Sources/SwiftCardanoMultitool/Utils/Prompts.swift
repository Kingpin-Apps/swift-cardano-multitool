
func getAddressBy() async throws -> GetAddressBy {
    let noora = try await Terminal.shared.noora()
    
    return noora.singleChoicePrompt(
        title: "Method",
        question: "Enter address files by:",
        description: "Do you want to enter the name of the address files or select them from the current working directory?.",
    )
}
