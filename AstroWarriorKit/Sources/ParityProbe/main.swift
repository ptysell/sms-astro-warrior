import Foundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers
import ReferenceEmu

// Classification pass: a dodging AI bot survives deep into Stage 1 while we catalog every
// entity type (first-seen frame, position, motion) and snapshot each for sprite ID.
let romPath = "/Users/ptysell/Code/astro-warrior/docs/AstroWarrior.sms"
let outDir = "/private/tmp/claude-501/-Users-ptysell-Code-astro-warrior/37163801-53f4-48ad-8fff-1bf95f8caba9/scratchpad"
guard let data = try? Data(contentsOf: URL(fileURLWithPath: romPath)) else { fputs("no rom\n", stderr); exit(1) }
let core = SMSPlusCore()
guard core.load(rom: data) else { fputs("load failed\n", stderr); exit(1) }

@MainActor func step(_ b: RefButtons) { core.step(buttons: b, pause: false) }
@MainActor func run(_ b: RefButtons, _ n: Int) { for _ in 0..<n { step(b) } }
@MainActor func ram(_ a: Int) -> Int { Int(core.readRAM(a)) }
@MainActor func wX(_ s: Int) -> Double { Double(ram(s + 0x0A) | (ram(s + 0x0B) << 8)) / 256.0 }
@MainActor func wY(_ s: Int) -> Double { Double(ram(s + 0x08) | (ram(s + 0x09) << 8)) / 256.0 }
let slots = Array(stride(from: 0xC600, to: 0xD000, by: 0x40))
func isFX(_ t: Int) -> Bool { t == 11 || t == 12 || t == 19 }

@MainActor func dump(_ name: String) {
    guard let img = core.frame else { return }
    let url = URL(fileURLWithPath: "\(outDir)/\(name).png") as CFURL
    if let d = CGImageDestinationCreateWithURL(url, UTType.png.identifier as CFString, 1, nil) {
        CGImageDestinationAddImage(d, img, nil); CGImageDestinationFinalize(d)
    }
}

// Simple dodging AI: stay near the bottom, slide away from the nearest threat above.
@MainActor func dodge() -> RefButtons {
    let px = wX(0xC600), py = wY(0xC600)
    var threatX: Double? = nil, best = 1e9
    for s in slots {
        let t = ram(s); if t == 0 || t == 1 || t == 2 || isFX(t) { continue }
        let ex = wX(s), ey = wY(s), dy = py - ey             // dy>0 → above the ship
        if dy > -24, dy < 90 { let d = abs(ex - px) + dy * 0.25; if d < best { best = d; threatX = ex } }
    }
    var b: RefButtons = [.fire]
    if let tx = threatX { b.insert(tx > px ? .left : .right) }
    if py < 150 { b.insert(.down) } else if py > 176 { b.insert(.up) }
    if px < 40 { b.remove(.left); b.insert(.right) }
    if px > 216 { b.remove(.right); b.insert(.left) }
    return b
}

// Motion accumulation for signatures.
struct Stat { var n = 0; var sumDy = 0.0, sumDx = 0.0, sumX = 0.0, minY = 1e9, maxY = -1e9 }
var stats = [Int: Stat](), prevT = [Int: Int](), prevX = [Int: Double](), prevY = [Int: Double]()
var firstSeen = [Int: (f: Int, x: Double, y: Double)]()

run([], 300); run(.fire, 5); run([], 8); run([], 40)       // into gameplay
for f in 0..<9000 {                                        // ~150s of survival
    if ram(0xC600) != 1 { run(.fire, 5); run([], 24); continue }   // died → continue
    step(dodge())
    for s in slots {
        let t = ram(s), x = wX(s), y = wY(s)
        if t != 0, t == prevT[s] {
            var st = stats[t] ?? Stat()
            st.n += 1; st.sumDy += y - (prevY[s] ?? y); st.sumDx += abs(x - (prevX[s] ?? x))
            st.sumX += x; st.minY = min(st.minY, y); st.maxY = max(st.maxY, y); stats[t] = st
        }
        if t != 0, firstSeen[t] == nil, y > 16, y < 176 {  // first clear sighting → snapshot
            firstSeen[t] = (f, x, y); dump(String(format: "type_%02d", t))
        }
        prevT[s] = t; prevX[s] = x; prevY[s] = y
    }
}

print("\nCATALOG — type : firstFrame  firstPos   count  avgDy  |dx|  avgX  yRange")
for (t, fs) in firstSeen.sorted(by: { $0.key < $1.key }) {
    let s = stats[t] ?? Stat()
    let ady = s.n > 0 ? s.sumDy / Double(s.n) : 0, adx = s.n > 0 ? s.sumDx / Double(s.n) : 0
    let ax = s.n > 0 ? s.sumX / Double(s.n) : 0
    print(String(format: "t%-3d : f%-5d (%3.0f,%3.0f)  n=%-5d %+5.2f %5.2f %4.0f  %3.0f-%-3.0f  -> type_%02d.png",
                 t, fs.f, fs.x, fs.y, s.n, ady, adx, ax, s.minY, s.maxY, t))
}
