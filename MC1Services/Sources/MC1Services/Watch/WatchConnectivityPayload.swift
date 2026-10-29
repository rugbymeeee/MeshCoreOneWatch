import Foundation

/// A value the iPhone and watch apps exchange over WatchConnectivity, carried as JSON under a
/// single key so every message, user info, and application context stays property-list safe.
public protocol WatchConnectivityPayload: Codable {
  /// Dictionary key holding the encoded value.
  static var payloadKey: String { get }
}

public extension WatchConnectivityPayload {
  /// Encodes into a WatchConnectivity dictionary.
  func payload() throws -> [String: Any] {
    try [Self.payloadKey: JSONEncoder().encode(self)]
  }

  /// Decodes from a received WatchConnectivity dictionary. Returns nil when it carries
  /// no value of this type.
  init?(payload: [String: Any]) throws {
    guard let data = payload[Self.payloadKey] as? Data else { return nil }
    self = try JSONDecoder().decode(Self.self, from: data)
  }
}
