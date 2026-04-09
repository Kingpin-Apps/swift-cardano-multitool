import Logging
import SwiftCardanoUtils
import os

public func getLogger(config: MultitoolConfig) -> Logging.Logger {
    var logger = Logger(
        label: "com.swift-cardano-multitool",
        factory: { label in
            OSLogHandler(subsystem: "com.swift-cardano-multitool", category: label)
        }
    )
    logger.logLevel = config.logLevel ?? .error
    return logger
}

struct OSLogHandler: LogHandler {
    let logger: os.Logger
    
    var logLevel: Logging.Logger.Level = .info
    var metadata: Logging.Logger.Metadata = [:]
    
    init(subsystem: String, category: String) {
        self.logger = os.Logger(subsystem: subsystem, category: category)
    }
    
    func log(event: LogEvent) {
        let mergedMetadata = self.metadata.merging(event.metadata ?? [:]) { $1 }
        let metadataString = mergedMetadata.isEmpty ? "" : " \(mergedMetadata)"
        
        switch event.level {
            case .trace, .debug:
                logger.debug("\(event.message)\(metadataString)")
            case .info, .notice:
                logger.info("\(event.message)\(metadataString)")
            case .warning:
                logger.warning("\(event.message)\(metadataString)")
            case .error:
                logger.error("\(event.message)\(metadataString)")
            case .critical:
                logger.fault("\(event.message)\(metadataString)")
        }
    }
    
    subscript(metadataKey key: String) -> Logging.Logger.Metadata.Value? {
        get { metadata[key] }
        set { metadata[key] = newValue }
    }
}


