import Foundation

enum ToolType: String, CaseIterable, Identifiable {
    case scan = "Scan"
    case `import` = "Image Convert"
    case merge = "Merge"
    case split = "Split / Extract"
    case markup = "Markup"
    case compress = "Compress"

    var id: String { rawValue }
}
