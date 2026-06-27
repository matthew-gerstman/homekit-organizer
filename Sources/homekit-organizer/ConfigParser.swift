import Foundation
import Yams

// MARK: - Config Parser Errors

enum ConfigParserError: LocalizedError {
    case fileNotFound(String)
    case readError(String, Error)
    case parseError(String, Error)
    case emptyConfig
    case invalidYaml(String)
    
    var errorDescription: String? {
        switch self {
        case .fileNotFound(let path):
            return "Configuration file not found: \(path)"
        case .readError(let path, let error):
            return "Failed to read configuration file '\(path)': \(error.localizedDescription)"
        case .parseError(let path, let error):
            return "Failed to parse configuration file '\(path)': \(error.localizedDescription)"
        case .emptyConfig:
            return "Configuration file is empty or contains no valid sections"
        case .invalidYaml(let detail):
            return "Invalid YAML: \(detail)"
        }
    }
}

// MARK: - Config Parser

/// Parses YAML configuration files into Config objects
struct ConfigParser {
    
    /// Parse a configuration file from the given path
    /// - Parameter path: Path to the YAML configuration file
    /// - Returns: Parsed Config object
    /// - Throws: ConfigParserError if the file cannot be read or parsed
    static func parse(fromPath path: String) throws -> Config {
        let expandedPath = (path as NSString).expandingTildeInPath
        let url = URL(fileURLWithPath: expandedPath)
        
        // Check file exists
        guard FileManager.default.fileExists(atPath: expandedPath) else {
            throw ConfigParserError.fileNotFound(path)
        }
        
        // Read file contents
        let contents: String
        do {
            contents = try String(contentsOf: url, encoding: .utf8)
        } catch {
            throw ConfigParserError.readError(path, error)
        }
        
        // Parse YAML
        return try parse(yaml: contents, sourcePath: path)
    }
    
    /// Parse a configuration from a YAML string
    /// - Parameters:
    ///   - yaml: YAML string content
    ///   - sourcePath: Source path for error messages (optional)
    /// - Returns: Parsed Config object
    /// - Throws: ConfigParserError if the YAML cannot be parsed
    static func parse(yaml: String, sourcePath: String = "<string>") throws -> Config {
        guard !yaml.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw ConfigParserError.emptyConfig
        }
        
        let decoder = YAMLDecoder()
        
        do {
            let config = try decoder.decode(Config.self, from: yaml)
            
            // Validate that config has some content
            if config.isEmpty {
                throw ConfigParserError.emptyConfig
            }
            
            return config
        } catch let error as DecodingError {
            throw ConfigParserError.parseError(sourcePath, error)
        } catch {
            throw ConfigParserError.parseError(sourcePath, error)
        }
    }
    
    /// Pretty-print a config for debugging
    static func dump(_ config: Config) -> String {
        var output: [String] = []
        
        output.append("=== Configuration ===")
        
        if let home = config.home {
            output.append("\nTarget Home: \(home)")
        }
        
        if let rooms = config.rooms, !rooms.isEmpty {
            output.append("\n--- Rooms (\(rooms.count)) ---")
            for room in rooms {
                output.append("  \(room.name):")
                if let accessories = room.accessories {
                    for selector in accessories {
                        output.append("    - \(selector.description)")
                    }
                } else {
                    output.append("    (no accessories)")
                }
            }
        }
        
        if let zones = config.zones, !zones.isEmpty {
            output.append("\n--- Zones (\(zones.count)) ---")
            for zone in zones {
                output.append("  \(zone.name):")
                if let rooms = zone.rooms, !rooms.isEmpty {
                    for room in rooms {
                        output.append("    - \(room)")
                    }
                } else {
                    output.append("    (no rooms)")
                }
            }
        }
        
        if let renames = config.renames, !renames.isEmpty {
            output.append("\n--- Renames (\(renames.count)) ---")
            for rename in renames {
                output.append("  \"\(rename.from)\" → \"\(rename.to)\"")
            }
        }
        
        if let scenes = config.scenes, !scenes.isEmpty {
            output.append("\n--- Scenes (\(scenes.count)) ---")
            for scene in scenes {
                output.append("  \(scene.name):")
                if let actions = scene.actions {
                    for action in actions {
                        let chars = action.characteristics.setCharacteristics
                            .map { "\($0.name): \($0.value)" }
                            .joined(separator: ", ")
                        output.append("    - \(action.accessory) [\(action.service)]: \(chars)")
                    }
                }
            }
        }
        
        return output.joined(separator: "\n")
    }
}

