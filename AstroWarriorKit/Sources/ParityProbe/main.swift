import Foundation
import ReferenceEmu

// Classify every ROM entity type by its MOTION signature over a survival run:
//   player bullet = up fast · enemy bullet = down fast · enemy = slow/weave · power-up = down centre.
let romPath = "/Users/ptysell/Code/astro-warrior/docs/AstroWarrior.sms"
guard let data = try? Data(contentsOf: URL(fileURLWithPath: romPath)) else { fputs("no rom\n", stderr); exit(1) }
let core = SMSPlusCore()
guard core.load(rom: data) else { fputs("load failed\n", stderr); exit(1) }

@MainActor func run(_ b: RefButtons, _ n: Int) { for _ in 0..<n { core.step(buttons: b, pause: false) } }
@MainActor func ram(_ a: Int) -> Int { Int(core.readRAM(a)) }
@MainActor func word(_ a: Int) -> Int { ram(a) | (ram(a + 1) << 8) }
let slots = Array(stride(from: 0xC600, to: 0xD000, by: 0x40))

struct Stat { var n = 0; var sumDy = 0.0, sumDx = 0.0, sumX = 0.0, minY = 999.0, maxY = -999.0 }
var stats = [Int: Stat]()
var prevType = [Int: Int](), prevX = [Int: Double](), prevY = [Int: Double]()

@MainActor func observe() {
    for s in slots {
        let t = ram(s)
        let x = Double(word(s + 0x0A)) / 256.0, y = Double(word(s + 0x08)) / 256.0
        if t != 0, t == prevType[s] {                     // same entity persisted → real motion
            var st = stats[t] ?? Stat()
            st.n += 1; st.sumDy += y - (prevY[s] ?? y); st.sumDx += abs(x - (prevX[s] ?? x))
            st.sumX += x; st.minY = min(st.minY, y); st.maxY = max(st.maxY, y)
            stats[t] = st
        }
        prevType[s] = t; prevX[s] = x; prevY[s] = y
    }
}

// Boot, then fly a survival pattern (weave + fire) for a good while.
run([], 300); run(.fire, 5); run([], 8); run([], 60)
// Stay central-ish (small weave) so shooters can aim + fire; re-tap Start if we die.
let pattern: [RefButtons] = [[.left, .fire], [.right, .fire], [.left, .fire], [.right, .fire]]
for cycle in 0..<150 {
    if ram(0xC600) != 1 { run(.fire, 5); run([], 20) }    // player gone → restart/continue
    let input = pattern[cycle % pattern.count]
    for _ in 0..<20 { run(input, 1); observe() }
}

print("type  count  avgDy   |dx|   avgX   yRange     signature")
for (t, s) in stats.sorted(by: { $0.key < $1.key }) where s.n > 6 {
    let avgDy = s.sumDy / Double(s.n), adx = s.sumDx / Double(s.n), avgX = s.sumX / Double(s.n)
    let sig: String
    if avgDy < -3 { sig = "▲ up-fast  → PLAYER BULLET" }
    else if avgDy > 3 { sig = "▼ down-fast → ENEMY BULLET" }
    else if abs(avgDy) < 0.2 && adx < 0.2 { sig = "· static → fx/ui" }
    else { sig = "≈ slow/weave → ENEMY" }
    print(String(format: "t%-3d %5d  %+5.2f  %5.2f  %5.0f  %3.0f-%-3.0f  %@",
                 t, s.n, avgDy, adx, avgX, s.minY, s.maxY, sig as NSString))
}
