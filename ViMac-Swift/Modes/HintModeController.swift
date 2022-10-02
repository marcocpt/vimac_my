//
//  HintModeController.swift
//  Vimac
//
//  Created by Dexter Leng on 21/3/21.
//  Copyright © 2021 Dexter Leng. All rights reserved.
//

import Cocoa
import RxSwift
import os
import Segment
import Preferences

extension NSEvent {
    static func localEventMonitor(matching: EventTypeMask) -> Observable<NSEvent> {
        Observable.create({ observer in
            let keyMonitor = NSEvent.addLocalMonitorForEvents(matching: matching, handler: { event -> NSEvent? in
                observer.onNext(event)
                // return nil to prevent the event from being dispatched
                // this removes the "doot doot" sound when typing with CMD / CTRL held down
                return nil
            })!

            let cancel = Disposables.create {
                NSEvent.removeMonitor(keyMonitor)
            }
            return cancel
        })
    }
    
    static func suppressingGlobalEventMonitor(matching: CGEventMask) -> Observable<NSEvent> {
        Observable.create({ observer in
            let tap = GlobalEventTap.init(eventMask: matching, placement: .tailAppendEventTap, onEvent: { cgEvent -> CGEvent? in
                guard let nsEvent = NSEvent(cgEvent: cgEvent) else {
                    return cgEvent
                }
                
                observer.onNext(nsEvent)
                
                return nil
            })
            
            tap.enable()

            let cancel = Disposables.create {
                tap.disable()
            }
            return cancel
        })
    }
}

enum HintModeInputIntent: Equatable {
    case autoMenu
    case rotate
    case exit
    case backspace
    case advance(by: String, action: HintAction)

    case reload
    case lock
    case center
    case grid

    case optionModifier
    case shiftModifier
    case commandModifier
    case controlModifier

    case rightClick
    case singleClick
    case doubleClick
    case tripleClick

    case drag
    case move

    case showHelp
    case showPreferences

    static let notState: [HintModeInputIntent] = [.rotate, .exit, .backspace, .showHelp, .showPreferences]
    
    static func from(event: NSEvent) -> HintModeInputIntent? {
        if event.type != .keyDown { return nil }
        let modifierkeys = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        if event.keyCode == kVK_Escape ||
            (event.keyCode == kVK_ANSI_LeftBracket && modifierkeys == .control) {
            return .exit
        }
        if event.keyCode == kVK_Delete { return .backspace }
        if event.keyCode == kVK_Tab { return .rotate }
        
        if event.keyCode == kVK_ANSI_Semicolon { return .move } // ";"
        if event.keyCode == kVK_ANSI_Backslash { return .drag } // "\"
        if event.keyCode == kVK_ANSI_Slash { // "/"
            if modifierkeys == .shift {
                return .showHelp
            } else {
                return .autoMenu
            }
        } 
        if event.keyCode == kVK_ANSI_Comma { return .showPreferences } // ","
        if event.keyCode == kVK_ANSI_Grave { return .center } // "`"
        if event.keyCode == kVK_ANSI_Equal { return .grid }
        
        if event.keyCode == kVK_Space { return .rightClick }

        if event.keyCode == kVK_ANSI_R { return .reload }
        if event.keyCode == kVK_ANSI_S { return .singleClick }
        if event.keyCode == kVK_ANSI_T { return .tripleClick }
        if event.keyCode == kVK_ANSI_U { return .lock }
        if event.keyCode == kVK_ANSI_V { return .doubleClick }
        if event.keyCode == kVK_ANSI_W { return .shiftModifier }
        if event.keyCode == kVK_ANSI_X { return .commandModifier }
        if event.keyCode == kVK_ANSI_Y { return .optionModifier }
        if event.keyCode == kVK_ANSI_Z { return .controlModifier }

        if let characters = event.charactersIgnoringModifiers {
            let action: HintAction = {
                if modifierkeys == .shift {
                    return .rightClick
                } else if modifierkeys == .command {
                    return .doubleLeftClick
                } else if modifierkeys == .option {
                    return .move
                } else {
                    return .leftClick
                }
            }()
            return .advance(by: characters, action: action)
        }

        return nil
    }
}

// a view controller that has a single view controller child that can be swapped out.
class ContentViewController: NSViewController {
    init() {
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError()
    }

    override func loadView() {
        self.view = NSView()        
    }

    func setChildViewController(_ vc: NSViewController) {
        assert(self.children.count <= 1)
        removeChildViewController()

        self.addChild(vc)
        vc.view.frame = self.view.frame
        self.view.addSubview(vc.view)
    }

    func removeChildViewController() {
        guard let childVC = self.children.first else { return }
        childVC.view.removeFromSuperview()
        childVC.removeFromParent()
    }
}

struct Hint {
    let element: Element
    let text: String
}

enum HintAction: String {
    case leftClick
    case rightClick
    case doubleLeftClick
    case move
}

class HintModeUserInterface {
    let window: Element?
    let windowController: OverlayWindowController
    let contentViewController: ContentViewController
    var hintsViewController: HintsViewController?

    let textSize = UserPreferences.HintMode.TextSizeProperty.readAsFloat()

    init(window: Element?) {
        self.window = window
        self.windowController = OverlayWindowController()
        self.windowController.window = NonKeyOverlayWindow()
        self.contentViewController = ContentViewController()
        self.windowController.window?.contentViewController = self.contentViewController

        let _frame = frame()
        self.windowController.fitToFrame(_frame)
    }
    
    func frame() -> NSRect {
        guard let window = window else {
            return NSScreen.main!.frame
        }

        let windowFrame = GeometryUtils.convertAXFrameToGlobal(window.frame)

        // expected: When an active window is fullscreen in a non-primary display, NSScreen.main returns the non-primary display
        // actual: it returns the primary display
        // this is a workaround for that edge case
        let fullscreenScreen = NSScreen.screens.first(where: { $0.frame == windowFrame })
        if let fullscreenScreen = fullscreenScreen {
            return fullscreenScreen.frame
        }
        
        // a window can extend outside the screen it belongs to (NSScreen.main)
        // it is visible in other screens if the "Displays have separate spaces" option is disabled
        return windowFrame.union(NSScreen.main!.frame)
    }

    func show() {
        self.windowController.showWindow(nil)
        self.windowController.window?.orderFront(nil)
    }

    func hide() {
        self.contentViewController.view.removeFromSuperview()
        self.windowController.window?.contentViewController = nil
        self.windowController.close()
    }

    func switchShowHelp(with info: String, forceOn: Bool = false) {
        guard let hintsViewController = hintsViewController else { return }
        let helpView = hintsViewController.helpView
        if forceOn || helpView.isHidden {
            let fontSize: CGFloat = 13
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
                let bounds = hintsViewController.view.bounds
                let size = helpView.frame.size
                return CGPoint(x: bounds.midX - size.width / 2, y: bounds.midY - size.height / 2)
            }()
            helpView.frame.origin = origin
            print("new helpView.frame: \(helpView.frame)")
        } else {
            helpView.isHidden = true
        }
    }
    
    func setHints(hints: [Hint], modifiers: ClickModifiers) {
        self.hintsViewController = HintsViewController(hints: hints, textSize: CGFloat(textSize), typed: "", modifiers: modifiers)
        self.contentViewController.setChildViewController(self.hintsViewController!)
    }

    func updateInput(input: String) {
        guard let hintsViewController = self.hintsViewController else { return }
        hintsViewController.updateTyped(typed: input)
    }

    func rotateHints() {
        guard let hintsViewController = self.hintsViewController else { return }
        hintsViewController.rotateHints()
    }
}

class WindowHintsUserInterface {
    var windowHints: [WindowHint]?
    var wcVcPairs: [(OverlayWindowController, WindowHintsViewController)]?
    
    func show() {
        guard let windowHints = windowHints else {
            return
        }
        
        var windowHintsByScreen: [NSScreen : [WindowHint]] = [:]
        for windowHint in windowHints {
            // window belongs to screen where its top-left lies
            let windowFrame = GeometryUtils.convertAXFrameToGlobal(windowHint.window.ax.frame)
            if let screen = NSScreen.screens.first(where: { $0.frame.contains(GeometryUtils.center(windowFrame)) }) {
                if windowHintsByScreen[screen] == nil {
                    windowHintsByScreen[screen] = []
                }
                windowHintsByScreen[screen]!.append(windowHint)
            }
        }
        
        var pairs: [(OverlayWindowController, WindowHintsViewController)] = []
        for (screen, windowHints) in windowHintsByScreen {

            let windowController = OverlayWindowController()
            windowController.window = NonKeyOverlayWindow()
            let windowHintsViewController = WindowHintsViewController(hints: windowHints)
            
            windowController.window?.contentViewController = windowHintsViewController
            windowController.fitToFrame(screen.frame)
            
            pairs.append((windowController, windowHintsViewController))
        }
        
        self.wcVcPairs = pairs
        
        for (wc, _) in pairs {
            wc.showWindow(nil)
            wc.window?.orderFront(nil)
        }
    }
    
    func hide() {
        for (wc, vc) in (self.wcVcPairs ?? []) {
            vc.view.removeFromSuperview()
            wc.window?.contentViewController = nil
            wc.close()
        }
    }
    
    func updateInput(input: String) {
        for (_, vc) in (self.wcVcPairs ?? []) {
            vc.updateTyped(typed: input)
        }
    }

}

class ClickModifiers {
    var option = false
    var shift = false
    var command = false
    var control = false

    /// 只在 left 时有效
    var clicks = 1
    /// right 不考虑 clicks 的值
    var right = false
    var drag = false
    var move = false

    var lock = false
    var linkCenter = false
    var grid = false
}

class HintModeController: ModeController {
    weak var delegate: ModeControllerDelegate?
    private var activated = false

    var modifiers: ClickModifiers

    private let startTime = CFAbsoluteTimeGetCurrent()
    private let disposeBag = DisposeBag()

    let hintCharacters = UserPreferences.HintMode.CustomCharactersProperty.read()
    
    private var ui: HintModeUserInterface?
    private var windowHintsUi: WindowHintsUserInterface?
    /// Activated keyboard input information
    private lazy var input = ""
    private var hints: [Hint]?
    private var windowHints: [WindowHint]?
    
    let app: NSRunningApplication?
    let window: Element?
    let menu: Element?
    
    init(app: NSRunningApplication?, window: Element?, menu: Element?, modifiers: ClickModifiers? = nil) {
        self.app = app
        self.window = window
        self.menu = menu
        self.modifiers = modifiers ?? ClickModifiers()
    }

    func activate() {
        if activated { return }
        activated = true
        
        HideCursorGlobally.hide()
        
        self.input = ""
        self.ui = HintModeUserInterface(window: self.window)
        self.ui!.show()
        
        self.queryHints(
            onSuccess: { [weak self] hints in
                guard let self = self else { return }
                self.onHintQuerySuccess(hints: hints)
            },
            onError: { [weak self] e in
                self?.deactivate()
            }
        )
        
        self.queryWindowHints(onComplete: { [weak self] windowHints in
            guard let self = self else { return }
            
            let windowHintsUi = WindowHintsUserInterface()
            windowHintsUi.windowHints = windowHints
            windowHintsUi.show()
            self.windowHintsUi = windowHintsUi
            self.windowHints = windowHints
        })
    }
    
    func deactivate() {
        if !activated { return }

        activated = false
        
        Analytics.shared().track("Hint Mode Deactivated", properties: [
            "Target Application": self.app?.bundleIdentifier as Any
        ])
        
        HideCursorGlobally.unhide()
        
        windowHintsUi?.hide()
        self.windowHintsUi = nil
        
        ui?.hide()
        self.ui = nil
        
        self.delegate?.modeDeactivated(controller: self)
    }
    
    func onHintQuerySuccess(hints: [Hint]) {
        guard let ui = ui else { return }
        
        self.hints = hints
        ui.setHints(hints: hints, modifiers: modifiers)
        
        listenForKeyPress(onEvent: { [weak self] event in
            self?.onKeyPress(event: event)
        })
    }
    
    private func onKeyPress(event: NSEvent) {
        guard let intent = HintModeInputIntent.from(event: event) else { return }

        switch intent {
        case .autoMenu:
            os_log("[Hint Mode] Auto menu")
            delegate?.switchAutoMenu()
        case .exit:
            self.deactivate()
        case .rotate:
            guard let ui = ui else { return }
            Analytics.shared().track("Hint Mode Rotated Hints", properties: [
                "Target Application": self.app?.bundleIdentifier as Any
            ])
            ui.rotateHints()
        case .lock:
            modifiers.lock = !modifiers.lock
            os_log("[Hint Mode] Lock Modifier %@", String(modifiers.lock))
        case .reload:
            self.deactivate()
            let delegate = NSApplication.shared.delegate as! AppDelegate
            let m = modifiers
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                delegate.modeCoordinator.setHintMode(mechanism: "Reload", modifiers: m)
                os_log("[Hint Mode] Reload")
            }
        case .center:
            self.deactivate()
            modifiers.linkCenter = !modifiers.linkCenter
            let delegate = NSApplication.shared.delegate as! AppDelegate
            delegate.modeCoordinator.setHintMode(mechanism: "Center", modifiers: modifiers)
            os_log("[Hint Mode] Center")

        case .grid:
            self.deactivate()
            modifiers.grid = !modifiers.grid
            let delegate = NSApplication.shared.delegate as! AppDelegate
            delegate.modeCoordinator.setHintMode(mechanism: "Grid", modifiers: modifiers)
            os_log("[Hint Mode] TODO: Grid")

        case .optionModifier:
            modifiers.option = !modifiers.option
            os_log("[Hint Mode] Option Modifier %@", String(modifiers.option))
        case .shiftModifier:
            modifiers.shift = !modifiers.shift
            os_log("[Hint Mode] Shift Modifier %@", String(modifiers.shift))
        case .commandModifier:
            modifiers.command = !modifiers.command
            os_log("[Hint Mode] Command Modifier %@", String(modifiers.command))
        case .controlModifier:
            modifiers.control = !modifiers.control
            os_log("[Hint Mode] Control Modifier %@", String(modifiers.control))
        case .rightClick:
            modifiers.right = !modifiers.right
            modifiers.move = false
            os_log("[Hint Mode] Left|Right Switch to %@", String(modifiers.right ? "right" : "left" ))
        case .singleClick:
            modifiers.clicks = 1
            os_log("[Hint Mode] Single Click")
        case .doubleClick:
            modifiers.clicks = 2
            os_log("[Hint Mode] Double Click")
        case .tripleClick:
            modifiers.clicks = 3
            os_log("[Hint Mode] Triple Click")

        case .drag:
            modifiers.drag = !modifiers.drag
            os_log("[Hint Mode] TODO: Drag %@", String(modifiers.drag))
            
        case .move:
            modifiers.move = !modifiers.move
            os_log("[Hint Mode] Move %@", String(modifiers.move))

        case .showHelp:
            os_log("[Hint Mode] TODO: Show Help")
            ui?.switchShowHelp(with: helpInfo)
        case .showPreferences:
            (NSApp.delegate as? AppDelegate)?.preferencesWindowController.show()

        case .backspace:
            _ = input.popLast()
            ui?.updateInput(input: input)
            windowHintsUi?.updateInput(input: input)
        case .advance(let by, let action):
            let newInput = input + by
            input = newInput
            
            ui?.updateInput(input: newInput)
            windowHintsUi?.updateInput(input: newInput)

            if let matchingWindowHint = windowHints?.first(where: { $0.text.starts(with: newInput.uppercased() )}) {
                Analytics.shared().track("Hint Mode Action Performed", properties: [
                    "Target Application": app?.bundleIdentifier as Any,
                    "Hint Action": "Window Raised"
                ])
                self.deactivate()
                focusWindow(window: matchingWindowHint.window.ax.rawElement, pid: matchingWindowHint.window.cg.pid)
                return
            }

            guard let hints = hints else { return }

            let hintsWithInputAsPrefix = hints.filter { $0.text.starts(with: newInput.uppercased()) }

            if hintsWithInputAsPrefix.count == 0 {
                Analytics.shared().track("Hint Mode Deadend", properties: [
                    "Target Application": app?.bundleIdentifier as Any
                ])
                self.deactivate()
                return
            }

            let matchingHint = hintsWithInputAsPrefix.first(where: { $0.text == newInput.uppercased() })

            if let matchingHint = matchingHint {
                Analytics.shared().track("Hint Mode Action Performed", properties: [
                    "Target Application": app?.bundleIdentifier as Any,
                    "Hint Action": action.rawValue
                ])
                
                self.deactivate()
                performHintAction(matchingHint, action: action, modifiers: modifiers)

                if modifiers.lock {
                    let m = self.modifiers
                    // Some menu elements do not appear immediately
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        let delegate = NSApplication.shared.delegate as! AppDelegate
                        delegate.modeCoordinator.setHintMode(mechanism: "Lock", modifiers: m)
                    }
                }
            }
            return
        }
        
        if !HintModeInputIntent.notState.contains(intent) {
            ui?.switchShowHelp(with: helpInfo, forceOn: true)
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                self.ui?.switchShowHelp(with: self.helpInfo)
            }
        }
    }
    
    // activate window without bringing forward other windows of the same app
    // uses the depreciated SetFrontProcessWithOptions since it has the above behaviour
    private func focusWindow(window: AXUIElement, pid: pid_t) {
        if AXUIElementSetAttributeValue(window, kAXMainAttribute as CFString, kCFBooleanTrue) != .success {
            return
        }
        HideCursorGlobally._activateWindow(pid)

    }
    
    private func queryHints(onSuccess: @escaping ([Hint]) -> Void, onError: @escaping (Error) -> Void) {
        HintModeQueryService.init(app: app, window: window, menu: menu, hintCharacters: hintCharacters).perform()
            .toArray()
            .observeOn(MainScheduler.instance)
            .do(onSuccess: { _ in self.logQueryTime() })
            .do(onError: { e in self.logError(e) })
            .subscribe(
                onSuccess: { onSuccess($0) },
                onError: { onError($0) }
            )
            .disposed(by: disposeBag)
    }
    
    private func queryWindowHints(onComplete: @escaping ([WindowHint]) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            let windows = QueryHintableWindowsService.init()
                .perform()
            var windowHints: [WindowHint] = []
            var count = 1
            for window in windows {
                let hint = WindowHint(window: window, text: String(count))
                windowHints.append(hint)
                count += 1
            }
            
            DispatchQueue.main.async {
                onComplete(windowHints)
            }
        }
    }

    private func listenForKeyPress(onEvent: @escaping (NSEvent) -> Void) {
        let mask = CGEventMask(1 << CGEventType.keyDown.rawValue)
        NSEvent.suppressingGlobalEventMonitor(matching: mask)
            .observeOn(MainScheduler.instance)
            .subscribe(onNext: { event in
                onEvent(event)
            })
            .disposed(by: disposeBag)
    }
    
    private func performHintAction(_ hint: Hint, action: HintAction, modifiers: ClickModifiers) {
        let element = hint.element
        let clickPosition: NSPoint = {
            // hints are shown at the bottom-left for AXLinks (see HintsViewController#renderHint),
            // so a click is performed there
            if !modifiers.linkCenter,
               element.role == "AXLink",
               let _: URL = try? UIElement(element.rawElement).attribute(.url)
            {
                return NSPoint(
                    // tiny offset in case clicking on the edge of the element does nothing
                    x: element.frame.origin.x + 5,
                    y: element.frame.origin.y + element.frame.height - 5
                )
            }
            return GeometryUtils.center(element.frame)
        }()

        Utils.moveMouse(position: clickPosition)

        if action == .rightClick || modifiers.right {
            Utils.rightClickMouse(position: clickPosition)
        } else if action == .doubleLeftClick || modifiers.clicks == 2 {
            Utils.doubleLeftClickMouse(position: clickPosition)
        } else if modifiers.clicks == 3 {
            Utils.tripleLeftClickMouse(position: clickPosition)
        } else if action == .move || modifiers.move {
            Utils.moveMouse(position: clickPosition)
        } else if modifiers.command {
            Utils.leftClickMouse(position: clickPosition, flags: .maskCommand)
        } else if modifiers.control {
            Utils.leftClickMouse(position: clickPosition, flags: .maskControl)
        } else if modifiers.shift {
            Utils.leftClickMouse(position: clickPosition, flags: .maskShift)
        } else if modifiers.option {
            Utils.leftClickMouse(position: clickPosition, flags: .maskAlternate)
        } else {
            Utils.leftClickMouse(position: clickPosition)
        }
    }
    
    private func logQueryTime() {
        let timeElapsed = CFAbsoluteTimeGetCurrent() - self.startTime
        os_log("[Hint mode] query time: %@", log: Log.accessibility, String(describing: timeElapsed))
    }

    private func logError(_ e: Error) {
        os_log("[Hint mode] query error: %@", log: Log.accessibility, String(describing: e))
    }
    
    private var helpInfo: String {
//        let spaceLine = "                            |"
        let spaceLine = "                            │"
        let tableLine = "────────────────────────────┼──────────────────────────────┤"
        let info1 =  """
Left|RightClick   , |⇧   \((!modifiers.right).symbol) │
SingleClick      s       \((modifiers.clicks == 1).symbol) │
DoubleClick      v, ⌘    \((modifiers.clicks == 2).symbol) │
TripleClick      t       \((modifiers.clicks == 3).symbol) │
\(spaceLine)
AutoMenu(+)      /       \((delegate?.autoMenuState ?? false).symbol) │
Center           `       \(modifiers.linkCenter.symbol) │
Lock             u       \(modifiers.lock.symbol) │
Drag             \\       \(modifiers.drag.symbol) │
Move             ;, ⌥    \(modifiers.move.symbol) │
\(spaceLine)
Help         ⇧/         │
"""
        let info2 = """
⇧                w       \(modifiers.shift.symbol) │
⌘                x       \(modifiers.command.symbol) │
⌥                y       \(modifiers.option.symbol) │
^                z       \(modifiers.control.symbol) │
\(spaceLine)
Backspace        Del        │
Exit             Esc, ^[    │
Grid             =          │
Reload           r          │
Rotate           ⇥          │
\(spaceLine)
Preferences  ,          │
"""
        let lines1 = info1.split(separator: "\n")
        let lines2 = info2.split(separator: "\n")
        let lines1Count = lines1.count
        let lines2Count = lines2.count

        assert(lines1Count >= lines2Count)
        
        return (0 ..< lines1Count).map {
            let line1 = lines1[$0]
            guard $0 < lines2Count else {
                return tableLine
            }
            let line2 = lines2[$0]
            if line1 == line2 {
                return "\n"
            }
            return "\(line1)  \(line2)"
        }.joined(separator: "\n")
    }
}

import AXSwift

struct WindowInfo {
    let pid: pid_t
    let frame: NSRect
    let layer: Int
    let rawInfo: [String: AnyObject]
    let number: CGWindowID
}

struct Window {
    let cg: WindowInfo
    let ax: Element
    let visiblePoint: NSPoint
}

struct WindowHint {
    let window: Window
    let text: String
}

class QueryHintableWindowsService {
    func perform() -> [Window] {
        let cgWindows = fetchCgWindows()
                            // remove menu bar items
                            .filter { $0.frame.height > 50 }
                            // remove floating windows
                            .filter { $0.layer == 0 }
        var axWindowsByPid = fetchAxWindowsByPid()
        var windows: [Window] = []
        
        for cgWindow in cgWindows {
            guard let axWindows = axWindowsByPid[cgWindow.pid] else { continue }
            // best guess based on frame and order
            // TODO: look into associating by title, ideally without screen recording permission
            guard let associatedAxWindowIndex = axWindows.firstIndex(where: { $0.frame == cgWindow.frame }) else { continue }
            let axWindow = axWindows[associatedAxWindowIndex]
            
            // remove the ax window so other cgWindows cannot match with it
            axWindowsByPid[cgWindow.pid]!.remove(at: associatedAxWindowIndex)

            let center = GeometryUtils.center(axWindow.frame)
            let isVisibleAtCenter = try? isWindowVisibleAtPoint(window: axWindow.rawElement, x: Float(center.x), y: Float(center.y))
            if isVisibleAtCenter ?? false {
                let window = Window(cg: cgWindow, ax: axWindow, visiblePoint: center)
                windows.append(window)
                continue
            }
            
            let topLeft = NSPoint(
                x: axWindow.frame.origin.x + min(50, axWindow.frame.width),
                y: axWindow.frame.origin.y + min(50, axWindow.frame.height)
            )
            let isVisibleAtTopLeft = try? isWindowVisibleAtPoint(window: axWindow.rawElement, x: Float(topLeft.x), y: Float(topLeft.y))
            if isVisibleAtTopLeft ?? false {
                let window = Window(cg: cgWindow, ax: axWindow, visiblePoint: topLeft)
                windows.append(window)
                continue
            }
        }
        
        if let mainIndex = windows.firstIndex(where: { window in
            let main: Bool? = try? UIElement(window.ax.rawElement).attribute(.main)
            return main ?? false
        }) {
            windows.remove(at: mainIndex)
        }
        
        return windows.sorted(by: { $0.ax.frame.origin.x <  $1.ax.frame.origin.x })
    }

    private func isWindowVisibleAtPoint(window: AXUIElement, x: Float, y: Float) throws -> Bool {
        guard let element = try systemWideElement.elementAtPosition(x, y) else { return false }
        guard let role: String = try element.attribute(.role) else { return false }
        
        var _windowAtPosition: UIElement?
        if role == "AXWindow" {
            _windowAtPosition = element
        } else {
            guard let window: UIElement = try element.attribute(.window) else { return false }
            _windowAtPosition = window
        }
        let windowAtPosition = _windowAtPosition!
        
        return windowAtPosition.element == window
        
    }
    
    // fetches all windows
    // windows are ordered from top to bottom
    private func fetchCgWindows() -> [WindowInfo] {
        let windowInfosRef = CGWindowListCopyWindowInfo(
            CGWindowListOption(rawValue:
                CGWindowListOption.optionOnScreenOnly.rawValue | CGWindowListOption.excludeDesktopElements.rawValue
            ),
            kCGNullWindowID
        )

        var windowInfos: [WindowInfo] = []
        for i in 0..<CFArrayGetCount(windowInfosRef) {
            let lineUnsafePointer: UnsafeRawPointer = CFArrayGetValueAtIndex(windowInfosRef, i)
            let lineRef = unsafeBitCast(lineUnsafePointer, to: CFDictionary.self)
            let dict = lineRef as [NSObject: AnyObject]

            guard let item = dict as? [String: AnyObject] else {
                continue
            }
            
            if let x = item["kCGWindowBounds"]?["X"] as? Int,
                let y = item["kCGWindowBounds"]?["Y"] as? Int,
                let width = item["kCGWindowBounds"]?["Width"] as? Int,
                let height = item["kCGWindowBounds"]?["Height"] as? Int,
                let pid = item["kCGWindowOwnerPID"] as? pid_t,
                let layer = item["kCGWindowLayer"] as? Int,
                let number = item["kCGWindowNumber"] as? CGWindowID {
                let frame = NSRect(x: x, y: y, width: width, height: height)
                windowInfos.append(
                    .init(pid: pid, frame: frame, layer: layer, rawInfo: item, number: number)
                )
            }
        }
        return windowInfos
    }
    
    // ax windows are of the same pid are in descending order
    private func fetchAxWindowsByPid() -> [pid_t : [Element]] {
        let apps = NSWorkspace.shared.runningApplications
        var axWindowsByPid: [pid_t : [Element]] = [:]

        for app in apps {
            if let axApp = Application(forProcessID: app.processIdentifier) {
                if let axWindows = try? axApp.windows() {
                    let elements = axWindows
                        .map({ $0.element })
                        .map({ Element.initialize(rawElement: $0) })
                        .compactMap({ $0 })
                    axWindowsByPid[app.processIdentifier] = elements
                }
            }
        }

        return axWindowsByPid
    }
    
    // groups windows into clusters of intersecting windows
    // windows of the same cluster are in same order as in the original window array input
    private func clusterCgWindows(windows: [WindowInfo]) -> [[WindowInfo]] {
        var windowInfosClusters: [[WindowInfo]] = []
        for windowInfo in windows {
            let clusterIndex = windowInfosClusters.firstIndex(where: { cluster in
                return cluster.contains(where: { clusterWindow in
                    clusterWindow.frame.intersects(windowInfo.frame)
                })
            })

            if let clusterIndex = clusterIndex {
                windowInfosClusters[clusterIndex].append(windowInfo)
            } else {
                let cluster = [windowInfo]
                windowInfosClusters.append(cluster)
            }
        }
        return windowInfosClusters
    }
}

extension Bool {
    var symbol: String {
        self ? "🟢" : "🔴"
    }
}

extension StringProtocol {
    func fix(width: Int, append: Character = " ") -> String {
        let count = self.count
        assert(width >= count)
        if count < width {
            let spaces = String(repeating: append, count: width - count)
            return appending(spaces)
        }
        
        return String(self)
    }
}
