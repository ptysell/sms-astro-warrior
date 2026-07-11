import Foundation
import GameSim
import GameInput
import ReferenceEmu

// PARITY BOT: a deterministic flight plan plays both the ROM and our sim with the SAME
// input each frame; we diff the ship position (ROM RAM vs our sim) to find divergences.
let romPath = "/Users/ptysell/Code/astro-warrior/docs/AstroWarrior.sms"
guard let data = try? Data(contentsOf: URL(fileURLWithPath: romPath)) else { fputs("no rom\n", stderr); exit(1) }
let core = SMSPlusCore()
guard core.load(rom: data) else { fputs("load failed\n", stderr); exit(1) }

@MainActor func run(_ b: RefButtons, _ n: Int) { for _ in 0..<n { core.step(buttons: b, pause: false) } }
@MainActor func romX() -> Double { Double(Int(core.readRAM(0xC60A)) | (Int(core.readRAM(0xC60B)) << 8)) / 256.0 }
@MainActor func romY() -> Double { Double(Int(core.readRAM(0xC608)) | (Int(core.readRAM(0xC609)) << 8)) / 256.0 }

// The bot's canonical output is a set of pad buttons; both cores derive their input from it.
func botPlan(_ f: Int) -> Set<PadButton> {
    var s: Set<PadButton> = [.button1]                 // always firing
    switch (f / 45) % 8 {
    case 0: s.insert(.right)
    case 1: s.insert(.left)
    case 2: s.insert(.up)
    case 3: s.insert(.down)
    case 4: s.formUnion([.up, .right])
    case 5: s.formUnion([.down, .left])
    case 6: s.formUnion([.up, .left])
    default: break                                     // idle
    }
    return s
}
func toRef(_ s: Set<PadButton>) -> RefButtons {
    var r: RefButtons = []
    if s.contains(.up) { r.insert(.up) }; if s.contains(.down) { r.insert(.down) }
    if s.contains(.left) { r.insert(.left) }; if s.contains(.right) { r.insert(.right) }
    if s.contains(.button1) { r.insert(.fire) }
    return r
}

// Boot ROM to gameplay.
run([], 300); run(.fire, 5); run([], 8); run([], 240)
print(String(format: "post-boot: shipBytes 0xC608..B = %d %d %d %d  frameCtr@C286=%d",
             core.readRAM(0xC608), core.readRAM(0xC609), core.readRAM(0xC60A), core.readRAM(0xC60B), core.readRAM(0xC286)))

// Our sim, player isolated (no enemies/collision) so we compare pure ship kinematics.
let world = World()
world.step(Intent(fire: true))                          // title → playing

print("frame | romX  ourX   Δx | romY  ourYs  Δy   (ourYs = our y mapped to screen)")
var sumDX = 0.0, sumDY = 0.0, maxDX = 0.0, maxDY = 0.0, n = 0
for f in 0..<315 {
    let pad = botPlan(f)
    core.step(buttons: toRef(pad), pause: false)
    let ctx = SimContext(world: world, intent: Intent(moveAxis: pad.axis, fire: true))
    world.player.update(ctx)

    let rx = romX(), ry = romY()
    let ox = world.player.position.x
    let oys = LOGICAL_HEIGHT - world.player.position.y   // our +Y-up → screen coords
    let dx = ox - rx, dy = oys - ry
    sumDX += abs(dx); sumDY += abs(dy); maxDX = max(maxDX, abs(dx)); maxDY = max(maxDY, abs(dy)); n += 1
    if f % 45 == 0 || f == 314 {
        print(String(format: "%5d | %5.1f %5.1f %+5.1f | %5.1f %5.1f %+5.1f", f, rx, ox, dx, ry, oys, dy))
    }
}
print(String(format: "\nmean |Δx|=%.2f  max|Δx|=%.2f   mean |Δy|=%.2f  max|Δy|=%.2f", sumDX/Double(n), maxDX, sumDY/Double(n), maxDY))
