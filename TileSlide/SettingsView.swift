//
//  SettingsView.swift
//  TileSlide
//
//  Created by Alex Brodie on 2/4/2022.
//  Copyright © 2022 Alex Brodie. All rights reserved.
//

import SwiftUI
import SpriteKit

struct SettingsView: View {
    @State private var borderColor: Color = .white
    @State private var borderThickness: CGFloat = 0.0
    @State private var settingsPresented: Bool = false
    
    var gameScene: SKScene {
        let s = SliderScene()
        s.scaleMode = .resizeFill
        s.backgroundColor = .black
        return s
    }

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
                            .imageScale(.small)
                            .frame(width: 32, height: 32)
                            .background(Color(white: 0, opacity: 0.06))
                            .cornerRadius(16)
                            .foregroundColor(.white)
                    }
                    .padding(16)
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
                    ColorPicker("Border color", selection: $borderColor)
                    Slider(value: $borderThickness, in: 0...1) {
                        Text("Thickness")
                    } minimumValueLabel: {
                        Text("Thin")
                    } maximumValueLabel: {
                        Text("Thick")
                    }
                }
        }
    }
}

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView()
    }
}
