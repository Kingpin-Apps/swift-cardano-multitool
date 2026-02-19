import Foundation
import ArgumentParser
import Noora
import SystemPackage
import SwiftCardanoCore
import SwiftCardanoUtils
import SwiftKES
import Configuration

// MARK: - Supporting Enums

/// Enum for witness type indicating whether the witness is local or external
public enum WitnessType: String, Codable, Sendable, Hashable {
    case local = "local"
    case external = "external"
}

/// Enum for relay type
public enum SPORelayType: String, Codable, Sendable, Hashable {
    case ip = "ip"
    case dns = "dns"
}

/// Enum for host type
public enum HostType: String, Codable, Sendable, Hashable {
    case ipv4 = "ipv4"
    case ipv6 = "ipv6"
    case single = "single"
    case multi = "multi"
}

// MARK: - Supporting Models

/// Pool Relay model for stake pool configuration
public struct PoolRelay: Codable, Sendable, Hashable, Equatable {
    public var type: SPORelayType?
    public var host: String?
    public var port: String?
    public var hostType: HostType?
    
    private enum CodingKeys: String, CodingKey {
        case type
        case host
        case port
        case hostType = "host_type"
    }
    
    public init(
        type: SPORelayType? = nil,
        host: String? = nil,
        port: String? = nil,
        hostType: HostType? = nil
    ) {
        self.type = type
        self.host = host
        self.port = port
        
        // Set default hostType based on relay type if not provided
        if let type = type, hostType == nil {
            self.hostType = (type == .ip) ? .ipv4 : .single
        } else {
            self.hostType = hostType
        }
    }
    
    /// Validates the host length (max 64 characters)
    public func validate() throws {
        if let host = host, host.count > 64 {
            throw SwiftCardanoMultitoolError.valueError(
                "The relay host is too long. Max. 64 chars allowed!"
            )
        }
    }
}

/// Delegator model for stake pool delegation
public struct Delegator: Codable, Sendable {
    public var name: String?
    public var witness: WitnessType
    
    @FilePathCodable
    public var stakeVkey: FilePath?
    
    @FilePathCodable
    public var stakeSkey: FilePath?
    
    @FilePathCodable
    public var delegationCertificate: FilePath?
    
    private enum CodingKeys: String, CodingKey {
        case name
        case witness
        case stakeVkey = "stake_vkey"
        case stakeSkey = "stake_skey"
        case delegationCertificate = "delegation_certificate"
    }
    
    public init(
        name: String? = nil,
        witness: WitnessType = .local,
        stakeVkey: FilePath? = nil,
        stakeSkey: FilePath? = nil,
        delegationCertificate: FilePath? = nil
    ) {
        self.name = name
        self.witness = witness
        
        let cwd = FilePath(FileManager.default.currentDirectoryPath)
        self.stakeVkey = stakeVkey ?? (name.map { cwd.appending("\($0).staking.vkey") })
        self.stakeSkey = stakeSkey ?? (name.map { cwd.appending("\($0).staking.skey") })
        self.delegationCertificate = delegationCertificate
    }
}

/// Pool Owner model (extends Delegator)
public struct PoolOwner: Codable, Sendable {
    public var name: String?
    public var witness: WitnessType
    
    @FilePathCodable
    public var stakeVkey: FilePath?
    
    @FilePathCodable
    public var stakeSkey: FilePath?
    
    @FilePathCodable
    public var delegationCertificate: FilePath?
    
    private enum CodingKeys: String, CodingKey {
        case name
        case witness
        case stakeVkey = "stake_vkey"
        case stakeSkey = "stake_skey"
        case delegationCertificate = "delegation_certificate"
    }
    
    public init(
        name: String? = nil,
        witness: WitnessType = .local,
        stakeVkey: FilePath? = nil,
        stakeSkey: FilePath? = nil,
        delegationCertificate: FilePath? = nil
    ) {
        self.name = name
        self.witness = witness
        
        let cwd = FilePath(FileManager.default.currentDirectoryPath)
        self.stakeVkey = stakeVkey ?? (name.map { cwd.appending("\($0).stake.vkey") })
        self.stakeSkey = stakeSkey ?? (name.map { cwd.appending("\($0).stake.skey") })
        self.delegationCertificate = delegationCertificate
    }
}

/// Rewards Owner model for stake pool rewards destination
public struct RewardsOwner: Codable, Sendable {
    public var name: String?
    
    @FilePathCodable
    public var stakeVkey: FilePath?
    
    @FilePathCodable
    public var stakeSkey: FilePath?
    
    private enum CodingKeys: String, CodingKey {
        case name
        case stakeVkey = "stake_vkey"
        case stakeSkey = "stake_skey"
    }
    
    public init(
        name: String? = nil,
        stakeVkey: FilePath? = nil,
        stakeSkey: FilePath? = nil
    ) {
        self.name = name
        
        let cwd = FilePath(FileManager.default.currentDirectoryPath)
        self.stakeVkey = stakeVkey ?? (name.map { cwd.appending("\($0).stake.vkey") })
        self.stakeSkey = stakeSkey ?? (name.map { cwd.appending("\($0).stake.skey") })
    }
}

/// Registration model for stake pool registration information
public struct PoolRegistration: Codable, Sendable {
    public var certCreated: Date?
    
    @FilePathCodable
    public var certificate: FilePath?
    
    public var protectionKey: String?
    public var epoch: Int?
    public var submitted: Date?
    public var submittedStatus: String?
    public var proof: String?
    
    private enum CodingKeys: String, CodingKey {
        case certCreated = "cert_created"
        case certificate
        case protectionKey = "protection_key"
        case epoch
        case submitted
        case submittedStatus = "submitted_status"
        case proof
    }
    
    public init(
        certCreated: Date? = nil,
        certificate: FilePath? = nil,
        protectionKey: String? = nil,
        epoch: Int? = nil,
        submitted: Date? = nil,
        submittedStatus: String? = nil,
        proof: String? = nil
    ) {
        self.certCreated = certCreated
        self.certificate = certificate
        self.protectionKey = protectionKey
        self.epoch = epoch
        self.submitted = submitted
        self.submittedStatus = submittedStatus
        self.proof = proof
    }
}

/// Deregistration model for stake pool deregistration information
public struct PoolDeregistration: Codable, Sendable {
    public var submitted: Date?
    public var certCreated: Date?
    
    @FilePathCodable
    public var certificate: FilePath?
    
    public var epoch: Int?
    public var proof: String?
    public var payeeName: String?
    public var payeeAddress: String?
    
    @FilePathCodable
    public var payeeSkey: FilePath?
    
    @FilePathCodable
    public var payeeHwsFile: FilePath?
    
    private enum CodingKeys: String, CodingKey {
        case submitted
        case certCreated = "cert_created"
        case certificate
        case epoch
        case proof
        case payeeName = "payee_name"
        case payeeAddress = "payee_address"
        case payeeSkey = "payee_skey"
        case payeeHwsFile = "payee_hws_file"
    }
    
    public init(
        submitted: Date? = nil,
        certCreated: Date? = nil,
        certificate: FilePath? = nil,
        epoch: Int? = nil,
        proof: String? = nil,
        payeeName: String? = nil,
        payeeAddress: String? = nil,
        payeeSkey: FilePath? = nil,
        payeeHwsFile: FilePath? = nil
    ) {
        self.submitted = submitted
        self.certCreated = certCreated
        self.certificate = certificate
        self.epoch = epoch
        self.proof = proof
        self.payeeName = payeeName
        self.payeeAddress = payeeAddress
        self.payeeSkey = payeeSkey
        self.payeeHwsFile = payeeHwsFile
    }
}

// MARK: - Pool Model

/// Stake pool model class for storing important information and configuration for a pool
public struct Pool: Codable, Sendable {
    
    // MARK: - Basic Pool Information
    
    /// Reference to the file name used on the hdd for the node files
    public var name: String?
    
    /// The list of pool owners
    public var owners: [PoolOwner]
    
    /// The amount of lovelaces (1 ADA = 1 Mio lovelaces) you are committing to hold in your owner wallet(s)
    public var pledge: Int?
    
    /// The amount of lovelaces (1 ADA = 1 Mio lovelaces) you are taking as a fee per epoch from the total rewards
    public var cost: Int?
    
    /// The amount in percentage you are taking from the total rewards: 0.00=0%, 0.10=10%, 1.00=100%
    public var margin: Double?
    
    /// The list of pool relays
    public var relays: [PoolRelay]
    
    // MARK: - Metadata Information
    
    /// This is a longer Name for your StakePool, shown in wallets like Daedalus or Yoroi
    public var metaName: String?
    
    /// This is a longer description for your StakePool, shown in wallets
    public var metaDescription: String?
    
    /// The short name, or Ticker, for your StakePool (3-5 characters)
    public var metaTicker: String?
    
    /// This is a link to your StakePool-Homepage (should be https://)
    public var metaHomepage: URL?
    
    /// This is a link to your MetaFile of your StakePool (should be https://)
    public var metaUrl: URL?
    
    /// Extended metadata URL for additional information (optional)
    public var extendedMetaUrl: URL?
    
    // MARK: - Pool IDs
    
    /// The pool id in Hex format
    public var idHex: String?
    
    /// The pool id in Bech32 format
    public var idBech: String?
    
    @FilePathCodable
    public var idHexFile: FilePath?
    
    @FilePathCodable
    public var idBechFile: FilePath?
    
    // MARK: - Metadata Files
    
    /// The hash of the pool metadata
    public var metadataHash: String?
    
    @FilePathCodable
    public var metadataFile: FilePath?
    
    @FilePathCodable
    public var additionalMetadataFile: FilePath?
    
    @FilePathCodable
    public var extendedMetadataFile: FilePath?
    
    // MARK: - Key Files
    
    /// poolname.node.vkey - public verification key file for stake pool's cold key
    @FilePathCodable
    public var coldVkey: FilePath?
    
    /// poolname.node.skey - secret (private) signing key file for stake pool (extremely sensitive)
    @FilePathCodable
    public var coldSkey: FilePath?
    
    /// poolname.node.counter
    @FilePathCodable
    public var nodeCounter: FilePath?
    
    /// poolname.vrf.skey - secret (private) signing key file for VRF key
    @FilePathCodable
    public var vrfSkey: FilePath?
    
    /// poolname.vrf.vkey - public verification key file for VRF key
    @FilePathCodable
    public var vrfVkey: FilePath?
    
    // MARK: - Rewards
    
    /// The rewards owner for the pool
    public var rewardsOwner: RewardsOwner?
    
    // MARK: - KES Keys
    
    /// poolname.kes-xxx.vkey - public verification key file for KES key
    @FilePathCodable
    public var kesVkey: FilePath?
    
    /// poolname.kes-xxx.skey - secret (private) signature key file for KES key
    @FilePathCodable
    public var kesSkey: FilePath?
    
    /// poolname.kes.counter
    @FilePathCodable
    public var kesCounter: FilePath?
    
    /// poolname.kes.counter-next
    @FilePathCodable
    public var kesCounterNext: FilePath?
    
    /// poolname.kes-expire.json
    @FilePathCodable
    public var kesExpireJson: FilePath?
    
    /// poolname.node-xxx.opcert
    @FilePathCodable
    public var opCert: FilePath?
    
    // MARK: - Payment Keys
    
    /// name.payment.addr - payment address for the stake pool
    public var paymentAddr: String?
    
    @FilePathCodable
    public var paymentSkey: FilePath?
    
    @FilePathCodable
    public var paymentVkey: FilePath?
    
    // MARK: - Stake Keys
    
    /// name.stake.addr - stake address for the stake pool
    public var stakeAddr: String?
    
    @FilePathCodable
    public var stakeSkey: FilePath?
    
    @FilePathCodable
    public var stakeVkey: FilePath?
    
    // MARK: - Registration/Deregistration
    
    /// Registration model used to store information about a pool registration
    public var registration: PoolRegistration?
    
    /// Deregistration model used to store information about a pool deregistration
    public var deregistration: PoolDeregistration?
    
    // MARK: - Delegators
    
    /// The list of pool delegators
    public var delegators: [Delegator]?
    
    @FilePathCodable
    public var delegationCertificates: FilePath?
    
    // MARK: - ITN Files
    
    /// poolname.itn.skey
    @FilePathCodable
    public var itnSkey: FilePath?
    
    /// poolname.itn.vkey
    @FilePathCodable
    public var itnVkey: FilePath?
    
    // MARK: - CodingKeys
    
    private enum CodingKeys: String, CodingKey {
        case name
        case owners
        case pledge
        case cost
        case margin
        case relays
        case metaName = "meta_name"
        case metaDescription = "meta_description"
        case metaTicker = "meta_ticker"
        case metaHomepage = "meta_homepage"
        case metaUrl = "meta_url"
        case extendedMetaUrl = "extended_meta_url"
        case idHex = "id_hex"
        case idBech = "id_bech"
        case idHexFile = "id_hex_file"
        case idBechFile = "id_bech_file"
        case metadataHash = "metadata_hash"
        case metadataFile = "metadata_file"
        case additionalMetadataFile = "additional_metadata_file"
        case extendedMetadataFile = "extended_metadata_file"
        case coldVkey = "cold_vkey"
        case coldSkey = "cold_skey"
        case nodeCounter = "node_counter"
        case vrfSkey = "vrf_skey"
        case vrfVkey = "vrf_vkey"
        case rewardsOwner = "rewards_owner"
        case kesVkey = "kes_vkey"
        case kesSkey = "kes_skey"
        case kesCounter = "kes_counter"
        case kesCounterNext = "kes_counter_next"
        case kesExpireJson = "kes_expire_json"
        case opCert = "op_cert"
        case paymentAddr = "payment_addr"
        case paymentSkey = "payment_skey"
        case paymentVkey = "payment_vkey"
        case stakeAddr = "stake_addr"
        case stakeSkey = "stake_skey"
        case stakeVkey = "stake_vkey"
        case registration
        case deregistration
        case delegators
        case delegationCertificates = "delegation_certificates"
        case itnSkey = "itn_skey"
        case itnVkey = "itn_vkey"
    }
    
    // MARK: - Initialization
    
    public init(
        name: String? = nil,
        owners: [PoolOwner] = [],
        pledge: Int? = nil,
        cost: Int? = nil,
        margin: Double? = nil,
        relays: [PoolRelay] = [],
        metaName: String? = nil,
        metaDescription: String? = nil,
        metaTicker: String? = nil,
        metaHomepage: URL? = nil,
        metaUrl: URL? = nil,
        extendedMetaUrl: URL? = nil,
        idHex: String? = nil,
        idBech: String? = nil,
        idHexFile: FilePath? = nil,
        idBechFile: FilePath? = nil,
        metadataHash: String? = nil,
        metadataFile: FilePath? = nil,
        additionalMetadataFile: FilePath? = nil,
        extendedMetadataFile: FilePath? = nil,
        coldVkey: FilePath? = nil,
        coldSkey: FilePath? = nil,
        nodeCounter: FilePath? = nil,
        vrfSkey: FilePath? = nil,
        vrfVkey: FilePath? = nil,
        rewardsOwner: RewardsOwner? = nil,
        kesVkey: FilePath? = nil,
        kesSkey: FilePath? = nil,
        kesCounter: FilePath? = nil,
        kesCounterNext: FilePath? = nil,
        kesExpireJson: FilePath? = nil,
        opCert: FilePath? = nil,
        paymentAddr: String? = nil,
        paymentSkey: FilePath? = nil,
        paymentVkey: FilePath? = nil,
        stakeAddr: String? = nil,
        stakeSkey: FilePath? = nil,
        stakeVkey: FilePath? = nil,
        registration: PoolRegistration? = nil,
        deregistration: PoolDeregistration? = nil,
        delegators: [Delegator]? = nil,
        delegationCertificates: FilePath? = nil,
        itnSkey: FilePath? = nil,
        itnVkey: FilePath? = nil,
    ) {
        self.name = name
        self.owners = owners
        self.pledge = pledge
        self.cost = cost
        self.margin = margin
        self.relays = relays
        self.metaName = metaName
        self.metaDescription = metaDescription
        self.metaTicker = metaTicker
        self.metaHomepage = metaHomepage
        self.metaUrl = metaUrl
        self.extendedMetaUrl = extendedMetaUrl
        self.idHex = idHex
        self.idBech = idBech
        self.metadataHash = metadataHash
        self.rewardsOwner = rewardsOwner
        self.paymentAddr = paymentAddr
        self.stakeAddr = stakeAddr
        self.registration = registration
        self.deregistration = deregistration
        self.delegators = delegators
        
        // Set default file paths based on pool name
        let cwd = FilePath(FileManager.default.currentDirectoryPath)
        
        if let name = name {
            self.coldVkey = coldVkey ?? cwd.appending("\(name).cold.vkey")
            self.coldSkey = coldSkey ?? cwd.appending("\(name).cold.skey")
            self.vrfSkey = vrfSkey ?? cwd.appending("\(name).vrf.skey")
            self.vrfVkey = vrfVkey ?? cwd.appending("\(name).vrf.vkey")
            self.nodeCounter = nodeCounter ?? cwd.appending("\(name).cold.counter")
            self.kesCounter = kesCounter ?? cwd.appending("\(name).kes.counter")
            self.kesCounterNext = kesCounterNext ?? cwd.appending("\(name).kes.counter-next")
            self.kesExpireJson = kesExpireJson ?? cwd.appending("\(name).kes-expire.json")
            self.metadataFile = metadataFile ?? cwd.appending("\(name).metadata.json")
            self.additionalMetadataFile = additionalMetadataFile ?? cwd.appending("\(name).additional-metadata.json")
            self.extendedMetadataFile = extendedMetadataFile ?? cwd.appending("\(name).extended-metadata.json")
            self.idHexFile = idHexFile ?? cwd.appending("\(name).pool.id")
            self.idBechFile = idBechFile ?? cwd.appending("\(name).pool.id-bech")
            
            // Search for latest KES and opcert files
            self.kesVkey = kesVkey ?? Self.searchLatestFile(name: name, prefix: "kes", suffix: "vkey", in: cwd)
            self.kesSkey = kesSkey ?? Self.searchLatestFile(name: name, prefix: "kes", suffix: "skey", in: cwd)
            self.opCert = opCert ?? Self.searchLatestFile(name: name, prefix: "node", suffix: "opcert", in: cwd)
        } else {
            self.coldVkey = coldVkey
            self.coldSkey = coldSkey
            self.vrfSkey = vrfSkey
            self.vrfVkey = vrfVkey
            self.nodeCounter = nodeCounter
            self.kesCounter = kesCounter
            self.kesCounterNext = kesCounterNext
            self.kesExpireJson = kesExpireJson
            self.metadataFile = metadataFile
            self.additionalMetadataFile = additionalMetadataFile
            self.extendedMetadataFile = extendedMetadataFile
            self.idHexFile = idHexFile
            self.idBechFile = idBechFile
            self.kesVkey = kesVkey
            self.kesSkey = kesSkey
            self.opCert = opCert
        }
        
        self.paymentSkey = paymentSkey
        self.paymentVkey = paymentVkey
        self.stakeSkey = stakeSkey
        self.stakeVkey = stakeVkey
        self.delegationCertificates = delegationCertificates
        self.itnSkey = itnSkey
        self.itnVkey = itnVkey
        
        // Load pool IDs from files if they exist
        if let idBechFile = self.idBechFile,
           FileManager.default.fileExists(atPath: idBechFile.string) {
            self.idBech = try? String(contentsOfFile: idBechFile.string, encoding: .utf8).trimmingCharacters(in: .whitespacesAndNewlines)
        } else {
            self.idBech = idBech
        }
        
        if let idHexFile = self.idHexFile,
           FileManager.default.fileExists(atPath: idHexFile.string) {
            self.idHex = try? String(contentsOfFile: idHexFile.string, encoding: .utf8).trimmingCharacters(in: .whitespacesAndNewlines)
        } else {
            self.idHex = idHex
        }
    }
    
    // MARK: - Validation
    
    /// Validates the stake pool configuration
    public func validate() throws {
        // Validate name length
        if let name = name, name.count > 50 {
            throw SwiftCardanoMultitoolError.valueError(
                "The pool name is too long. Max. 50 chars allowed!"
            )
        }
        
        // Validate pool ID bech32
        if let idBech = idBech {
            if !idBech.hasPrefix("pool1") || idBech.count != 56 {
                throw SwiftCardanoMultitoolError.valueError(
                    "The pool id bech32 is not valid!"
                )
            }
        }
        
        // Validate pool ID hex
        if let idHex = idHex {
            let hexPattern = "^[a-fA-F0-9]{56}$"
            let regex = try? NSRegularExpression(pattern: hexPattern)
            let range = NSRange(idHex.startIndex..., in: idHex)
            if regex?.firstMatch(in: idHex, options: [], range: range) == nil {
                throw SwiftCardanoMultitoolError.valueError(
                    "The pool id hex is not valid!"
                )
            }
        }
        
        // Validate meta name length
        if let metaName = metaName, metaName.count > 50 {
            throw SwiftCardanoMultitoolError.valueError(
                "The pool meta name is too long. Max. 50 chars allowed!"
            )
        }
        
        // Validate meta homepage length
        if let metaHomepage = metaHomepage, metaHomepage.absoluteString.count > 64 {
            throw SwiftCardanoMultitoolError.valueError(
                "The pool meta homepage is too long. Max. 64 chars allowed!"
            )
        }
        
        // Validate meta description length
        if let metaDescription = metaDescription, metaDescription.count > 255 {
            throw SwiftCardanoMultitoolError.valueError(
                "The pool meta description is too long. Max. 255 chars allowed!"
            )
        }
        
        // Validate meta ticker
        if let metaTicker = metaTicker {
            if metaTicker.count < 3 || metaTicker.count > 5 {
                throw SwiftCardanoMultitoolError.valueError(
                    "The poolMetaTicker Entry must be between 3-5 chars long!"
                )
            }
        }
        
        // Validate extended meta URL length
        if let extendedMetaUrl = extendedMetaUrl, extendedMetaUrl.absoluteString.count > 64 {
            throw SwiftCardanoMultitoolError.valueError(
                "The pool extended meta url is too long. Max. 64 chars allowed!"
            )
        }
        
        // Validate all relays
        for relay in relays {
            try relay.validate()
        }
    }
    
    // MARK: - File Operations
    
    /// Search for the latest file matching the pattern name.prefix-xxx.suffix
    private static func searchLatestFile(name: String, prefix: String, suffix: String, in directory: FilePath) -> FilePath? {
        let fm = FileManager.default
        guard let contents = try? fm.contentsOfDirectory(atPath: directory.string) else {
            return nil
        }
        
        // Pattern: name.prefix-xxx.suffix (e.g., mypool.kes-001.vkey)
        let pattern = "\(name).\(prefix)-"
        let matchingFiles = contents.filter { file in
            file.hasPrefix(pattern) && file.hasSuffix(".\(suffix)")
        }
        
        // Sort to get the latest (highest number)
        let sortedFiles = matchingFiles.sorted { a, b in
            // Extract numbers from filenames for comparison
            let numA = Self.extractNumber(from: a, pattern: pattern, suffix: suffix)
            let numB = Self.extractNumber(from: b, pattern: pattern, suffix: suffix)
            return numA > numB
        }
        
        if let latestFile = sortedFiles.first {
            return directory.appending(latestFile)
        }
        
        return nil
    }
    
    /// Extract number from filename pattern
    private static func extractNumber(from filename: String, pattern: String, suffix: String) -> Int {
        let withoutPrefix = filename.dropFirst(pattern.count)
        let withoutSuffix = withoutPrefix.dropLast(suffix.count + 1) // +1 for the dot
        return Int(withoutSuffix) ?? 0
    }
    
    /// Load a StakePool from a pool.json file
    /// - Parameter poolJsonFile: The path to the pool json file
    /// - Returns: The StakePool object
    public static func load(from poolJsonFile: FilePath) throws -> Pool {
        let data = try Data(contentsOf: URL(fileURLWithPath: poolJsonFile.string))
        var poolJson = try JSONDecoder().decode(Pool.self, from: data)
        
        return poolJson
    }
    
    /// Merge this StakePool with another, preferring non-nil values from self
    private func merging(with other: Pool) -> Pool {
        return Pool(
            name: self.name ?? other.name,
            owners: self.owners.isEmpty ? other.owners : self.owners,
            pledge: self.pledge ?? other.pledge,
            cost: self.cost ?? other.cost,
            margin: self.margin ?? other.margin,
            relays: self.relays.isEmpty ? other.relays : self.relays,
            metaName: self.metaName ?? other.metaName,
            metaDescription: self.metaDescription ?? other.metaDescription,
            metaTicker: self.metaTicker ?? other.metaTicker,
            metaHomepage: self.metaHomepage ?? other.metaHomepage,
            metaUrl: self.metaUrl ?? other.metaUrl,
            extendedMetaUrl: self.extendedMetaUrl ?? other.extendedMetaUrl,
            idHex: self.idHex ?? other.idHex,
            idBech: self.idBech ?? other.idBech,
            idHexFile: self.idHexFile ?? other.idHexFile,
            idBechFile: self.idBechFile ?? other.idBechFile,
            metadataHash: self.metadataHash ?? other.metadataHash,
            metadataFile: self.metadataFile ?? other.metadataFile,
            additionalMetadataFile: self.additionalMetadataFile ?? other.additionalMetadataFile,
            extendedMetadataFile: self.extendedMetadataFile ?? other.extendedMetadataFile,
            coldVkey: self.coldVkey ?? other.coldVkey,
            coldSkey: self.coldSkey ?? other.coldSkey,
            nodeCounter: self.nodeCounter ?? other.nodeCounter,
            vrfSkey: self.vrfSkey ?? other.vrfSkey,
            vrfVkey: self.vrfVkey ?? other.vrfVkey,
            rewardsOwner: self.rewardsOwner ?? other.rewardsOwner,
            kesVkey: self.kesVkey ?? other.kesVkey,
            kesSkey: self.kesSkey ?? other.kesSkey,
            kesCounter: self.kesCounter ?? other.kesCounter,
            kesCounterNext: self.kesCounterNext ?? other.kesCounterNext,
            kesExpireJson: self.kesExpireJson ?? other.kesExpireJson,
            opCert: self.opCert ?? other.opCert,
            paymentAddr: self.paymentAddr ?? other.paymentAddr,
            paymentSkey: self.paymentSkey ?? other.paymentSkey,
            paymentVkey: self.paymentVkey ?? other.paymentVkey,
            stakeAddr: self.stakeAddr ?? other.stakeAddr,
            stakeSkey: self.stakeSkey ?? other.stakeSkey,
            stakeVkey: self.stakeVkey ?? other.stakeVkey,
            registration: self.registration ?? other.registration,
            deregistration: self.deregistration ?? other.deregistration,
            delegators: self.delegators ?? other.delegators,
            delegationCertificates: self.delegationCertificates ?? other.delegationCertificates,
            itnSkey: self.itnSkey ?? other.itnSkey,
            itnVkey: self.itnVkey ?? other.itnVkey,
        )
    }
    
    /// Save the pool JSON to the pool json file
    /// - Parameters:
    ///   - path: Optional custom path. If nil, uses the poolFile property
    ///   - overwrite: Whether to overwrite existing file
    public func save(to path: FilePath, overwrite: Bool = false) throws {
        if !overwrite && FileManager.default.fileExists(atPath: path.string) {
            throw SwiftCardanoMultitoolError.fileAlreadyExists(path)
        }
        
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        
        let data = try encoder.encode(self)
        try data.write(to: URL(fileURLWithPath: path.string), options: .atomic)
    }
    
    /// Load a StakePool from a ConfigReader
    /// - Parameter config: The ConfigReader to read configuration values from
    /// - Returns: The loaded StakePool
    public init(config: ConfigReader) {
        self.name = config.string(forKey: CodingKeys.name.rawValue)
        self.pledge = config.int(forKey: CodingKeys.pledge.rawValue)
        self.cost = config.int(forKey: CodingKeys.cost.rawValue)
        self.margin = config.double(forKey: CodingKeys.margin.rawValue)
        
        self.metaName = config.string(forKey: CodingKeys.metaName.rawValue)
        self.metaDescription = config.string(forKey: CodingKeys.metaDescription.rawValue)
        self.metaTicker = config.string(forKey: CodingKeys.metaTicker.rawValue)
        self.metaHomepage = config.string(forKey: CodingKeys.metaHomepage.rawValue, as: URL.self)
        self.metaUrl = config.string(forKey: CodingKeys.metaUrl.rawValue, as: URL.self)
        self.extendedMetaUrl = config.string(forKey: CodingKeys.extendedMetaUrl.rawValue, as: URL.self)
        
        self.idHex = config.string(forKey: CodingKeys.idHex.rawValue)
        self.idBech = config.string(forKey: CodingKeys.idBech.rawValue)
        self.metadataHash = config.string(forKey: CodingKeys.metadataHash.rawValue)
        
        self.paymentAddr = config.string(forKey: CodingKeys.paymentAddr.rawValue)
        self.stakeAddr = config.string(forKey: CodingKeys.stakeAddr.rawValue)
        
        // File paths
        self.coldVkey = config.string(forKey: CodingKeys.coldVkey.rawValue, as: FilePath.self)
        self.coldSkey = config.string(forKey: CodingKeys.coldSkey.rawValue, as: FilePath.self)
        self.vrfSkey = config.string(forKey: CodingKeys.vrfSkey.rawValue, as: FilePath.self)
        self.vrfVkey = config.string(forKey: CodingKeys.vrfVkey.rawValue, as: FilePath.self)
        self.nodeCounter = config.string(forKey: CodingKeys.nodeCounter.rawValue, as: FilePath.self)
        self.kesVkey = config.string(forKey: CodingKeys.kesVkey.rawValue, as: FilePath.self)
        self.kesSkey = config.string(forKey: CodingKeys.kesSkey.rawValue, as: FilePath.self)
        self.kesCounter = config.string(forKey: CodingKeys.kesCounter.rawValue, as: FilePath.self)
        self.kesCounterNext = config.string(forKey: CodingKeys.kesCounterNext.rawValue, as: FilePath.self)
        self.kesExpireJson = config.string(forKey: CodingKeys.kesExpireJson.rawValue, as: FilePath.self)
        self.opCert = config.string(forKey: CodingKeys.opCert.rawValue, as: FilePath.self)
        self.metadataFile = config.string(forKey: CodingKeys.metadataFile.rawValue, as: FilePath.self)
        self.additionalMetadataFile = config.string(forKey: CodingKeys.additionalMetadataFile.rawValue, as: FilePath.self)
        self.extendedMetadataFile = config.string(forKey: CodingKeys.extendedMetadataFile.rawValue, as: FilePath.self)
        self.idHexFile = config.string(forKey: CodingKeys.idHexFile.rawValue, as: FilePath.self)
        self.idBechFile = config.string(forKey: CodingKeys.idBechFile.rawValue, as: FilePath.self)
        self.paymentSkey = config.string(forKey: CodingKeys.paymentSkey.rawValue, as: FilePath.self)
        self.paymentVkey = config.string(forKey: CodingKeys.paymentVkey.rawValue, as: FilePath.self)
        self.stakeSkey = config.string(forKey: CodingKeys.stakeSkey.rawValue, as: FilePath.self)
        self.stakeVkey = config.string(forKey: CodingKeys.stakeVkey.rawValue, as: FilePath.self)
        self.itnSkey = config.string(forKey: CodingKeys.itnSkey.rawValue, as: FilePath.self)
        self.itnVkey = config.string(forKey: CodingKeys.itnVkey.rawValue, as: FilePath.self)
        self.delegationCertificates = config.string(forKey: CodingKeys.delegationCertificates.rawValue, as: FilePath.self)
        
        // Initialize empty arrays for owners and relays (can be populated later)
        self.owners = []
        self.relays = []
        self.delegators = nil
        self.rewardsOwner = nil
        self.registration = nil
        self.deregistration = nil
    }
    
    // MARK: - Metadata Generation
    
    /// Generate the metadata JSON dictionary
    /// - Parameter includeExtendedMetadata: Whether to include the extended metadata URL
    /// - Returns: The metadata dictionary
    public func metadataJson(includeExtendedMetadata: Bool = false) -> [String: Any] {
        var metadata: [String: Any] = [
            "name": metaName ?? "",
            "description": metaDescription ?? "",
            "ticker": metaTicker ?? "",
            "homepage": metaHomepage?.absoluteString ?? ""
        ]
        
        if includeExtendedMetadata, let extendedMetaUrl = extendedMetaUrl {
            metadata["extended"] = extendedMetaUrl.absoluteString
        }
        
        return metadata
    }
    
    /// Generate a dummy pool JSON for template purposes
    public func dummyPoolJson() -> [String: Any] {
        return [
            "name": name ?? "",
            "owners": [
                [
                    "name": "set_your_owner_name_here",
                    "witness": "local",
                    "stake_vkey": NSNull(),
                    "stake_skey": NSNull(),
                    "delegation_certificate": NSNull()
                ]
            ],
            "rewards_owner": [
                "name": "set_your_rewards_name_here_can_be_same_as_owner",
                "stake_vkey": NSNull(),
                "stake_skey": NSNull()
            ],
            "pledge": 100000000000,
            "cost": 10000000000,
            "margin": 0.10,
            "relays": [
                [
                    "type": "ip or dns",
                    "host": "x.x.x.x_or_the_dns-name_of_your_relay",
                    "port": "3001",
                    "host_type": "ipv4, ipv6, single, or multi"
                ]
            ],
            "meta_name": "THE NAME OF YOUR POOL",
            "meta_description": "THE DESCRIPTION OF YOUR POOL",
            "meta_ticker": "THE TICKER OF YOUR POOL",
            "meta_homepage": "https://set_your_webserver_url_here",
            "meta_url": "https://set_your_webserver_url_here/\(name ?? "pool").metadata.json",
            "extended_meta_url": NSNull(),
            "---": "--- DO NOT EDIT OR DELETE BELOW THIS LINE ---"
        ]
    }
    
    /// Generate a new pool.json file interactively
    /// - Parameter poolJson: The path to the poolName.pool.json file
    public static func generateNewPoolJson(at poolJson: FilePath) throws {
        let poolName = poolJson.lastComponent?.string.split(separator: ".").first.map(String.init) ?? "pool"
        let pool = Pool(name: poolName.lowercased())
        
        let dummyJson = pool.dummyPoolJson()
        let jsonData = try JSONSerialization.data(withJSONObject: dummyJson, options: [.prettyPrinted, .sortedKeys])
        try jsonData.write(to: URL(fileURLWithPath: poolJson.string), options: .atomic)
        
        noora.success(
            .alert("Stakepool Info JSON created: \(poolJson.string)")
        )
        print("\nPlease edit the \(poolJson.string) file and run this script again.")
    }
}
