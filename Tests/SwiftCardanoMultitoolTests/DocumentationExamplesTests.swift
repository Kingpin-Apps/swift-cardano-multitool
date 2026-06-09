import ArgumentParser
import Testing
@testable import SwiftCardanoMultitool

/// Parser-level checks for every command-line invocation shown in the README and DocC catalog.
///
/// Each test mirrors a code block from `README.md` or `Sources/SwiftCardanoMultitoolApp/scm.docc/`
/// and exercises only argument parsing — no chain context or filesystem state is required. If a
/// flag is renamed or removed, these tests fail and surface the doc drift before the next release.
@Suite("Documentation examples — parse")
struct DocumentationExamplesTests {

    // MARK: - asset

    @Test("asset mint — combined positional + --fee-payment-address --submit")
    func assetMintPositionalExample() throws {
        let cmd = try AssetMainCommand.Mint.parse([
            "myPolicy.MYTOK", "--amount", "1000",
            "--fee-payment-address", "addr_test1vr2p8st5t5cxqglyjky7vk98k7jtfhdpvhl4e97cezuhn0cqcexl7",
            "--submit",
        ])
        #expect(cmd.policyAsset == "myPolicy.MYTOK")
        #expect(cmd.amount == 1000)
        #expect(cmd.transactionOptions.submit == true)
    }

    @Test("asset mint — explicit --policy-name + --asset-name + --amount form")
    func assetMintExplicitFlagsExample() throws {
        let cmd = try AssetMainCommand.Mint.parse([
            "--policy-name", "myPolicy",
            "--asset-name", "MYTOK",
            "--amount", "1000",
            "--fee-payment-address", "addr_test1vr2p8st5t5cxqglyjky7vk98k7jtfhdpvhl4e97cezuhn0cqcexl7",
            "--submit",
        ])
        #expect(cmd.policyName == "myPolicy")
        #expect(cmd.assetName == "MYTOK")
        #expect(cmd.amount == 1000)
        #expect(cmd.transactionOptions.submit == true)
    }

    @Test("asset burn — combined positional example")
    func assetBurnPositionalExample() throws {
        let cmd = try AssetMainCommand.Burn.parse([
            "myPolicy.MYTOK", "--amount", "200",
            "--fee-payment-address", "addr_test1vr2p8st5t5cxqglyjky7vk98k7jtfhdpvhl4e97cezuhn0cqcexl7",
            "--submit",
        ])
        #expect(cmd.policyAsset == "myPolicy.MYTOK")
        #expect(cmd.amount == 200)
    }

    @Test("asset burn — explicit flag form example")
    func assetBurnExplicitFlagsExample() throws {
        let cmd = try AssetMainCommand.Burn.parse([
            "--policy-name", "myPolicy",
            "--asset-name", "MYTOK",
            "--amount", "200",
            "--fee-payment-address", "addr_test1vr2p8st5t5cxqglyjky7vk98k7jtfhdpvhl4e97cezuhn0cqcexl7",
            "--submit",
        ])
        #expect(cmd.policyName == "myPolicy")
        #expect(cmd.amount == 200)
    }

    // MARK: - governance vote

    @Test("governance vote — positional govActionId + choice + --voter-vkey-file")
    func governanceVoteExample() throws {
        let cmd = try GovernanceMainCommand.Vote.parse([
            "gov_action1xyz", "yes",
            "--voter-vkey-file", "myDRep.drep.vkey",
            "--fee-payment-address", "addr_test1vr2p8st5t5cxqglyjky7vk98k7jtfhdpvhl4e97cezuhn0cqcexl7",
            "--submit",
        ])
        #expect(cmd.govActionId == "gov_action1xyz")
        #expect(cmd.choice != nil)
        #expect(cmd.voterVkeyFile?.string == "myDRep.drep.vkey")
    }

    // MARK: - governance info-action

    @Test("governance info-action — anchor + deposit-return + fee-payment example")
    func governanceInfoActionExample() throws {
        let cmd = try GovernanceMainCommand.InfoAction.parse([
            "--anchor-url", "ipfs://Qm...",
            "--anchor-hash", String(repeating: "a", count: 64),
            "--deposit-return-stake-address", "stake_test1upyz3gk6mw5he20apnwfn96cn9rscgvmmsxc9r86dh0k66gswf59n",
            "--fee-payment-address", "addr_test1vr2p8st5t5cxqglyjky7vk98k7jtfhdpvhl4e97cezuhn0cqcexl7",
            "--submit",
        ])
        #expect(cmd.actionOptions.anchorUrl == "ipfs://Qm...")
        #expect(cmd.actionOptions.anchorHash == String(repeating: "a", count: 64))
    }

    // MARK: - governance treasury-withdrawal

    @Test("governance treasury-withdrawal — full anchored example")
    func governanceTreasuryWithdrawalExample() throws {
        let cmd = try GovernanceMainCommand.TreasuryWithdrawal.parse([
            "--withdrawal", "stake1addr:1000000000",
            "--anchor-url", "ipfs://Qm...",
            "--anchor-hash", String(repeating: "b", count: 64),
            "--deposit-return-stake-address", "stake_test1upyz3gk6mw5he20apnwfn96cn9rscgvmmsxc9r86dh0k66gswf59n",
            "--fee-payment-address", "addr_test1vr2p8st5t5cxqglyjky7vk98k7jtfhdpvhl4e97cezuhn0cqcexl7",
            "--submit",
        ])
        #expect(cmd.withdrawal == ["stake1addr:1000000000"])
    }

    // MARK: - governance no-confidence

    @Test("governance no-confidence — prev-action-id example")
    func governanceNoConfidenceExample() throws {
        let cmd = try GovernanceMainCommand.NoConfidence.parse([
            "--anchor-url", "ipfs://Qm...",
            "--anchor-hash", String(repeating: "c", count: 64),
            "--prev-action-id", "gov_action1prev",
            "--deposit-return-stake-address", "stake_test1upyz3gk6mw5he20apnwfn96cn9rscgvmmsxc9r86dh0k66gswf59n",
            "--fee-payment-address", "addr_test1vr2p8st5t5cxqglyjky7vk98k7jtfhdpvhl4e97cezuhn0cqcexl7",
            "--submit",
        ])
        #expect(cmd.prevActionId == "gov_action1prev")
    }

    // MARK: - governance submit-action

    @Test("governance submit-action — single --action-file")
    func governanceSubmitActionSingle() throws {
        let cmd = try GovernanceMainCommand.SubmitAction.parse([
            "--action-file", "mywallet_info_20260604.action",
            "--fee-payment-address", "addr_test1vr2p8st5t5cxqglyjky7vk98k7jtfhdpvhl4e97cezuhn0cqcexl7",
            "--submit",
        ])
        #expect(cmd.actionFile.count == 1)
        #expect(cmd.actionFile.first?.string == "mywallet_info_20260604.action")
    }

    @Test("governance submit-action — repeated --action-file")
    func governanceSubmitActionRepeated() throws {
        let cmd = try GovernanceMainCommand.SubmitAction.parse([
            "--action-file", "proposal-a.action",
            "--action-file", "proposal-b.action",
            "--fee-payment-address", "addr_test1vr2p8st5t5cxqglyjky7vk98k7jtfhdpvhl4e97cezuhn0cqcexl7",
            "--submit",
        ])
        #expect(cmd.actionFile.map(\.string) == ["proposal-a.action", "proposal-b.action"])
    }

    // MARK: - governance canonize

    @Test("governance canonize --data-file example")
    func governanceCanonizeExample() throws {
        let cmd = try GovernanceMainCommand.Canonize.parse([
            "--data-file", "proposal.jsonld",
        ])
        #expect(cmd.dataFile?.string == "proposal.jsonld")
    }

    // MARK: - governance cip129 encode/decode

    @Test("governance cip129 encode — --prefix + --key-hash")
    func governanceCip129EncodeExample() throws {
        let cmd = try GovernanceMainCommand.CIP129Command.Encode.parse([
            "--prefix", "drep",
            "--key-hash", String(repeating: "a", count: 56),
        ])
        #expect(cmd.prefix == "drep")
        #expect(cmd.script == false)
    }

    @Test("governance cip129 encode — --script flag example")
    func governanceCip129EncodeScriptExample() throws {
        let cmd = try GovernanceMainCommand.CIP129Command.Encode.parse([
            "--prefix", "drep",
            "--key-hash", String(repeating: "a", count: 56),
            "--script",
        ])
        #expect(cmd.script == true)
    }

    @Test("governance cip129 decode --id example")
    func governanceCip129DecodeExample() throws {
        let cmd = try GovernanceMainCommand.CIP129Command.Decode.parse([
            "--id", "drep1ygx",
        ])
        #expect(cmd.id == "drep1ygx")
    }

    // MARK: - sign

    @Test("sign default --data + --secret-key example")
    func signDefaultDataExample() throws {
        let cmd = try SignMainCommand.SignDefault.parse([
            "--data", "hello",
            "--secret-key", "payment.skey",
        ])
        #expect(cmd.data == "hello")
        #expect(cmd.secretKey == "payment.skey")
    }

    @Test("sign default --data-hex + --secret-key + --json-extended example")
    func signDefaultDataHexExample() throws {
        let cmd = try SignMainCommand.SignDefault.parse([
            "--data-hex", "48656c6c6f",
            "--secret-key", "payment.skey",
            "--json-extended",
        ])
        #expect(cmd.dataHex == "48656c6c6f")
        #expect(cmd.output.jsonExtended == true)
    }

    @Test("sign default --data-file + --secret-key + --out-file example")
    func signDefaultDataFileExample() throws {
        let cmd = try SignMainCommand.SignDefault.parse([
            "--data-file", "message.txt",
            "--secret-key", "payment.skey",
            "--out-file", "sig.txt",
        ])
        #expect(cmd.dataFile?.string == "message.txt")
        #expect(cmd.output.outFile?.string == "sig.txt")
    }

    @Test("sign cip8 --data + --secret-key + --testnet + --attach-cose-key example")
    func signCip8FullExample() throws {
        let cmd = try SignMainCommand.SignCIP8.parse([
            "--data", "hello",
            "--secret-key", "payment.skey",
            "--testnet",
            "--attach-cose-key",
        ])
        #expect(cmd.testnet == true)
        #expect(cmd.attachCoseKey == true)
    }

    @Test("sign cip30 --data + --secret-key example")
    func signCip30Example() throws {
        let cmd = try SignMainCommand.SignCIP30.parse([
            "--data", "hello",
            "--secret-key", "wallet.skey",
        ])
        #expect(cmd.data == "hello")
        #expect(cmd.secretKey == "wallet.skey")
    }

    @Test("sign cip36 registration example — payment-address + vote-public-key + secret-key")
    func signCip36RegistrationExample() throws {
        let cmd = try SignMainCommand.SignCIP36.parse([
            "--payment-address", "addr1abc",
            "--vote-public-key", "vote.vkey",
            "--secret-key", "stake.skey",
        ])
        #expect(cmd.paymentAddress == "addr1abc")
        #expect(cmd.votePublicKeys == ["vote.vkey"])
        #expect(cmd.secretKey == "stake.skey")
        #expect(cmd.deregister == false)
    }

    @Test("sign cip36 deregistration example")
    func signCip36DeregistrationExample() throws {
        let cmd = try SignMainCommand.SignCIP36.parse([
            "--deregister",
            "--secret-key", "stake.skey",
        ])
        #expect(cmd.deregister == true)
        #expect(cmd.secretKey == "stake.skey")
    }

    @Test("sign cip88 --calidus-public-key + --secret-key example")
    func signCip88Example() throws {
        let cmd = try SignMainCommand.SignCIP88.parse([
            "--calidus-public-key", "calidus.vkey",
            "--secret-key", "pool.cold.skey",
        ])
        #expect(cmd.calidusPublicKey == "calidus.vkey")
        #expect(cmd.secretKey == "pool.cold.skey")
    }

    @Test("sign cip100 --data-file + --secret-key + --author-name example")
    func signCip100Example() throws {
        let cmd = try SignMainCommand.SignCIP100.parse([
            "--data-file", "proposal.jsonld",
            "--secret-key", "author.skey",
            "--author-name", "Alice",
        ])
        #expect(cmd.dataFile?.string == "proposal.jsonld")
        #expect(cmd.secretKey == "author.skey")
        #expect(cmd.authorName == "Alice")
    }

    // MARK: - verify

    @Test("verify default --data + --public-key + --signature example")
    func verifyDefaultExample() throws {
        let cmd = try VerifyMainCommand.VerifyDefault.parse([
            "--data", "hello",
            "--public-key", "payment.vkey",
            "--signature", "8a5fd6aabbccddeeff",
        ])
        #expect(cmd.data == "hello")
        #expect(cmd.publicKey == "payment.vkey")
        #expect(cmd.signature == "8a5fd6aabbccddeeff")
    }

    @Test("verify cip8 --cose-sign1 + --cose-key example")
    func verifyCip8Example() throws {
        let cmd = try VerifyMainCommand.VerifyCIP8.parse([
            "--cose-sign1", "84582a",
            "--cose-key", "a401",
        ])
        #expect(cmd.coseSign1 == "84582a")
        #expect(cmd.coseKey == "a401")
    }

    @Test("verify cip30 --cose-sign1 + --cose-key example")
    func verifyCip30Example() throws {
        let cmd = try VerifyMainCommand.VerifyCIP30.parse([
            "--cose-sign1", "84582a",
            "--cose-key", "a401",
        ])
        #expect(cmd.coseSign1 == "84582a")
        #expect(cmd.coseKey == "a401")
    }

    @Test("verify cip100 --data-file example")
    func verifyCip100Example() throws {
        let cmd = try VerifyMainCommand.VerifyCIP100.parse([
            "--data-file", "proposal-signed.jsonld",
        ])
        #expect(cmd.dataFile?.string == "proposal-signed.jsonld")
    }

    @Test("verify cip100 --data-file + --json-extended example")
    func verifyCip100ExtendedExample() throws {
        let cmd = try VerifyMainCommand.VerifyCIP100.parse([
            "--data-file", "proposal-signed.jsonld",
            "--json-extended",
        ])
        #expect(cmd.dataFile?.string == "proposal-signed.jsonld")
        #expect(cmd.output.jsonExtended == true)
    }
}

/// README examples for `certificate` subcommand names — these names appear in the README's
/// command table. If any subcommand is renamed or removed, the table is wrong; these checks
/// catch that drift.
@Suite("README — certificate subcommand names exist")
struct CertificateReadmeNamesTests {

    @Test("certificate alias 'cert' is registered")
    func certAliasRegistered() {
        #expect(CertificateMainCommand.configuration.aliases.contains("cert"))
    }

    @Test("every certificate subcommand listed in README is registered")
    func subcommandsCoverReadmeTable() {
        let registered = Set(CertificateMainCommand.configuration.subcommands.map { $0.configuration.commandName })
        let documented = [
            "stake-address-registration",
            "stake-address-delegation",
            "stake-address-deregistration",
            "pool-registration",
            "pool-deregistration",
            "vote-delegation",
            "stake-vote-delegation",
            "stake-register-delegation",
            "vote-register-delegation",
            "stake-vote-register-delegation",
            "auth-committee-hot",
            "resign-committee-cold",
            "register-drep",
            "unregister-drep",
            "update-drep",
            "genesis-key-delegation",
            "move-instantaneous-rewards",
        ]
        for name in documented {
            #expect(registered.contains(name), "README documents 'certificate \(name)' but no such subcommand is registered.")
        }
    }
}

/// Parser-level checks for every command-line invocation shown in `GenerateCommand.md`.
@Suite("Generate documentation examples — parse")
struct GenerateDocumentationExamplesTests {

    // MARK: - node-cold-keys

    @Test("node-cold-keys --pool-name --key-gen-method cli example")
    func nodeColdKeysCliExample() throws {
        let cmd = try GenerateMainCommand.NodeColdKeys.parse([
            "--pool-name", "myPool",
            "--key-gen-method", "cli",
        ])
        #expect(cmd.poolName == "myPool")
        #expect(cmd.keyGenMethod == .cli)
    }

    @Test("node-cold-keys --key-gen-method enc example")
    func nodeColdKeysEncExample() throws {
        let cmd = try GenerateMainCommand.NodeColdKeys.parse([
            "--pool-name", "myPool",
            "--key-gen-method", "enc",
        ])
        #expect(cmd.keyGenMethod == .enc)
    }

    @Test("node-cold-keys --key-gen-method hw --cold-key-index example")
    func nodeColdKeysHwExample() throws {
        let cmd = try GenerateMainCommand.NodeColdKeys.parse([
            "--pool-name", "myPool",
            "--key-gen-method", "hw",
            "--cold-key-index", "0",
        ])
        #expect(cmd.keyGenMethod == .hw)
        #expect(cmd.coldKeyIndex == 0)
    }

    // MARK: - node-kes-keys

    @Test("node-kes-keys --pool-name --key-gen-method cli example")
    func nodeKesKeysExample() throws {
        let cmd = try GenerateMainCommand.NodeKESKeys.parse([
            "--pool-name", "myPool",
            "--key-gen-method", "cli",
        ])
        #expect(cmd.poolName == "myPool")
        #expect(cmd.keyGenMethod == .cli)
    }

    // MARK: - node-vrf-keys

    @Test("node-vrf-keys --pool-name --key-gen-method cli example")
    func nodeVrfKeysExample() throws {
        let cmd = try GenerateMainCommand.NodeVRFKeys.parse([
            "--pool-name", "myPool",
            "--key-gen-method", "cli",
        ])
        #expect(cmd.poolName == "myPool")
        #expect(cmd.keyGenMethod == .cli)
    }

    // MARK: - node-operational-certificate

    @Test("node-operational-certificate --pool-name example")
    func nodeOpCertSimpleExample() throws {
        let cmd = try GenerateMainCommand.NodeOperationalCertificate.parse([
            "--pool-name", "myPool",
        ])
        #expect(cmd.poolName == "myPool")
        #expect(cmd.useOpCertCounter == nil)
    }

    @Test("node-operational-certificate --use-op-cert-counter example")
    func nodeOpCertCounterExample() throws {
        let cmd = try GenerateMainCommand.NodeOperationalCertificate.parse([
            "--pool-name", "myPool",
            "--use-op-cert-counter", "12",
        ])
        #expect(cmd.useOpCertCounter == 12)
    }

    // MARK: - payment-address-only

    @Test("payment-address-only --address-name --key-gen-method cli example")
    func paymentAddressOnlyCliExample() throws {
        let cmd = try GenerateMainCommand.PaymentAddressOnly.parse([
            "--address-name", "owner",
            "--key-gen-method", "cli",
        ])
        #expect(cmd.addressName == "owner")
        #expect(cmd.keyGenMethod == .cli)
    }

    @Test("payment-address-only --key-gen-method mnemonics --sub-account --index example")
    func paymentAddressOnlyMnemonicsExample() throws {
        let cmd = try GenerateMainCommand.PaymentAddressOnly.parse([
            "--address-name", "owner",
            "--key-gen-method", "mnemonics",
            "--sub-account", "0",
            "--index", "0",
        ])
        #expect(cmd.keyGenMethod == .mnemonics)
        #expect(cmd.subAccount == 0)
        #expect(cmd.index == 0)
    }

    // MARK: - payment-and-stake-address

    @Test("payment-and-stake-address --address-name --key-gen-method cli example")
    func paymentAndStakeCliExample() throws {
        let cmd = try GenerateMainCommand.PaymentAndStakeAddress.parse([
            "--address-name", "owner",
            "--key-gen-method", "cli",
        ])
        #expect(cmd.addressName == "owner")
        #expect(cmd.keyGenMethod == .cli)
    }

    @Test("payment-and-stake-address mnemonics example")
    func paymentAndStakeMnemonicsExample() throws {
        let cmd = try GenerateMainCommand.PaymentAndStakeAddress.parse([
            "--address-name", "owner",
            "--key-gen-method", "mnemonics",
            "--sub-account", "0",
            "--index", "0",
        ])
        #expect(cmd.keyGenMethod == .mnemonics)
        #expect(cmd.subAccount == 0)
        #expect(cmd.index == 0)
    }

    // MARK: - pool-json

    @Test("pool-json --pool-name example")
    func poolJsonExample() throws {
        let cmd = try GenerateMainCommand.PoolJSON.parse([
            "--pool-name", "myPool",
        ])
        #expect(cmd.poolName == "myPool")
        #expect(cmd.overwrite == false)
    }

    @Test("pool-json --pool-name --overwrite example")
    func poolJsonOverwriteExample() throws {
        let cmd = try GenerateMainCommand.PoolJSON.parse([
            "--pool-name", "myPool",
            "--overwrite",
        ])
        #expect(cmd.overwrite == true)
    }

    @Test("pool-json registers the 'pool' alias")
    func poolJsonAlias() {
        #expect(GenerateMainCommand.PoolJSON.configuration.aliases.contains("pool"))
    }

    // MARK: - key-rotation

    @Test("key-rotation --pool-name --key-gen-method cli example")
    func keyRotationSingleExample() throws {
        let cmd = try GenerateMainCommand.KeyRotation.parse([
            "--pool-name", "myPool",
            "--key-gen-method", "cli",
        ])
        #expect(cmd.poolName == "myPool")
        #expect(cmd.keyGenMethod == .cli)
    }

    @Test("key-rotation --number-of-pools example")
    func keyRotationMultiExample() throws {
        let cmd = try GenerateMainCommand.KeyRotation.parse([
            "--pool-name", "myPool",
            "--number-of-pools", "3",
            "--key-gen-method", "cli",
        ])
        #expect(cmd.numberOfPools == 3)
    }

    @Test("generate alias 'gen' is registered")
    func generateGenAlias() {
        #expect(GenerateMainCommand.configuration.aliases.contains("gen"))
    }
}

/// Parser-level checks for every command-line invocation shown in `TransactionCommand.md`.
@Suite("Transaction documentation examples — parse")
struct TransactionDocumentationExamplesTests {

    // MARK: - build

    @Test("transaction build --tx-in --tx-out --change-address --out-file example")
    func buildExample() throws {
        let txHash = String(repeating: "a", count: 64)
        let cmd = try TransactionMainCommand.Build.parse([
            "--tx-in", "\(txHash)#0",
            "--tx-out", "addr1...+2000000",
            "--change-address", "addr1...",
            "--out-file", "tx.body",
        ])
        #expect(cmd.txIn == ["\(txHash)#0"])
        #expect(cmd.txOut == ["addr1...+2000000"])
        #expect(cmd.changeAddress == "addr1...")
        #expect(cmd.outFile?.string == "tx.body")
    }

    // MARK: - sign

    @Test("transaction sign --tx-file --signing-keys --out-file example")
    func signExample() throws {
        let cmd = try TransactionMainCommand.Sign.parse([
            "--tx-file", "tx.body",
            "--signing-keys", "payment.skey",
            "--signing-keys", "stake.skey",
            "--out-file", "tx.signed",
        ])
        #expect(cmd.txFile?.string == "tx.body")
        #expect(cmd.signingKeys.map(\.string) == ["payment.skey", "stake.skey"])
        #expect(cmd.outFile?.string == "tx.signed")
    }

    // MARK: - witness

    @Test("transaction witness --tx-file --signing-keys --out-file example")
    func witnessExample() throws {
        let cmd = try TransactionMainCommand.Witness.parse([
            "--tx-file", "tx.body",
            "--signing-keys", "payment.skey",
            "--out-file", "payment.witness",
        ])
        #expect(cmd.txFile?.string == "tx.body")
        #expect(cmd.signingKeys.map(\.string) == ["payment.skey"])
        #expect(cmd.outFile?.string == "payment.witness")
    }

    // MARK: - assemble

    @Test("transaction assemble --tx-file --witness-file example")
    func assembleExample() throws {
        let cmd = try TransactionMainCommand.Assemble.parse([
            "--tx-file", "tx.body",
            "--witness-file", "payment.witness",
            "--witness-file", "stake.witness",
            "--out-file", "tx.signed",
        ])
        #expect(cmd.witnessFiles.map(\.string) == ["payment.witness", "stake.witness"])
    }

    // MARK: - submit

    @Test("transaction submit --tx-file example")
    func submitFileExample() throws {
        let cmd = try TransactionMainCommand.Submit.parse([
            "--tx-file", "tx.signed",
        ])
        #expect(cmd.txFile?.string == "tx.signed")
    }

    @Test("transaction submit --cbor-hex example")
    func submitCborExample() throws {
        let cmd = try TransactionMainCommand.Submit.parse([
            "--cbor-hex", "84a40081825820",
        ])
        #expect(cmd.cborHex == "84a40081825820")
    }

    // MARK: - calculate-min-fee

    @Test("transaction calculate-min-fee --tx-file --witness-count example")
    func calcMinFeeExample() throws {
        let cmd = try TransactionMainCommand.CalculateMinFee.parse([
            "--tx-file", "tx.body",
            "--witness-count", "1",
        ])
        #expect(cmd.txFile?.string == "tx.body")
        #expect(cmd.witnessCount == 1)
    }

    @Test("transaction calculate-min-fee --cbor-hex --reference-script-size example")
    func calcMinFeeRefScriptExample() throws {
        let cmd = try TransactionMainCommand.CalculateMinFee.parse([
            "--cbor-hex", "84a5",
            "--witness-count", "2",
            "--reference-script-size", "512",
        ])
        #expect(cmd.witnessCount == 2)
        #expect(cmd.referenceScriptSize == 512)
    }

    @Test("calculate-min-fee registers 'min-fee' alias")
    func calcMinFeeAlias() {
        #expect(TransactionMainCommand.CalculateMinFee.configuration.aliases.contains("min-fee"))
    }

    // MARK: - calculate-min-required-utxo

    @Test("transaction calculate-min-required-utxo --tx-out-address --tx-out-value example")
    func calcMinUtxoExample() throws {
        let cmd = try TransactionMainCommand.CalculateMinRequiredUtxo.parse([
            "--tx-out-address", "addr1...",
            "--tx-out-value", "2000000 lovelace",
        ])
        #expect(cmd.txOutAddress == "addr1...")
        #expect(cmd.txOutValue == "2000000 lovelace")
    }

    @Test("calculate-min-required-utxo registers 'min-utxo' alias")
    func calcMinUtxoAlias() {
        #expect(TransactionMainCommand.CalculateMinRequiredUtxo.configuration.aliases.contains("min-utxo"))
    }

    // MARK: - hash-script-data

    @Test("transaction hash-script-data --script-data-file example")
    func hashScriptDataFileExample() throws {
        let cmd = try TransactionMainCommand.HashScriptData.parse([
            "--script-data-file", "datum.json",
        ])
        #expect(cmd.scriptDataFile?.string == "datum.json")
    }

    @Test("transaction hash-script-data --script-data-value example")
    func hashScriptDataInlineExample() throws {
        let cmd = try TransactionMainCommand.HashScriptData.parse([
            "--script-data-value", "{\"int\": 42}",
        ])
        #expect(cmd.scriptDataValue == "{\"int\": 42}")
    }

    @Test("transaction hash-script-data --script-data-cbor-hex example")
    func hashScriptDataCborHexExample() throws {
        let cmd = try TransactionMainCommand.HashScriptData.parse([
            "--script-data-cbor-hex", "1864",
        ])
        #expect(cmd.scriptDataCborHex == "1864")
    }

    @Test("hash-script-data registers 'hsd' alias")
    func hashScriptDataAlias() {
        #expect(TransactionMainCommand.HashScriptData.configuration.aliases.contains("hsd"))
    }

    // MARK: - rewards-withdraw

    @Test("transaction rewards-withdraw --stake-address --to-address example")
    func rewardsWithdrawExample() throws {
        let cmd = try TransactionMainCommand.RewardsWithdraw.parse([
            "--stake-address", "stake_test1upyz3gk6mw5he20apnwfn96cn9rscgvmmsxc9r86dh0k66gswf59n",
            "--to-address", "addr_test1vr2p8st5t5cxqglyjky7vk98k7jtfhdpvhl4e97cezuhn0cqcexl7",
        ])
        #expect(cmd.stakeAddress != nil)
        #expect(cmd.transactionOptions.toAddress != nil)
    }

    @Test("transaction rewards-withdraw --fee-payment-address + --message + --submit example")
    func rewardsWithdrawFullExample() throws {
        let cmd = try TransactionMainCommand.RewardsWithdraw.parse([
            "--stake-address", "stake_test1upyz3gk6mw5he20apnwfn96cn9rscgvmmsxc9r86dh0k66gswf59n",
            "--to-address", "addr_test1vr2p8st5t5cxqglyjky7vk98k7jtfhdpvhl4e97cezuhn0cqcexl7",
            "--fee-payment-address", "addr_test1vr2p8st5t5cxqglyjky7vk98k7jtfhdpvhl4e97cezuhn0cqcexl7",
            "--message", "Rewards for epoch 450",
            "--submit",
        ])
        #expect(cmd.transactionOptions.messages == ["Rewards for epoch 450"])
        #expect(cmd.transactionOptions.submit == true)
    }

    // MARK: - id (NOT txid)

    @Test("transaction txid --tx-file example (subcommand is 'txid' with 'id' alias)")
    func txidExample() throws {
        #expect(TransactionMainCommand.Id.configuration.commandName == "txid")
        #expect(TransactionMainCommand.Id.configuration.aliases.contains("id"))
        let cmd = try TransactionMainCommand.Id.parse([
            "--tx-file", "tx.signed",
        ])
        #expect(cmd.txFile?.string == "tx.signed")
    }

    @Test("transaction txid --json flag example")
    func txidJsonExample() throws {
        let cmd = try TransactionMainCommand.Id.parse([
            "--tx-file", "tx.signed",
            "--json",
        ])
        #expect(cmd.json == true)
    }

    // MARK: - view / inspect / validate

    @Test("transaction view --tx-file example")
    func viewExample() throws {
        let cmd = try TransactionMainCommand.View.parse([
            "--tx-file", "tx.signed",
        ])
        #expect(cmd.txFile?.string == "tx.signed")
    }

    @Test("transaction inspect --tx-file example")
    func inspectExample() throws {
        let cmd = try TransactionMainCommand.Inspect.parse([
            "--tx-file", "tx.signed",
        ])
        #expect(cmd.txFile?.string == "tx.signed")
    }

    @Test("transaction inspect --tx-file --json example")
    func inspectJsonExample() throws {
        let cmd = try TransactionMainCommand.Inspect.parse([
            "--tx-file", "tx.signed",
            "--json",
        ])
        #expect(cmd.json == true)
    }

    @Test("transaction validate --tx-file example")
    func validateExample() throws {
        let cmd = try TransactionMainCommand.Validate.parse([
            "--tx-file", "tx.signed",
        ])
        #expect(cmd.txFile?.string == "tx.signed")
    }

    @Test("transaction alias 'tx' is registered")
    func transactionAlias() {
        #expect(TransactionMainCommand.configuration.aliases.contains("tx"))
    }
}
