import GameSim

// AVAudioEngine driven by Snapshot.audio commands so the sim stays silent (§8).
// TODO(P2): SN76489 synth (3 square + noise) or recreated samples.
public final class AudioEngine {
    public init() {}
    public func handle(_ commands: [AudioCommand]) {
        // TODO(P2): map AudioCommand → AVAudioEngine nodes.
    }
}
