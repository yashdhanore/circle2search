import CoreGraphics

struct ScreenSelection {
    let displayID: CGDirectDisplayID
    let rectInScreenCoordinates: CGRect

    var summary: String {
        let width = Int(rectInScreenCoordinates.width.rounded())
        let height = Int(rectInScreenCoordinates.height.rounded())
        let x = Int(rectInScreenCoordinates.origin.x.rounded())
        let y = Int(rectInScreenCoordinates.origin.y.rounded())

        return "Display \(displayID) at (\(x), \(y)) size \(width)x\(height)"
    }
}
