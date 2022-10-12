//
//  AppCustomization.swift
//  Vimac
//
//  Created by marcow on 2022/10/7.
//  Copyright © 2022 Dexter Leng. All rights reserved.
//

import Foundation

enum AppCustomization : String {
    case accessibilityInspector = "com.apple.AccessibilityInspector"
    case alfredPreferences = "com.runningwithcrayons.Alfred-Preferences"
    case clion = "com.jetbrains.CLion"
    case ida = "com.hexrays.ida64"
    case logseq = "com.electron.logseq"
    case iphonesimulator = "com.apple.iphonesimulator"
    case pathFinder = "com.cocoatech.PathFinder"
    case pdfExpertMac = "com.readdle.PDFExpert-Mac"
    case typora = "abnerworks.Typora"
    case xcode = "com.apple.dt.Xcode"
    
    static let needStaticText = [AppCustomization.clion, .logseq, .pathFinder, .pdfExpertMac, .typora]
}
