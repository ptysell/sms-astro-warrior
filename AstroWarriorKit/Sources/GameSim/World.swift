// The running game state. Owns the object graph and runs ONE tick per step (§5.10).
// Single isolation domain (§9): plain class, mutated only on the game-loop actor.
public enum Mode: Sendable { case title, playing, boss, gameOver }

public final class World {
    public private(set) var entities: [Entity] = []
    public var player: Player
    public var scrollY: Double = 0                  // camera position lives here (§5.10)
    public let campaign: Campaign
    public private(set) var director: LevelDirector

    public var score = 0
    public var hiScore = 0
    public var lives = Tuning.startingLives
    public var mode: Mode = .title
    public var rng = RNG(seed: Tuning.rngSeed)

    private var nextExtraLifeAt = Tuning.extraLifeEvery
    private var extraLivesGranted = 0
    private(set) var bossDefeated = false
    private var events: [Snapshot.Event] = []      // accumulated since last snapshot()
    private let spawner = WaveSpawner()

    func emit(_ event: Snapshot.Event) { events.append(event) }

    public init(campaign: Campaign = DefaultContent.campaign()) {
        self.campaign = campaign
        self.director = LevelDirector(level: campaign.current)
        self.player = Player(at: Vec2(LOGICAL_WIDTH / 2, 24),
                             speed: Tuning.shipSpeed,
                             weapon: SingleShot(speed: Tuning.shipBulletSpeed))
    }

    // ONE TICK — order matters and is faithfulness-critical (§5.10).
    public func step(_ intent: Intent) {
        let ctx = SimContext(world: self, intent: intent)
        switch mode {
        case .playing, .boss:
            scrollY += campaign.current.scrollSpeed     // background advance
            player.update(ctx)
            director.update(self, ctx)
            spawner.update(self, ctx)
            for e in entities { e.update(ctx) }
            CollisionSystem().resolve(self, ctx)
            reapDead()
            cullOffField()
            checkExtraLife()
        case .title, .gameOver:
            updateMenus(intent)
        }
    }

    // —— Spawning / queries used by the director & collision ——
    public func spawn(_ wave: Wave) {
        let baseX = 40 + rng.unit() * (LOGICAL_WIDTH - 80)   // formation anchor (varies per wave)
        spawner.enqueue(wave, baseX: baseX)
    }

    public func spawnBoss(_ spec: BossSpec) {
        bossDefeated = false
        // Screen-relative: enter near the top of the field (§6.3 fixed window for now).
        let boss = Boss(spec: spec, at: Vec2(LOGICAL_WIDTH / 2, LOGICAL_HEIGHT - 30),
                        phase: BossHover())
        entities.append(boss)
        mode = .boss
    }

    public func add(_ e: Entity) { entities.append(e) }

    func addScore(_ p: Int) { score += p; hiScore = max(hiScore, score) }

    func onBossDefeated() { bossDefeated = true; mode = .playing; spawner.reset() }

    func onPlayerDied() {
        lives -= 1
        if lives < 0 { mode = .gameOver; return }
        // Respawn at the start position and clear the field.
        player.isDead = false
        player.position = Vec2(LOGICAL_WIDTH / 2, 24)
        entities.removeAll { $0 is Bullet || $0 is Enemy }
        spawner.reset()
    }

    public func snapshot() -> Snapshot {
        var draws: [Snapshot.SpriteDraw] = []
        draws.reserveCapacity(entities.count + 1)
        draws.append(.init(sprite: player.sprite, pos: player.position,
                           size: player.hitbox.boundingSize, z: 100))
        for e in entities {
            draws.append(.init(sprite: e.sprite, pos: e.position,
                               size: e.hitbox.boundingSize, z: 50))
        }
        let out = Snapshot(
            sprites: draws,
            scrollY: scrollY,
            background: campaign.current.background,
            audio: [],
            events: events,
            hud: HUDState(score: score, hiScore: hiScore, lives: lives, form: player.form)
        )
        events.removeAll(keepingCapacity: true)    // one-shot — consumed by the renderer
        return out
    }

    // —— internals ——
    private func reapDead() { entities.removeAll { $0.isDead } }

    private func cullOffField() {
        entities.removeAll {
            $0.position.y < -16 || $0.position.y > LOGICAL_HEIGHT + 96 ||
            $0.position.x < -20 || $0.position.x > LOGICAL_WIDTH + 20
        }
    }

    private func checkExtraLife() {
        while extraLivesGranted < Tuning.maxExtraLives, score >= nextExtraLifeAt {
            lives += 1
            extraLivesGranted += 1
            nextExtraLifeAt += Tuning.extraLifeEvery
        }
    }

    private var startFireLatch = false

    private func updateMenus(_ intent: Intent) {
        // Edge-triggered start: a fire that's already held (e.g. carried across a reset)
        // must not auto-start — you press to start. The game auto-starts because its fire
        // rises from false on frame 1.
        if mode == .title, intent.fire, !startFireLatch { mode = .playing }
        startFireLatch = intent.fire
    }

    /// Seed the title fire-latch so a currently-held fire isn't seen as a fresh press.
    public func primeTitleFire(_ held: Bool) { startFireLatch = held }
}
