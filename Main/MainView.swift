//
//  MainView.swift
//  TileSlide
//
//  Created by Alex Brodie on 2/4/2022.
//  Copyright © 2022 Alex Brodie. All rights reserved.
//

import SwiftUI
import SpriteKit

struct SettingsView: View {
    @ObservedObject private var settings: SliderSettings
    
    init(_ settings: SliderSettings) {
        self.settings = settings
    }
    
    var body: some View {
        TabView {
            //Section(header: Text("General")) {
            VStack {
                Slider(value: $settings.speedFactor, in: 0...3) {
                    Text("Speed")
                } minimumValueLabel: {
                    Text("Fast")
                } maximumValueLabel: {
                    Text("Slow")
                }
                Toggle(isOn: $settings.enableHaptics) {
                    Text("Haptics")
                }
            }
            .padding(5)
            .tabItem {
                Label("General", systemImage: "gear")
            }
            //Section(header: Text("Labels")) {
            VStack {
                Picker("Label type", selection: $settings.tileLabelType) {
                    ForEach(LabelType.allCases, id: \.self) { labelType in
                        Text(verbatim: labelType.glyphs.name)
                            .tag(LabelType?.some(labelType))
                    }
                }
                .pickerStyle(.segmented)
                Picker("Font", selection: $settings.tileLabelFont) {
                    ForEach(fontNames, id: \.self) { fontName in
                        HStack {
                            Text(verbatim: "\(fontName)")
                                .tag(fontName)
                            Spacer()
                            Text("123 \u{2196}\u{FE0E}\u{2191}\u{FE0E}\u{2197}\u{FE0E}")
                                .font(.custom(fontName, size: 0))
                        }
                    }
                }
                HStack {
                    Slider(value: $settings.tileLabelSize, in: 0...1) {
                        Text("Label size")
                    }
                    ColorPicker("Color", selection: $settings.tileLabelColor)
                }
                .labelsHidden()
            }
            .padding(5)
            .tabItem {
                Label("Label", systemImage: "number")
            }
            //Section(header: Text("Debug")) {
            VStack {
                // Version
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
            .padding(5)
            .tabItem {
                Label("Info", systemImage: "info")
            }
        }
        .frame(height: 200)
    }
}

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
                .ignoresSafeArea()
        }
            .ignoresSafeArea()
            .customDialog(isPresented: $settingsPresented) {
                // Settings content
                SettingsView(settings)
                    .toolbar {
                        ToolbarItem(placement: .primaryAction) {
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
                    }
                    .ignoresSafeArea()
            }
    }
}

struct MainView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView(SliderSettings())
        //MainView()
    }
}
