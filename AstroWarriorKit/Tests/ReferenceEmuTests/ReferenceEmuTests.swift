import Testing
import Foundation
import CoreGraphics
@testable import ReferenceEmu

// Verifies the vendored SMS core actually runs the ROM and renders a real frame.
// The ROM is gitignored, so this no-ops gracefully when it isn't present locally.
// SERIALIZED: the C core is a singleton (global sms/cart/bitmap), so its tests must
// not run concurrently or they clobber each other's state.
@Suite(.serialized)
struct ReferenceEmuTests {

    private func romURL() -> URL? {
        // .../AstroWarriorKit/Tests/ReferenceEmuTests/<file> → repo root → docs/
        var root = URL(fileURLWithPath: #filePath)
        for _ in 0..<4 { root.deleteLastPathComponent() }
        let url = root.appendingPathComponent("docs/AstroWarrior.sms")
        return FileManager.default.fileExists(atPath: url.path) ? url : nil
    }

    @Test func emulatorBootsAndRenders() throws {
        guard let url = romURL(), let data = try? Data(contentsOf: url) else { return }
        let core = SMSPlusCore()
        #expect(core.load(rom: data))
        for _ in 0..<300 { core.step(buttons: [.fire], pause: false) }   // boot past title
        let img = try #require(core.frame)
        #expect(img.width == 256 && img.height == 192)
        #expect(distinctColors(img) > 1)                                 // rendered something
    }

    // Same input from reset ⇒ identical state. This is what makes replay-based parity valid.
    @Test func deterministicReplay() throws {
        guard let url = romURL(), let data = try? Data(contentsOf: url) else { return }
        let core = SMSPlusCore()
        #expect(core.load(rom: data))
        let addrs = [0xC608, 0xC609, 0xC60A, 0xC60B, 0xC01C]   // ship X/Y + frame counter
        func run() -> [UInt8] {
            core.reset()
            for i in 0..<240 {
                let b: RefButtons = (i % 40 < 20) ? [.right, .fire] : [.left, .fire]
                core.step(buttons: b, pause: false)
            }
            return addrs.map { core.readRAM($0) }
        }
        #expect(run() == run())                               // reproducible
    }

    private func distinctColors(_ img: CGImage) -> Int {
        guard let data = img.dataProvider?.data else { return 0 }
        let n = CFDataGetLength(data)
        let ptr = CFDataGetBytePtr(data)!
        var seen = Set<UInt32>()
        var i = 0
        while i + 3 < n {
            let px = UInt32(ptr[i]) << 16 | UInt32(ptr[i + 1]) << 8 | UInt32(ptr[i + 2])
            seen.insert(px)
            if seen.count > 1 { return seen.count }
            i += 4 * 101                                                  // sparse sample
        }
        return seen.count
    }
}
