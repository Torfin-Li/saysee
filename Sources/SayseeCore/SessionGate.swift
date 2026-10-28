import Foundation
public struct SessionGate {
 private var current: UUID?
 public init() {}
 public mutating func begin() -> UUID { let id = UUID(); current = id; return id }
 public mutating func cancel() { current = nil }
 public func accepts(_ id: UUID) -> Bool { current == id }
}
public enum SayseeError: LocalizedError {
 case message(String)
 public var errorDescription: String? { switch self { case .message(let message): return message } }
}
