import SwiftUI
import SpriteKit
import GameSim
import GameInput
import GameRenderSpriteKit

// Dual viewer in deterministic lockstep + a live System Monitor inspector.
// Defaults: arrows = move · Z = fire · X = Button 2 · Q = Pause · W = Reset.
public struct ParityDebuggerView: View {
    @State private var model = ParityDebugModel()
    @FocusState private var focused: Bool
    private let clock = Timer.publish(every: 1.0 / 60.0, on: .main, in: .common).autoconnect()

    // Instrument palette
    private let romTint = Color(red: 0.35, green: 0.85, blue: 1.0)     // cyan
    private let ourTint = Color(red: 0.45, green: 1.0, blue: 0.55)     // green
    private let panelBG = Color(white: 0.06)

    public init() {}

    public var body: some View {
        VStack(spacing: 0) {
            controlBar
            recordBar
            HStack(spacing: 10) {
                gamePane("ORIGINAL ROM", tint: romTint) {
                    if let img = model.emulatorImage {
                        Image(decorative: img, scale: 1).resizable().interpolation(.none)
                            .aspectRatio(256.0 / 192.0, contentMode: .fit)
                    } else { placeholder(model.romLoaded ? "starting…" : "ROM not found") }
                }
                gamePane("OUR SIM", tint: ourTint) {
                    ZStack {
                        SpriteView(scene: model.scene, options: [.ignoresSiblingOrder])
                            .aspectRatio(256.0 / 192.0, contentMode: .fit)
                        if model.simMode == .title {
                            Text("PRESS Z").font(.system(.headline, design: .monospaced))
                                .foregroundStyle(.white).padding(8)
                                .background(.black.opacity(0.5), in: Capsule())
                        }
                    }
                }
                systemMonitor.frame(width: 300)
                Spacer(minLength: 0)                 // absorb extra width so nothing is pushed off-screen
            }
            .padding(10)
            legend
        }
        .background(.black)
        .focusable().focused($focused)
        .onAppear { focused = true }
        .onReceive(clock) { _ in model.tick() }
        .onKeyPress(phases: [.down, .up]) { handle($0) }
    }

    // MARK: - System Monitor
    private var systemMonitor: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Label("SYSTEM MONITOR", systemImage: "waveform.path.ecg")
                    .font(.system(size: 11, weight: .heavy, design: .monospaced))
                    .foregroundStyle(.white)
                Spacer()
                drivePill
            }
            .padding(.horizontal, 12).padding(.vertical, 9)
            .background(Color(white: 0.12))

            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    parityBlock
                    entitiesBlock
                    objectsBlock
                    simStateBlock
                    romRawBlock
                    inputBlock
                }
                .padding(12)
            }
        }
        .background(panelBG)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(.white.opacity(0.08)))
    }

    private var drivePill: some View {
        let (label, color): (String, Color) = {
            switch model.drive {
            case .live: return ("LIVE", .gray)
            case .recording: return ("● REC \(model.tapeLength)", .red)
            case .replaying: return ("▶ PLAY", .yellow)
            }
        }()
        return Text(label).font(.system(size: 9, weight: .bold, design: .monospaced))
            .foregroundStyle(color).padding(.horizontal, 8).padding(.vertical, 3)
            .background(color.opacity(0.15), in: Capsule())
    }

    // Parity comparison — the mapped, comparable signals.
    private var parityBlock: some View {
        let rom = model.romShipScreen, our = model.ourShipScreen
        return VStack(alignment: .leading, spacing: 6) {
            sectionHeader("PARITY", "ROM ⟷ SIM")
            HStack(spacing: 0) {
                cell("SIGNAL", .gray, 78, .leading)
                cell("ROM", romTint, 64, .trailing)
                cell("OURS", ourTint, 64, .trailing)
                cell("Δ", .gray, 60, .trailing)
            }.font(.system(size: 9, weight: .semibold, design: .monospaced))
            parityRow("ship.x", rom.x, our.x)
            parityRow("ship.y", rom.y, our.y)
        }
    }

    private func parityRow(_ name: String, _ rom: Double, _ our: Double) -> some View {
        let d = our - rom
        let dColor: Color = abs(d) < 1.0 ? ourTint : (abs(d) < 4 ? .yellow : .orange)
        return VStack(spacing: 3) {
            HStack(spacing: 0) {
                cell(name, .white.opacity(0.85), 78, .leading)
                cell(String(format: "%.1f", rom), romTint, 64, .trailing)
                cell(String(format: "%.1f", our), ourTint, 64, .trailing)
                cell(String(format: "%+.1f", d), dColor, 60, .trailing)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(.white.opacity(0.06)).frame(height: 3)
                    Capsule().fill(dColor)
                        .frame(width: max(2, geo.size.width * (1 - min(1, abs(d) / 24))), height: 3)
                }
            }.frame(height: 3)
        }
        .font(.system(size: 11, weight: .medium, design: .monospaced))
    }

    // Entity-pool comparison: ROM (classified from work RAM) vs our sim.
    private var entitiesBlock: some View {
        let p = model.romPool()
        return VStack(alignment: .leading, spacing: 4) {
            sectionHeader("ENTITIES", "ROM ⟷ SIM")
            HStack(spacing: 0) {
                cell("", .gray, 96, .leading)
                cell("ROM", romTint, 60, .trailing)
                cell("OURS", ourTint, 60, .trailing)
            }.font(.system(size: 9, weight: .semibold, design: .monospaced))
            // "gameplay" excludes fx/hud (no sim equivalent) so it matches at true parity.
            compareRow("gameplay", "\(p.total - p.other)", "\(model.simEntities + 1)")   // +1: player is separate
            // ROM classifier lumps the boss into enemies, so OURS adds bosses to compare like-for-like.
            compareRow("· enemies", "\(p.enemies)", "\(model.simEnemies + model.simBosses)")
            compareRow("· power-ups", "\(p.powerups)", "\(model.simPowerUps)")   // t18, down-centre
            compareRow("· p.bullets", "\(p.playerBullets)", "\(model.simPlayerBullets)")
            compareRow("· e.bullets", "—", "\(model.simEnemyBullets)")       // ROM: fold into enemies (rare)
            compareRow("· fx/hud", "\(p.other)", "—")
            Text("ROM types  \(p.histogram.isEmpty ? "—" : p.histogram)")
                .font(.system(size: 9, design: .monospaced)).foregroundStyle(.white.opacity(0.45))
                .fixedSize(horizontal: false, vertical: true).padding(.top, 2)
        }
    }

    // Live per-object inspector — one row per active ROM pool slot.
    private var objectsBlock: some View {
        VStack(alignment: .leading, spacing: 3) {
            sectionHeader("OBJECTS", "ROM pool · live")
            HStack(spacing: 0) {
                cell("#", .gray, 24, .leading)
                cell("type", .gray, 84, .leading)
                cell("pos", .gray, 70, .leading)
                cell("status", .gray, 78, .leading)
            }.font(.system(size: 9, weight: .semibold, design: .monospaced))
            ForEach(model.romObjects) { o in
                HStack(spacing: 0) {
                    cell("\(o.id)", .white.opacity(0.45), 24, .leading)
                    cell(o.name, objColor(o.name), 84, .leading)
                    cell(String(format: "%.0f,%.0f", o.x, o.y), .white.opacity(0.8), 70, .leading)
                    cell(o.status, .white.opacity(0.65), 78, .leading)
                }.font(.system(size: 10, design: .monospaced))
            }
            if model.romObjects.isEmpty {
                Text("— none —").font(.system(size: 9, design: .monospaced)).foregroundStyle(.gray)
            }
        }
    }
    private func objColor(_ name: String) -> Color {
        if name == "player" { return ourTint }
        if name == "p.bullet" { return .yellow }
        if name == "fx/hud" { return .white.opacity(0.4) }
        return .orange
    }

    private func compareRow(_ name: String, _ rom: String, _ ours: String) -> some View {
        HStack(spacing: 0) {
            cell(name, .white.opacity(0.85), 96, .leading)
            cell(rom, romTint, 60, .trailing)
            cell(ours, ourTint, 60, .trailing)
        }.font(.system(size: 11, weight: .medium, design: .monospaced))
    }

    // Our sim internals (score/lives/mode).
    private var simStateBlock: some View {
        VStack(alignment: .leading, spacing: 5) {
            sectionHeader("SIM STATE", "our engine")
            kv("mode", String(describing: model.simMode), ourTint)
            kv("score", "\(model.simScore)", ourTint)
            kv("lives", String(repeating: "▲", count: max(0, model.simLives)), ourTint)
            kv("form", "\(model.simForm)", ourTint)
            kv("scrollY", String(format: "%.0f", model.simScroll), .white.opacity(0.6))
        }
    }

    // Raw ROM bytes — "what the machine is doing".
    private var romRawBlock: some View {
        VStack(alignment: .leading, spacing: 5) {
            sectionHeader("ROM RAW", "work RAM")
            hexByte("timer @C286", 0xC286)
            hexByte("p.type @C600", 0xC600)
            hexByte("p.x.hi @C60B", 0xC60B)
            hexByte("p.y.hi @C609", 0xC609)
        }
    }

    private var inputBlock: some View {
        VStack(alignment: .leading, spacing: 6) {
            sectionHeader("INPUT", "shared")
            HStack(spacing: 6) {
                glyph("◀", .left); glyph("▲", .up); glyph("▼", .down); glyph("▶", .right)
                Spacer().frame(width: 8)
                glyph("Z", .button1); glyph("X", .button2)
                Spacer()
                Text("f\(model.frameCount)").font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(.gray)
            }
        }
    }

    private func glyph(_ s: String, _ b: PadButton) -> some View {
        let on = model.lastPad.contains(b)
        return Text(s).font(.system(size: 12, weight: .bold, design: .monospaced))
            .foregroundStyle(on ? .black : .white.opacity(0.35))
            .frame(width: 22, height: 22)
            .background(on ? ourTint : Color(white: 0.14), in: RoundedRectangle(cornerRadius: 5))
    }

    // MARK: - small builders
    private func sectionHeader(_ title: String, _ sub: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title).font(.system(size: 10, weight: .heavy, design: .monospaced)).foregroundStyle(.white)
            Text(sub).font(.system(size: 8, design: .monospaced)).foregroundStyle(.gray)
            Spacer()
        }
        .padding(.bottom, 2)
        .overlay(Rectangle().fill(.white.opacity(0.08)).frame(height: 1), alignment: .bottom)
    }
    private func cell(_ s: String, _ c: Color, _ w: CGFloat, _ a: Alignment) -> some View {
        Text(s).foregroundStyle(c).frame(width: w, alignment: a)
    }
    private func kv(_ k: String, _ v: String, _ c: Color) -> some View {
        HStack {
            Text(k).font(.system(size: 11, design: .monospaced)).foregroundStyle(.gray)
            Spacer()
            Text(v).font(.system(size: 11, weight: .semibold, design: .monospaced)).foregroundStyle(c)
        }
    }
    private func hexByte(_ k: String, _ addr: Int) -> some View {
        let v = model.romByte(addr)
        return HStack {
            Text(k).font(.system(size: 10, design: .monospaced)).foregroundStyle(.gray)
            Spacer()
            Text(String(format: "0x%02X", v)).font(.system(size: 11, weight: .semibold, design: .monospaced)).foregroundStyle(romTint)
            Text("(\(v))").font(.system(size: 9, design: .monospaced)).foregroundStyle(.white.opacity(0.4))
        }
    }

    // MARK: - chrome
    private var controlBar: some View {
        HStack(spacing: 14) {
            Button(model.running ? "⏸ Pause" : "▶ Resume") { model.running.toggle() }
            Button("⏭ Step") { model.stepOnce() }.disabled(model.running)
            Button("↺ Reset") { model.resetBoth() }
            Spacer()
            Text(model.romLoaded ? "ROM ✓" : "ROM ✗")
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(model.romLoaded ? .green : .red)
        }
        .padding(.horizontal, 12).padding(.vertical, 8).background(.black)
    }
    private var recordBar: some View {
        HStack(spacing: 10) {
            Button("● Rec") { model.startRecording() }.foregroundStyle(model.drive == .recording ? .red : .primary)
            Button("▶ Play") { model.startReplay() }.disabled(model.tapeLength == 0)
            Button("■ Stop") { model.stopTape() }
            Button("Save") { model.saveTape() }.disabled(model.tapeLength == 0)
            Button("Load") { model.loadTape() }
            Spacer()
        }
        .padding(.horizontal, 12).padding(.vertical, 4).background(.black).font(.caption)
    }
    private var legend: some View {
        Text("← ↑ ↓ →  move   ·   Z  fire   ·   X  button 2   ·   Q  pause   ·   W  reset")
            .font(.system(size: 11, design: .monospaced)).foregroundStyle(.gray)
            .padding(.vertical, 6).frame(maxWidth: .infinity).background(.black)
    }
    private func gamePane<Content: View>(_ title: String, tint: Color, @ViewBuilder _ content: () -> Content) -> some View {
        VStack(spacing: 4) {
            Text(title).font(.system(size: 10, weight: .bold, design: .monospaced)).foregroundStyle(tint)
                .padding(.top, 6)
            content()
            Spacer(minLength: 0)
        }
        .frame(maxWidth: 460, maxHeight: .infinity).background(.black)   // cap so the monitor stays on-screen
    }
    private func placeholder(_ text: String) -> some View {
        ZStack { Color.black
            Text(text).font(.system(.body, design: .monospaced)).foregroundStyle(.gray)
        }.aspectRatio(256.0 / 192.0, contentMode: .fit)
    }

    // MARK: - input
    private func handle(_ press: KeyPress) -> KeyPress.Result {
        guard let token = token(for: press.key) else { return .ignored }
        return model.handleKey(token: token, down: press.phase == .down) ? .handled : .ignored
    }
    private func token(for key: KeyEquivalent) -> String? {
        switch key {
        case .upArrow: return "upArrow"
        case .downArrow: return "downArrow"
        case .leftArrow: return "leftArrow"
        case .rightArrow: return "rightArrow"
        default:
            let c = key.character
            return c.isLetter || c.isNumber ? String(c).lowercased() : nil
        }
    }
}
