
func getAddressBy() async throws -> GetAddressBy {    
    return noora.singleChoicePrompt(
        title: "Method",
        question: "Enter address files by:",
        description: "Do you want to enter the name of the address files or select them from the current working directory?.",
    )
}

func enterAddressBy() async throws -> EnterAddressBy {
    return noora.singleChoicePrompt(
        title: "Address",
        question: "Enter address by:",
        description: "Do you want to enter the address or AdaHandle directly or provide a file containing the address?.",
    )
}
