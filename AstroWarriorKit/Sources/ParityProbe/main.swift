import Foundation
import ReferenceEmu

// Discover the ROM entity pool: which type bytes are player / bullets / enemies / power-ups.
let romPath = "/Users/ptysell/Code/astro-warrior/docs/AstroWarrior.sms"
guard let data = try? Data(contentsOf: URL(fileURLWithPath: romPath)) else { fputs("no rom\n", stderr); exit(1) }
let core = SMSPlusCore()
guard core.load(rom: data) else { fputs("load failed\n", stderr); exit(1) }

@MainActor func run(_ b: RefButtons, _ n: Int) { for _ in 0..<n { core.step(buttons: b, pause: false) } }
@MainActor func ram(_ a: Int) -> Int { Int(core.readRAM(a)) }
@MainActor func word(_ a: Int) -> Int { ram(a) | (ram(a + 1) << 8) }

let slots = Array(stride(from: 0xC600, to: 0xD000, by: 0x40))   // 40-slot pool
@MainActor func dumpPool(_ label: String) {
    print("\n── \(label) ──  (slot: type  X,Y)")
    var hist = [Int: Int]()
    for s in slots where ram(s) != 0 {
        let t = ram(s), x = word(s + 0x0A) / 256, y = word(s + 0x08) / 256
        hist[t, default: 0] += 1
        print(String(format: "  0x%04X: type=%2d  (%3d,%3d)", s, t, x, y))
    }
    let h = hist.sorted { $0.key < $1.key }.map { "t\($0.key)×\($0.value)" }.joined(separator: " ")
    print("  types: \(h)")
}

// Boot to gameplay.
run([], 300); run(.fire, 5); run([], 8); run([], 60)
dumpPool("just started (ship only)")

run(.fire, 4); run([], 2)
dumpPool("after firing (bullet appears)")

// Survive a while so enemies spawn; weave + fire.
for k in 0..<8 { run(k % 2 == 0 ? [.right, .fire] : [.left, .fire], 30) }
dumpPool("mid-wave (enemies present)")

run([], 200)
dumpPool("later")
