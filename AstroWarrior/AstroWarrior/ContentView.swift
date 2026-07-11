//
//  ContentView.swift
//  AstroWarrior
//
//  Created by Patrick Tysell on 6/30/26.
//

import SwiftUI
import GameUI
import ParityDebug   // DEV ONLY — links the GPL reference core; strip before shipping.

struct ContentView: View {
    enum Mode: String, CaseIterable { case game = "Game", parity = "Parity Debugger" }
    @State private var mode: Mode = .game

    var body: some View {
        VStack(spacing: 0) {
            Picker("Mode", selection: $mode) {
                ForEach(Mode.allCases, id: \.self) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)
            .padding(6)
            .background(.black)

            switch mode {
            case .game:   GameContainerView()
            case .parity: ParityDebuggerView()
            }
        }
        .background(.black)
    }
}

#Preview {
    ContentView()
}
