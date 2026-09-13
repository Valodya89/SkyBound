import Foundation

/// Platform-neutral colour so the core package never imports UIKit.
public struct RGBA: Sendable, Hashable, Codable {
    public var r: Double
    public var g: Double
    public var b: Double
    public var a: Double

    public init(r: Double, g: Double, b: Double, a: Double = 1) {
        self.r = r; self.g = g; self.b = b; self.a = a
    }

    /// Accepts `#RRGGBB` or `RRGGBB`.
    public init(hex: String, alpha: Double = 1) {
        var s = hex.hasPrefix("#") ? String(hex.dropFirst()) : hex
        if s.count == 3 { s = s.map { "\($0)\($0)" }.joined() }
        let v = UInt32(s, radix: 16) ?? 0xFFFFFF
        self.init(r: Double((v >> 16) & 0xFF) / 255,
                  g: Double((v >> 8) & 0xFF) / 255,
                  b: Double(v & 0xFF) / 255,
                  a: alpha)
    }

    /// Linear blend toward `other` by `t` (0…1).
    public func mixed(with other: RGBA, _ t: Double) -> RGBA {
        let k = min(max(t, 0), 1)
        return RGBA(r: r + (other.r - r) * k, g: g + (other.g - g) * k, b: b + (other.b - b) * k, a: a + (other.a - a) * k)
    }

    /// Positive `t` lightens toward white, negative darkens toward black.
    public func shaded(_ t: Double) -> RGBA {
        let k: Double = t < 0 ? 0 : 1
        let f = abs(t)
        return RGBA(r: r + (k - r) * f, g: g + (k - g) * f, b: b + (k - b) * f, a: a)
    }

    public func withAlpha(_ alpha: Double) -> RGBA { RGBA(r: r, g: g, b: b, a: alpha) }
}

public enum Hazard: String, Sendable, Codable {
    case none, gust, storm, fog
}

/// A visual sector of the corridor. Every 1000 metres the run advances to the next one.
public struct Biome: Sendable, Hashable, Identifiable {
    public let id: Int
    public let name: String
    public let zoneLabel: String
    public let skyTop: RGBA
    public let skyMid: RGBA
    public let skyBottom: RGBA
    public let horizon: RGBA
    public let cloud: RGBA
    public let hillNear: RGBA
    public let hillFar: RGBA
    public let groundTop: RGBA
    public let groundBottom: RGBA
    public let road: RGBA
    public let laneTint: RGBA
    public let dash: RGBA
    public let edge: RGBA
    public let accent: RGBA
    public let hazard: Hazard
    public let isNight: Bool
}

public enum BiomeCatalog {
    /// Six sectors of deep space. Field names date from the sky-and-hills renderer and are reused as follows:
    /// `cloud` and `hillFar` tint the two nebula fields, `hillNear` is the planet, `horizon` is the fog that
    /// far objects fade toward, `road`/`edge`/`dash` are the launch corridor.
    public static let all: [Biome] = [
        Biome(id: 0, name: "LAUNCH ORBIT", zoneLabel: "SECTOR 01",
              skyTop: RGBA(hex: "#070A14"), skyMid: RGBA(hex: "#0E1326"), skyBottom: RGBA(hex: "#141B33"),
              horizon: RGBA(hex: "#2A3352"), cloud: RGBA(hex: "#33254F", alpha: 0.55),
              hillNear: RGBA(hex: "#C8684E"), hillFar: RGBA(hex: "#173A44"),
              groundTop: RGBA(hex: "#0C1020"), groundBottom: RGBA(hex: "#060810"), road: RGBA(hex: "#141B2F"),
              laneTint: RGBA(hex: "#182238"), dash: RGBA(hex: "#34446A", alpha: 0.8), edge: RGBA(hex: "#7EDCF2"),
              accent: RGBA(hex: "#F97B2F"), hazard: .none, isNight: true),
        Biome(id: 1, name: "RING SHALLOWS", zoneLabel: "SECTOR 02",
              skyTop: RGBA(hex: "#0A0A18"), skyMid: RGBA(hex: "#1A1230"), skyBottom: RGBA(hex: "#2A1E44"),
              horizon: RGBA(hex: "#3D2C5E"), cloud: RGBA(hex: "#4A2B50", alpha: 0.5),
              hillNear: RGBA(hex: "#E39A6B"), hillFar: RGBA(hex: "#1F2F5A"),
              groundTop: RGBA(hex: "#0E0C1E"), groundBottom: RGBA(hex: "#07060F"), road: RGBA(hex: "#1A1630"),
              laneTint: RGBA(hex: "#221C3C"), dash: RGBA(hex: "#4A3A70", alpha: 0.8), edge: RGBA(hex: "#F2B544"),
              accent: RGBA(hex: "#F2B544"), hazard: .none, isNight: true),
        Biome(id: 2, name: "ION BELT", zoneLabel: "SECTOR 03",
              skyTop: RGBA(hex: "#05111A"), skyMid: RGBA(hex: "#0B2230"), skyBottom: RGBA(hex: "#0F3A44"),
              horizon: RGBA(hex: "#1F5A66"), cloud: RGBA(hex: "#173A44", alpha: 0.55),
              hillNear: RGBA(hex: "#5FB8D8"), hillFar: RGBA(hex: "#0E4A5A"),
              groundTop: RGBA(hex: "#08141A"), groundBottom: RGBA(hex: "#04090C"), road: RGBA(hex: "#0F2430"),
              laneTint: RGBA(hex: "#123040"), dash: RGBA(hex: "#2E6A7A", alpha: 0.8), edge: RGBA(hex: "#7EDCF2"),
              accent: RGBA(hex: "#7EDCF2"), hazard: .gust, isNight: true),
        Biome(id: 3, name: "NIGHT DRIFT", zoneLabel: "SECTOR 04",
              skyTop: RGBA(hex: "#04040C"), skyMid: RGBA(hex: "#0B0B22"), skyBottom: RGBA(hex: "#15153A"),
              horizon: RGBA(hex: "#2A2A60"), cloud: RGBA(hex: "#262060", alpha: 0.5),
              hillNear: RGBA(hex: "#9B85FF"), hillFar: RGBA(hex: "#121440"),
              groundTop: RGBA(hex: "#08081A"), groundBottom: RGBA(hex: "#030308"), road: RGBA(hex: "#10102A"),
              laneTint: RGBA(hex: "#161638"), dash: RGBA(hex: "#3A3A78", alpha: 0.8), edge: RGBA(hex: "#B4BEFF"),
              accent: RGBA(hex: "#8B7CFF"), hazard: .none, isNight: true),
        Biome(id: 4, name: "PLASMA FRONT", zoneLabel: "SECTOR 05",
              skyTop: RGBA(hex: "#14060A"), skyMid: RGBA(hex: "#2C0C14"), skyBottom: RGBA(hex: "#4A1420"),
              horizon: RGBA(hex: "#7A2430"), cloud: RGBA(hex: "#5A1A2A", alpha: 0.55),
              hillNear: RGBA(hex: "#FF5D8F"), hillFar: RGBA(hex: "#2A0C18"),
              groundTop: RGBA(hex: "#140608"), groundBottom: RGBA(hex: "#070203"), road: RGBA(hex: "#241018"),
              laneTint: RGBA(hex: "#2E1420"), dash: RGBA(hex: "#7A3448", alpha: 0.8), edge: RGBA(hex: "#FF9273"),
              accent: RGBA(hex: "#F97B2F"), hazard: .storm, isNight: true),
        Biome(id: 5, name: "AURORA GATE", zoneLabel: "SECTOR 06",
              skyTop: RGBA(hex: "#02100E"), skyMid: RGBA(hex: "#04241E"), skyBottom: RGBA(hex: "#0A3A32"),
              horizon: RGBA(hex: "#12655C"), cloud: RGBA(hex: "#0F3E36", alpha: 0.5),
              hillNear: RGBA(hex: "#2FE0A6"), hillFar: RGBA(hex: "#062320"),
              groundTop: RGBA(hex: "#04140F"), groundBottom: RGBA(hex: "#020806"), road: RGBA(hex: "#0C2A22"),
              laneTint: RGBA(hex: "#10342A"), dash: RGBA(hex: "#2E7A62", alpha: 0.8), edge: RGBA(hex: "#5FFFD0"),
              accent: RGBA(hex: "#2FE0A6"), hazard: .fog, isNight: true),
    ]

    public static func biome(forZone index: Int) -> Biome {
        all[((index % all.count) + all.count) % all.count]
    }
}
