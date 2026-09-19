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
    public func readVDPReg(_ reg: Int) -> UInt8 { UInt8(truncatingIfNeeded: sms_core_vdp_reg(Int32(reg))) }

    // ── Audiovisual + stage-warp taps ──
    public func readVRAM(_ address: Int) -> UInt8 { UInt8(truncatingIfNeeded: sms_core_vram(Int32(address))) }
    public func readCRAM(_ address: Int) -> UInt8 { UInt8(truncatingIfNeeded: sms_core_cram(Int32(address))) }
    public func satBase() -> Int { Int(sms_core_sat_base()) }
    public func readSAT(_ index: Int) -> UInt8 { UInt8(truncatingIfNeeded: sms_core_sat(Int32(index))) }

    public func writeRAM(_ address: Int, _ value: UInt8) {
        guard loaded else { return }
        sms_core_write_ram(Int32(address), Int32(value))
    }

    public func psgCaptureReset() { sms_core_psg_capture_reset() }

    public func psgDrain() -> [UInt8] {
        let count = Int(sms_core_psg_count())
        guard count > 0 else { return [] }
        var buf = [UInt8](repeating: 0, count: count)
        let n = buf.withUnsafeMutableBufferPointer { p in
            Int(sms_core_psg_drain(p.baseAddress, Int32(p.count)))
        }
        if n < buf.count { buf.removeLast(buf.count - n) }
        return buf
    }

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
