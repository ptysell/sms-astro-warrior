import Foundation
import CoreGraphics

// ─────────────────────────────────────────────────────────────────────────────
// GalaxyPixelArt — OUR-OWN, hand-authored pixel art for the Galaxy zone.
//
// PROVENANCE: every grid below is drawn BY HAND in this file as ASCII. Nothing is
// read from the ROM. These are original renditions that follow the original's
// abstract shape language (a symmetric fighter, concentric ring-discs, a diagonal
// green "X", a small chevron starship, a flaming wheel, a teal fortress core) and
// use the (non-copyrightable) Galaxy palette COLORS from GalaxyPalette.json.
//
// A grid is an array of equal-length rows; each character is a palette index via
// `legend` ('.' / ' ' = transparent). Row 0 is the TOP of the sprite.
// ─────────────────────────────────────────────────────────────────────────────

public enum GalaxyPixelArt {

    /// Character → palette index (see GalaxyPalette.json). '.' and ' ' are transparent.
    public static let legend: [Character: Int] = [
        "W": 17, // white
        "M": 18, // magenta / pink
        "Y": 19, // yellow
        "R": 20, // red
        "O": 21, // orange
        "C": 22, // cyan
        "G": 23, // green
        "B": 24, // blue
        "D": 25, // deep blue
        "g": 26, // pale green
        "y": 27, // pale yellow
        "a": 28, // gray
        "q": 29, // aqua
        "t": 30, // teal-green
    ]

    public struct Art: Sendable {
        public let rows: [String]
        public var height: Int { rows.count }
        public var width: Int { rows.first?.count ?? 0 }
    }

    // MARK: player ship — symmetric fighter, nose UP (row 0 = nose)
    public static let ship = Art(rows: [
        ".......WW.......",
        ".......WW.......",
        "......WRRW......",
        "......WRRW......",
        "......CWWC......",
        ".....CCWWCC.....",
        "...B.CWWWWC.B...",
        "..BB.CWWWWC.BB..",
        ".BBBCCWWWWCCBBB.",
        "BBBBCCWCCWCCBBBB",
        "BBB.CCWCCWCC.BBB",
        ".B..CCWCCWCC..B.",
        "....CCWCCWCC....",
        ".....WCOOCW.....",
        "......OOOO......",
        ".......OO.......",
    ])

    // MARK: player bullet — yellow/orange bolt (8×8)
    public static let bullet = Art(rows: [
        "...WW...",
        "..WYYW..",
        "..YYYY..",
        "..YOOY..",
        "..YOOY..",
        "..YOOY..",
        "...OO...",
        "...OO...",
    ])

    // MARK: enemy bullet — red plasma ball with white core (8×8)
    public static let ebullet = Art(rows: [
        "..RRRR..",
        ".RRRRRR.",
        "RRRWWRRR",
        "RRWWWWRR",
        "RRWWWWRR",
        "RRRWWRRR",
        ".RRRRRR.",
        "..RRRR..",
    ])

    // MARK: cult (0x15) — concentric ring-disc, magenta→yellow→cyan→green (16×16)
    public static let cult = Art(rows: [
        "....MMMMMMMM....",
        "..MMMYYYYYYMMM..",
        ".MMYYYCCCCYYYMM.",
        ".MYYCCCCCCCCYYM.",
        "MYYCCCGGGGCCCYYM",
        "MYCCCGGGGGGCCCYM",
        "MYCCGGGGGGGGCCYM",
        "MYCCGGGWWGGGCCYM",
        "MYCCGGGWWGGGCCYM",
        "MYCCGGGGGGGGCCYM",
        "MYCCCGGGGGGCCCYM",
        "MYYCCCGGGGCCCYYM",
        ".MYYCCCCCCCCYYM.",
        ".MMYYYCCCCYYYMM.",
        "..MMMYYYYYYMMM..",
        "....MMMMMMMM....",
    ])

    // MARK: zanix / turret (0x16) — green diagonal "X" with a yellow core (16×16)
    public static let zanix = Art(rows: [
        "GG............GG",
        ".GG..........GG.",
        "..GG........GG..",
        "...GG......GG...",
        "....GG....GG....",
        ".....GG..GG.....",
        "......GGGG......",
        "......GYYG......",
        "......GYYG......",
        "......GGGG......",
        ".....GG..GG.....",
        "....GG....GG....",
        "...GG......GG...",
        "..GG........GG..",
        ".GG..........GG.",
        "GG............GG",
    ])

    // MARK: sharlin (0x18) — small chevron starship, red nose / blue nacelles (8×16)
    public static let sharlin = Art(rows: [
        "...RR...",
        "..RRRR..",
        "..RWWR..",
        ".RWCCWR.",
        ".WCCCCW.",
        ".WCYYCW.",
        ".CCYYCC.",
        "BCC..CCB",
        "BC....CB",
        "BB....BB",
        ".B....B.",
        ".B....B.",
        ".BB..BB.",
        "..B..B..",
        "..O..O..",
        "..O..O..",
    ])

    // MARK: kyra (0x22) — blue-winged interceptor, red-cored center (16×16)
    public static let kyra = Art(rows: [
        ".......WW.......",
        "......WCCW......",
        ".....WCCCCW.....",
        "B...WCCCCCCW...B",
        "BB.WCCMMMMCCW.BB",
        "BBBWCMYYYYMCWBBB",
        "BBBWCMYRRYMCWBBB",
        "BBBWCMYRRYMCWBBB",
        "BBBWCMYYYYMCWBBB",
        "BBBWCCMMMMCCWBBB",
        "BB.WCCCCCCCCW.BB",
        "B...WCCCCCCW...B",
        ".....WCCCCW.....",
        "......WCCW......",
        "......WCCW......",
        ".......WW.......",
    ])

    // MARK: gyron (0x27) — blue/magenta/cyan concentric disc, red core (16×16)
    public static let gyron = Art(rows: [
        "....BBBBBBBB....",
        "..BBBMMMMMMBBB..",
        ".BBMMMCCCCMMMBB.",
        ".BMMCCCCCCCCMMB.",
        "BMMCCCRRRRCCCMMB",
        "BMCCCRRRRRRCCCMB",
        "BMCCRRRRRRRRCCMB",
        "BMCCRRRWWRRRCCMB",
        "BMCCRRRWWRRRCCMB",
        "BMCCRRRRRRRRCCMB",
        "BMCCCRRRRRRCCCMB",
        "BMMCCCRRRRCCCMMB",
        ".BMMCCCCCCCCMMB.",
        ".BBMMMCCCCMMMBB.",
        "..BBBMMMMMMBBB..",
        "....BBBBBBBB....",
    ])

    // MARK: delta (0x19) — flaming wheel, red/orange/yellow with a white hub (16×16)
    public static let delta = Art(rows: [
        "....RRRRRRRR....",
        "..RRROOOOOORRR..",
        ".RROOOYYYYOOORR.",
        ".ROOYYYYYYYYOOR.",
        "ROOYYYRRRRYYYOOR",
        "ROYYYRRRRRRYYYOR",
        "ROYYRRRRRRRRYYOR",
        "ROYYRRRWWRRRYYOR",
        "ROYYRRRWWRRRYYOR",
        "ROYYRRRRRRRRYYOR",
        "ROYYYRRRRRRYYYOR",
        "RROOOYYYYYYOOORR",
        ".ROOYYYYYYYYOOR.",
        ".RROOOYYYYOOORR.",
        "..RRROOOOOORRR..",
        "....RRRRRRRR....",
    ])

    // MARK: zanoni boss core (0x28) — teal armored fortress core, red cannon port (16×16)
    public static let zanoni = Art(rows: [
        "atttttttttttttta",
        "ttaaaaaaaaaaaatt",
        "taaaaaaaaaaaaaat",
        "taaaaRRRRRRaaaat",
        "taaaaRWWWWRaaaat",
        "taaaaRWOOWRaaaat",
        "taaaaRWOOWRaaaat",
        "taaaaRWWWWRaaaat",
        "taaaaRRRRRRaaaat",
        "taaaaaaaaaaaaaat",
        "taaWaaaaaaaaWaat",
        "taaaaaaaaaaaaaat",
        "ttaaaaaaaaaaaatt",
        "atttttttttttttta",
        ".tttttttttttttt.",
        "..tttttttttttt..",
    ])

    // MARK: explosion — radial burst (16×16), used for the cosmetic hit flash
    public static let explosion = Art(rows: [
        ".......YY.......",
        "...Y...OO...Y...",
        "....Y..OO..Y....",
        "..Y..OYYYYO..Y..",
        "...O.YRRRRY.O...",
        "..Y.ORRWWRRO.Y..",
        "...ORRWWWWRRO...",
        "YYOORWWWWWWROOYY",
        "YYOORWWWWWWROOYY",
        "...ORRWWWWRRO...",
        "..Y.ORRWWRRO.Y..",
        "...O.YRRRRY.O...",
        "..Y..OYYYYO..Y..",
        "....Y..OO..Y....",
        "...Y...OO...Y...",
        ".......YY.......",
    ])

    /// A single teal fortress wall tile (8×8) — teal plating with a rivet corner.
    static let fortressPlate = Art(rows: [
        "tttttttt",
        "taaaaaat",
        "tattttat",
        "tattttat",
        "tattttat",
        "tattttat",
        "taaaaaat",
        "tttttttt",
    ])

    /// A fortress embrasure tile (8×8) — teal frame around a red cannon port.
    static let fortressPort = Art(rows: [
        "tttttttt",
        "tRRRRRRt",
        "tRWWWWRt",
        "tRWOOWRt",
        "tRWOOWRt",
        "tRWWWWRt",
        "tRRRRRRt",
        "tttttttt",
    ])

    // MARK: rasterization ------------------------------------------------------

    /// Rasterize an Art to premultiplied-RGBA bytes (row 0 at top). Transparent = 0,0,0,0.
    /// `flipV` flips vertically (used to match a renderer whose texture origin is bottom-left).
    public static func rgba(_ art: Art, palette: GalaxyPalette, flipV: Bool = false) -> (w: Int, h: Int, px: [UInt8]) {
        let w = art.width, h = art.height
        var px = [UInt8](repeating: 0, count: w * h * 4)
        for (r, row) in art.rows.enumerated() {
            let dr = flipV ? (h - 1 - r) : r
            for (c, ch) in row.enumerated() {
                guard let idx = legend[ch] else { continue }   // '.'/' ' → transparent
                let col = palette[idx]
                let o = (dr * w + c) * 4
                px[o] = col.r; px[o + 1] = col.g; px[o + 2] = col.b; px[o + 3] = 255
            }
        }
        return (w, h, px)
    }

    /// Build a CGImage (nearest-neighbor friendly) from an Art.
    public static func cgImage(_ art: Art, palette: GalaxyPalette, flipV: Bool = false) -> CGImage? {
        let (w, h, px) = rgba(art, palette: palette, flipV: flipV)
        guard w > 0, h > 0 else { return nil }
        let cs = CGColorSpaceCreateDeviceRGB()
        let info = CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue)
        guard let prov = CGDataProvider(data: Data(px) as CFData) else { return nil }
        return CGImage(width: w, height: h, bitsPerComponent: 8, bitsPerPixel: 32,
                       bytesPerRow: w * 4, space: cs, bitmapInfo: info,
                       provider: prov, decode: nil, shouldInterpolate: false, intent: .defaultIntent)
    }

    // MARK: procedural starfield (OUR own, no ROM) -----------------------------

    public struct Star: Sendable { public let x: Double; public let y: Double; public let paletteIndex: Int; public let size: Int }

    /// Deterministic star list for one parallax layer, filling a `w`×`h` native tile.
    /// `seed` varies per layer; brighter/larger stars for nearer layers.
    public static func stars(w: Int, h: Int, count: Int, seed: UInt64, palette: [Int], maxSize: Int) -> [Star] {
        var s = seed | 1
        func next() -> UInt64 { s ^= s << 13; s ^= s >> 7; s ^= s << 17; return s }
        func unit() -> Double { Double(next() % 100_000) / 100_000.0 }
        var out: [Star] = []
        out.reserveCapacity(count)
        for _ in 0..<count {
            let x = unit() * Double(w)
            let y = unit() * Double(h)
            let pi = palette[Int(next() % UInt64(palette.count))]
            let sz = 1 + Int(next() % UInt64(max(1, maxSize)))
            out.append(Star(x: x, y: y, paletteIndex: pi, size: sz))
        }
        return out
    }
}
