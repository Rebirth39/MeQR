import Foundation

enum PassSubtitleLimiter {
    private static let maxHalfWidthUnits = 20

    static func limited(_ value: String) -> String {
        let normalized = value
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
            .replacingOccurrences(of: "\n", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        var units = 0
        var result = ""

        for character in normalized {
            let nextUnits = units + halfWidthUnits(for: character)
            if nextUnits > maxHalfWidthUnits {
                break
            }
            result.append(character)
            units = nextUnits
        }

        return result
    }

    private static func halfWidthUnits(for character: Character) -> Int {
        character.unicodeScalars.allSatisfy(\.isASCII) ? 1 : 2
    }
}
