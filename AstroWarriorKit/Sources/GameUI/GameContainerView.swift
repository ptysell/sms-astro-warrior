import SwiftUI
import SpriteKit
import GameSim
import GameRenderSpriteKit

// Observable bridge: the scene pushes HUD changes here; SwiftUI overlays them (§10).
@MainActor @Observable
public final class GameModel {
    public var hud = HUDState(score: 0, hiScore: 0, lives: Tuning.startingLives, form: 1)
    public init() {}
}

public struct GameContainerView: View {
    @State private var model = GameModel()
    @State private var scene: GameScene = {
        let s = GameScene(size: CGSize(width: LOGICAL_WIDTH, height: LOGICAL_HEIGHT * 2))
        s.scaleMode = .resizeFill
        return s
    }()
    @State private var pressed: Set<String> = []
    @FocusState private var focused: Bool

    public init() {}

    public var body: some View {
        SpriteView(scene: scene, options: [.ignoresSiblingOrder])
            .ignoresSafeArea()
            .overlay(alignment: .top) { hudBar }
            .background(.black)
            .focusable()
            .focused($focused)
            .onAppear {
                scene.onHUD = { model.hud = $0 }
                focused = true
            }
            .onKeyPress(phases: [.down, .up]) { handle($0) }
    }

    private var hudBar: some View {
        HStack(spacing: 18) {
            label("SCORE", "\(model.hud.score)")
            label("HI", "\(model.hud.hiScore)")
            label("SHIPS", String(repeating: "▲", count: max(0, model.hud.lives)))
            label("FORM", "\(model.hud.form)")
        }
        .padding(.horizontal, 16).padding(.vertical, 8)
        .background(.black.opacity(0.55), in: Capsule())
        .padding(.top, 8)
    }

    private func label(_ title: String, _ value: String) -> some View {
        VStack(spacing: 1) {
            Text(title).font(.system(size: 9, weight: .semibold, design: .monospaced)).foregroundStyle(.gray)
            Text(value).font(.system(size: 14, weight: .heavy, design: .monospaced)).foregroundStyle(.green)
        }
    }

    // Keyboard → directional axis. Arrow keys + WASD; +Y is up the field.
    private func handle(_ press: KeyPress) -> KeyPress.Result {
        guard let dir = direction(for: press.key) else { return .ignored }
        if press.phase == .down { pressed.insert(dir) } else { pressed.remove(dir) }
        let x = (pressed.contains("right") ? 1.0 : 0) - (pressed.contains("left") ? 1.0 : 0)
        let y = (pressed.contains("up") ? 1.0 : 0) - (pressed.contains("down") ? 1.0 : 0)
        scene.setMoveAxis(Vec2(x, y))
        return .handled
    }

    private func direction(for key: KeyEquivalent) -> String? {
        switch key {
        case .upArrow: return "up"
        case .downArrow: return "down"
        case .leftArrow: return "left"
        case .rightArrow: return "right"
        default: break
        }
        switch key.character {
        case "w", "W": return "up"
        case "s", "S": return "down"
        case "a", "A": return "left"
        case "d", "D": return "right"
        default: return nil
        }
    }
}
