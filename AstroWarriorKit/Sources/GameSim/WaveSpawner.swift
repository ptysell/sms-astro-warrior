import Foundation

// Streams a wave's members into the World, laid out in formation (§5.8).
// A WaveCue hands the director a Wave; the director calls World.spawn, which enqueues here.
//
// Emission model (matched to the ROM, docs/parity-findings.md §4b/§4c/§4e):
//   • FLIGHT-SCRIPT STREAM (type 0x18 sharlin — the only true ROM "stream" type; identified here
//     by carrying a decoded `pathIndex`): the ROM spawns ALL N members AT ONCE, stacked at the
//     wave's centre X, and staggers each member's MOVEMENT release by record +0x15 = ordinal×interval
//     (8,16,…). So the field holds all N from the wave's first frame; we emit them together and set
//     each member's `releaseDelay`. (Previously we staggered EMISSION, which under-populated the
//     stream region to ~1 early — the real DIVERGENCE driver.)
//   • every other wave (lines, and the zanix/kyra `.stream` best-fits, which are ROM LINE-type
//     records) — members emit `interval` ticks apart (interval 0 = all at once), as before.
final class WaveSpawner {
    private struct Pending {
        let wave: Wave
        let baseX: Double        // formation anchor (screen-relative x)
        var index = 0
        var timer = 0.0
    }
    private var pending: [Pending] = []

    func enqueue(_ wave: Wave, baseX: Double) {
        pending.append(Pending(wave: wave, baseX: baseX))
    }

    func reset() { pending.removeAll() }

    // A genuine ROM stream (type 0x18 sharlin): stacked spawn + per-member movement-release stagger.
    private func isFlightStream(_ w: Wave) -> Bool { w.formation == .stream && w.pathIndex != nil }

    func update(_ world: World, _ ctx: SimContext) {
        for i in pending.indices {
            if pending[i].timer > 0 { pending[i].timer -= 1 }
            // Flight-script stream members all spawn on the same frame (stacked); everything else
            // keeps the emission stagger (interval 0 = all at once).
            let emitInterval = isFlightStream(pending[i].wave) ? 0.0 : pending[i].wave.interval
            while pending[i].index < pending[i].wave.count, pending[i].timer <= 0 {
                emit(pending[i], into: world)
                pending[i].index += 1
                pending[i].timer += emitInterval
            }
        }
        pending.removeAll { $0.index >= $0.wave.count }
    }

    private func emit(_ p: Pending, into world: World) {
        let e = p.wave.make()
        let pos = Self.position(p.wave.formation, i: p.index, count: p.wave.count, baseX: p.baseX)
        e.position = pos
        e.anchorX = pos.x
        if isFlightStream(p.wave) {
            // ROM +0x15: member ordinal (i, 0-based) → movement-release stagger (i+1)·interval frames.
            e.releaseDelay = Int((Double(p.index) + 1) * p.wave.interval)
        }
        // ROM +0x13: stamp the wave's decoded flight-script index onto every member (sharlin).
        if let path = p.wave.pathIndex { e.flightPathIndex = path }
        world.add(e)
    }

    // Entry position for member `i` of `count` in a formation. Members enter above the
    // field (y > LOGICAL_HEIGHT) and their movement behavior carries them down.
    static func position(_ f: Formation, i: Int, count: Int, baseX: Double) -> Vec2 {
        let topY = LOGICAL_HEIGHT + 8
        let n = max(1, count)
        let t = n == 1 ? 0.5 : Double(i) / Double(n - 1)      // 0…1 across the wave
        func clampX(_ x: Double, _ margin: Double) -> Double {
            min(max(x, margin), LOGICAL_WIDTH - margin)
        }
        switch f {
        case .line:                                           // a fixed-spacing row centered on baseX
            // MEASURED (Galaxy "Cult" waves): members enter in a flat horizontal row ~32 px apart,
            // centered on the scripted anchor — not spread across the whole width.
            let spacing = 32.0
            let center = Double(n - 1) / 2
            return Vec2(clampX(baseX + (Double(i) - center) * spacing, 16), topY)
        case .stream:                                         // single column, staggered in time
            return Vec2(clampX(baseX, 20), topY)
        case .vee:                                            // a V — edges lead, center trails
            let center = Double(n - 1) / 2
            let dx = Double(i) - center
            return Vec2(clampX(baseX + dx * 22, 20), topY + abs(dx) * 10)
        case .arc:                                            // shallow arc
            let a = (t - 0.5) * .pi * 0.9
            return Vec2(clampX(baseX + sin(a) * 90, 20), topY + (1 - cos(a)) * 34)
        }
    }
}
