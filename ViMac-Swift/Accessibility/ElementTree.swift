//
//  ElementTree.swift
//  Vimac
//
//  Created by Dexter Leng on 30/3/21.
//  Copyright © 2021 Dexter Leng. All rights reserved.
//

import Cocoa

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
    
    private var appCustomization: AppCustomization?
    
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
        
        if let bundleID = NSWorkspace.shared.frontmostApplication?.bundleIdentifier {
            appCustomization = AppCustomization(rawValue: bundleID)
        }
        
        while let element = stack.popLast() {
            stack.append(contentsOf: customizationIgnored(element))
            
            if isHintable(element) {
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
        } else if element.role == "AXScrollArea" || element.role == "AXTextArea" {
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
    private func isRowWithoutHintableChildren(_ element: Element) -> Bool {
        /// - Tag: FIXME_TO1
        element.role == "AXRow" // && hintableChildrenCount(element) == 0 
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
               let app = app {
                let frame = element.frame
                // Show the Variables View
                let x1 = Float(frame.maxX - 47 + 10)
                let y1 = Float(frame.maxY - 25 + 10)
                var xElement: AXUIElement?
                var error = _AXUIElementCopyElementAtPositionIncludeIgnored(app.rawElement, x1, y1, &xElement, true)
                if error == .success, let xElement = xElement,
                    let element = Element(rawElement: xElement) {
                    r.append(element)
                }
                
                // Show the Console
                let x2 = Float(frame.maxX - 26 + 10)
                error = _AXUIElementCopyElementAtPositionIncludeIgnored(app.rawElement, x2, y1, &xElement, true)
                if error == .success, let xElement = xElement,
                   let element = Element(rawElement: xElement) {
                   r.append(element)
               }
            }
        }
        return r
    }
}
