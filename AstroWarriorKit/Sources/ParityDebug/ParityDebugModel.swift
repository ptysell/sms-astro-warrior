import Foundation
import CoreGraphics
import GameController
import GameSim
import GameInput
import GameRenderSpriteKit
import ReferenceEmu

// Drives BOTH sides in deterministic lockstep from one shared input stream:
//   • reference ROM (SMS Plus core) — real controller + console buttons
//   • our sim (an externally-driven GameScene) — the same pad, stepped one tick per frame
// Supports record/replay of the input stream so comparisons are reproducible (§13).
@MainActor @Observable
public final class ParityDebugModel {
    public enum Drive: Equatable { case live, recording, replaying }

    public let scene: GameScene
    private let core: ReferenceCore = SMSPlusCore()

    public var emulatorImage: CGImage?
    public private(set) var romLoaded = false
    public private(set) var frameCount = 0
    public var bindings = KeyBindings.defaults        // remappable (Settings later)

    public var running = true                         // master run toggle (⏸)
    private var simPaused = false                      // SMS console pause (Q)
    public private(set) var drive: Drive = .live

    private var keyPad = Set<PadButton>()
    private var prevPad = Set<PadButton>()
    private var tape: [[PadButton]] = []
    private var replayIndex = 0

    public var simMode: Mode { scene.simMode }
    public var ourShip: Vec2 { scene.playerPos }

    /// The pad actually driving both cores this frame (live or replayed) — for the monitor.
    public private(set) var lastPad = Set<PadButton>()

    // —— System-monitor readouts ——
    public var romShipScreen: (x: Double, y: Double) { romShip }                 // already screen coords
    public var ourShipScreen: (x: Double, y: Double) { (scene.playerPos.x, LOGICAL_HEIGHT - scene.playerPos.y) }
    public var simScore: Int { scene.simScore }
    public var simLives: Int { scene.simLives }
    public var simForm: Int { scene.simForm }
    public var simEntities: Int { scene.simEntityCount }
    public var simEnemies: Int { scene.simEnemyCount }
    public var simBullets: Int { scene.simBulletCount }
    public var simScroll: Double { scene.simScrollY }
    public var simPlayerBullets: Int { scene.simPlayerBullets }
    public var simEnemyBullets: Int { scene.simEnemyBullets }
    public var simBosses: Int { scene.simBossCount }
    public func romByte(_ a: Int) -> Int { Int(core.readRAM(a)) }

    // Classify the ROM's 40-slot entity pool (0xC600, stride 0x40, +0x00 = type).
    // Type map is empirical (t1 player, t2 player bullet, high types = enemies) and
    // refined by watching the live histogram in the monitor.
    public struct RomPool {
        public var total = 0, player = 0, playerBullets = 0, enemies = 0, other = 0
        public var hist: [Int: Int] = [:]
        public var histogram: String {
            hist.sorted { $0.key < $1.key }.map { "t\($0.key)·\($0.value)" }.joined(separator: " ")
        }
    }
    // —— Live per-object inspector: one row per active ROM pool slot ——
    public struct RomObject: Identifiable {
        public let id: Int          // slot index 0…39
        public let type: Int
        public let name: String
        public let x: Double, y: Double
        public let status: String
    }
    public private(set) var romObjects: [RomObject] = []
    private var prevObjPos: [Int: Vec2] = [:]

    private func romWord(_ a: Int) -> Int { Int(core.readRAM(a)) | (Int(core.readRAM(a + 1)) << 8) }

    static func typeName(_ t: Int) -> String {
        switch t {
        case 1:          return "player"
        case 2:          return "p.bullet"
        case 11, 12, 19: return "fx/hud"
        default:         return "enemy·\(t)"
        }
    }
    static func statusFor(_ t: Int, vx: Double, vy: Double) -> String {
        if t == 2 { return "▲ shot" }
        if abs(vx) < 0.2 && abs(vy) < 0.2 { return "idle" }
        if vy < -1 { return "▲ up" }
        if abs(vx) > 1.2 { return "↔ weave" }     // screen Y is +down
        if vy > 0.3 { return "▼ descend" }
        return "· move"
    }

    private func computeRomObjects() {
        var objs: [RomObject] = [], seen = Set<Int>()
        for s in stride(from: 0xC600, to: 0xD000, by: 0x40) {
            let t = Int(core.readRAM(s)); guard t != 0 else { continue }
            seen.insert(s)
            let x = Double(romWord(s + 0x0A)) / 256.0, y = Double(romWord(s + 0x08)) / 256.0
            var vx = 0.0, vy = 0.0
            if let p = prevObjPos[s] { vx = x - p.x; vy = y - p.y }
            prevObjPos[s] = Vec2(x, y)
            objs.append(RomObject(id: (s - 0xC600) / 0x40, type: t, name: Self.typeName(t),
                                  x: x, y: y, status: Self.statusFor(t, vx: vx, vy: vy)))
        }
        prevObjPos = prevObjPos.filter { seen.contains($0.key) }               // drop dead slots
        romObjects = objs
    }

    public func romPool() -> RomPool {
        var p = RomPool()
        for s in stride(from: 0xC600, to: 0xD000, by: 0x40) {
            let t = Int(core.readRAM(s))
            guard t != 0 else { continue }
            p.total += 1; p.hist[t, default: 0] += 1
            switch t {
            case 1:          p.player += 1
            case 2:          p.playerBullets += 1
            case 11, 12, 19: p.other += 1      // MEASURED fx/HUD (static, motion-classified)
            default:         p.enemies += 1    // every wave adds a species (18,20,21,22,24,25,39…)
            }                                   // (rare enemy bullets/power-ups fold in here)
        }
        return p
    }

    // ROM ship position — MEASURED via ParityProbe: X = 8.8 word @0xC60A, Y = 8.8 word @0xC608.
    public var romShip: (x: Double, y: Double) {
        (Double(core.readRAM16(0xC60A)) / 256.0, Double(core.readRAM16(0xC608)) / 256.0)
    }

    public init() {
        scene = GameScene(size: CGSize(width: LOGICAL_WIDTH, height: LOGICAL_HEIGHT * 2))
        scene.scaleMode = .resizeFill
        scene.acceptsInternalInput = false
        scene.externallyDriven = true                 // we step it, in lockstep
        if let url = Bundle.module.url(forResource: "AstroWarrior", withExtension: "sms"),
           let data = try? Data(contentsOf: url) {
            romLoaded = core.load(rom: data)
        }
    }

    // MARK: driving
    public func tick() { if running { advance() } }
    public func stepOnce() { advance() }              // advances BOTH by one frame

    private func advance() {
        // Resolve this frame's pad: replay from tape, else live (keyboard ∪ controller).
        let live = keyPad.union(controllerPad())
        var pad = live
        if drive == .replaying {
            if replayIndex < tape.count { pad = Set(tape[replayIndex]); replayIndex += 1 }
            else { drive = .live; pad = live }
        }
        if drive == .recording { tape.append(pad.sorted { $0.rawValue < $1.rawValue }) }

        let pauseEdge = pad.contains(.pause) && !prevPad.contains(.pause)
        let resetEdge = pad.contains(.reset) && !prevPad.contains(.reset)
        prevPad = pad

        if resetEdge { resetBoth(fireHeld: pad.contains(.button1), recordReset: false); return }
        if pauseEdge { simPaused.toggle() }

        // Reference ROM — one frame; console pause is a one-frame pulse.
        var rb: RefButtons = []
        if pad.contains(.up)      { rb.insert(.up) }
        if pad.contains(.down)    { rb.insert(.down) }
        if pad.contains(.left)    { rb.insert(.left) }
        if pad.contains(.right)   { rb.insert(.right) }
        if pad.contains(.button1) { rb.insert(.fire) }
        if pad.contains(.button2) { rb.insert(.fire2) }
        core.step(buttons: rb, pause: pauseEdge)
        emulatorImage = core.frame

        // Our sim — same pad, one tick in lockstep (unless console-paused).
        if !simPaused {
            scene.setMoveAxis(pad.axis)
            scene.setFire(pad.contains(.button1))
            scene.stepSim(1)
        }
        lastPad = pad
        computeRomObjects()
        frameCount += 1
    }

    /// Reset both cores. `recordReset` inserts a `.reset` frame into the tape when recording,
    /// so an out-of-band reset (the ↺ button) is reproduced on replay. In-band resets (W key,
    /// handled in advance()) pass false — the frame carrying `.reset` is already recorded.
    public func resetBoth(fireHeld: Bool? = nil, recordReset: Bool = true) {
        let live = keyPad.union(controllerPad())
        if recordReset && drive == .recording {
            var frame = live
            frame.insert(.reset)                          // carry held buttons + the reset
            tape.append(frame.sorted { $0.rawValue < $1.rawValue })
        }
        core.reset()
        let held = fireHeld ?? live.contains(.button1)
        scene.resetWorld(fireHeld: held)
        simPaused = false
        frameCount = 0
        emulatorImage = core.frame
        // prevPad intentionally left intact so a held Reset key isn't re-read as a fresh edge.
    }

    // MARK: record / replay
    public func startRecording() {
        resetBoth(fireHeld: false, recordReset: false); tape = []; replayIndex = 0
        prevPad = []; drive = .recording
    }
    public func startReplay() {
        guard !tape.isEmpty else { return }
        resetBoth(fireHeld: false, recordReset: false); replayIndex = 0
        prevPad = []; drive = .replaying
    }
    public func stopTape() { drive = .live }

    public var tapeLength: Int { tape.count }
    public var driveLabel: String {
        switch drive {
        case .live: return "LIVE"
        case .recording: return "REC \(tape.count)"
        case .replaying: return "PLAY \(replayIndex)/\(tape.count)"
        }
    }

    private var tapeURL: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("parity-tape.json")
    }
    public func saveTape() {
        let snapshot = tape, url = tapeURL          // value copy; IO off the main actor
        Task.detached { try? JSONEncoder().encode(snapshot).write(to: url) }
    }
    public func loadTape() {
        let url = tapeURL
        Task { [weak self] in
            let loaded = await Task.detached { () -> [[PadButton]]? in
                guard let d = try? Data(contentsOf: url) else { return nil }
                return try? JSONDecoder().decode([[PadButton]].self, from: d)
            }.value
            if let loaded { self?.tape = loaded }
        }
    }

    // MARK: keyboard (normalized tokens from the view)
    @discardableResult
    public func handleKey(token: String, down: Bool) -> Bool {
        guard let button = bindings.button(forToken: token) else { return false }
        if down { keyPad.insert(button) } else { keyPad.remove(button) }
        return true
    }

    // MARK: game controller (shared with both sides)
    private func controllerPad() -> Set<PadButton> {
        guard let gp = GCController.current?.extendedGamepad else { return [] }
        var s = Set<PadButton>()
        if gp.dpad.up.isPressed    || gp.leftThumbstick.yAxis.value >  0.5 { s.insert(.up) }
        if gp.dpad.down.isPressed  || gp.leftThumbstick.yAxis.value < -0.5 { s.insert(.down) }
        if gp.dpad.left.isPressed  || gp.leftThumbstick.xAxis.value < -0.5 { s.insert(.left) }
        if gp.dpad.right.isPressed || gp.leftThumbstick.xAxis.value >  0.5 { s.insert(.right) }
        if gp.buttonA.isPressed { s.insert(.button1) }
        if gp.buttonB.isPressed || gp.buttonX.isPressed { s.insert(.button2) }
        if gp.buttonMenu.isPressed { s.insert(.pause) }
        return s
    }
}
