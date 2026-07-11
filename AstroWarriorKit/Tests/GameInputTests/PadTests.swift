import Testing
import Foundation
import GameSim
@testable import GameInput

struct PadTests {
    @Test func defaultBindings() {
        let b = KeyBindings.defaults
        #expect(b.button(forToken: "leftArrow") == .left)
        #expect(b.button(forToken: "rightArrow") == .right)
        #expect(b.button(forToken: "z") == .button1)
        #expect(b.button(forToken: "x") == .button2)
        #expect(b.button(forToken: "q") == .pause)
        #expect(b.button(forToken: "w") == .reset)
        #expect(b.button(forToken: "k") == nil)     // unbound
    }

    @Test func axisFromPad() {
        #expect(Set<PadButton>([.up, .right]).axis == Vec2(1, 1))
        #expect(Set<PadButton>([.left]).axis == Vec2(-1, 0))
        #expect(Set<PadButton>([.up, .down]).axis == Vec2(0, 0))   // opposing cancels
        #expect(Set<PadButton>().axis == Vec2(0, 0))
    }

    @Test func bindingsAreCodable() throws {
        let data = try JSONEncoder().encode(KeyBindings.defaults)
        let round = try JSONDecoder().decode(KeyBindings.self, from: data)
        #expect(round == KeyBindings.defaults)      // survives persistence (Settings later)
    }
}
