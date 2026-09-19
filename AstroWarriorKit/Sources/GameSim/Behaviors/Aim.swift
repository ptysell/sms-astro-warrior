import Foundation

// AIM-at-player primitive — ROM 0x18fd + polar unit table @0x19C0
// (docs/rom-decode-systems.md §"Enemy movement model").
//
// The ROM computes dx = playerX − enemyX, dy = playerY − enemyY, sets the +0x02 direction
// bits from their signs, then reads a velocity record from a polar table indexed by the
// angle bucket. Every record in that table has the SAME total magnitude 0x01E0 = 1.875 px/f,
// split across the two axes by angle — i.e. a unit-speed vector pointing at the player. We
// port it as a continuous normalise-to-1.875 (the decode notes this is the faithful model;
// the 9-bucket quantisation differs by <0.1 px and does not affect parity). Used by cult,
// shamir, tinker and every enemy bullet (type 0x14).
public enum Aim {
    // Point `e` at `target`: write the per-axis step magnitudes and the direction bitfield so
    // the shared integrator carries the enemy toward the target at `speed` px/frame total.
    public static func lock(_ e: Enemy, toward target: Vec2, speed: Double = Tuning.aimUnitSpeed) {
        let dx = target.x - e.position.x
        let dy = target.y - e.position.y                 // sim +Y up: player below ⇒ dy < 0
        let dist = max((dx * dx + dy * dy).squareRoot(), 0.0001)
        e.stepX = speed * abs(dx) / dist
        e.stepY = speed * abs(dy) / dist
        var mask: UInt8 = 0
        mask |= dx >= 0 ? MoveDir.right : MoveDir.left
        mask |= dy <= 0 ? MoveDir.down : MoveDir.up      // move toward the player's row
        e.dirMask = mask
    }
}
