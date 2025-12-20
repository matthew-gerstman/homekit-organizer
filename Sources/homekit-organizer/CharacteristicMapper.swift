import Foundation
import HomeKit

// MARK: - Characteristic Mapping

/// Maps configuration characteristic names to HomeKit characteristic types
struct CharacteristicMapper {
    
    /// Known characteristic mappings
    private static let knownMappings: [String: String] = [
        // Power
        "on": HMCharacteristicTypePowerState,
        "power": HMCharacteristicTypePowerState,
        "powerstate": HMCharacteristicTypePowerState,
        
        // Brightness
        "brightness": HMCharacteristicTypeBrightness,
        "level": HMCharacteristicTypeBrightness,
        
        // Color
        "hue": HMCharacteristicTypeHue,
        "saturation": HMCharacteristicTypeSaturation,
        "colortemperature": HMCharacteristicTypeColorTemperature,
        
        // Position
        "targetposition": HMCharacteristicTypeTargetPosition,
        "currentposition": HMCharacteristicTypeCurrentPosition,
        
        // Temperature
        "targettemperature": HMCharacteristicTypeTargetTemperature,
        "currenttemperature": HMCharacteristicTypeCurrentTemperature,
        
    ]
    
    /// Known service mappings
    private static let serviceMappings: [String: String] = [
        "lightbulb": HMServiceTypeLightbulb,
        "light": HMServiceTypeLightbulb,
        "switch": HMServiceTypeSwitch,
        "outlet": HMServiceTypeOutlet,
        "fan": HMServiceTypeFan,
        "thermostat": HMServiceTypeThermostat,
        "lock": HMServiceTypeLockMechanism,
        "door": HMServiceTypeDoor,
        "window": HMServiceTypeWindow,
        "windowcovering": HMServiceTypeWindowCovering,
        "blind": HMServiceTypeWindowCovering,
        "garagedoor": HMServiceTypeGarageDoorOpener,
        "motionsensor": HMServiceTypeMotionSensor,
        "contactsensor": HMServiceTypeContactSensor,
        "humiditysensor": HMServiceTypeHumiditySensor,
        "temperaturesensor": HMServiceTypeTemperatureSensor,
        "lightsensor": HMServiceTypeLightSensor,
    ]
    
    // MARK: - Public Methods
    
    /// Find a characteristic on a service by config name
    /// - Parameters:
    ///   - name: Config characteristic name (e.g., "on", "brightness")
    ///   - service: HomeKit service to search
    /// - Returns: Matching characteristic or nil
    static func findCharacteristic(named name: String, on service: HMService) -> HMCharacteristic? {
        let normalizedName = name.lowercased().replacingOccurrences(of: "_", with: "")
        
        // First try known mappings
        if let characteristicType = knownMappings[normalizedName] {
            return service.characteristics.first { $0.characteristicType == characteristicType }
        }
        
        // Fallback: search by type name containing the search term
        return service.characteristics.first { characteristic in
            let typeName = characteristic.characteristicType.lowercased()
            return typeName.contains(normalizedName)
        }
    }
    
    /// Find a service on an accessory by config name
    /// - Parameters:
    ///   - name: Config service name (e.g., "lightbulb", "switch")
    ///   - accessory: HomeKit accessory to search
    /// - Returns: Matching service or nil
    static func findService(named name: String, on accessory: HMAccessory) -> HMService? {
        let normalizedName = name.lowercased().replacingOccurrences(of: "_", with: "")
        
        // First try known mappings
        if let serviceType = serviceMappings[normalizedName] {
            return accessory.services.first { $0.serviceType == serviceType }
        }
        
        // Fallback: search by type name or service name
        return accessory.services.first { service in
            let typeName = service.serviceType.lowercased()
            let serviceName = service.name.lowercased()
            return typeName.contains(normalizedName) || serviceName.contains(normalizedName)
        }
    }
    
    /// Convert a config value to the appropriate type for a characteristic
    /// - Parameters:
    ///   - value: Value from config
    ///   - characteristic: Target characteristic (for metadata)
    /// - Returns: NSNumber value suitable for HomeKit
    static func convertValue(_ value: Any, for characteristic: HMCharacteristic) -> NSNumber {
        // Handle boolean values
        if let boolValue = value as? Bool {
            return NSNumber(value: boolValue)
        }
        
        // Handle integer values
        if let intValue = value as? Int {
            // Clamp to valid range if metadata is available
            if let metadata = characteristic.metadata,
               let minValue = metadata.minimumValue?.intValue,
               let maxValue = metadata.maximumValue?.intValue {
                let clamped = max(minValue, min(maxValue, intValue))
                return NSNumber(value: clamped)
            }
            return NSNumber(value: intValue)
        }
        
        // Handle double values
        if let doubleValue = value as? Double {
            return NSNumber(value: doubleValue)
        }
        
        // Handle string values
        if let stringValue = value as? String {
            // Try parsing as bool
            if stringValue.lowercased() == "true" || stringValue.lowercased() == "on" {
                return NSNumber(value: true)
            }
            if stringValue.lowercased() == "false" || stringValue.lowercased() == "off" {
                return NSNumber(value: false)
            }
            // Try parsing as int
            if let intValue = Int(stringValue) {
                return NSNumber(value: intValue)
            }
            // Try parsing as double
            if let doubleValue = Double(stringValue) {
                return NSNumber(value: doubleValue)
            }
        }
        
        // Default fallback
        return NSNumber(value: 0)
    }
    
    /// Get a human-readable description of a characteristic type
    static func describeCharacteristic(_ type: String) -> String {
        // Reverse lookup in known mappings
        for (name, mappedType) in knownMappings {
            if mappedType == type {
                return name
            }
        }
        
        // Extract name from type string
        // HMCharacteristicTypePowerState -> "PowerState"
        if type.hasPrefix("HMCharacteristicType") {
            return String(type.dropFirst("HMCharacteristicType".count))
        }
        
        return type
    }
    
    /// Get a human-readable description of a service type
    static func describeService(_ type: String) -> String {
        // Reverse lookup in known mappings
        for (name, mappedType) in serviceMappings {
            if mappedType == type {
                return name
            }
        }
        
        // Extract name from type string
        if type.hasPrefix("HMServiceType") {
            return String(type.dropFirst("HMServiceType".count))
        }
        
        return type
    }
}

// MARK: - Supported Characteristics Info

extension CharacteristicMapper {
    
    /// List of characteristics supported in v0.1
    static let supportedCharacteristics: [(name: String, description: String, valueType: String)] = [
        ("on", "Power state (on/off)", "Bool"),
        ("brightness", "Brightness level (0-100)", "Int"),
    ]
    
    /// Format supported characteristics for help text
    static func supportedCharacteristicsHelp() -> String {
        var lines = ["Supported characteristics (v0.1):"]
        for char in supportedCharacteristics {
            lines.append("  - \(char.name): \(char.description) [\(char.valueType)]")
        }
        return lines.joined(separator: "\n")
    }
}

