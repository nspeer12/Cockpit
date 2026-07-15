import Testing
@testable import Cockpit

@Test func neoIdentityHasStableExecutiveDesignation() {
    #expect(NEOIdentity.name == "NEO")
    #expect(NEOIdentity.expansion == "Networked Executive Orchestrator")
    #expect(NEOIdentity.designation == "Hermes embodied operating presence")
}

@Test func neoSystemPromptDefinesDirectCalmOperatingStyle() {
    let prompt = NEOIdentity.systemPrompt

    #expect(prompt.contains("calm"))
    #expect(prompt.contains("decisive"))
    #expect(prompt.contains("do not fabricate"))
}

@Test func neoAcknowledgesACommandWithoutPretendingItExecutedIt() {
    let acknowledgement = NEOIdentity.acknowledgement(for: "check the network")

    #expect(acknowledgement.contains("received"))
    #expect(acknowledgement.contains("check the network"))
    #expect(!acknowledgement.contains("completed"))
}
