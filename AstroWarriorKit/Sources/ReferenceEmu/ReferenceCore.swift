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
