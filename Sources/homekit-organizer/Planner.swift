import Foundation

// MARK: - Planner

/// Plans operations by comparing config to current HomeKit state
struct Planner {
    
    /// Create an operation plan from config and current state
    /// - Parameters:
    ///   - config: The desired configuration
    ///   - snapshot: Current HomeKit state
    ///   - deleteUnlistedRooms: If true, delete rooms not in config
    /// - Returns: Plan of operations to execute
    static func plan(config: Config, snapshot: HomeKitSnapshot, deleteUnlistedRooms: Bool = false) -> OperationPlan {
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
        
        // Get set of room names from config (exact match for deletion, case-insensitive for creation)
        let configRoomNamesExact = Set((config.rooms ?? []).map { $0.name })
        let configRoomNamesLower = Set((config.rooms ?? []).map { $0.name.lowercased() })
        
        // 0. Plan room deletions (if enabled)
        if deleteUnlistedRooms {
            for room in snapshot.rooms {
                // Skip default room (can't be deleted)
                if room.isDefault { continue }
                
                // If room name doesn't EXACTLY match a config room, delete it
                // This handles duplicates like "Guest Room" vs "Guest room"
                if !configRoomNamesExact.contains(room.name) {
                    operations.append(.deleteRoom(roomId: room.id, name: room.name))
                }
            }
        }
        
        // 1. Plan accessory removals
        if let removeSelectors = config.remove {
            for selector in removeSelectors {
                let matchResult = AccessoryMatcher.match(selector: selector, against: snapshot.accessories)
                
                if !matchResult.hasMatches {
                    warnings.append("No accessories matched for removal: \(selector.description)")
                    continue
                }
                
                for accessory in matchResult.matchedAccessories {
                    operations.append(.removeAccessory(accessoryId: accessory.id, name: accessory.name))
                }
            }
        }
        
        // 2. Plan rename operations (so subsequent matching uses new names)
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
        
        // 3. Plan zone operations
        if let zones = config.zones {
            // Build lookup for existing zones
            let existingZones = Dictionary(
                snapshot.zones.map { ($0.name.lowercased(), $0) },
                uniquingKeysWith: { first, _ in first }
            )
            
            // Get set of zone names from config
            let configZoneNames = Set(zones.map { $0.name.lowercased() })
            
            // Plan zone deletions (zones not in config)
            for zone in snapshot.zones {
                if !configZoneNames.contains(zone.name.lowercased()) {
                    operations.append(.deleteZone(zoneId: zone.id, name: zone.name))
                }
            }
            
            for zoneConfig in zones {
                let zoneNameLower = zoneConfig.name.lowercased()
                
                // Check if zone exists
                if existingZones[zoneNameLower] == nil {
                    operations.append(.createZone(name: zoneConfig.name))
                } else {
                    skipped.append(SkippedOperation(
                        reason: "Zone exists",
                        detail: "'\(zoneConfig.name)'"
                    ))
                }
                
                // Plan room assignments to zone
                if let roomNames = zoneConfig.rooms {
                    let existingZone = existingZones[zoneNameLower]
                    let existingRoomNamesInZone = Set(existingZone?.roomNames.map { $0.lowercased() } ?? [])
                    
                    for roomName in roomNames {
                        // Check if room is already in zone
                        if existingRoomNamesInZone.contains(roomName.lowercased()) {
                            skipped.append(SkippedOperation(
                                reason: "Room already in zone",
                                detail: "'\(roomName)' in '\(zoneConfig.name)'"
                            ))
                        } else if existingRooms[roomName.lowercased()] != nil {
                            operations.append(.addRoomToZone(roomName: roomName, zoneName: zoneConfig.name))
                        } else {
                            warnings.append("Room '\(roomName)' not found for zone '\(zoneConfig.name)'")
                        }
                    }
                    
                    // Plan room removals from zone (rooms in zone but not in config)
                    if let existingZone = existingZone {
                        let configRoomNamesLower = Set(roomNames.map { $0.lowercased() })
                        for (index, roomName) in existingZone.roomNames.enumerated() {
                            if !configRoomNamesLower.contains(roomName.lowercased()) {
                                operations.append(.removeRoomFromZone(
                                    roomId: existingZone.roomIds[index],
                                    roomName: roomName,
                                    zoneId: existingZone.id,
                                    zoneName: existingZone.name
                                ))
                            }
                        }
                    }
                }
            }
        }
        
        // 4. Plan scene operations
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

