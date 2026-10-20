import SwiftUI

extension CategoryDefinition {
    /// The pastel card colour.
    var tint: Color { colorToken.soft }
    /// Text and marks drawn on the pastel.
    var tintInk: Color { colorToken.color }
}
