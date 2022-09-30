//
//  HintsViewController.swift
//  Vimac
//
//  Created by Dexter Leng on 24/2/21.
//  Copyright © 2021 Dexter Leng. All rights reserved.
//

import Cocoa
import AXSwift

class HintsViewController: NSViewController {
    let hints: [Hint]
    let textSize: CGFloat
    var typed: String

    var hintViews: [HintView]!
    let modifiers: ClickModifiers
    
    init(hints: [Hint], textSize: CGFloat, typed: String = "", modifiers: ClickModifiers) {
        self.hints = hints
        self.textSize = textSize
        self.typed = typed
        self.modifiers = modifiers
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError()
    }
    
    override func loadView() {
        self.view = NSView()
    }

    override func viewDidAppear() {
        super.viewDidAppear()
        
        self.hintViews = hints
            .map { renderHint($0, modifiers: modifiers) }
            .compactMap({ $0 })

        for hintView in self.hintViews {
            self.view.addSubview(hintView)
        }
    }
    
    func updateTyped(typed: String) {
        guard let hintViews = self.hintViews else { return }
        
        self.typed = typed
        hintViews.forEach { hintView in
            hintView.isHidden = true
            if hintView.hintTextView!.stringValue.starts(with: typed.uppercased()) {
                hintView.updateTypedText(typed: typed)
                hintView.isHidden = false
            }
        }
    }
    
    func rotateHints() {
        for hintView in hintViews {
            hintView.removeFromSuperview()
        }
        
        let shuffledHintViews = hintViews.shuffled()
        for hintView in shuffledHintViews {
            self.view.addSubview(hintView)
        }
        self.hintViews = shuffledHintViews
    }

    /// are you changing the location where hints are rendered?
    /// make sure to update HintModeController#performHintAction as well
    /// 
    /// - Tag: FIXME_HV1
    func renderHint(_ hint: Hint, modifiers: ClickModifiers) -> HintView? {
        let view = HintView(associatedElement: hint.element, hintTextSize: CGFloat(textSize), hintText: hint.text, typedHintText: "")
        guard let elementFrame = self.elementFrame(hint.element) else { return nil }
        
        let hintOrigin: NSPoint = {
            let viewSize = view.intrinsicContentSize
            // position hint on bottom-left of AXLinks (see #373)
            if !modifiers.linkCenter,
               hint.element.role == "AXLink",
               let _: URL = try? UIElement(hint.element.rawElement).attribute(.url)
            {
                let y = elementFrame.origin.y - viewSize.height / 2
                return CGPoint(x: elementFrame.origin.x, y: y < 0 ? 0 : y)
            }

            // position hint on center of element
            let elementCenter = GeometryUtils.center(elementFrame)
            let x = elementCenter.x - (viewSize.width / 2)
            let y = elementCenter.y - viewSize.height
            return NSPoint( x: x < 0 ? 0 : x, y: y < 0 ? 0 : y)
        }()

        if hintOrigin.x.isNaN || hintOrigin.y.isNaN {
            return nil
        }

        view.frame.origin = hintOrigin
        return view
    }
    
    func elementFrame(_ element: Element) -> NSRect? {
        guard let window = self.view.window else { return nil }

        let globalFrame = GeometryUtils.convertAXFrameToGlobal(
            element.clippedFrame ?? element.frame)
        let windowFrame = window.convertFromScreen(globalFrame)
        let viewFrame = window.contentView?.convert(windowFrame, to: self.view)
        
        return viewFrame
    }
}

class WindowHintsViewController: NSViewController {
    let hints: [WindowHint]
    var typed: String

    var hintViews: [WindowHintView]!
    
    init(hints: [WindowHint], typed: String = "") {
        self.hints = hints
        self.typed = typed
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError()
    }
    
    override func loadView() {
        self.view = NSView()
    }

    override func viewDidAppear() {
        super.viewDidAppear()
        
        self.hintViews = hints
            .map { renderHint($0) }
            .compactMap({ $0 })

        for hintView in self.hintViews {
            self.view.addSubview(hintView)
        }
    }
    
    func updateTyped(typed: String) {
        guard let hintViews = self.hintViews else { return }
        
        self.typed = typed
        hintViews.forEach { hintView in
            hintView.isHidden = true
            if hintView.hintTextView!.stringValue.starts(with: typed.uppercased()) {
                hintView.updateTypedText(typed: typed)
                hintView.isHidden = false
            }
        }
    }
    
    func rotateHints() {
        for hintView in hintViews {
            hintView.removeFromSuperview()
        }
        
        let shuffledHintViews = hintViews.shuffled()
        for hintView in shuffledHintViews {
            self.view.addSubview(hintView)
        }
        self.hintViews = shuffledHintViews
    }

    func renderHint(_ hint: WindowHint) -> WindowHintView? {
        guard let window = self.view.window else { return nil }
        
        let view = WindowHintView(associatedElement: hint.window.ax, hintText: hint.text, typedHintText: "")
        
        guard let visiblePoint: NSPoint = {
            let axFrame = NSRect(origin: hint.window.visiblePoint, size: .zero)
            let globalFrame = GeometryUtils.convertAXFrameToGlobal(axFrame)
            let windowFrame = window.convertFromScreen(globalFrame)
            let viewFrame = window.contentView?.convert(windowFrame, to: self.view)
            return viewFrame?.origin
        }() else {
            return nil
        }
        
        let hintOrigin: NSPoint = {
            return NSPoint(
                x: visiblePoint.x - (view.intrinsicContentSize.width / 2),
                y: visiblePoint.y - (view.intrinsicContentSize.height / 2)
            )
        }()

        if hintOrigin.x.isNaN || hintOrigin.y.isNaN {
            return nil
        }

        view.frame.origin = hintOrigin
        return view
    }
    
    func elementFrame(_ element: Element) -> NSRect? {
        guard let window = self.view.window else { return nil }

        let globalFrame = GeometryUtils.convertAXFrameToGlobal(
            element.clippedFrame ?? element.frame)
        let windowFrame = window.convertFromScreen(globalFrame)
        let viewFrame = window.contentView?.convert(windowFrame, to: self.view)
        
        return viewFrame
    }
}
