// Immutable description the renderer/audio consume; logical coordinates (§5.13).
// This is the ONLY thing handed across the sim → presentation seam.
public struct Snapshot: Sendable {
    public struct SpriteDraw: Sendable {
        public let sprite: SpriteRef
        public let pos: Vec2           // logical position
        public let size: Vec2          // logical width×height = the collision bounds
        public let z: Int
        public init(sprite: SpriteRef, pos: Vec2, size: Vec2, z: Int) {
            self.sprite = sprite; self.pos = pos; self.size = size; self.z = z
        }
    }

    // Transient one-shot effects emitted during the tick(s) since the last snapshot.
    public enum Event: Sendable {
        case explosion(pos: Vec2)
        case playerHit(pos: Vec2)
    }

    public let sprites: [SpriteDraw]
    public let scrollY: Double         // camera position in the world
    public let background: BackgroundRef
    public let audio: [AudioCommand]   // play sfx / set music — no audio API here
    public let events: [Event]         // cosmetic, consumed by the renderer
    public let hud: HUDState

    public init(sprites: [SpriteDraw], scrollY: Double, background: BackgroundRef,
                audio: [AudioCommand], events: [Event] = [], hud: HUDState) {
        self.sprites = sprites; self.scrollY = scrollY; self.background = background
        self.audio = audio; self.events = events; self.hud = hud
    }
}

public struct BackgroundRef: Sendable {
    public var id: String
    public init(_ id: String) { self.id = id }
}

public enum AudioCommand: Sendable {
    case playSFX(String)
    case setMusic(String)
    case stopMusic
}

public struct HUDState: Sendable, Equatable {
    public var score: Int
    public var hiScore: Int
    public var lives: Int
    public var form: Int               // 1 = single, 2 = triple, 3 = laser
    public init(score: Int, hiScore: Int, lives: Int, form: Int) {
        self.score = score; self.hiScore = hiScore; self.lives = lives; self.form = form
    }
}
