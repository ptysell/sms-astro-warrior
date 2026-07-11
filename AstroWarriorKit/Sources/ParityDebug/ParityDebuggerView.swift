import SwiftUI
import SpriteKit
import GameSim
import GameRenderSpriteKit

// Dual viewer in deterministic lockstep: original ROM (left) vs our sim (right), one input
// stream driving both, with record/replay and a live position readout for measurement.
// Defaults: arrows = move · Z = fire · X = Button 2 · Q = Pause · W = Reset.
public struct ParityDebuggerView: View {
    @State private var model = ParityDebugModel()
    @FocusState private var focused: Bool

    private let clock = Timer.publish(every: 1.0 / 60.0, on: .main, in: .common).autoconnect()

    public init() {}

    public var body: some View {
        VStack(spacing: 0) {
            controlBar
            recordBar
            HStack(spacing: 0) {
                pane(title: "ORIGINAL ROM") {
                    if let img = model.emulatorImage {
                        Image(decorative: img, scale: 1)
                            .resizable().interpolation(.none)
                            .aspectRatio(256.0 / 192.0, contentMode: .fit)
                    } else {
                        placeholder(model.romLoaded ? "starting…" : "ROM not found")
                    }
                }
                Divider().overlay(.white.opacity(0.15))
                pane(title: "OUR SIM") {
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
            }
            telemetry
            legend
        }
        .background(.black)
        .focusable().focused($focused)
        .onAppear { focused = true }
        .onReceive(clock) { _ in model.tick() }
        .onKeyPress(phases: [.down, .up]) { handle($0) }
    }

    private var controlBar: some View {
        HStack(spacing: 14) {
            Button(model.running ? "⏸ Pause" : "▶ Resume") { model.running.toggle() }
            Button("⏭ Step") { model.stepOnce() }.disabled(model.running)
            Button("↺ Reset") { model.resetBoth() }
            Spacer()
            Text("frame \(model.frameCount)")
                .font(.system(.caption, design: .monospaced)).foregroundStyle(.gray)
            Text(model.romLoaded ? "ROM ✓" : "ROM ✗")
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(model.romLoaded ? .green : .red)
        }
        .padding(.horizontal, 12).padding(.vertical, 8).background(.black)
    }

    private var recordBar: some View {
        HStack(spacing: 10) {
            Button("● Rec") { model.startRecording() }
                .foregroundStyle(model.drive == .recording ? .red : .primary)
            Button("▶ Play") { model.startReplay() }.disabled(model.tapeLength == 0)
            Button("■ Stop") { model.stopTape() }
            Button("Save") { model.saveTape() }.disabled(model.tapeLength == 0)
            Button("Load") { model.loadTape() }
            Spacer()
            Text(model.driveLabel).font(.system(.caption, design: .monospaced))
                .foregroundStyle(model.drive == .live ? .gray : .yellow)
        }
        .padding(.horizontal, 12).padding(.vertical, 4).background(.black)
        .font(.caption)
    }

    private var telemetry: some View {
        let rom = model.romShip, our = model.ourShip
        let dx = our.x - rom.x, dy = our.y - rom.y
        return HStack(spacing: 24) {
            metric("ROM ship", String(format: "%.1f, %.1f", rom.x, rom.y), .cyan)
            metric("OUR ship", String(format: "%.1f, %.1f", our.x, our.y), .green)
            metric("Δ", String(format: "%.1f, %.1f", dx, dy),
                   abs(dx) + abs(dy) < 2 ? .green : .orange)
            metric("our mode", String(describing: model.simMode), .gray)
        }
        .padding(.horizontal, 12).padding(.vertical, 6).background(.black)
    }

    private func metric(_ label: String, _ value: String, _ color: Color) -> some View {
        HStack(spacing: 6) {
            Text(label).font(.system(size: 10, design: .monospaced)).foregroundStyle(.gray)
            Text(value).font(.system(size: 12, weight: .bold, design: .monospaced)).foregroundStyle(color)
        }
    }

    private var legend: some View {
        Text("← ↑ ↓ →  move   ·   Z  fire   ·   X  button 2   ·   Q  pause   ·   W  reset")
            .font(.system(size: 11, design: .monospaced)).foregroundStyle(.gray)
            .padding(.vertical, 6).frame(maxWidth: .infinity).background(.black)
    }

    private func pane<Content: View>(title: String, @ViewBuilder _ content: () -> Content) -> some View {
        VStack(spacing: 4) {
            Text(title).font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundStyle(.gray).padding(.top, 6)
            content()
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity).background(.black)
    }

    private func placeholder(_ text: String) -> some View {
        ZStack { Color.black
            Text(text).font(.system(.body, design: .monospaced)).foregroundStyle(.gray)
        }.aspectRatio(256.0 / 192.0, contentMode: .fit)
    }

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
