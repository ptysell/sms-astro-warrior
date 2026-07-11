import Foundation

// Streams a wave's members into the World over time, laid out in formation (§5.8).
// A WaveCue hands the director a Wave; the director calls World.spawn, which enqueues
// here. Members then emit `interval` ticks apart (interval 0 = all at once).
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

    func update(_ world: World, _ ctx: SimContext) {
        for i in pending.indices {
            if pending[i].timer > 0 { pending[i].timer -= 1 }
            while pending[i].index < pending[i].wave.count, pending[i].timer <= 0 {
                emit(pending[i], into: world)
                pending[i].index += 1
                pending[i].timer += pending[i].wave.interval
            }
        }
        pending.removeAll { $0.index >= $0.wave.count }
    }

    private func emit(_ p: Pending, into world: World) {
        let e = p.wave.make()
        let pos = Self.position(p.wave.formation, i: p.index, count: p.wave.count, baseX: p.baseX)
        e.position = pos
        e.anchorX = pos.x
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
        case .line:                                           // spread across the top at once
            return Vec2(40 + t * (LOGICAL_WIDTH - 80), topY)
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
