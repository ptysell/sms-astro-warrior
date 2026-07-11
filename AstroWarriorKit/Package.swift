// swift-tools-version: 6.0
import PackageDescription

// AstroWarriorKit — the game engine (the "parts in the garage").
// The Xcode app target ("AstroWarrior") links the GameUI product, which
// transitively pulls in the rest. GameSim depends on NOTHING — that one-way
// dependency arrow is the discipline that keeps the simulation pure (§12).
let package = Package(
    name: "AstroWarriorKit",
    platforms: [
        .macOS(.v15),   // Mac-first dev; bump toward 26 as APIs are adopted
        .iOS(.v18),
    ],
    products: [
        // The app links this one product; it re-exports the engine.
        .library(name: "GameUI", targets: ["GameUI"]),
        // Parity debugger (dev only — links the GPL reference core).
        .library(name: "ParityDebug", targets: ["ParityDebug"]),
        // Exposed individually so headless agents/tests can target them.
        .library(name: "GameSim", targets: ["GameSim"]),
        .library(name: "GameRenderSpriteKit", targets: ["GameRenderSpriteKit"]),
        .library(name: "GameAudio", targets: ["GameAudio"]),
        .library(name: "GameInput", targets: ["GameInput"]),
    ],
    targets: [
        // Vendored SMS Plus GX core (GPL-2) behind a tiny C shim. DEBUG/PARITY ONLY —
        // never linked into the shipping app; a Swift-native emulator replaces it later.
        .target(
            name: "CSMSCore",
            path: "Sources/CSMSCore",
            sources: [
                "shim.c",
                "smsplus/system.c", "smsplus/sms.c", "smsplus/memz80.c", "smsplus/pio.c",
                "smsplus/vdp.c", "smsplus/tms.c", "smsplus/render.c",
                "smsplus/cpu_cores/z80/z80.c",
                "smsplus/sound/sound.c", "smsplus/sound/ym2413.c", "smsplus/sound/fmintf.c",
                "smsplus/sound/maxim_sn76489/sn76489.c",
            ],
            publicHeadersPath: "include",
            cSettings: [
                .headerSearchPath("include"),
                .headerSearchPath("smsplus"),
                .headerSearchPath("smsplus/cpu_cores/z80"),
                .headerSearchPath("smsplus/sound"),
                .headerSearchPath("smsplus/sound/maxim_sn76489"),
                .define("LSB_FIRST"),
                .define("NOZIP_SUPPORT"),
                .define("MAXIM_PSG"),               // select the vendored SN76489
                .define("SOUND_FREQUENCY", to: "44100"),
                .define("LOCK_VIDEO", to: ""),      // no-op the SDL surface-lock macros
                .define("UNLOCK_VIDEO", to: ""),
            ]
        ),

        // The ported game. Pure Swift, no platform frameworks (§5).
        .target(name: "GameSim"),

        // Presentation skins — each depends ONLY on GameSim (§4, §6).
        .target(name: "GameRenderSpriteKit", dependencies: ["GameSim"]),
        .target(name: "GameAudio", dependencies: ["GameSim"]),
        .target(name: "GameInput", dependencies: ["GameSim"]),

        // SwiftUI shell wires render + audio + input over the sim (§10).
        .target(
            name: "GameUI",
            dependencies: ["GameSim", "GameRenderSpriteKit", "GameAudio", "GameInput"]
        ),

        // Swift wrapper over the reference core (swap seam for a native emulator later).
        .target(name: "ReferenceEmu", dependencies: ["CSMSCore"]),

        // Headless measurement + parity tool — drives the ROM and our sim together.
        .executableTarget(name: "ParityProbe", dependencies: ["ReferenceEmu", "GameSim", "GameInput"]),

        // Side-by-side parity debugger: ROM (left) vs our sim (right), one input stream.
        .target(
            name: "ParityDebug",
            dependencies: ["ReferenceEmu", "GameSim", "GameRenderSpriteKit", "GameInput"],
            resources: [.copy("Resources/AstroWarrior.sms")]
        ),

        // Headless tests over the pure sim (§13).
        .testTarget(name: "GameSimTests", dependencies: ["GameSim"]),
        .testTarget(name: "GameInputTests", dependencies: ["GameInput"]),
        .testTarget(name: "ReferenceEmuTests", dependencies: ["ReferenceEmu"]),
    ],
    swiftLanguageModes: [.v6]
)
