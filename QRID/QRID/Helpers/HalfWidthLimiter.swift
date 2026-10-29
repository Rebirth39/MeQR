import Foundation

enum HalfWidthLimiter {
    static func limited(_ value: String, maxUnits: Int, flattenNewlines: Bool = false) -> String {
        var text = value
        if flattenNewlines {
            text = text
                .replacingOccurrences(of: "\r\n", with: "\n")
                .replacingOccurrences(of: "\r", with: "\n")
                .replacingOccurrences(of: "\n", with: " ")
        }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        var units = 0
        var result = ""

        for character in trimmed {
            let nextUnits = units + unitCount(for: character)
            if nextUnits > maxUnits {
                break
            }
            result.append(character)
            units = nextUnits
        }

        return result
    }

    static func unitCount(_ value: String) -> Int {
        value.reduce(0) { $0 + unitCount(for: $1) }
    }

    private static func unitCount(for character: Character) -> Int {
        character.unicodeScalars.allSatisfy(\.isASCII) ? 1 : 2
    }
}
