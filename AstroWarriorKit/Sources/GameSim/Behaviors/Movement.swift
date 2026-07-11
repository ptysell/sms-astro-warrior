import Foundation

// Movement strategy objects (§5.4). All numeric fields are [extract] — §16.
public protocol MovementBehavior {
    func step(_ e: Enemy, _ ctx: SimContext)
}

public struct Descend: MovementBehavior {        // straight down
    public let speed: Double
    public init(speed: Double) { self.speed = speed }
    public func step(_ e: Enemy, _ ctx: SimContext) {
        e.position.y -= speed                      // +Y is up the field; enemies descend
    }
}

public struct Weave: MovementBehavior {          // sinusoidal
    public let speed, amp, freq: Double
    public init(speed: Double, amp: Double, freq: Double) {
        self.speed = speed; self.amp = amp; self.freq = freq
    }
    public func step(_ e: Enemy, _ ctx: SimContext) {
        e.position.y -= speed
        e.position.x = e.anchorX + amp * sin(Double(e.age) * freq)
    }
}

public struct Dive: MovementBehavior {           // descends, then homes toward player once
    public let speed: Double
    public let lockAt: Double                      // y at which it commits its dive heading
    public init(speed: Double, lockAt: Double = LOGICAL_HEIGHT * 0.75) {
        self.speed = speed; self.lockAt = lockAt
    }
    public func step(_ e: Enemy, _ ctx: SimContext) {
        if !e.headingLocked {
            e.position.y -= speed                  // straight descent until the commit line
            if e.position.y <= lockAt {
                let d = ctx.world.player.position - e.position
                let len = d.length
                e.velocity = len > 0.0001 ? (d / len) * speed : Vec2(0, -speed)
                e.headingLocked = true
            }
        } else {
            e.position += e.velocity                // committed straight-line dive
        }
    }
}

public struct FormationHold: MovementBehavior {  // keeps slot relative to a wave anchor
    public let speed: Double
    public init(speed: Double = 0) { self.speed = speed }
    public func step(_ e: Enemy, _ ctx: SimContext) { e.position.y -= speed }
}
