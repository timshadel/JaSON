//
// MARK: - JSONError Type
//

public enum JSONError: ErrorType, CustomStringConvertible {
    case KeyNotFound(key: JSONKeyType)
    case NullValue(key: JSONKeyType)
    case TypeMismatch(expected: Any, actual: Any)
    case TypeMismatchWithKey(key: JSONKeyType, expected: Any, actual: Any)
    
    public var description: String {
        switch self {
        case let .KeyNotFound(key):
            return "Key not found: \(key.stringValue)"
        case let .NullValue(key):
            return "Null Value found at: \(key.stringValue)"
        case let .TypeMismatch(expected, actual):
            return "Type mismatch. Expected type \(expected). Got '\(actual)'"
        case let .TypeMismatchWithKey(key, expected, actual):
            return "Type mismatch. Expected type \(expected) at key: \(key). Got '\(actual)'"
        }
    }
}

//
// MARK: - JSONKeyType
//

public protocol JSONKeyType: Hashable {
    var stringValue: String { get }
}

extension String: JSONKeyType {
    public var stringValue: String {
        return self
    }
}

//
// MARK: - JSONValueType
//

public protocol JSONValueType {
    typealias _JSONValue = Self
    
    static func JSONValue(object: Any) throws -> _JSONValue
}

extension JSONValueType {
    public static func JSONValue(object: Any) throws -> _JSONValue {
        guard let objectValue = object as? _JSONValue else {
            throw JSONError.TypeMismatch(expected: _JSONValue.self, actual: object.dynamicType)
        }
        return objectValue
    }
}

//
// MARK: - JSONValueType Implementations
//

extension String: JSONValueType {}
extension Int: JSONValueType {}
extension UInt: JSONValueType {}
extension Float: JSONValueType {}
extension Double: JSONValueType {}
extension Bool: JSONValueType {}

extension Array where Element: JSONValueType {
    public static func JSONValue(object: Any) throws -> [Element] {
        guard let anyArray = object as? [AnyObject] else {
            throw JSONError.TypeMismatch(expected: self, actual: object.dynamicType)
        }
        return try anyArray.map {
            let value = try Element.JSONValue($0)
            guard let element = value as? Element else {
                throw JSONError.TypeMismatch(expected: Element.self, actual: value.dynamicType)
            }
            return element
        }
    }
}

extension Dictionary: JSONValueType {
    public static func JSONValue(object: Any) throws -> [Key: Value] {
        guard let objectValue = object as? [Key: Value] else {
            throw JSONError.TypeMismatch(expected: self, actual: object.dynamicType)
        }
        return objectValue
    }
}

extension NSURL: JSONValueType {
    public static func JSONValue(object: Any) throws -> NSURL {
        guard let urlString = object as? String, objectValue = NSURL(string: urlString) else {
            throw JSONError.TypeMismatch(expected: self, actual: object.dynamicType)
        }
        return objectValue
    }
}

//
// MARK: - JSONObject
//

public typealias JSONObject = [String: AnyObject]

extension Dictionary where Key: JSONKeyType {
    private func anyForKey(key: Key) throws -> Any {
        let pathComponents = key.stringValue.characters.split(".").map(String.init)
        var accumulator: Any = self
        
        for component in pathComponents {
            if let componentData = accumulator as? [Key: Value], value = componentData[component as! Key] {
                accumulator = value
                continue
            }
            
            throw JSONError.KeyNotFound(key: key)
        }
        
        if let _ = accumulator as? NSNull {
            throw JSONError.NullValue(key: key)
        }
        
        return accumulator
    }
    
    public func JSONValueForKey<A: JSONValueType>(key: Key) throws -> A {
        let any = try anyForKey(key)
        guard let result = try A.JSONValue(any) as? A else {
            throw JSONError.TypeMismatchWithKey(key: key, expected: A.self, actual: any.dynamicType)
        }
        
        return result
    }
    
    public func JSONValueForKey<A: JSONValueType>(key: Key) throws -> [A] {
        let any = try anyForKey(key)
        return try Array<A>.JSONValue(any)
    }

    public func JSONValueForKey<A: JSONValueType>(key: Key) throws -> [A]? {
        do {
            return try self.JSONValueForKey(key) as [A]
        }
        catch JSONError.KeyNotFound {
            return nil
        }
        catch JSONError.NullValue {
            return nil
        }
    }

    public func JSONValueForKey<A: JSONValueType>(key: Key) throws -> A? {
        do {
            return try self.JSONValueForKey(key) as A
        }
        catch JSONError.KeyNotFound {
            return nil
        }
        catch JSONError.NullValue {
            return nil
        }
    }
}

extension Dictionary where Key: JSONKeyType { // Enums
    public func JSONValueForKey<A: RawRepresentable where A.RawValue: JSONValueType>(key: Key) throws -> A {
        let raw = try self.JSONValueForKey(key) as A.RawValue
        guard let value = A(rawValue: raw) else {
            throw JSONError.TypeMismatch(expected: A.self, actual: raw)
        }
        return value
    }
    
    public func JSONValueForKey<A: RawRepresentable where A.RawValue: JSONValueType>(key: Key) throws -> A? {
        do {
            return try self.JSONValueForKey(key) as A
        }
        catch JSONError.KeyNotFound {
            return nil
        }
        catch JSONError.NullValue {
            return nil
        }
    }
    
    public func JSONValueForKey<A: RawRepresentable where A.RawValue: JSONValueType>(key: Key) throws -> [A] {
        let rawArray = try self.JSONValueForKey(key) as [A.RawValue]
        return try rawArray.map({ raw in
            guard let value = A(rawValue: raw) else {
                throw JSONError.TypeMismatch(expected: A.self, actual: raw)
            }
            return value
        })
    }
    
    public func JSONValueForKey<A: RawRepresentable where A.RawValue: JSONValueType>(key: Key) throws -> [A]? {
        do {
            return try self.JSONValueForKey(key) as [A]
        }
        catch JSONError.KeyNotFound {
            return nil
        }
        catch JSONError.NullValue {
            return nil
        }
    }
}

