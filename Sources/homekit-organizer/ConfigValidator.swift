import Foundation

// MARK: - Validation Errors

enum ConfigValidationError: LocalizedError {
    case duplicateRoomName(String)
    case emptyRoomName
    case duplicateSceneName(String)
    case emptySceneName
    case emptyAccessorySelector
    case duplicateRenameFrom(String)
    case emptyRenameValue
    case sceneWithNoActions(String)
    case actionWithNoCharacteristics(String, String)
    case invalidBrightnessValue(Int)
    case multipleErrors([ConfigValidationError])
    
    var errorDescription: String? {
        switch self {
        case .duplicateRoomName(let name):
            return "Duplicate room name: '\(name)'"
        case .emptyRoomName:
            return "Room name cannot be empty"
        case .duplicateSceneName(let name):
            return "Duplicate scene name: '\(name)'"
        case .emptySceneName:
            return "Scene name cannot be empty"
        case .emptyAccessorySelector:
            return "Accessory selector cannot be empty"
        case .duplicateRenameFrom(let name):
            return "Duplicate rename 'from' value: '\(name)'"
        case .emptyRenameValue:
            return "Rename 'from' and 'to' values cannot be empty"
        case .sceneWithNoActions(let name):
            return "Scene '\(name)' has no actions defined"
        case .actionWithNoCharacteristics(let scene, let accessory):
            return "Action for '\(accessory)' in scene '\(scene)' has no characteristics set"
        case .invalidBrightnessValue(let value):
            return "Brightness value \(value) is invalid (must be 0-100)"
        case .multipleErrors(let errors):
            let messages = errors.compactMap { $0.errorDescription }
            return "Multiple validation errors:\n" + messages.map { "  - \($0)" }.joined(separator: "\n")
        }
    }
}

// MARK: - Validation Result

struct ValidationResult {
    let isValid: Bool
    let errors: [ConfigValidationError]
    let warnings: [String]
    
    static var valid: ValidationResult {
        ValidationResult(isValid: true, errors: [], warnings: [])
    }
    
    static func invalid(_ errors: [ConfigValidationError], warnings: [String] = []) -> ValidationResult {
        ValidationResult(isValid: false, errors: errors, warnings: warnings)
    }
    
    static func withWarnings(_ warnings: [String]) -> ValidationResult {
        ValidationResult(isValid: true, errors: [], warnings: warnings)
    }
}

// MARK: - Config Validator

/// Validates a parsed configuration for semantic correctness
struct ConfigValidator {
    
    /// Validate a configuration and return all found issues
    /// - Parameter config: The configuration to validate
    /// - Returns: ValidationResult with errors and warnings
    static func validate(_ config: Config) -> ValidationResult {
        var errors: [ConfigValidationError] = []
        var warnings: [String] = []
        
        // Validate rooms
        if let rooms = config.rooms {
            errors.append(contentsOf: validateRooms(rooms))
        }
        
        // Validate scenes
        if let scenes = config.scenes {
            errors.append(contentsOf: validateScenes(scenes, warnings: &warnings))
        }
        
        // Validate renames
        if let renames = config.renames {
            errors.append(contentsOf: validateRenames(renames))
        }
        
        if errors.isEmpty {
            if warnings.isEmpty {
                return .valid
            } else {
                return .withWarnings(warnings)
            }
        } else {
            return .invalid(errors, warnings: warnings)
        }
    }
    
    /// Validate and throw if invalid
    /// - Parameter config: The configuration to validate
    /// - Throws: ConfigValidationError if validation fails
    static func validateOrThrow(_ config: Config) throws {
        let result = validate(config)
        
        if !result.isValid {
            if result.errors.count == 1 {
                throw result.errors[0]
            } else {
                throw ConfigValidationError.multipleErrors(result.errors)
            }
        }
    }
    
    // MARK: - Private Validation Methods
    
    private static func validateRooms(_ rooms: [RoomConfig]) -> [ConfigValidationError] {
        var errors: [ConfigValidationError] = []
        var seenNames: Set<String> = []
        
        for room in rooms {
            // Check for empty name
            if room.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                errors.append(.emptyRoomName)
                continue
            }
            
            // Check for duplicates (case-insensitive)
            let normalizedName = room.name.lowercased()
            if seenNames.contains(normalizedName) {
                errors.append(.duplicateRoomName(room.name))
            } else {
                seenNames.insert(normalizedName)
            }
            
            // Check accessory selectors
            if let accessories = room.accessories {
                for selector in accessories {
                    if selector.value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        errors.append(.emptyAccessorySelector)
                    }
                }
            }
        }
        
        return errors
    }
    
    private static func validateScenes(_ scenes: [SceneConfig], warnings: inout [String]) -> [ConfigValidationError] {
        var errors: [ConfigValidationError] = []
        var seenNames: Set<String> = []
        
        for scene in scenes {
            // Check for empty name
            if scene.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                errors.append(.emptySceneName)
                continue
            }
            
            // Check for duplicates (case-insensitive)
            let normalizedName = scene.name.lowercased()
            if seenNames.contains(normalizedName) {
                errors.append(.duplicateSceneName(scene.name))
            } else {
                seenNames.insert(normalizedName)
            }
            
            // Check actions
            guard let actions = scene.actions, !actions.isEmpty else {
                warnings.append("Scene '\(scene.name)' has no actions - it will be created but empty")
                continue
            }
            
            for action in actions {
                // Check that action has at least one characteristic
                if action.characteristics.isEmpty {
                    errors.append(.actionWithNoCharacteristics(scene.name, action.accessory))
                }
                
                // Validate brightness range
                if let brightness = action.characteristics.brightness {
                    if brightness < 0 || brightness > 100 {
                        errors.append(.invalidBrightnessValue(brightness))
                    }
                }
            }
        }
        
        return errors
    }
    
    private static func validateRenames(_ renames: [RenameRule]) -> [ConfigValidationError] {
        var errors: [ConfigValidationError] = []
        var seenFroms: Set<String> = []
        
        for rename in renames {
            // Check for empty values
            if rename.from.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
               rename.to.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                errors.append(.emptyRenameValue)
                continue
            }
            
            // Check for duplicate 'from' values
            let normalizedFrom = rename.from.lowercased()
            if seenFroms.contains(normalizedFrom) {
                errors.append(.duplicateRenameFrom(rename.from))
            } else {
                seenFroms.insert(normalizedFrom)
            }
        }
        
        return errors
    }
}

