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
    private(set) var frame: NSRect
    let actions: [String]
    let role: String
    
    var clippedFrame: NSRect?
    
    private(set) lazy var ui = UIElement(rawElement)
    
    #if DEBUG
    var title: String?
    #endif
    
    init?(rawElement: AXUIElement) {
        let uiElement = UIElement(rawElement)
        do {
            let attributes = [Attribute.size, .position, .role]
            #if DEBUG
            let debugAttr = [Attribute.description, .value, .title, .domID, .domClasses]
            let newAttr = attributes + debugAttr
            let values = try uiElement.getMultipleAttributes(newAttr)
            title = values.filter { debugAttr.contains($0.0) }
                .compactMap {
                    if let a = $0.1 as? [String], !a.isEmpty {
                        return a.description
                    }
                    if let s = $0.1 as? String, !s.isEmpty {
                        return s
                    }
                    return nil
                }
                .joined(separator: " ")
            #else
            let values = try uiElement.getMultipleAttributes(attributes)
            #endif
            
            let frame: CGRect = {
                if let size = values[.size] as? CGSize,
                   let position = values[.position] as? CGPoint
                {
                    return CGRect(origin: position, size: size)
                }
                return .null
            }()

            guard let role = values[.role] as? String else { 
                throw ELError.roleNull
            }
            
            let newActions: [String]
            do {
                newActions = try uiElement.actionsAsStrings()
            } catch {
                os_log("⚠️ [Element] init actions nil of uiElement: %@, error: %@", uiElement.description, error.localizedDescription)
                newActions = []
            }
            self.rawElement = rawElement
            self.frame = frame
            self.actions = newActions
            self.role = role
            return
        } catch let error {
            let errorInfo: String
            if let e = error as? ELError {
                errorInfo = e.rawValue
            } else {
                errorInfo = error.localizedDescription
            }
            os_log("❌ [Element] init failed of uiElement: %@, title: %@, error: %@", uiElement.description, title ?? "", errorInfo)
        }
        return nil
    }
    
    func setClippedFrame(_ clippedFrame: NSRect) {
        self.clippedFrame = clippedFrame
    }
    
    var children: [Element] {
        UIElement(rawElement).childrens.compactMap { Element(rawElement: $0.element) }
    }
        func children(recursionIndexs: [Int]) -> [Element] {
        var c = children
        for index in recursionIndexs {
            guard index < c.count else { return [] }
            c = c[index].children
        }
        return c
    }
    
    var parent: Element? {
        guard let raw = UIElement(rawElement).parent?.element else { return nil }
        return Element(rawElement: raw)
    }
    
    func repair(frame: CGRect) {
        self.frame = frame
        setClippedFrame(frame)
    }
}


extension Element: CustomStringConvertible {
    var description: String {
        let roleStr = String(format: "role: %-14s", role.cstr!)
        let actionsStr = actions.joined(separator: ", ")
        #if DEBUG
        if let title = title, !title.isEmpty {
            return "\(frame) \(roleStr) [\(actionsStr)] - \(title)"
        }
        #endif
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

enum ELError: String,  Error {
    case frameNull = "frame is null or Empty"
    case roleNull = "role is null"
}

extension UIElement {
    var appCustom: AppCustomization? {
        guard let pid = try? pid(),
              let bundleID = NSRunningApplication(processIdentifier: pid)?.bundleIdentifier
        else {
            os_log("❌ appCustomization nil!")
            return nil 
        }
        return AppCustomization(rawValue: bundleID)
    }
}
