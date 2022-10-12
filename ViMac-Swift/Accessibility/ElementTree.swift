//
//  ElementTree.swift
//  Vimac
//
//  Created by Dexter Leng on 30/3/21.
//  Copyright © 2021 Dexter Leng. All rights reserved.
//

import Cocoa
import os

class ElementTree {
    private var elementsById: [AXUIElement : Element]
    private var childrenById: [AXUIElement : [AXUIElement]]
    private var app: Element?
    private var rootId: AXUIElement?
    
    private var cachedHintableChildrenCountById: [AXUIElement : Int]?
    
    init() {
        elementsById = [:]
        childrenById = [:]
    }
    
    lazy private var appCustomization = app?.ui.appCustom
    
    func insert(_ element: Element, parentId: AXUIElement?) -> Bool {
        let isRoot = parentId == nil

        if find(element.rawElement) != nil { return false }
        if let parentId = parentId {
            if find(parentId) == nil { return false }
        }
        
        if isRoot {
            if self.rootId != nil { return false }
            self.rootId = element.rawElement
            app = element.parent
        }

        elementsById[element.rawElement] = element
        
        if let parentId = parentId {
            addChild(parentId, childId: element.rawElement)
        }

        return true
    }
    
    private func addChild(_ id: AXUIElement, childId: AXUIElement) {
        guard let _ = find(id),
              let _ = find(childId) else { return }
        
        if childrenById[id] == nil {
            childrenById[id] = []
        }
        
        childrenById[id]!.append(childId)
    }
    
    func find(_ id: AXUIElement) -> Element? {
        elementsById[id]
    }
    
    func query() -> [Element]? {
        guard let rootId = rootId,
              let rootElement = elementsById[rootId]
        else { return nil }
        
        self.cachedHintableChildrenCountById = [:]
        
        var results: [Element] = []
        var stack: [Element] = [rootElement]
        
        while let element = stack.popLast() {
            stack.append(contentsOf: customizationIgnored(element))
            
            if isHintable(element) {
                if appCustomization == .accessibilityInspector {
                    repairAccessibilityInspector(element)
                }
                results.append(element)
            }
            
            let children = self.children(element.rawElement)
            for child in (children ?? []) {
                stack.append(child)
            }
        }
        
        return results
    }
    
    func children(_ id: AXUIElement) -> [Element]? {
        guard let childIds = childrenById[id] else { return nil }
        return childIds.map { elementsById[$0]! }
    }
    
    private func isHintable(_ element: Element) -> Bool {
        let frame = element.frame
        // [Xcode] `AXSplitter` width not zero, height is zero
        if frame.isNull {
            os_log("⚠️ [isHintable] frame is empty or null of element: %@", element.description)
            return false
        }
        /// - Tag: FIXME_CL2 [[CLion]] 中没 Actions
        if ["AXButton", "AXRadioButton", ].contains(element.role) {
            return true
        } else if element.role == "AXStaticText"  { 
            if let app = appCustomization, AppCustomization.needStaticText.contains(app) {
                return true
            }
        } else if element.role == "AXUnknown" { // HotKey: Alfred-Preferences, Dash
            if appCustomization == .pathFinder {
                return false
            }
            return true
        } else if element.role == "AXScrollArea" || element.role == "AXTextArea" ||
                  element.role == "AXSplitter"
        {
            return true
        } else if element.role == "AXWindow" {
            return false
        }
        
        return isActionable(element) || isRowWithoutHintableChildren(element)
    }
    
    private func isActionable(_ element: Element) -> Bool {
        let ignoredActions: Set = [
            "AXShowMenu",
            "AXScrollToVisible",
            "AXShowDefaultUI",
            "AXShowAlternateUI"
        ]
        let actions = Set(element.actions).subtracting(ignoredActions)
        return actions.count > 0
    }
    
    /// - Tag: FIXME_TO1
    /// - Tag: FIXME_XC2 
    private func isRowWithoutHintableChildren(_ element: Element) -> Bool {
        /// - Tag: FIXME_TO1
        element.role == "AXRow" // && hintableChildrenCount(element) == 0 
        || (element.role == "AXGroup" && hintableChildrenCount(element) == 0 ) /// - Tag: FIXME_XC2 
    }
    
    private func hintableChildrenCount(_ element: Element) -> Int {
        if self.cachedHintableChildrenCountById == nil {
            fatalError()
        }
        
        if let hintableChildrenCount = cachedHintableChildrenCountById![element.rawElement] {
            return hintableChildrenCount
        }

        let children = self.children(element.rawElement) ?? []
        let hintableChildrenCount = children
            .map { self.hintableChildrenCount($0) + (isHintable($0) ? 1 : 0) }
            .reduce(0, +)
        
        self.cachedHintableChildrenCountById![element.rawElement] = hintableChildrenCount
        return hintableChildrenCount
    }
    
    private func customizationIgnored(_ element: Element) -> [Element] {
        if appCustomization == .xcode {
            return customizationXcodeIgnored(element)
        }
        return []
    }
    
    /// - Tag: FIXME_XC1
    private func customizationXcodeIgnored(_ element: Element)  -> [Element] {
        var r = [Element]()
        if element.role == "AXGroup" {
            if let id: String = try? element.ui.attribute(.identifier),
               id == "debug area",
               let app = app 
            {
                let frame = element.frame
                // Show the Variables View
                let x1 = Float(frame.maxX - 47 + 10)
                let y1 = Float(frame.maxY - 25 + 10)
                var xElement: AXUIElement?
                var error = AXUIElementCopyElementAtPosition(app.rawElement, x1, y1, &xElement)
                if error == .success, let xElement = xElement,
                    let element = Element(rawElement: xElement) {
                    r.append(element)
                }
                
                // Show the Console
                let x2 = Float(frame.maxX - 26 + 10)
                error = AXUIElementCopyElementAtPosition(app.rawElement, x2, y1, &xElement)
                if error == .success, let xElement = xElement,
                   let element = Element(rawElement: xElement) {
                   r.append(element)
               }
            }
        }
        return r
    }
    
    private func repairAccessibilityInspector(_ element: Element) {
        guard element.frame.size == .zero, 
                element.role == "AXPopUpButton" else { return }
        
        let origin = element.frame.origin
        let newOigin = CGPoint(x: origin.x, y: origin.y - 20)
        let size = CGSize(width: 20, height: 20)
        element.repair(frame: CGRect(origin: newOigin, size: size))
    }
}
