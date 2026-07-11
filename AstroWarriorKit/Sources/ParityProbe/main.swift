import Foundation
import ReferenceEmu

// Measure player fire cadence + bullet speed from the ROM.
let romPath = "/Users/ptysell/Code/astro-warrior/docs/AstroWarrior.sms"
guard let data = try? Data(contentsOf: URL(fileURLWithPath: romPath)) else { fputs("no rom\n", stderr); exit(1) }
let core = SMSPlusCore()
guard core.load(rom: data) else { fputs("load failed\n", stderr); exit(1) }

@MainActor func run(_ b: RefButtons, _ n: Int) { for _ in 0..<n { core.step(buttons: b, pause: false) } }
@MainActor func ram(_ a: Int) -> Int { Int(core.readRAM(a)) }
@MainActor func word(_ a: Int) -> Int { ram(a) | (ram(a + 1) << 8) }         // 16-bit LE (Int-safe)

// Entity pool: 40 slots × 0x40 from 0xC600. Per measured layout: +0x00 type, +0x08 Y(8.8), +0x0A X(8.8).
let slots = Array(stride(from: 0xC600, to: 0xD000, by: 0x40))
@MainActor func slotY(_ s: Int) -> Double { Double(word(s + 8)) / 256.0 }
@MainActor func slotX(_ s: Int) -> Double { Double(word(s + 0x0A)) / 256.0 }
@MainActor func active(_ s: Int) -> Bool { ram(s) != 0 }

// Boot to gameplay, settle.
run([], 300); run(.fire, 5); run([], 8); run([], 120)
print(String(format: "ship at (%.0f,%.0f)", slotX(0xC600), slotY(0xC600)))

// --- Bullet speed: fire one shot, follow the fastest upward mover ---
var prev = slots.map { slotY($0) }
run(.fire, 3); run([], 1)
var bulletSlot = -1, bestSpeed = 0.0
for _ in 0..<14 {
    run([], 1)
    for (i, s) in slots.enumerated() where s != 0xC600 {
        let y = slotY(s); let dy = y - prev[i]                 // negative = moving up
        if active(s), y > 2, y < 150, -dy > bestSpeed { bestSpeed = -dy; bulletSlot = s }
        prev[i] = y
    }
}
print(String(format: "bullet slot 0x%04X  speed ≈ %.2f px/frame (up)", bulletSlot, bestSpeed))

// --- Fire cadence: hold fire, count spawns (slots entering the ship's Y band) ---
run([], 60)                                                    // clear existing bullets
let shipY = slotY(0xC600)
var wasAtShip = Set<Int>(), spawnFrames: [Int] = []
for f in 0..<180 {
    run(.fire, 1)
    for s in slots where s != 0xC600 {
        let atShip = active(s) && abs(slotY(s) - shipY) < 8
        if atShip && !wasAtShip.contains(s) { spawnFrames.append(f); wasAtShip.insert(s) }
        if !atShip { wasAtShip.remove(s) }
    }
}
let gaps = zip(spawnFrames.dropFirst(), spawnFrames).map { $0 - $1 }
let avg = gaps.isEmpty ? 0 : Double(gaps.reduce(0, +)) / Double(gaps.count)
print("spawns at frames: \(spawnFrames.prefix(12))")
print(String(format: "fire cadence ≈ %.1f frames between shots (gaps: \(gaps.prefix(10)))", avg))
