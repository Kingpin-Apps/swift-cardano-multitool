import Logging
import os

struct OSLogHandler: LogHandler {
    let logger: os.Logger
    
    var logLevel: Logging.Logger.Level = .info
    var metadata: Logging.Logger.Metadata = [:]
    
    init(subsystem: String, category: String) {
        self.logger = os.Logger(subsystem: subsystem, category: category)
    }
    
    func log(level: Logging.Logger.Level, message: Logging.Logger.Message,
             metadata: Logging.Logger.Metadata?, source: String,
             file: String, function: String, line: UInt) {
        let mergedMetadata = self.metadata.merging(metadata ?? [:]) { $1 }
        let metadataString = mergedMetadata.isEmpty ? "" : " \(mergedMetadata)"
        
        switch level {
            case .trace, .debug:
                logger.debug("\(message)\(metadataString)")
            case .info, .notice:
                logger.info("\(message)\(metadataString)")
            case .warning:
                logger.warning("\(message)\(metadataString)")
            case .error:
                logger.error("\(message)\(metadataString)")
            case .critical:
                logger.fault("\(message)\(metadataString)")
        }
    }
    
    subscript(metadataKey key: String) -> Logging.Logger.Metadata.Value? {
        get { metadata[key] }
        set { metadata[key] = newValue }
    }
}


