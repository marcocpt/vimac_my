//
//  HintModeQueryService.swift
//  Vimac
//
//  Created by Dexter Leng on 24/2/21.
//  Copyright © 2021 Dexter Leng. All rights reserved.
//

import Cocoa
import os
import RxSwift
import AXSwift

class HintModeQueryService {
    let app: NSRunningApplication?
    let window: Element?
    let menu: Element?
    let hintCharacters: String
    
    init(app: NSRunningApplication?, window: Element?, menu: Element?, hintCharacters: String) {
        self.app = app
        self.window = window
        self.menu = menu
        self.hintCharacters = hintCharacters
    }
    
    func perform() -> Observable<Hint> {
        let elements = elementObservable().share()
        let elementsArray = elements.toArray()
        let count = elementsArray.map({ $0.count })
        let hintStrings: Observable<String> = count
            .map { AlphabetHints().hintStrings(linkCount: $0, hintCharacters: self.hintCharacters) }
            .asObservable()
            .flatMap({ Observable.from($0) })
        
//        #if DEBUG
//        var typeCounts = [String: Int]()
//        let hints = elements.map {
//            let r = $0.role.roleKey
//            let currentCount: Int
//            if let count = typeCounts[r] { 
//                currentCount = count + 1
//            } else {
//                currentCount = 10
//            }
//            typeCounts[r] = currentCount
//            return Hint(element: $0, text: "\(r)\(currentCount)")
//        }
//        #else
        let hints = Observable.zip(elements, hintStrings).map { Hint(element: $0, text: $1) }
//        #endif
        return hints
    }
    
    private func elementObservable() -> Observable<Element> {
        let nothing: Observable<Element> = Observable.empty()
        
        var menuBarElements = nothing
        if let app = app {
            menuBarElements = Utils.singleToObservable(single: queryMenuBarSingle(app: app))
        }
        
        if let menu = menu {
            return Utils.eagerConcat(observables: [
                menuBarElements,
                Utils.singleToObservable(single: queryMenuBarExtrasSingle()),
                Utils.singleToObservable(single: queryNotificationCenterSingle()),
                Utils.singleToObservable(single: queryOpenedMenuSingle(menu: menu))
            ])
        }
        
        var windowElements = nothing
        if let app = app,
           let window = window {
            windowElements = Utils.singleToObservable(single: queryWindowElementsSingle(app: app, window: window))
        }
        
        return Utils.eagerConcat(observables: [
            Utils.singleToObservable(single: dockElements()),
            menuBarElements,
            Utils.singleToObservable(single: queryMenuBarExtrasSingle()),
            Utils.singleToObservable(single: queryNotificationCenterSingle()),
            windowElements
        ])
    }
    
    private func queryWindowElementsSingle(app: NSRunningApplication, window: Element) -> Single<[Element]> {
        return Single.create(subscribe: { event in
            let thread = Thread.init(block: {
                let service = QueryWindowService.init(app: app, window: window)
                event(.success(service.perform()))
            })
            thread.start()
            return Disposables.create {
                thread.cancel()
            }
        })
    }
    
    private func queryOpenedMenuSingle(menu: Element) -> Single<[Element]> {
        return Single.create(subscribe: { event in
            let thread = Thread.init(block: {
                let menuItemsOptional: [AXUIElement]? = try? UIElement(menu.rawElement).attribute(.children)
                let menuItems = menuItemsOptional ?? []
                let menuItemElements = menuItems
                    .compactMap { Element(rawElement: $0) }
                event(.success(menuItemElements))
            })
            thread.start()
            return Disposables.create {
                thread.cancel()
            }
        })
    }
    
    private func queryMenuBarSingle(app: NSRunningApplication) -> Single<[Element]> {
        return Single.create(subscribe: { event in
            let thread = Thread.init(block: {                
                let service = QueryMenuBarItemsService.init(app: app)
                let elements = try? service.perform()
                event(.success(elements ?? []))
            })
            thread.start()
            return Disposables.create {
                thread.cancel()
            }
        })
    }
    
    private func queryMenuBarExtrasSingle() -> Single<[Element]> {
        return Single.create(subscribe: { event in
            let thread = Thread.init(block: {
                let service = QueryMenuBarExtrasService.init()
                let elements = try? service.perform()
                event(.success(elements ?? []))
            })
            thread.start()
            return Disposables.create {
                thread.cancel()
            }
        })
    }
    
    private func queryNotificationCenterSingle() -> Single<[Element]> {
        return Single.create(subscribe: { event in
            let thread = Thread.init(block: {
                let service = QueryNotificationCenterItemsService.init()
                let elements = try? service.perform()
                event(.success(elements ?? []))
            })
            thread.start()
            return Disposables.create {
                thread.cancel()
            }
        })
    }
    
    private func dockElements() -> Single<[Element]> {
        return Single.create(subscribe: { event in
            let thread = Thread.init(block: {
                let service = QueryDockService.init()
                let elements = service.perform()
                event(.success(elements ?? []))
            })
            thread.start()
            return Disposables.create {
                thread.cancel()
            }
        })
    }
}

extension String {
    var roleKey: String {
        switch self {
        case "AXApplication"        : return "A"
        case "AXButton"             : return "B" // 2
        case "AXCheckBox"           : return "C" // 2
        case "AXDisclosureTriangle" : return "D" // 2
        case "AXCell"               : return "E"
        case "AXTextField"          : return "F"
        case "AXGroup"              : return "G" // Logseq: 代码块
        case "AXMenuItem"           : return "I" //
        case "AXScrollArea"         : return "J"
        case "AXDockItem"           : return "K" // 2
        case "AXLink"               : return "L" // 2
        case "AXMenuBarItem"        : return "M" // 2
        case "AXMenuButton"         : return "N"
        case "AXOutline"            : return "O"
        case "AXPopUpButton"        : return "P" // 2
        case "AXRow"                : return "Q" // 2
        case "AXRadioButton"        : return "R" // 2
        case "AXStaticText"         : return "S" // 2
        case "AXTextArea"           : return "T"
        
        case "AXWindow"             : return "W" // x
            
            
        case "AXBusyIndicator"      : return "BI"
        case "AXBrowser"            : return "BU"
        
        case "AXColumn"             : return "CN"
        case "AXComboBox"           : return "CO" // FreeFileSync
        case "AXColorWell"          : return "CW"
            
        case "AXDrawer"             : return "DR"
        
        case "AXGrowArea"           : return "GA"
        case "AXGrid"               : return "GI"
            
        case "AXHandle"             : return "HA"
        case "AXHelpTag"            : return "HT"
        
        case "AXImage"              : return "IM" // x
        case "AXIncrementor"        : return "IN" // FreeFileSync, Xcode

        case "AXLayoutArea"         : return "LA"
        case "AXLevelIndicator"     : return "LD"
        case "AXLayoutItem"         : return "LI"
        case "AXList"               : return "LS" // VSC; Xcode
            
        case "AXMatte"              : return "MA"
        case "AXMenuBar"            : return "MB"
        
        case "AXMenu"               : return "MU"
            
        case "AXProgressIndicator"  : return "PI"
        case "AXPopover"            : return "PO"
        
        case "AXRadioGroup"         : return "RG"
        case "AXRelevanceIndicator" : return "RI"
        case "AXRulerMarker"        : return "RM"
       
        case "AXRuler"              : return "RU"
        
        case "AXScrollBar"          : return "SB" // Xcode
        case "AXSplitGroup"         : return "SG" // Xcode
        case "AXSheet"              : return "SH"
        case "AXSlider"             : return "SL"
        case "AXSplitter"           : return "SP" // 分割窗口之间的调节线。Path Finder, Xcode
        case "AXSystemWide"         : return "SW"
        
        case "AXToolbar"            : return "TB" // Xcode
        case "AXTable"              : return "TE" // Xcode
        case "AXTabGroup"           : return "TG" // Xcode
        
        case "AXValueIndicator"     : return "VI" // Path Finder: x; Xcode: x
        
        case "AXUnknown"            : return "UK"
            
        case "AXWebArea"            : return "WA" // VSC: x
        default:
            print("unknow: \(self)")
            return "Z"
        }
    }
    
    var roleColor: NSColor {
        switch self {
        case "AXApplication"        : return .systemGreen
        case "AXButton"             : return .systemBlue
        case "AXCheckBox"           : return .systemOrange
        case "AXDisclosureTriangle" : return .systemYellow
        case "AXCell"               : return .systemBrown
        case "AXTextField"          : return .systemPink
        case "AXGroup"              : return .systemPurple
        case "AXMenuItem"           : return .systemTeal
        case "AXScrollArea"         : return .systemMint
            
        case "AXLink"               : return .systemGreen
        case "AXMenuBarItem"        : return .systemBlue
        case "AXMenuButton"         : return .systemOrange
        case "AXOutline"            : return .systemYellow
        case "AXPopUpButton"        : return .systemBrown
        case "AXRow"                : return .systemPink    
        case "AXRadioButton"        : return .systemPurple
        case "AXStaticText"         : return .systemTeal
        case "AXTextArea"           : return .systemMint
            
        default                     : return .systemRed
        }
    }
}


