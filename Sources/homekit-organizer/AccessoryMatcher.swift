import Foundation

// MARK: - Match Result

/// Result of matching accessories against a selector
struct MatchResult {
    let selector: AccessorySelector
    let matchedAccessories: [AccessoryInfo]
    let isExact: Bool
    
    /// Whether any accessories matched
    var hasMatches: Bool {
        !matchedAccessories.isEmpty
    }
    
    /// Whether exactly one accessory matched (unambiguous)
    var isUnambiguous: Bool {
        matchedAccessories.count == 1
    }
    
    /// Description for display
    var description: String {
        if matchedAccessories.isEmpty {
            return "\(selector.description) → No matches"
        } else if matchedAccessories.count == 1 {
            return "\(selector.description) → \(matchedAccessories[0].name)"
        } else {
            let names = matchedAccessories.map { $0.name }.joined(separator: ", ")
            return "\(selector.description) → [\(matchedAccessories.count) matches: \(names)]"
        }
    }
}

// MARK: - Accessory Matcher

/// Matches accessories against selectors (exact names, wildcards, or regex)
struct AccessoryMatcher {
    
    /// Match a selector against a list of accessories
    /// - Parameters:
    ///   - selector: The selector to match
    ///   - accessories: Available accessories to match against
    /// - Returns: MatchResult with all matching accessories
    static func match(selector: AccessorySelector, against accessories: [AccessoryInfo]) -> MatchResult {
        switch selector {
        case .exact(let name):
            let matches = accessories.filter { $0.name.lowercased() == name.lowercased() }
            return MatchResult(selector: selector, matchedAccessories: matches, isExact: true)
            
        case .pattern(let pattern):
            let matches = matchPattern(pattern, against: accessories)
            return MatchResult(selector: selector, matchedAccessories: matches, isExact: false)
        }
    }
    
    /// Match all selectors and return results
    /// - Parameters:
    ///   - selectors: Selectors to match
    ///   - accessories: Available accessories
    /// - Returns: Array of match results
    static func matchAll(selectors: [AccessorySelector], against accessories: [AccessoryInfo]) -> [MatchResult] {
        return selectors.map { match(selector: $0, against: accessories) }
    }
    
    // MARK: - Pattern Matching
    
    private static func matchPattern(_ pattern: String, against accessories: [AccessoryInfo]) -> [AccessoryInfo] {
        // Determine if this is a regex or wildcard pattern
        let isRegex = pattern.hasPrefix("^") || pattern.hasSuffix("$")
        
        if isRegex {
            return matchRegex(pattern, against: accessories)
        } else {
            return matchWildcard(pattern, against: accessories)
        }
    }
    
    /// Match using regex pattern
    private static func matchRegex(_ pattern: String, against accessories: [AccessoryInfo]) -> [AccessoryInfo] {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
            // Invalid regex - return no matches
            return []
        }
        
        return accessories.filter { accessory in
            let range = NSRange(accessory.name.startIndex..., in: accessory.name)
            return regex.firstMatch(in: accessory.name, options: [], range: range) != nil
        }
    }
    
    /// Match using wildcard pattern (* = any substring)
    private static func matchWildcard(_ pattern: String, against accessories: [AccessoryInfo]) -> [AccessoryInfo] {
        // Convert wildcard to regex:
        // 1. Escape all regex metacharacters except *
        // 2. Replace * with .*
        
        var regexPattern = NSRegularExpression.escapedPattern(for: pattern)
        regexPattern = regexPattern.replacingOccurrences(of: "\\*", with: ".*")
        
        // Make it a full-string match
        regexPattern = "^" + regexPattern + "$"
        
        guard let regex = try? NSRegularExpression(pattern: regexPattern, options: [.caseInsensitive]) else {
            return []
        }
        
        return accessories.filter { accessory in
            let range = NSRange(accessory.name.startIndex..., in: accessory.name)
            return regex.firstMatch(in: accessory.name, options: [], range: range) != nil
        }
    }
}

// MARK: - Diagnostic Helpers

extension AccessoryMatcher {
    
    /// Generate a diagnostic report for a set of match results
    static func diagnostics(for results: [MatchResult]) -> String {
        var lines: [String] = []
        
        let matched = results.filter { $0.hasMatches }
        let unmatched = results.filter { !$0.hasMatches }
        let ambiguous = results.filter { $0.matchedAccessories.count > 1 }
        
        if !matched.isEmpty {
            lines.append("Matched (\(matched.count)):")
            for result in matched {
                let icon = result.isExact ? "=" : "~"
                let count = result.matchedAccessories.count
                let countStr = count > 1 ? " [\(count) matches]" : ""
                lines.append("  \(icon) \(result.selector.description)\(countStr)")
                for accessory in result.matchedAccessories {
                    lines.append("    → \(accessory.name)")
                }
            }
        }
        
        if !unmatched.isEmpty {
            lines.append("\nNot Found (\(unmatched.count)):")
            for result in unmatched {
                lines.append("  ✗ \(result.selector.description)")
            }
        }
        
        if !ambiguous.isEmpty {
            lines.append("\nAmbiguous (multiple matches):")
            for result in ambiguous {
                lines.append("  ⚠️  \(result.selector.description) matches \(result.matchedAccessories.count) accessories")
            }
        }
        
        return lines.joined(separator: "\n")
    }
}

