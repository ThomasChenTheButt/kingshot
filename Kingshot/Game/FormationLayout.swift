import CoreGraphics
import Foundation

/// Positions shared by the crowd blob and enemy grids.
enum FormationLayout {
    private static let goldenAngle: CGFloat = 2.399963

    /// Sunflower (phyllotaxis) layout: dense round blob that grows evenly with the count.
    static func blobPosition(index: Int, spacing: CGFloat) -> CGPoint {
        let i = CGFloat(index)
        let radius = spacing * i.squareRoot()
        let angle = i * goldenAngle
        return CGPoint(x: radius * cos(angle), y: radius * sin(angle))
    }

    static func blobRadius(count: Int, spacing: CGFloat) -> CGFloat {
        spacing * CGFloat(max(count, 1)).squareRoot() + spacing
    }

    /// Rank-and-file grid. Row 0 is the front line (lowest s), later rows stack behind.
    static func gridOffset(index: Int, columns: Int, spacing: CGFloat) -> (across: CGFloat, back: CGFloat) {
        let col = index % columns
        let row = index / columns
        let across = (CGFloat(col) - CGFloat(columns - 1) / 2) * spacing
        return (across, CGFloat(row) * spacing)
    }
}
