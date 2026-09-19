import Testing
@testable import GameSim

// Wave 3a — the ADDITIVE stage-warp hook that lets ParityScore measure Asteroid/Nebula.
// World.setZone / Campaign.setZone jump straight to a zone (loop 0) before play begins. These
// lock two properties: (1) the mapping/clamping is correct, and (2) zone 0 (Galaxy) is a strict
// no-op, so no default schedule/behavior changes — the whole point of "additive".
struct StageWarpTests {

    // Run a fresh world (optionally warped) for `n` playing frames and record the per-frame
    // entity count — a compact fingerprint of the spawn schedule under a fixed input.
    private func trajectory(zone: Int?, frames: Int, fire: Bool = true) -> [Int] {
        let w = World()
        if let z = zone { w.setZone(z) }
        w.step(Intent(fire: true))                 // title → playing
        var counts: [Int] = []
        for _ in 0..<frames {
            w.step(Intent(fire: fire))
            counts.append(w.entities.count)
        }
        return counts
    }

    @Test func defaultWorldIsGalaxy() {
        #expect(World().campaign.current.id == .galaxy)
    }

    @Test func setZoneSelectsTheRightLevel() {
        let g = World(); g.setZone(0); #expect(g.campaign.current.id == .galaxy)
        let a = World(); a.setZone(1); #expect(a.campaign.current.id == .asteroid)
        let n = World(); n.setZone(2); #expect(n.campaign.current.id == .nebula)
    }

    @Test func setZoneClampsOutOfRange() {
        let lo = World(); lo.setZone(-5); #expect(lo.campaign.current.id == .galaxy)
        let hi = World(); hi.setZone(99); #expect(hi.campaign.current.id == .nebula)   // last zone
    }

    // ADDITIVITY: warping to zone 0 must be byte-for-byte identical to never warping at all.
    @Test func zoneZeroIsANoOpForGalaxy() {
        #expect(trajectory(zone: nil, frames: 300) == trajectory(zone: 0, frames: 300))
    }

    // The warp actually re-arms the director: a different zone runs a DIFFERENT schedule off the
    // same input, so its spawn fingerprint diverges from Galaxy's (proves setZone did something).
    @Test func warpChangesTheSchedule() {
        let galaxy = trajectory(zone: 0, frames: 300)
        let asteroid = trajectory(zone: 1, frames: 300)
        let nebula = trajectory(zone: 2, frames: 300)
        #expect(galaxy != asteroid)
        #expect(galaxy != nebula)
        #expect(asteroid.contains { $0 > 0 })      // asteroid actually spawns something
    }
}
