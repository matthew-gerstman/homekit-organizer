import Foundation

// MARK: - Planner

/// Plans operations by comparing config to current HomeKit state
struct Planner {
    
    /// Create an operation plan from config and current state
    /// - Parameters:
    ///   - config: The desired configuration
    ///   - snapshot: Current HomeKit state
    /// - Returns: Plan of operations to execute
    static func plan(config: Config, snapshot: HomeKitSnapshot) -> OperationPlan {
        var operations: [Operation] = []
        var skipped: [SkippedOperation] = []
        var warnings: [String] = []
        
        // Build lookup maps
        let existingRooms = Dictionary(
            snapshot.rooms.map { ($0.name.lowercased(), $0) },
            uniquingKeysWith: { first, _ in first }
        )
        
        let accessoriesByName = Dictionary(
            snapshot.accessories.map { ($0.name.lowercased(), $0) },
            uniquingKeysWith: { first, _ in first }
        )
        
        // 1. Plan rename operations (first, so subsequent matching uses new names)
        if let renames = config.renames {
            for rename in renames {
                if let accessory = accessoriesByName[rename.from.lowercased()] {
                    if accessory.name == rename.to {
                        skipped.append(SkippedOperation(
                            reason: "Already named",
                            detail: "'\(rename.to)' (no change needed)"
                        ))
                    } else {
                        operations.append(.renameAccessory(
                            accessoryId: accessory.id,
                            from: accessory.name,
                            to: rename.to
                        ))
                    }
                } else {
                    warnings.append("Rename target not found: '\(rename.from)'")
                }
            }
        }
        
        // 2. Plan room operations
        if let rooms = config.rooms {
            for roomConfig in rooms {
                let roomNameLower = roomConfig.name.lowercased()
                
                // Check if room exists
                if existingRooms[roomNameLower] == nil {
                    operations.append(.createRoom(name: roomConfig.name))
                } else {
                    skipped.append(SkippedOperation(
                        reason: "Room exists",
                        detail: "'\(roomConfig.name)'"
                    ))
                }
                
                // Plan accessory assignments (exact and pattern matches)
                if let selectors = roomConfig.accessories {
                    for selector in selectors {
                        let matchResult = AccessoryMatcher.match(selector: selector, against: snapshot.accessories)
                        
                        if !matchResult.hasMatches {
                            warnings.append("No accessories matched: \(selector.description)")
                            continue
                        }
                        
                        // Plan assignment for each matched accessory
                        for accessory in matchResult.matchedAccessories {
                            planAccessoryAssignment(
                                accessory: accessory,
                                targetRoom: roomConfig.name,
                                snapshot: snapshot,
                                operations: &operations,
                                skipped: &skipped
                            )
                        }
                    }
                }
            }
        }
        
        // 3. Plan scene operations
        if let scenes = config.scenes {
            let existingScenes = Set(snapshot.home.name.lowercased()) // TODO: Get actual scenes from snapshot
            
            for sceneConfig in scenes {
                // For now, always plan to create scenes (idempotency handled in executor)
                operations.append(.createScene(name: sceneConfig.name))
                
                if let actions = sceneConfig.actions {
                    for action in actions {
                        if let accessory = accessoriesByName[action.accessory.lowercased()] {
                            let chars = action.characteristics.setCharacteristics
                            operations.append(.addSceneAction(
                                sceneName: sceneConfig.name,
                                accessoryId: accessory.id,
                                accessoryName: accessory.name,
                                service: action.service,
                                characteristics: chars
                            ))
                        } else {
                            warnings.append("Scene action target not found: '\(action.accessory)' in scene '\(sceneConfig.name)'")
                        }
                    }
                }
            }
        }
        
        return OperationPlan(operations: operations, skipped: skipped, warnings: warnings)
    }
    
    // MARK: - Private Helpers
    
    private static func planAccessoryAssignment(
        accessory: AccessoryInfo,
        targetRoom: String,
        snapshot: HomeKitSnapshot,
        operations: inout [Operation],
        skipped: inout [SkippedOperation]
    ) {
        // Check current room
        if let currentRoomId = accessory.roomId,
           let currentRoom = snapshot.rooms.first(where: { $0.id == currentRoomId }) {
            if currentRoom.name.lowercased() == targetRoom.lowercased() {
                skipped.append(SkippedOperation(
                    reason: "Already assigned",
                    detail: "'\(accessory.name)' in '\(targetRoom)'"
                ))
                return
            }
        }
        
        // Plan assignment
        operations.append(.assignAccessory(
            accessoryId: accessory.id,
            accessoryName: accessory.name,
            toRoom: targetRoom
        ))
    }
}

// MARK: - Plan Display

extension OperationPlan {
    
    /// Format the plan for display
    func format(verbose: Bool = false) -> String {
        var lines: [String] = []
        
        if isEmpty {
            lines.append("No operations needed - everything is already configured correctly!")
            
            if verbose && !skipped.isEmpty {
                lines.append("\nSkipped (already satisfied):")
                for skip in skipped {
                    lines.append("  ✓ \(skip.description)")
                }
            }
        } else {
            lines.append("Operations to perform (\(count)):")
            
            for (category, ops) in operationsByCategory {
                lines.append("\n\(category.rawValue):")
                for op in ops {
                    lines.append("  • \(op.description)")
                }
            }
            
            if verbose && !skipped.isEmpty {
                lines.append("\nSkipped (already satisfied):")
                for skip in skipped {
                    lines.append("  ✓ \(skip.description)")
                }
            }
        }
        
        if !warnings.isEmpty {
            lines.append("\nWarnings:")
            for warning in warnings {
                lines.append("  ⚠️  \(warning)")
            }
        }
        
        return lines.joined(separator: "\n")
    }
}

