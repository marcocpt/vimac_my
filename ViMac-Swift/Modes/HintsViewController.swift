//
//  HintsViewController.swift
//  Vimac
//
//  Created by Dexter Leng on 24/2/21.
//  Copyright © 2021 Dexter Leng. All rights reserved.
//

import Cocoa
import os
import AXSwift

class HintsViewController: NSViewController {
    let hints: [Hint]
    let textSize: CGFloat
    var typed: String

    var hintViews: [HintView]!
    let modifiers: ClickModifiers
    
    lazy var helpView: NSTextView = {
        let textView = NSTextView()
        textView.wantsLayer = true
        textView.layer?.masksToBounds = true
        textView.layer?.borderWidth = 1
        textView.layer?.borderColor = NSColor.systemGray.cgColor
        view.addSubview(textView)
        
        let size = CGSize(width: 470, height: 200)
        textView.frame = CGRect(origin: .zero, size: size)
        return textView
    }()
    
    init(hints: [Hint], textSize: CGFloat, typed: String = "", modifiers: ClickModifiers) {
        self.hints = hints
        self.textSize = textSize
        self.typed = typed
        self.modifiers = modifiers
        super.init(nibName: nil, bundle: nil)
        view.wantsLayer = true
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
        #if DEBUG
        logHints()
        for hintView in self.hintViews {
            view.addSubview(hintView)
            if let shape = hintView.shape {
                view.layer?.addSublayer(shape)
            }
        }
        #else
        for hintView in self.hintViews {
            self.view.addSubview(hintView)
        }
        #endif
        
        helpView.isHidden = true
    }
    
    override func viewDidDisappear() {
        super.viewDidDisappear()
        helpView.isHidden = true
    }
    
    func updateTyped(typed: String) {
        guard let hintViews = self.hintViews else { return }
        
        self.typed = typed
        hintViews.forEach { hintView in
            hintView.isHidden = true
            hintView.shape?.isHidden = true
            if hintView.hintTextView!.stringValue.starts(with: typed.uppercased()) {
                hintView.updateTypedText(typed: typed)
                hintView.isHidden = false
                hintView.shape?.isHidden = false
            }
        }
    }
    
    func rotateHints() {
        for hintView in hintViews {
            hintView.removeFromSuperview()
            hintView.shape?.removeFromSuperlayer()
        }
        
        let shuffledHintViews = hintViews.shuffled()
        for hintView in shuffledHintViews {
            self.view.addSubview(hintView)
            if let shape = hintView.shape {
                view.layer?.addSublayer(shape)
            }
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
    
    @objc func helpOff() {
        helpView.isHidden = true
    }
    
    func logHints() {
        var roleCounts = [String : Int]()
        hints.forEach {
            let role = $0.element.role
            let key = String(format: "%-2s %@", role.roleKey.cstr!, role)
            if let count = roleCounts[key] {
                roleCounts[key] = count + 1
            } else {
                roleCounts[key] = 1
            }
        }
        let info = roleCounts
            .sorted { $0.1 > $1.1 }
            .map { String(format: "%-3d %@", $0.1, $0.0) }
        os_log("roleCounts: %@", info)
    }
    
    func switchShowHelp(with info: String, forceOn: Bool = false) {
        if forceOn || helpView.isHidden {
            let fontSize: CGFloat = 12
            let fontAttr: [NSFontDescriptor.AttributeName : Any] = [
                .family: "SF Mono",
                .face: "Medium",
                //                .fixedAdvance: fontSize / 2,
                //                .size: fontSize,
            ]
            let descriptor = NSFontDescriptor(fontAttributes: fontAttr)
            let font = NSFont(descriptor: descriptor, size: fontSize)
            let attributes: [NSAttributedString.Key : Any] = [
                .font: font ?? .systemFont(ofSize: fontSize),
                .foregroundColor: NSColor.textColor
            ]
            let attMuString = NSMutableAttributedString(string: info, attributes: attributes)
            helpView.textStorage?.setAttributedString(attMuString)
            
            print("old helpView.frame: \(helpView.frame)")
            helpView.isHidden = false
            helpView.sizeToFit()
            let origin: CGPoint = {
                let bounds = view.bounds
                let size = helpView.frame.size
                return CGPoint(x: bounds.midX - size.width / 2, y: 50)
            }()
            helpView.frame.origin = origin
            print("new helpView.frame: \(helpView.frame)")
        } else {
            helpView.isHidden = true
        }
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
