import Testing
@testable import GameSim

// Headless sanity over the pure sim (§13). Golden-replay + tuning-regression land later (I4).
struct SimSmokeTests {
    @Test func worldBoots() {
        let w = World()
        #expect(w.mode == .title)
        #expect(w.lives == Tuning.startingLives)
    }

    @Test func titleStartsOnFire() {
        let w = World()
        w.step(Intent(fire: true))          // title → playing
        #expect(w.mode == .playing)
    }

    @Test func deterministicRNG() {
        var a = RNG(seed: 0xA57E)
        var b = RNG(seed: 0xA57E)
        #expect(a.next() == b.next())
    }

    @Test func scoreTracksHiScore() {
        let w = World()
        w.step(Intent(fire: true))          // enter playing
        for _ in 0..<120 { w.step(Intent(fire: true)) }
        #expect(w.hiScore >= w.score - 1)   // hiScore never below score
    }
}
