import Foundation
import ReferenceEmu

// Find the ROM score address: over a kill-heavy run, score bytes never decrease
// (BCD low bytes wrap, so the meaningful score byte is monotonic non-decreasing).
let romPath = "/Users/ptysell/Code/astro-warrior/docs/AstroWarrior.sms"
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

@MainActor func dodge() -> RefButtons {
    let px = wX(0xC600), py = wY(0xC600)
    var threatX: Double? = nil, best = 1e9
    for s in slots {
        let t = ram(s); if t == 0 || t == 1 || t == 2 || t == 18 || isFX(t) { continue }
        let ex = wX(s), ey = wY(s), dy = py - ey
        if dy > -24, dy < 90 { let d = abs(ex - px) + dy * 0.25; if d < best { best = d; threatX = ex } }
    }
    var b: RefButtons = [.fire]
    if let tx = threatX { b.insert(tx > px ? .left : .right) }
    if py < 150 { b.insert(.down) } else if py > 176 { b.insert(.up) }
    if px < 40 { b.remove(.left); b.insert(.right) }
    if px > 216 { b.remove(.right); b.insert(.left) }
    return b
}

run([], 300); run(.fire, 5); run([], 8); run([], 40)

let base = (0..<0x2000).map { ram(0xC000 + $0) }
var decreased = [Bool](repeating: false, count: 0x2000)
var prev = base
for _ in 0..<4000 {
    if ram(0xC600) != 1 { run(.fire, 5); run([], 24); continue }
    step(dodge())
    for i in 0..<0x2000 {
        let v = ram(0xC000 + i)
        if v < prev[i] { decreased[i] = true }
        prev[i] = v
    }
}
print("score-byte candidates (never decreased, grew ≥16):")
for i in 0..<0x2000 where !decreased[i] && (prev[i] - base[i]) >= 16 {
    print(String(format: "  0x%04X : %d -> %d", 0xC000 + i, base[i], prev[i]))
}
