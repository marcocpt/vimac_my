//
//  TraverseGenericElementService.swift
//  Vimac
//
//  Created by Dexter Leng on 6/9/20.
//  Copyright © 2020 Dexter Leng. All rights reserved.
//

import Cocoa
import os
import AXSwift

class TraverseGenericElementService : TraverseElementService {
    let tree: ElementTree
    let element: Element
    let parent: Element?
    let app: NSRunningApplication
    let windowElement: Element
    let clipBounds: NSRect?
    
    required init(tree: ElementTree, element: Element, parent: Element?, app: NSRunningApplication, windowElement: Element, clipBounds: NSRect?) {
        self.tree = tree
        self.element = element
        self.parent = parent
        self.app = app
        self.windowElement = windowElement
        self.clipBounds = clipBounds
    }
    
    func perform() {
        if !isElementVisible() {
            return
        }
        
        element.setClippedFrame(elementClippedBounds())

        if !tree.insert(element, parentId: parent?.rawElement) { return }
        
        let children: [Element]? = try? getChildren(element)

        children?.forEach { child in
            traverseElement(child)
        }
    }
    /// - Tag: FIXME_AI1
    private func isElementVisible() -> Bool {
        /// - Tag: FIXME_AI1
        if element.frame.size == .zero {
            os_log("⚠️ size zeo of element: %@", element.description)
            return true
        }
        if let clipBounds = clipBounds {
            if !clipBounds.intersects(element.frame) {
                os_log("⚠️ not visible of element: %@", element.description)
                return false
            }
        }
        return true
    }
    
    private func elementClippedBounds() -> NSRect {
        if let clipBounds = clipBounds {
            return clipBounds.intersection(element.frame)
        }
        return element.frame
    }
    
    private func traverseElement(_ element: Element) {
        TraverseElementServiceFinder
            .init(app: app, element: element).find()
            .init(tree: tree, element: element, parent: self.element, app: app, windowElement: windowElement, clipBounds: elementClippedBounds()).perform()
    }

    private func getChildren(_ element: Element) throws -> [Element]? {
        let rawElements: [AXUIElement]? = try {
            if let r = try listChildren(element) { return r }
            if let r = try tabGroupChildren(element) { return r }
            return try UIElement(element.rawElement).attribute(.children)
        }()
        return rawElements?
            .compactMap { Element(rawElement: $0) }
    }
    
    /// - Tag: FIXME_CL2
    private func tabGroupChildren(_ element: Element) throws -> [AXUIElement]? {
        guard element.role == "AXTabGroup" else { return nil }
        
        guard let r: [AXUIElement] = try? element.ui.attribute(.visibleChildren),
              !r.isEmpty else { return nil }
        
        return r
    }
    
    private func listChildren(_ element: Element) throws -> [AXUIElement]? {
        guard element.role == "AXTable" || element.role == "AXOutline" else { return nil }
        if let r: [AXUIElement] = try? UIElement(element.rawElement).attribute(.visibleRows),
           !r.isEmpty
        {
            return r
        }
        
        /// [[IDA]]:  "AXTable" not have "AXVisibleRows" and children is too much!
        return try scanRowChildren(element)
    }
    
    private func scanRowChildren(_ element: Element) throws -> [AXUIElement]? {
        os_log("⚠️ [scanRowChildren] start at element: %@", element.description)
        guard let root = windowElement.parent else { return nil }
        let frame = element.frame
        let minY = frame.minY
        var deltaY = frame.height / 2
        var point = frame.center
        var r = [AXUIElement]()
        var delta: CGFloat = 0
        repeat {
            if let uiElement = try? root.ui.elementForRoot(at: point),
               uiElement.element != element.rawElement,
               let row1Frame: CGRect = try? uiElement.attribute(.frame),
               frame.contains(row1Frame)
            {
                r.append(uiElement.element)
                delta = row1Frame.height
                break
            }
            deltaY /= 2
            point.y -= deltaY
        } while point.y - minY > 5
        
        if r.isEmpty { return nil }
        
        point.y += delta
        let maxY = frame.maxY
        
        repeat {
            guard let uiElement = try? root.ui.elementForRoot(at: point),
                  let rowFrame: CGRect = try? uiElement.attribute(.frame),
                  frame.contains(rowFrame)
            else { break }
            
            r.insert(uiElement.element, at: 0)
            point.y += rowFrame.height
        } while point.y < maxY
        
        point.y = frame.origin.y + deltaY
    
        repeat {
            guard let uiElement = try? root.ui.elementForRoot(at: point),
                  let rowFrame: CGRect = try? uiElement.attribute(.frame),
                  frame.contains(rowFrame)
            else { break }
            
            r.append(uiElement.element)
            point.y -= rowFrame.height
        } while point.y > minY
        
        return r
    }
}

extension CGRect {
    var center: CGPoint {
        CGPoint(x: midX, y: midY)
    }
}
