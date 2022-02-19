//
//  MainView.swift
//  TileSlide
//
//  Created by Alex Brodie on 2/4/2022.
//  Copyright © 2022 Alex Brodie. All rights reserved.
//

import SwiftUI
import SpriteKit

struct MainView: View {
    @State private var settingsPresented: Bool = false
    @StateObject private var settings = SliderSettings()
    @StateObject private var game = SliderScene()
    
    var body: some View {
        ZStack {
            // Main
            SpriteView(scene: game)
                .ignoresSafeArea()
                .blur(radius: settingsPresented ? 2 : 0, opaque: true)
                .onAppear {
                    game.settings = settings
                }
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
                            .foregroundColor(.white.opacity(0.3))
                    }
                        .buttonStyle(.plain)
                        .padding(16)
                }
                Spacer()
            }
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
                        Toggle(isOn: $settings.enableHaptics) {
                            Text("Enable Haptics")
                        }
                        ColorPicker("Number color", selection: $settings.tileNumberColor)
                        Slider(value: $settings.tileNumberFontSize, in: 0...1) {
                            Text("Number size")
                        } minimumValueLabel: {
                            Text("Small")
                        } maximumValueLabel: {
                            Text("Large")
                        }
                        Slider(value: $settings.speedFactor, in: 0...3) {
                            Text("Speed")
                        } minimumValueLabel: {
                            Text("Fast")
                        } maximumValueLabel: {
                            Text("Slow")
                        }
                        Text("Doguillo v\(Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "?")\n\(app_build_date).\(app_commit)")
                            .multilineTextAlignment(.center)
                            .font(.footnote)
                        // Debug
                        HStack {
                            Slider(value: $settings.debug, in: 0...1) {
                                Text("Debug")
                            }
                            Text("\(settings.debug)")
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
