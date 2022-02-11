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
    @StateObject private var gameScene = SliderScene()

    var body: some View {
        ZStack {
            SpriteView(scene: gameScene)
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    Button{
                        settingsPresented.toggle()
                    } label: {
                        Image(systemName: "gearshape")
                            .imageScale(.large)
                            .frame(width: 48, height: 48)
                            .background(Color(white: 1, opacity: 0.1))
                            .cornerRadius(24)
                            .foregroundColor(.white)
                    }
                    .padding(8)
                }
            }
        }
        .background(Color.black)
        .sheet(isPresented: $settingsPresented) {
        } content: {
                Form {
                    HStack {
                        Spacer()
                        Button {
                            settingsPresented = false
                        } label: {
                            Image(systemName: "xmark")
                                .imageScale(.small)
                                .frame(width: 32, height: 32)
                                .background(Color(white: 1, opacity: 0.06))
                                .cornerRadius(16)
                                .foregroundColor(.black)
                        }
                    }
                    Toggle(isOn: $gameScene.settings.enableHaptics) {
                        Text("Enable Haptics")
                    }
                    ColorPicker("Number color", selection: $gameScene.settings.tileNumberColor)
                    //Slider(value: $tileNumberSize, in: 0...1) {
                    Slider(value: $gameScene.settings.tileNumberFontSize, in: 0...1) {
                        Text("Number size")
                    } minimumValueLabel: {
                        Text("Small")
                    } maximumValueLabel: {
                        Text("Large")
                    }
                }
        }
    }
}

struct MainView_Previews: PreviewProvider {
    static var previews: some View {
        MainView()
    }
}
