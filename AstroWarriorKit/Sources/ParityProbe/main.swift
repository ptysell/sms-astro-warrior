import Foundation
import ReferenceEmu

let romPath = "/Users/ptysell/Code/astro-warrior/docs/AstroWarrior.sms"
guard let data = try? Data(contentsOf: URL(fileURLWithPath: romPath)) else { fputs("no rom\n", stderr); exit(1) }
let core = SMSPlusCore()
guard core.load(rom: data) else { fputs("load failed\n", stderr); exit(1) }

@MainActor func run(_ b: RefButtons, _ n: Int) { for _ in 0..<n { core.step(buttons: b, pause: false) } }
@MainActor func tap(_ b: RefButtons) { run(b, 5); run([], 8) }
@MainActor func ram(_ a: Int) -> Int { Int(core.readRAM(a)) }
// Empirically: ship X = 8.8 word @0xC60A(lo)/0xC60B(hi); ship Y = 8.8 word @0xC608/0xC609.
@MainActor func shipX() -> Double { Double(ram(0xC60A) | (ram(0xC60B) << 8)) / 256.0 }
@MainActor func shipY() -> Double { Double(ram(0xC608) | (ram(0xC609) << 8)) / 256.0 }

run([], 300); tap(.fire); run([], 240)          // into gameplay
print(String(format: "start pos: X=%.2f  Y=%.2f", shipX(), shipY()))

@MainActor func speed(_ dir: RefButtons, _ read: @MainActor () -> Double, _ frames: Int) -> Double {
    let s = read(); run(dir, frames); let e = read()
    return (e - s) / Double(frames)
}
let right = speed(.right, shipX, 20); run([.left], 20)
let left  = -speed(.left, shipX, 20); run([.right], 20)
let up    = -speed(.up, shipY, 20);   run([.down], 20)
let down  = speed(.down, shipY, 20);  run([.up], 20)

print(String(format: "\nMEASURED base ship speed (px/frame):"))
print(String(format: "  right=%.3f  left=%.3f  up=%.3f  down=%.3f", right, left, up, down))
print(String(format: "  => horizontal ≈ %.2f, vertical ≈ %.2f px/frame", (right + left) / 2, (up + down) / 2))
