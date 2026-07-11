import Foundation

// The one timing rule that makes play identical to the original's 60 Hz cadence (§5.2).
public let SIM_HZ: Double = 60.0
public let SIM_DT: Double = 1.0 / SIM_HZ

// The logical playfield (§5.1). World extends arbitrarily far in +Y (scroll).
public let LOGICAL_WIDTH: Double = 256.0
public let LOGICAL_HEIGHT: Double = 192.0
