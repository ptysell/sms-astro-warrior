import Foundation
import ReferenceEmu
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

// AssetRip — reusable, COMMITTED dev harness that extracts each zone's ground-truth
// graphics from the reference ROM as DEV-ONLY REFERENCE images.
//
//   ⚠️  PROVENANCE / DISCIPLINE: the images this tool writes are ©SEGA and MUST NOT be
//       committed or shipped. They are decode references for a "recreate-to-match" art
//       pipeline. Only this SOURCE FILE is committed; output goes OUTSIDE the repo, to
//       /tmp/astro-refrips by default. Never stage the .png/.json it produces, nor the ROM.
//
// Ground-truth format (docs/rom-decode-systems.md):
//   • CRAM palette: 32 bytes, --BBGGRR (2 bits/channel *85 → 0/85/170/255).
//     0x00–0x0F = background palette, 0x10–0x1F = sprite palette.
//   • Tiles: 8×8, 4bpp PLANAR, 32 bytes/tile (per row [p0,p1,p2,p3]; pixel = bit from each plane).
//   • Name table @VRAM 0x3800: 32 cols, 2-byte entries (bits0–8 tile, b9 hflip, b10 vflip,
//     b11 palette-select, b12 priority).
//   • Sprites: 8×16 hardware sprites (reg1=0xA2), composed from the renderer descriptor.
//     For appearance index f, descriptor = word[ROM 0x1187 + f*2] → [Yoff,Xoff,VRAMtile] triples,
//     end 0x80. Each triple is one 8×16 piece: VRAM tile (top 8×8) + tile+1 (bottom 8×8).
//   • Per-zone graphics: the loader @0x07E3 copies a per-variant 112-tile block into VRAM tile
//     0x90 at game-start using 0xC240 mod 3, so each zone has DIFFERENT VRAM pixels. We warp by
//     HOLDING 0xC240 across boot so the loader reads our variant, then read pixels straight from VRAM.
//
// Usage: AssetRip [outputDir=/tmp/astro-refrips] [zone=all|galaxy|asteroid|nebula|0|1|2]

// ───────────────────────── args + ROM ─────────────────────────

let argv = CommandLine.arguments
let outRoot = argv.count > 1 ? argv[1] : "/tmp/astro-refrips"
let zoneArg = argv.count > 2 ? argv[2].lowercased() : "all"

// The ROM is gitignored/absent from the tree. Locate it via $ASTRO_ROM, then the usual local
// paths (ParityDebug resources / the docs copy in the main checkout or a worktree), like the
// other harness tools — so this isn't pinned to one machine's absolute path.
let romCandidates = [
    ProcessInfo.processInfo.environment["ASTRO_ROM"],
    "AstroWarriorKit/Sources/ParityDebug/Resources/AstroWarrior.sms",
    "Sources/ParityDebug/Resources/AstroWarrior.sms",
    "docs/AstroWarrior.sms",
    "/Users/ptysell/Code/astro-warrior/docs/AstroWarrior.sms",
].compactMap { $0 }
guard let romPath = romCandidates.first(where: { FileManager.default.fileExists(atPath: $0) }),
      let romData = try? Data(contentsOf: URL(fileURLWithPath: romPath)) else {
    fputs("AssetRip: ROM not found. Set $ASTRO_ROM or place it at one of: \(romCandidates.joined(separator: ", "))\n", stderr); exit(1)
}
let rom = [UInt8](romData)   // flat, headerless — ROM addr 0x0000–0x3FFF maps 1:1 to file offset

struct Zone { let name: String; let variant: UInt8 }
let allZones = [Zone(name: "galaxy", variant: 0),
                Zone(name: "asteroid", variant: 1),
                Zone(name: "nebula", variant: 2)]
let zones: [Zone]
switch zoneArg {
case "all":                 zones = allZones
case "galaxy", "0":         zones = [allZones[0]]
case "asteroid", "1":       zones = [allZones[1]]
case "nebula", "2":         zones = [allZones[2]]
default:
    fputs("AssetRip: unknown zone '\(zoneArg)' (want all|galaxy|asteroid|nebula)\n", stderr); exit(1)
}

// romType → renderer appearance index (IX+3), grouped by the zone whose 112-tile block holds its
// pixels. Values are ROM-verified in docs/rom-decode-systems.md (§ species decode). The player
// (type 0x01, frame 0x01) uses static VRAM tiles present in every zone, so it is ripped per zone.
struct SpriteSpec { let romType: Int; let frame: Int; let name: String }
let playerSpec = SpriteSpec(romType: 0x01, frame: 0x01, name: "player")
let spriteSpecs: [UInt8: [SpriteSpec]] = [
    0: [ // Galaxy
        playerSpec,
        SpriteSpec(romType: 0x15, frame: 0x3A, name: "asteroids-ringdisc"),
        SpriteSpec(romType: 0x16, frame: 0x41, name: "spin-cross"),
        SpriteSpec(romType: 0x18, frame: 0x23, name: "starships"),
        SpriteSpec(romType: 0x19, frame: 0x37, name: "burning-tires"),
        SpriteSpec(romType: 0x22, frame: 0x3E, name: "tie-fighters"),
        SpriteSpec(romType: 0x27, frame: 0x61, name: "blue-wisps"),
        SpriteSpec(romType: 0x28, frame: 0x63, name: "boss-zanoni-seg"),
    ],
    1: [ // Asteroid
        playerSpec,
        SpriteSpec(romType: 0x17, frame: 0x4C, name: "spiders"),
        SpriteSpec(romType: 0x1B, frame: 0x46, name: "chainlinks"),
        SpriteSpec(romType: 0x1D, frame: 0x2B, name: "double-missiles"),
        SpriteSpec(romType: 0x1E, frame: 0x31, name: "swoopers"),
        SpriteSpec(romType: 0x21, frame: 0x43, name: "small-asteroids"),
        SpriteSpec(romType: 0x24, frame: 0x49, name: "flying-saucers"),
        SpriteSpec(romType: 0x29, frame: 0x66, name: "boss-nebiros-core"),
        SpriteSpec(romType: 0x29, frame: 0x65, name: "boss-nebiros-body"),
    ],
    2: [ // Nebula
        playerSpec,
        SpriteSpec(romType: 0x1A, frame: 0x34, name: "t-ships"),
        SpriteSpec(romType: 0x1F, frame: 0x5C, name: "star-mine-base"),
        SpriteSpec(romType: 0x1F, frame: 0x5E, name: "star-mine-burst"),
        SpriteSpec(romType: 0x20, frame: 0x54, name: "replicating-tris"),
        SpriteSpec(romType: 0x23, frame: 0x4F, name: "space-bases"),
        SpriteSpec(romType: 0x25, frame: 0x58, name: "emitters"),
        SpriteSpec(romType: 0x26, frame: 0x52, name: "side-ships"),
        SpriteSpec(romType: 0x2C, frame: 0x7A, name: "boss-belzebul-seg"),
        SpriteSpec(romType: 0x2D, frame: 0x6D, name: "boss-belzebul-core"),
    ],
]

// ───────────────────────── ROM descriptor decode (pure) ─────────────────────────

func s8(_ v: Int) -> Int { v > 127 ? v - 256 : v }

/// Walk the renderer descriptor for appearance index `f`: word[0x1187+f*2] → [Yoff,Xoff,tile]*,0x80.
func descriptorTriples(frame f: Int) -> [(y: Int, x: Int, tile: Int)] {
    let tab = 0x1187 + f * 2
    guard tab + 1 < rom.count else { return [] }
    let ptr = Int(rom[tab]) | (Int(rom[tab + 1]) << 8)
    var out: [(Int, Int, Int)] = []
    var a = ptr
    var n = 0
    while n < 64 {
        n += 1
        guard a + 2 < rom.count else { break }
        if rom[a] == 0x80 { break }
        out.append((Int(rom[a]), Int(rom[a + 1]), Int(rom[a + 2])))
        a += 3
    }
    return out
}

// ───────────────────────── VDP reads (VRAM/CRAM) ─────────────────────────

typealias RGB = (r: Int, g: Int, b: Int)

@MainActor func decodePalette(_ core: SMSPlusCore) -> [RGB] {
    (0..<32).map { i in
        let v = Int(core.readCRAM(i))
        return ((v & 0x03) * 85, ((v >> 2) & 0x03) * 85, ((v >> 4) & 0x03) * 85)
    }
}

/// 8×8 grid of 4bpp palette indices for VRAM tile `tile`.
@MainActor func tileIndices(_ core: SMSPlusCore, _ tile: Int) -> [[Int]] {
    let base = tile * 32
    var rows: [[Int]] = []
    rows.reserveCapacity(8)
    for r in 0..<8 {
        let o = base + r * 4
        guard o + 3 <= 0x3FFF else { rows.append([Int](repeating: 0, count: 8)); continue }
        let p0 = Int(core.readVRAM(o)), p1 = Int(core.readVRAM(o + 1))
        let p2 = Int(core.readVRAM(o + 2)), p3 = Int(core.readVRAM(o + 3))
        var row = [Int](repeating: 0, count: 8)
        for c in 0..<8 {
            let bit = 7 - c
            row[c] = ((p0 >> bit) & 1) | (((p1 >> bit) & 1) << 1)
                   | (((p2 >> bit) & 1) << 2) | (((p3 >> bit) & 1) << 3)
        }
        rows.append(row)
    }
    return rows
}

// ───────────────────────── tiny RGBA canvas + PNG ─────────────────────────

final class Canvas {
    let w: Int, h: Int
    var px: [UInt8]
    init(_ w: Int, _ h: Int, fill: (UInt8, UInt8, UInt8, UInt8) = (0, 0, 0, 255)) {
        self.w = max(1, w); self.h = max(1, h)
        px = [UInt8](repeating: 0, count: self.w * self.h * 4)
        var i = 0
        while i < px.count { px[i] = fill.0; px[i+1] = fill.1; px[i+2] = fill.2; px[i+3] = fill.3; i += 4 }
    }
    @inline(__always) func set(_ x: Int, _ y: Int, _ c: RGB, _ a: UInt8 = 255) {
        guard x >= 0, x < w, y >= 0, y < h else { return }
        let o = (y * w + x) * 4
        px[o] = UInt8(c.r); px[o+1] = UInt8(c.g); px[o+2] = UInt8(c.b); px[o+3] = a
    }
    func scaled(_ s: Int) -> Canvas {
        guard s > 1 else { return self }
        let c = Canvas(w * s, h * s, fill: (0, 0, 0, 0))
        for y in 0..<h {
            for x in 0..<w {
                let o = (y * w + x) * 4
                for dy in 0..<s {
                    for dx in 0..<s {
                        let oo = ((y * s + dy) * (w * s) + (x * s + dx)) * 4
                        c.px[oo] = px[o]; c.px[oo+1] = px[o+1]; c.px[oo+2] = px[o+2]; c.px[oo+3] = px[o+3]
                    }
                }
            }
        }
        return c
    }
}

@discardableResult
func writePNG(_ cv: Canvas, to path: String) -> Bool {
    let cs = CGColorSpaceCreateDeviceRGB()
    let info = CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue)
    let data = Data(cv.px)
    guard let prov = CGDataProvider(data: data as CFData),
          let img = CGImage(width: cv.w, height: cv.h, bitsPerComponent: 8, bitsPerPixel: 32,
                            bytesPerRow: cv.w * 4, space: cs, bitmapInfo: info,
                            provider: prov, decode: nil, shouldInterpolate: false, intent: .defaultIntent)
    else { return false }
    let url = URL(fileURLWithPath: path) as CFURL
    guard let dst = CGImageDestinationCreateWithURL(url, UTType.png.identifier as CFString, 1, nil) else { return false }
    CGImageDestinationAddImage(dst, img, nil)
    return CGImageDestinationFinalize(dst)
}

// ───────────────────────── renderers ─────────────────────────

/// Blit one 8×8 tile (given as palette indices) onto a canvas.
func blitTile(_ cv: Canvas, _ idx: [[Int]], pal: [RGB], palBase: Int, ox: Int, oy: Int,
              transparentZero: Bool, hflip: Bool = false, vflip: Bool = false) {
    for r in 0..<8 {
        for c in 0..<8 {
            let sr = vflip ? 7 - r : r
            let sc = hflip ? 7 - c : c
            let pi = idx[sr][sc]
            if transparentZero && pi == 0 { continue }
            cv.set(ox + c, oy + r, pal[palBase + pi])
        }
    }
}

/// Full VRAM pattern table (tiles 0..<count) as a sheet, `perRow` tiles wide, shown in `palBase`.
@MainActor func renderTileSheet(_ core: SMSPlusCore, pal: [RGB], palBase: Int,
                                count: Int, perRow: Int) -> Canvas {
    let rows = (count + perRow - 1) / perRow
    let cv = Canvas(perRow * 8, rows * 8)
    for t in 0..<count {
        let idx = tileIndices(core, t)
        let ox = (t % perRow) * 8, oy = (t / perRow) * 8
        blitTile(cv, idx, pal: pal, palBase: palBase, ox: ox, oy: oy, transparentZero: false)
    }
    return cv
}

/// Name-table background: `cols`×`rows` entries starting at VRAM `base`.
@MainActor func renderBackground(_ core: SMSPlusCore, pal: [RGB], base: Int,
                                 cols: Int, rows: Int) -> Canvas {
    let cv = Canvas(cols * 8, rows * 8)
    var cache: [Int: [[Int]]] = [:]
    for row in 0..<rows {
        for col in 0..<cols {
            let e = base + (row * cols + col) * 2
            guard e + 1 <= 0x3FFF else { continue }
            let entry = Int(core.readVRAM(e)) | (Int(core.readVRAM(e + 1)) << 8)
            let tile = entry & 0x1FF
            let hflip = (entry & 0x200) != 0
            let vflip = (entry & 0x400) != 0
            let palBase = (entry & 0x800) != 0 ? 0x10 : 0x00
            let idx = cache[tile] ?? { let v = tileIndices(core, tile); cache[tile] = v; return v }()
            blitTile(cv, idx, pal: pal, palBase: palBase, ox: col * 8, oy: row * 8,
                     transparentZero: false, hflip: hflip, vflip: vflip)
        }
    }
    return cv
}

/// Compose a metasprite from its descriptor. Returns canvas, sorted VRAM tiles used, and whether
/// any non-transparent pixel was produced (false ⇒ the frame resolved only to blank/transparent tiles).
@MainActor func composeSprite(_ core: SMSPlusCore, frame: Int, pal: [RGB])
    -> (canvas: Canvas, tiles: [Int], nonBlank: Bool)? {
    let trips = descriptorTriples(frame: frame)
    guard !trips.isEmpty else { return nil }
    var minX = Int.max, minY = Int.max, maxX = Int.min, maxY = Int.min
    for t in trips {
        let sx = s8(t.x), sy = s8(t.y)
        minX = min(minX, sx); minY = min(minY, sy)
        maxX = max(maxX, sx + 8); maxY = max(maxY, sy + 16)
    }
    let cv = Canvas(maxX - minX, maxY - minY, fill: (0, 0, 0, 0))
    var tilesUsed = Set<Int>()
    var nonBlank = false
    for t in trips {
        let ox = s8(t.x) - minX, oy = s8(t.y) - minY
        let top = t.tile & 0xFE, bot = (t.tile & 0xFE) | 1
        tilesUsed.insert(top); tilesUsed.insert(bot)
        let topIdx = tileIndices(core, top), botIdx = tileIndices(core, bot)
        for r in 0..<8 {
            for c in 0..<8 {
                let pt = topIdx[r][c]
                if pt != 0 { nonBlank = true; cv.set(ox + c, oy + r, pal[0x10 + pt]) }
                let pb = botIdx[r][c]
                if pb != 0 { nonBlank = true; cv.set(ox + c, oy + 8 + r, pal[0x10 + pb]) }
            }
        }
    }
    return (cv, tilesUsed.sorted(), nonBlank)
}

/// A 2-row palette swatch strip (bg 0–15 top, sprite 16–31 bottom).
func renderPaletteStrip(_ pal: [RGB], swatch: Int) -> Canvas {
    let cv = Canvas(16 * swatch, 2 * swatch, fill: (24, 24, 24, 255))
    for i in 0..<32 {
        let col = i % 16, rowBand = i / 16
        for y in 0..<(swatch - 1) {
            for x in 0..<(swatch - 1) {
                cv.set(col * swatch + x, rowBand * swatch + y, pal[i])
            }
        }
    }
    return cv
}

// ───────────────────────── output scales (documented) ─────────────────────────

let SPRITE_SCALE = 6   // metasprites are ~16×16 native; scale up so shapes are eyeball-legible
let TILE_SCALE   = 2   // tile sheet 128×224 native → 256×448
let BG_SCALE     = 1   // backgrounds are 256×224 native — kept 1:1 (pixel-exact reference)
let SWATCH       = 20  // palette swatch px

let NT_BASE = 0x3800   // name-table base (docs); also derivable from VDP reg2 (verified at runtime)
let NT_COLS = 32
let NT_ROWS = 28
let PATTERN_TILES = 0x1C0   // 448 tiles: VRAM 0x0000–0x37FF, the region below the name table
let TILES_PER_ROW = 16

// ───────────────────────── driver ─────────────────────────

func ensureDir(_ p: String) { try? FileManager.default.createDirectory(atPath: p, withIntermediateDirectories: true) }
ensureDir(outRoot)

let core = SMSPlusCore()
guard core.load(rom: romData) else { fputs("AssetRip: ROM load failed\n", stderr); exit(1) }

func hexByte(_ v: Int) -> String { String(format: "%02X", v) }
func hexColor(_ c: RGB) -> String { String(format: "#%02X%02X%02X", c.r, c.g, c.b) }

var manifest: [String] = []
manifest.append("Astro Warrior — asset rip (©SEGA REFERENCE, DEV-ONLY — DO NOT COMMIT/SHIP)")
manifest.append("generated: \(ISO8601DateFormatter().string(from: Date()))")
manifest.append("source ROM: \(romPath)")
manifest.append("scales: sprite ×\(SPRITE_SCALE), tiles ×\(TILE_SCALE), background ×\(BG_SCALE) (native pixel dims noted per entry)")
manifest.append("")

// Structured cross-check accumulators
var palettesSummary: [String] = []
var notesLines: [String] = []
var totalFiles = 0

@MainActor func warpAndCapture(_ zone: Zone) {
    let v = zone.variant
    core.reset()
    func hstep(_ b: RefButtons) { core.writeRAM(0xC240, v); core.step(buttons: b, pause: false) }
    // Boot with the variant HELD across the title→game transition so the tile loader @0x07E3
    // (runs once at game-start) reads our variant and copies the zone's 112-tile block into VRAM.
    for _ in 0..<300 { hstep([]) }        // title / attract
    for _ in 0..<5   { hstep(.fire) }     // press Start → new-life init → 0x07E3 tile+palette load
    for _ in 0..<8   { hstep([]) }
    // Run gameplay while still holding the variant, so live enemies of this zone populate the
    // scene/background. (Sprite pixels are read straight from the loaded VRAM block regardless.)
    for _ in 0..<900 {
        var b: RefButtons = [.fire]
        let px = Double(Int(core.readRAM(0xC60A)) | (Int(core.readRAM(0xC60B)) << 8)) / 256.0
        if px < 120 { b.insert(.right) } else if px > 136 { b.insert(.left) }
        hstep(b)
    }
}

for zone in zones {
    warpAndCapture(zone)
    let zdir = "\(outRoot)/\(zone.name)"
    ensureDir(zdir)
    ensureDir("\(zdir)/sprites")

    let pal = decodePalette(core)
    let ntBaseReg = (Int(core.readVDPReg(2)) & 0x0E) << 10
    let ntBase = ntBaseReg == 0 ? NT_BASE : ntBaseReg

    manifest.append("== ZONE \(zone.name) (variant \(zone.variant)) ==")
    manifest.append("  name-table base: 0x\(String(format: "%04X", ntBase)) (reg2-derived: 0x\(String(format: "%04X", ntBaseReg)))")

    // 1) palette.json + palette.png
    var palJSON: [String] = ["["]
    var offPalette = false
    for i in 0..<32 {
        let raw = Int(core.readCRAM(i))
        let c = pal[i]
        if ![0, 85, 170, 255].contains(c.r) || ![0, 85, 170, 255].contains(c.g) || ![0, 85, 170, 255].contains(c.b) { offPalette = true }
        let region = i < 16 ? "bg" : "sprite"
        let comma = i < 31 ? "," : ""
        palJSON.append("  {\"index\":\(i),\"region\":\"\(region)\",\"cram\":\"0x\(hexByte(raw))\",\"r\":\(c.r),\"g\":\(c.g),\"b\":\(c.b),\"hex\":\"\(hexColor(c))\"}\(comma)")
    }
    palJSON.append("]")
    try? palJSON.joined(separator: "\n").write(toFile: "\(zdir)/palette.json", atomically: true, encoding: .utf8)
    let palStrip = renderPaletteStrip(pal, swatch: SWATCH).scaled(1)
    writePNG(palStrip, to: "\(zdir)/palette.png")
    totalFiles += 2
    let bgHex = (0..<16).map { hexColor(pal[$0]) }.joined(separator: " ")
    let spHex = (16..<32).map { hexColor(pal[$0]) }.joined(separator: " ")
    manifest.append("  palette.json  (32 entries, bg 0–15 / sprite 16–31)\(offPalette ? "  ⚠️ OFF-PALETTE VALUE" : "")")
    manifest.append("  palette.png   \(palStrip.w)×\(palStrip.h)")
    palettesSummary.append("\(zone.name):\n    bg     \(bgHex)\n    sprite \(spHex)")

    // 2) tiles.png (bg palette) + tiles_sprite.png (sprite palette)
    let sheetBG = renderTileSheet(core, pal: pal, palBase: 0x00, count: PATTERN_TILES, perRow: TILES_PER_ROW).scaled(TILE_SCALE)
    let sheetSP = renderTileSheet(core, pal: pal, palBase: 0x10, count: PATTERN_TILES, perRow: TILES_PER_ROW).scaled(TILE_SCALE)
    writePNG(sheetBG, to: "\(zdir)/tiles.png")
    writePNG(sheetSP, to: "\(zdir)/tiles_sprite.png")
    totalFiles += 2
    // Non-blank check: count distinct non-zero pixels in the bg sheet.
    var nonZeroPixels = 0
    var pi = 0
    while pi < sheetBG.px.count { if sheetBG.px[pi] != 0 || sheetBG.px[pi+1] != 0 || sheetBG.px[pi+2] != 0 { nonZeroPixels += 1 }; pi += 4 }
    manifest.append("  tiles.png        \(sheetBG.w)×\(sheetBG.h)  (\(PATTERN_TILES) tiles, \(TILES_PER_ROW)/row, bg palette; non-black px=\(nonZeroPixels))")
    manifest.append("  tiles_sprite.png \(sheetSP.w)×\(sheetSP.h)  (same tiles, sprite palette)")

    // 3) background.png
    let bg = renderBackground(core, pal: pal, base: ntBase, cols: NT_COLS, rows: NT_ROWS).scaled(BG_SCALE)
    writePNG(bg, to: "\(zdir)/background.png")
    totalFiles += 1
    var bgNonZero = 0
    var bi = 0
    while bi < bg.px.count { if bg.px[bi] != 0 || bg.px[bi+1] != 0 || bg.px[bi+2] != 0 { bgNonZero += 1 }; bi += 4 }
    manifest.append("  background.png   \(bg.w)×\(bg.h)  (name-table \(NT_COLS)×\(NT_ROWS); non-black px=\(bgNonZero))")

    // 4) sprites/<romTypeHex>-<name>.png
    let specs = spriteSpecs[zone.variant] ?? []
    var okSprites = 0, blankSprites = 0
    for spec in specs {
        guard let comp = composeSprite(core, frame: spec.frame, pal: pal) else {
            notesLines.append("\(zone.name) 0x\(hexByte(spec.romType)) \(spec.name): descriptor empty (frame 0x\(hexByte(spec.frame))) — UNRESOLVED")
            continue
        }
        let scaled = comp.canvas.scaled(SPRITE_SCALE)
        let fname = "\(hexByte(spec.romType))-\(spec.name).png"
        writePNG(scaled, to: "\(zdir)/sprites/\(fname)")
        totalFiles += 1
        let tilesHex = comp.tiles.map { "0x\(hexByte($0))" }.joined(separator: ",")
        let flag = comp.nonBlank ? "" : "  ⚠️ BLANK (tiles resolved transparent)"
        manifest.append("  sprites/\(fname)  \(scaled.w)×\(scaled.h) (native \(comp.canvas.w)×\(comp.canvas.h); frame 0x\(hexByte(spec.frame)); tiles \(tilesHex))\(flag)")
        if comp.nonBlank { okSprites += 1 } else {
            blankSprites += 1
            notesLines.append("\(zone.name) 0x\(hexByte(spec.romType)) \(spec.name): frame 0x\(hexByte(spec.frame)) composed only transparent pixels (tiles \(tilesHex)) — likely an animation/boss frame pointing at VRAM tile 0")
        }
    }
    manifest.append("  sprites: \(okSprites) rendered, \(blankSprites) blank/degenerate (of \(specs.count) specs)")
    manifest.append("")
}

manifest.append("TOTAL FILES WRITTEN: \(totalFiles) (under \(outRoot))")
if notesLines.isEmpty { notesLines.append("all sprite descriptors resolved to non-blank metasprites") }
let manifestText = manifest.joined(separator: "\n") + "\n"
try? manifestText.write(toFile: "\(outRoot)/manifest.txt", atomically: true, encoding: .utf8)

// Echo to stdout so the harness/log captures the run.
print(manifestText)
print("── palettes ──")
print(palettesSummary.joined(separator: "\n"))
print("── notes ──")
print(notesLines.joined(separator: "\n"))
