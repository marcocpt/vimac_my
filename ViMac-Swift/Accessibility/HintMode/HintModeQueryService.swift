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
        
        #if DEBUG
        var typeCounts = [String: Int]()
        let hints = elements.map {
            let r = $0.role.roleKey
            let currentCount: Int
            if let count = typeCounts[r] { 
                currentCount = count + 1
            } else {
                currentCount = 10
            }
            typeCounts[r] = currentCount
            return Hint(element: $0, text: "\(r)\(currentCount)")
        }
        #else
        let hints = Observable.zip(elements, hintStrings).map { Hint(element: $0, text: $1) }
        #endif
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
                let elements = try? service.perform()
                event(.success(elements ?? []))
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
                print(menu.role)
                let menuItemsOptional: [AXUIElement]? = try? UIElement(menu.rawElement).attribute(.children)
                print(menuItemsOptional?.count)
                let menuItems = menuItemsOptional ?? []
                let menuItemElements = menuItems
                    .map { Element.initialize(rawElement: $0) }
                    .compactMap({ $0 })
                print(menuItemElements)
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
}

extension String {
    var roleKey: String {
        switch self {
        case "AXApplication"        : return "A"
        case "AXButton"             : return "B"
        case "AXCheckBox"           : return "C"
        case "AXDisclosureTriangle" : return "D" // 
        case "AXCell"               : return "E"
        case "AXTextField"          : return "F"
        case "AXGroup"              : return "G" // Logseq: 代码块
        case "AXMenuItem"           : return "I"
        case "AXScrollArea"         : return "J"
            
        case "AXLink"               : return "L"
        case "AXMenuBarItem"        : return "M"
        case "AXMenuButton"         : return "N"
        case "AXOutline"            : return "O"
        case "AXPopUpButton"        : return "P"
        case "AXRow"                : return "Q"
        case "AXRadioButton"        : return "R"
        case "AXStaticText"         : return "S"
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
}


