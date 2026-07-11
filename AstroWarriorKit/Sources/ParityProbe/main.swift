import Foundation
import GameSim
import GameInput
import ReferenceEmu

// Parity verify: push the ship into every wall and confirm ROM vs our sim clamp identically.
let romPath = "/Users/ptysell/Code/astro-warrior/docs/AstroWarrior.sms"
guard let data = try? Data(contentsOf: URL(fileURLWithPath: romPath)) else { fputs("no rom\n", stderr); exit(1) }
let core = SMSPlusCore()
guard core.load(rom: data) else { fputs("load failed\n", stderr); exit(1) }

@MainActor func run(_ b: RefButtons, _ n: Int) { for _ in 0..<n { core.step(buttons: b, pause: false) } }
@MainActor func romX() -> Double { Double(Int(core.readRAM(0xC60A)) | (Int(core.readRAM(0xC60B)) << 8)) / 256.0 }
@MainActor func romY() -> Double { Double(Int(core.readRAM(0xC608)) | (Int(core.readRAM(0xC609)) << 8)) / 256.0 }

// A plan that holds each direction long enough to reach the walls.
func plan(_ f: Int) -> Set<PadButton> {
    var s: Set<PadButton> = [.button1]
    switch (f / 90) % 4 {
    case 0: s.insert(.right)
    case 1: s.insert(.left)
    case 2: s.insert(.up)
    default: s.insert(.down)
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

run([], 300); run(.fire, 5); run([], 8); run([], 120)      // ROM gameplay
let world = World(); world.step(Intent(fire: true))        // our sim → playing

var sumDX = 0.0, sumDY = 0.0, maxDX = 0.0, maxDY = 0.0, n = 0
for f in 0..<360 {
    let pad = plan(f)
    core.step(buttons: toRef(pad), pause: false)
    world.player.update(SimContext(world: world, intent: Intent(moveAxis: pad.axis, fire: true)))
    let dx = world.player.position.x - romX()
    let dy = (LOGICAL_HEIGHT - world.player.position.y) - romY()
    sumDX += abs(dx); sumDY += abs(dy); maxDX = max(maxDX, abs(dx)); maxDY = max(maxDY, abs(dy)); n += 1
    if f % 89 == 0 {
        print(String(format: "f%3d  romX %.0f ourX %.0f (Δ%+.1f) | romY %.0f ourY %.0f (Δ%+.1f)",
                     f, romX(), world.player.position.x, dx, romY(), LOGICAL_HEIGHT - world.player.position.y, dy))
    }
}
print(String(format: "\nwith measured bounds:  mean|Δx|=%.2f max=%.2f   mean|Δy|=%.2f max=%.2f",
             sumDX / Double(n), maxDX, sumDY / Double(n), maxDY))
