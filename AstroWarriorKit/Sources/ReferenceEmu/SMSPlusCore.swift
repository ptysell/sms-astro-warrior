import Foundation
import CoreGraphics
import CSMSCore

// ReferenceCore backed by the vendored SMS Plus GX core (GPL-2, dev/debug only).
public final class SMSPlusCore: ReferenceCore {
    private var loaded = false
    private let cs = CGColorSpaceCreateDeviceRGB()
    public private(set) var frame: CGImage?
    public var frameSize: (width: Int, height: Int) { (256, 192) }

    public init() {}
    deinit { if loaded { sms_core_shutdown() } }

    @discardableResult
    public func load(rom: Data) -> Bool {
        let ok = rom.withUnsafeBytes { raw -> Int32 in
            guard let base = raw.bindMemory(to: UInt8.self).baseAddress else { return 0 }
            return sms_core_load(base, Int32(rom.count))
        }
        loaded = ok == 1
        return loaded
    }

    public func reset() { if loaded { sms_core_reset() } }

    public func readRAM(_ address: Int) -> UInt8 { UInt8(truncatingIfNeeded: sms_core_ram(Int32(address))) }
    public func readPort(_ port: Int) -> UInt8 { UInt8(truncatingIfNeeded: sms_core_port(Int32(port))) }

    public func step(buttons: RefButtons, pause: Bool) {
        guard loaded else { return }
        sms_core_set_buttons(buttons.rawValue, pause ? 1 : 0)
        sms_core_run_frame()
        frame = makeImage()
    }

    private func makeImage() -> CGImage? {
        var w: Int32 = 0, h: Int32 = 0
        guard let ptr = sms_core_framebuffer(&w, &h) else { return nil }
        let width = Int(w), height = Int(h)
        let byteCount = width * height * 4
        let data = Data(bytes: ptr, count: byteCount)            // bytes R,G,B,A
        guard let provider = CGDataProvider(data: data as CFData) else { return nil }
        let info = CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue)
        return CGImage(width: width, height: height, bitsPerComponent: 8, bitsPerPixel: 32,
                       bytesPerRow: width * 4, space: cs, bitmapInfo: info,
                       provider: provider, decode: nil, shouldInterpolate: false,
                       intent: .defaultIntent)
    }
}
