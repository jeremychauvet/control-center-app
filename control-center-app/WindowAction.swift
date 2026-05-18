import Foundation

enum WindowAction: String, CaseIterable, Identifiable, Codable {
    case leftHalf
    case rightHalf
    case topHalf
    case bottomHalf
    case maximize
    case center

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .leftHalf:   return "Left Half"
        case .rightHalf:  return "Right Half"
        case .topHalf:    return "Top Half"
        case .bottomHalf: return "Bottom Half"
        case .maximize:   return "Maximize"
        case .center:     return "Center"
        }
    }

    var systemImage: String {
        switch self {
        case .leftHalf:   return "rectangle.lefthalf.filled"
        case .rightHalf:  return "rectangle.righthalf.filled"
        case .topHalf:    return "rectangle.tophalf.filled"
        case .bottomHalf: return "rectangle.bottomhalf.filled"
        case .maximize:   return "rectangle.fill"
        case .center:     return "rectangle.center.inset.filled"
        }
    }
}
