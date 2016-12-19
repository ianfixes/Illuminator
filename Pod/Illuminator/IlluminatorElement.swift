//
//  IlluminatorElement.swift
//  Illuminator
//
//  Created by Ian Katz on 2016-12-12.
//




enum AbortIlluminatorTree: ErrorType { // swift3: Error {
    case backtrack(data: IlluminatorElement?)
    case eof()
    case parseError(badLine: String)
    case doubleDepth(badLine: String)
}


class IlluminatorElement: Equatable {
    var source = ""                              // input data
    var depth = 0                                // interpretation of whitespace
    var parent: IlluminatorElement?              // linked list
    var children = [IlluminatorElement]()        // tree
    var elementType: XCUIElementType = .Other    // tie back to automation elements
    var handle: UInt = 0                         // memory address, probably
    var traits: UInt = 0                         // bit flags, probably
    var x = 0.0                                  // coordinates
    var y = 0.0
    var w = 0.0
    var h = 0.0
    var isMainWindow = false                     // mainWindow is special
    var label: String? = nil                     // accessibility label
    var identifier: String? = nil                // accessibility identifier
    var value: String? = nil                     // field value
    var placeholderValue: String? = nil          //
    
    var index: String? {
        get {
            return identifier ?? label
        }
    }
    
    var numericIndex: UInt? {
        get {
            guard let parent = parent else { return 0 }
            guard let idx = parent.childrenMatchingType(elementType).indexOf(self) else { return nil }
            return UInt(idx)
        }
    }
    
    func toString() -> String {
        let elementDesc = elementType.toString()
        return "\(elementDesc) - label: \(label) identifier: \(identifier) value: \(value)"
    }
    
    func treeToString() -> String {
        // swift3 let indent = String(repeating: " ", count: depth)
        let indent = String(count: depth, repeatedValue: Character(" "))
        let childrenString = children.map{ $0.toString() }.joinWithSeparator("")
        return ["\(indent)\(toString())", childrenString].joinWithSeparator("\n")
    }
    
    // from a line of a debug description, create a standalone element
    static func fromDebugDescriptionLine(_ content: String) -> IlluminatorElement? {
        // regex crap
        let fc = "([\\d\\.]+)"        // float capture
        let pc = "\\{\(fc), \(fc)\\}" // pair capture
        let innerRE = "([ →]*)([^\\s]+) 0x([\\dabcdef]+): (.*)?\\{\(pc), \(pc)\\}(, )?(.*)?"
        
        // safely regex capture
        let safeRegex = { (input: String, regex: String, capture: Int) -> String? in
            guard let field = input.matchingStrings(regex)[safe: 0] else { return nil }
            return field[safe: capture]
        }
        
        // safely extract data from the "extra" field at the end
        let safeExtra = { (input: String, label: String) -> String? in safeRegex(input, "\(label): '([^']*)'($|,)", 1) }
        
        // ensure doubles parse
        guard let matches = content.matchingStrings(innerRE)[safe: 0] where matches.count > 10,
        let x = Double(matches[safe: 5] ?? ""),
        let y = Double(matches[safe: 6] ?? ""),
        let w = Double(matches[safe: 7] ?? ""),
        let h = Double(matches[safe: 8] ?? "")
        else {
            return nil
        }
        
        // get depth
        let d = (matches[1].characters.count / 2) - 1
        guard d >= 0 else { return nil }
        
        // build return element
        let ret = IlluminatorElement()
        ret.depth        = d
        ret.elementType  = XCUIElementType.fromString(matches[2])
        ret.handle       = strtoul(matches[3], nil, 16)
        ret.x            = x
        ret.y            = y
        ret.w            = w
        ret.h            = h
        ret.source       = content
        
        let special      = matches[4]
        ret.isMainWindow = special.matchingStrings("Main Window").count == 1
        if let field = safeRegex(special, "traits: (\\d+)", 1),
            let trait = UInt(field) {
            ret.traits = trait
        }
        
        let extras           = matches[10]
        ret.label            = safeExtra(extras, "label")
        ret.identifier       = safeExtra(extras, "identifier")
        ret.value            = safeExtra(extras, "value")
        ret.placeholderValue = safeExtra(extras, "placeholderValue")
        
        return ret
    }
    
    private static func parseTreeHelper(parent: IlluminatorElement?, source: [String]) throws -> IlluminatorElement {
        guard let line = source.first else { throw AbortIlluminatorTree.eof() }
        
        guard let elem = IlluminatorElement.fromDebugDescriptionLine(line) else {
            throw AbortIlluminatorTree.parseError(badLine: line)
        }

        // process parent
        if let parent = parent {
            guard elem.depth - parent.depth == 1 else { throw AbortIlluminatorTree.backtrack(data: elem) }
            elem.parent = parent
            parent.children.append(elem)
        }
        
        // process children
        do {
            try parseTreeHelper(elem, source: source.tail)
        } catch AbortIlluminatorTree.eof {
            // no problem
        } catch AbortIlluminatorTree.backtrack(let data) {
            if let data = data, let parent = parent {
                // extra backtrack if necessary
                if data.depth - parent.depth < 1 {
                    throw AbortIlluminatorTree.backtrack(data: data)
                }
                
                if data.depth - parent.depth == 1 {
                    // fast forward the choices that occurred during recursion
                    let fastforward = Array(source[source.indexOf(data.source)!..<source.count])
                    try parseTreeHelper(parent, source: fastforward)
                }
            }
        }
        return elem
    }
    
    // return a tree of IlluminatorElements from the relevant section of a debugDescription
    // or nil if there is a parse error
    private static func parseTree(_ content: String) -> IlluminatorElement? {
        let lines = content.componentsSeparatedByString("\n")
        guard lines.count > 0 else { return nil }
        
        let elems = lines.map() { (line: String) -> IlluminatorElement? in IlluminatorElement.fromDebugDescriptionLine(line) }
        let actualElems = elems.flatMap{ $0 }
        
        guard elems.count == actualElems.count else {
            print("Caught a parse error in there somewhere, FIXME find where")
            return nil
        }
        
        do {
            return try parseTreeHelper(nil, source: lines)
        } catch AbortIlluminatorTree.backtrack {
            print("Somehow got a backtrack error at the top level of tree parsing")
        } catch AbortIlluminatorTree.parseError(let badLine) {
            print("Caught a parse error of \(badLine)")
        } catch {
            print("Caught an error that we didn't throw... somehow")
        }
        return nil
    }
    
    // return a tree of IlluminatorElements from a debugDescription
    static func fromDebugDescription(_ content: String) -> IlluminatorElement? {
        let outerRE = "\\n([^:]+):\\n( →.+(\\n .*)*)"
        let matches = content.matchingStrings(outerRE)
        let sections = matches.reduce([String: String]()) { dict, matches in
            var ret = dict
            ret[matches[1]] = matches[2]
            return ret
        }
        guard let section = sections["Element subtree"] else { return nil }
        return parseTree(section)
    }
    
    // given a chain of elements and a top level app, get the tail element
    private func toXCUIElementHelper(acc: [IlluminatorElement], app: XCUIApplication) -> XCUIElement {
        
        let finish = { (top: XCUIElement) in
            return acc.reduce(app) { (parent: XCUIElement, elem) in elem.toXCUIElementWith(parent: parent) }
        }
        
        guard elementType != XCUIElementType.Application else { return finish(app) }
        guard let parent = parent else {
            print("Warning about toXCUIElementHelper not knowing it's done")
            return finish(app)
        }
        return parent.toXCUIElementHelper([self] + acc, app: app)
    }
    
    // given the parent element, get this element
    func toXCUIElementWith(parent p: XCUIElement) -> XCUIElement {
        return p.childrenMatchingType(elementType)[index ?? ""]
    }
    
    // given the app, work out the full reference to this element
    func toXCUIElement(app: XCUIApplication) -> XCUIElement {
        return toXCUIElementHelper([], app: app)
    }
    
    // recursively find the toplevel then construct a string
    private func toXCUIElementStringHelper(acc: [IlluminatorElement], appString: String) -> String? {
        let finish = { (top: String) -> String? in
            guard let last = acc.last else { return appString }
            guard last.elementType != XCUIElementType.Other || last.index != nil else { return nil }
            return acc.reduce(appString) { (parentStr: String, elem) in elem.toXCUIElementStringWith(parentStr) }
            
        }
        
        guard elementType != XCUIElementType.Application else { return finish(appString) }
        guard let parent = parent else {
            print("Warning about toXCUIElementStringHelper not knowing it's done: \(toString())")
            return finish(appString)
        }
        return parent.toXCUIElementStringHelper([self] + acc, appString: appString)
    }
    
    // given the parent element, get the string that comes from this element
    func toXCUIElementStringWith(parent: String) -> String {
        guard elementType != XCUIElementType.Other || index != nil else { return parent }
        guard !isMainWindow else { return parent }
        
        let prefix = parent + ".\(elementType.toElementString())"
        
        // fall back on numeric index
        guard let idx = index else {
            if let nidx = numericIndex {
                return "\(prefix).elementAtIndex(\(nidx))"
            } else {
                return "\(prefix).elementAtIndex(-1)"
            }
        }

        return "\(prefix)[\"\(idx)\"]"
    }
    
    // given the app string, work out the full string representing this element
    func toXCUIElementString(appString: String) -> String? {
        return toXCUIElementStringHelper([], appString: appString)
    }
    
    // get a dictionary of label -> element for the children
    func childrenMatchingType(elementType: XCUIElementType) -> [IlluminatorElement] {
        
        return children.reduce([IlluminatorElement]()) { arr, elem in
            guard elem.elementType == elementType else { return arr }
            var ret = arr
            ret.append(elem)
            return ret
        }
    }
    // get a dictionary of label -> element for the children
    func childrenMatchingTypeDict(elementType: XCUIElementType) -> [String: IlluminatorElement] {
        
        return children.reduce([String: IlluminatorElement]()) { dict, elem in
            guard let idx = elem.index else { return dict }
            guard elem.elementType == elementType else { return dict }
            var ret = dict
            ret[idx] = elem
            return ret
        }
    }
    
    func reduce<T>(initialResult: T, nextPartialResult: (T, IlluminatorElement) throws -> T) rethrows -> T {
        return try children.reduce(nextPartialResult(initialResult, self)) { (acc, nextElem) in
            return try nextElem.reduce(acc, nextPartialResult: nextPartialResult)
        }
    }
    
    
    // return a list of copy-pastable accessors representing elements on the screen
    static func accessorDump(appVarname: String, appDebugDescription: String) -> [String] {
        let parsedTree = IlluminatorElement.fromDebugDescription(appDebugDescription)
        
        let lines = parsedTree!.reduce([String?]()) { (acc, elem) in
            let str = elem.toXCUIElementString(appVarname)
            return str == nil ? acc : acc + [str]
        }
        return lines.flatMap({$0})
    }
    
}

extension IlluminatorElement : Hashable {
    var hashValue: Int { return Int(handle) }
}

func ==(lhs: IlluminatorElement, rhs: IlluminatorElement) -> Bool {
    return lhs.hashValue == rhs.hashValue
}
