import Foundation

public enum JSONValue: Codable, Equatable, Sendable {
    case null
    case bool(Bool)
    case number(Double)
    case string(String)
    case array([JSONValue])
    case object([String: JSONValue])

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            self = .null
        } else if let value = try? container.decode(Bool.self) {
            self = .bool(value)
        } else if let value = try? container.decode(Double.self) {
            self = .number(value)
        } else if let value = try? container.decode(String.self) {
            self = .string(value)
        } else if let value = try? container.decode([String: JSONValue].self) {
            self = .object(value)
        } else if let value = try? container.decode([JSONValue].self) {
            self = .array(value)
        } else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Unsupported JSON value")
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .null:
            try container.encodeNil()
        case let .bool(value):
            try container.encode(value)
        case let .number(value):
            try container.encode(value)
        case let .string(value):
            try container.encode(value)
        case let .array(value):
            try container.encode(value)
        case let .object(value):
            try container.encode(value)
        }
    }
}

func toJSONString<T: Encodable>(_ value: T) throws -> String {
    let encoder = JSONEncoder()
    let data = try encoder.encode(value)
    guard let str = String(data: data, encoding: .utf8) else {
        throw NSError(domain: "CBBCoachCore", code: 900, userInfo: [NSLocalizedDescriptionKey: "Failed to encode JSON string"])
    }
    return str
}

func fromJSONString<T: Decodable>(_ text: String, as type: T.Type = T.self) throws -> T {
    guard let data = text.data(using: .utf8) else {
        throw NSError(domain: "CBBCoachCore", code: 901, userInfo: [NSLocalizedDescriptionKey: "Failed to decode JSON string bytes"])
    }
    return try JSONDecoder().decode(T.self, from: data)
}
