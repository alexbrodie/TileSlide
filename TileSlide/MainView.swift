//
//  MainView.swift
//  TileSlide
//
//  Created by Alex Brodie on 2/4/2022.
//  Copyright © 2022 Alex Brodie. All rights reserved.
//

import SwiftUI
import SpriteKit

class GameSceneStore : ObservableObject {
    var scene = SliderScene()
    
    init() {
        scene.backgroundColor = .black
    }
}

struct MainView: View {
    @State private var settingsPresented: Bool = false
    @StateObject private var gameSceneStore = GameSceneStore()
    
    var body: some View {
        ZStack {
            // Main
            SpriteView(scene: gameSceneStore.scene)
                .ignoresSafeArea()
                .blur(radius: settingsPresented ? 2 : 0, opaque: true)
            // HUD
            VStack {
                HStack {
                    Spacer()
                    Button{
                        withAnimation {
                            settingsPresented.toggle()
                        }
                    } label: {
                        Image(systemName: "gearshape")
                            .imageScale(.large)
                            .padding(4)
                            .background(Circle()
                                .foregroundColor(.white.opacity(0.1)))
                            .foregroundColor(.white.opacity(0.6))
                    }
                        .buttonStyle(.plain)
                        .padding(16)
                }
                    .frame(maxWidth: .infinity)
                Spacer()
                    .frame(maxHeight: .infinity)
            }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .ignoresSafeArea()
            // Settings
            if settingsPresented {
                Rectangle()
                    .foregroundColor(.black.opacity(0.5))
                    .ignoresSafeArea()
                    .onTapGesture { withAnimation { settingsPresented = false } }
                ZStack {
                    // Settings content
                    VStack {
                        HStack {
                            Spacer()
                            Button {
                                withAnimation {
                                    settingsPresented = false
                                }
                            } label: {
                                Image(systemName: "xmark")
                                    .imageScale(.small)
                                    .frame(width: 32, height: 32)
                                    .background(Color(white: 1, opacity: 0.06))
                                    .cornerRadius(16)
                                    .foregroundColor(.black)
                            }
                        }
                        Toggle(isOn: $gameSceneStore.scene.settings.enableHaptics) {
                            Text("Enable Haptics")
                        }
                        ColorPicker("Number color", selection: $gameSceneStore.scene.settings.tileNumberColor)
                        Slider(value: $gameSceneStore.scene.settings.tileNumberFontSize, in: 0...1) {
                            Text("Number size")
                        } minimumValueLabel: {
                            Text("Small")
                        } maximumValueLabel: {
                            Text("Large")
                        }
                    }
                        .background(RoundedRectangle(cornerRadius: 8)
                            .foregroundColor(.white)
                            .shadow(color: .black, radius: 8)
                            .padding(-8))
                        .foregroundColor(.black)
                }
                    .padding(32)
            }
        }
    }
}

struct MainView_Previews: PreviewProvider {
    static var previews: some View {
        MainView()
    }
}
