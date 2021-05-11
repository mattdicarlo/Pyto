//
//  View+hover.swift
//  Pyto
//
//  Created by Emma Labbé on 31-10-20.
//  Copyright © 2018-2021 Emma Labbé. All rights reserved.
//

import SwiftUI

extension View {
    
    func hover() -> some View {
        if #available(iOS 13.4, *), !isiOSAppOnMac {
            return AnyView(contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous)).hoverEffect(.automatic))
        } else {
            return AnyView(self)
        }
    }
}
