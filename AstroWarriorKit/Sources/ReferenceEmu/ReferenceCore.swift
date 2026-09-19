import Foundation
import CoreGraphics

// The parity "ground truth" seam. Today it's the vendored SMS Plus core; later a
// Swift-native emulator drops in behind the same protocol without touching the debugger.
public protocol ReferenceCore: AnyObject {
    /// Load a raw SMS ROM image. Returns true on success.
    @discardableResult func load(rom: Data) -> Bool
    func reset()
    /// Feed one frame of input, then advance exactly one video frame.
    func step(buttons: RefButtons, pause: Bool)
    /// Latest rendered frame as an image (nil until the first step).
    var frame: CGImage? { get }
    var frameSize: (width: Int, height: Int) { get }
    /// Read a byte of work RAM (0xC000–0xDFFF) — for reading the ROM's entity state.
    func readRAM(_ address: Int) -> UInt8

    // ── Audiovisual + stage-warp taps (dev/debug) ──

    /// Read a byte of VDP VRAM (0x0000–0x3FFF): name table, patterns, sprite table.
    func readVRAM(_ address: Int) -> UInt8
    /// Read a byte of VDP CRAM (0x00–0x3F). SMS uses 0x00–0x1F: two 16-colour palettes,
    /// each byte packed `--BBGGRR` (6-bit colour).
    func readCRAM(_ address: Int) -> UInt8
    /// Sprite Attribute Table base address in VRAM (derived from VDP reg 5).
    func satBase() -> Int
    /// Read a byte of the Sprite Attribute Table by index relative to `satBase()`.
    func readSAT(_ index: Int) -> UInt8

    /// Poke a byte of work RAM (0xC000–0xDFFF). Lets a harness set the variant/stage
    /// selector (e.g. 0xC240), wave-index (0xC211), or stage counter (0xC25B) to warp.
    func writeRAM(_ address: Int, _ value: UInt8)

    /// Enable and clear PSG (SN76489) write capture. Opt-in; a no-op tap when disabled,
    /// it does not affect emulation timing or determinism.
    func psgCaptureReset()
    /// Drain the raw PSG-port bytes captured since `psgCaptureReset()` (oldest first),
    /// clearing the log. Capture stays enabled for the next window.
    func psgDrain() -> [UInt8]
}

public extension ReferenceCore {
    /// Read a little-endian 16-bit value from two consecutive RAM bytes.
    func readRAM16(_ address: Int) -> Int {
        Int(readRAM(address)) | (Int(readRAM(address + 1)) << 8)
    }
}

public struct RefButtons: OptionSet, Sendable {
    public let rawValue: UInt32
    public init(rawValue: UInt32) { self.rawValue = rawValue }
    public static let up    = RefButtons(rawValue: 0x01)
    public static let down  = RefButtons(rawValue: 0x02)
    public static let left  = RefButtons(rawValue: 0x04)
    public static let right = RefButtons(rawValue: 0x08)
    public static let fire  = RefButtons(rawValue: 0x10)   // Button 1
    public static let fire2 = RefButtons(rawValue: 0x20)   // Button 2
}
