//
//  Element.swift
//  Vimac
//
//  Created by Dexter Leng on 5/9/20.
//  Copyright © 2020 Dexter Leng. All rights reserved.
//

import Cocoa
import os
import AXSwift

class Element {
    let rawElement: AXUIElement
    let frame: NSRect
    let actions: [String]
    let role: String
    
    var clippedFrame: NSRect?
    
    static func initialize(rawElement: AXUIElement) -> Element? {
        let uiElement = UIElement.init(rawElement)
        let valuesOptional = try? uiElement.getMultipleAttributes([.size, .position, .role])
        
        guard let values = valuesOptional else {
            os_log("[Element] init nil")
            return nil
        }

        guard let size = values[Attribute.size] as? CGSize,
              let position = values[Attribute.position] as? CGPoint,
              let role = values[Attribute.role] as? String else 
        { 
            os_log("[Element] init nil")
            return nil 
        }
        let frame = NSRect(origin: position, size: size)

        let actions = try? uiElement.actionsAsStrings()
        
        return Element.init(rawElement: rawElement, frame: frame, actions: actions ?? [], role: role)
    }
    
    init(rawElement: AXUIElement, frame: NSRect, actions: [String], role: String) {
        self.rawElement = rawElement
        self.frame = frame
        self.actions = actions
        self.role = role
    }
    
    func setClippedFrame(_ clippedFrame: NSRect) {
        self.clippedFrame = clippedFrame
    }
}


extension Element: CustomStringConvertible {
    var description: String {
        let roleStr = String(format: "role: %-14s", role.cstr!)
        let actionsStr = actions.joined(separator: ", ")
        return "\(frame) \(roleStr) [\(actionsStr)]"
    }
}

extension CGRect: CustomStringConvertible {
    public var description: String {
        String(format: "r:(%5.f, %5.f, %4.f, %4.f)", origin.x, origin.y, size.width, size.height)
    }
}

extension String {
    var cstr: UnsafePointer<CChar>? {
        (self as NSString).utf8String
    }
}
