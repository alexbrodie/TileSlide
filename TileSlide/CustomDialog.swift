//
//  CustomDialog.swift
//  TileSlide
//
//  Created by Alex Brodie on 2/11/2022.
//  Copyright © 2022 Alex Brodie. All rights reserved.
//

import SwiftUI

struct CustomDialog<DialogContent: View>: ViewModifier {
    @Binding var isPresented: Bool
    let dialogContent: DialogContent

    init(isPresented: Binding<Bool>,
         @ViewBuilder dialogContent: () -> DialogContent) {
        _isPresented = isPresented
        self.dialogContent = dialogContent()
    }

    func body(content: Content) -> some View {
        ZStack {
            content
                .blur(radius: isPresented ? 2 : 0, opaque: true)
            if isPresented {
                Rectangle()
                    .foregroundColor(.black.opacity(0.5))
                    .ignoresSafeArea()
                    .onTapGesture { isPresented = false }
                ZStack {
                    dialogContent
                        .background(RoundedRectangle(cornerRadius: 8)
                                .foregroundColor(.white)
                                        .shadow(color: .black, radius: 8)
                                .padding(-8))
                }
                    .padding(32)
            }
        }
    }
}

extension View {
    func customDialog<DialogContent: View>(
            isPresented: Binding<Bool>,
            @ViewBuilder dialogContent: @escaping () -> DialogContent
        ) -> some View {
        self.modifier(CustomDialog(isPresented: isPresented, dialogContent: dialogContent))
    }
}
