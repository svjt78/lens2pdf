import Foundation

public enum ShareProfile: String, Codable {
    case standard
    case compact // optimized for messaging
}

public struct ShareConfiguration: Codable, Equatable {
    public var profile: ShareProfile
    public var suggestedFileName: String
    public init(profile: ShareProfile, suggestedFileName: String) {
        self.profile = profile
        self.suggestedFileName = suggestedFileName
    }
}

