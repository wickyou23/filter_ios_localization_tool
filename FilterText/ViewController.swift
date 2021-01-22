//
//  ViewController.swift
//  FilterText
//
//  Created by Apple on 2/25/20.
//  Copyright © 2020 thangphung. All rights reserved.
//

import Cocoa

class ViewController: NSViewController {
    
    @IBOutlet weak var textField: NSTextField!
    @IBOutlet weak var button: NSButton!
    @IBOutlet weak var processTextField: NSTextField!
    @IBOutlet weak var totalFileTextField: NSTextField!
    
    var inputUrl: URL?
    var oldFileUrl: URL?
    var dictText: [String: String] = [:]
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Do any additional setup after loading the view.
    }
    
    override var representedObject: Any? {
        didSet {
            // Update the view, if already loaded.
        }
    }
    
    @IBAction func handleClickButton(_ sender: Any) {
        self.handleSelectedInputFolder()
    }
    
    @IBAction func handleRunClickButton(_ sender: Any) {
        guard self.inputUrl != nil else { return }
        self.run()
    }
    
    func handleSelectedInputFolder() {
        let dialog = NSOpenPanel()
        dialog.title = "Selected File"
        dialog.showsResizeIndicator    = true
        dialog.showsHiddenFiles        = false
        dialog.canChooseDirectories    = true
        dialog.canCreateDirectories    = true
        dialog.allowsMultipleSelection = false
        
        if (dialog.runModal() == .OK) {
            let result = dialog.url // Pathname of the file
            
            if (result != nil) {
                self.inputUrl = result
                let path = result!.path
                textField.stringValue = path
            }
        }
    }
    
    func handleSaveFile() {
        let fDefault = FileManager.default
        let outputPath = try? fDefault.url(for: .cachesDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
        guard let tempPath = outputPath?.appendingPathComponent("temp.strings").path,
              fDefault.fileExists(atPath: tempPath),
              let data = fDefault.contents(atPath: tempPath) else { return }
        let sPanel = NSSavePanel()
        sPanel.title = "Save to"
        sPanel.directoryURL = try? fDefault.url(for: .desktopDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
        sPanel.showsResizeIndicator = true
        sPanel.showsHiddenFiles = false
        sPanel.canCreateDirectories = true
        sPanel.nameFieldStringValue = "en.strings"
        sPanel.begin { (result) in
            if result == .OK {
                try? data.write(to: sPanel.url!, options: .atomicWrite)
                try? fDefault.removeItem(atPath: tempPath)
            }
        }
    }
    
    func run() {
        DispatchQueue.global().async {
            [unowned self] in
            var totalFile = 0
            let path = self.inputUrl!.path
            let fDefault = FileManager.default
            var queueFile: [URL] = [URL(fileURLWithPath: path, isDirectory: true)]
            var keyText: [String] = []
            guard fDefault.fileExists(atPath: path, isDirectory: nil) else {
                return
            }
            
            do {
                while !queueFile.isEmpty {
                    let popItem = queueFile.popLast()!
                    var isDirectory: ObjCBool = false
                    if fDefault.fileExists(atPath: popItem.path, isDirectory: &isDirectory) {
                        if isDirectory.boolValue == true {
                            let allFile = try fDefault.contentsOfDirectory(at: popItem, includingPropertiesForKeys: nil, options: [])
                            queueFile.append(contentsOf: allFile)
                        }
                        else {
                            if popItem.pathExtension == "swift" {
                                totalFile += 1
                                DispatchQueue.main.async {
                                    [unowned self] in
                                    self.processTextField.stringValue = popItem.lastPathComponent
                                    self.totalFileTextField.stringValue = "Total File: \(totalFile)" + (queueFile.isEmpty ? " - Done" : "")
                                }
                                
                                keyText += self.handleFilterText(atPath: popItem.path)
                            }
                        }
                    }
                }
                
                let setKeyText = Set<String>(keyText)
                keyText = Array(setKeyText).sorted { (a, b) -> Bool in
                    return a.compare(b) == .orderedAscending
                }
                
                self.handleWriteToFile(contents: keyText)
                DispatchQueue.main.async {
                    [unowned self] in
                    self.handleSaveFile()
                }
            } catch {
                NSLog("Handle Failed")
            }
        }
    }
    
    func handleFilterText(atPath path: String) -> [String] {
        let fDefault = FileManager.default
        guard let data = fDefault.contents(atPath: path),
              let text = String(data: data, encoding: .utf8)
        else { return [] }
        do {
            let nsMsgKey = NSString(string: text)
            //(\"[\\w\\s%.@]+\")\\.(localized){1}
            //\"(.*?)\"\\.(localized){1}
            //\".+\"\\.localized
            //\"([^\\\"]|\\\")*\".localized
            let regex = try NSRegularExpression.init(pattern: "\"([^\"]|\\\\\")*\".localized", options: [])
            let results = regex.matches(in: text, options: [], range: NSRange.init(location: 0, length: text.count))
            let strings = results.compactMap { (rs) -> String? in
                return nsMsgKey.substring(with: rs.range).replacingOccurrences(of: ".localized", with: "")
            }
            
            return strings
        } catch {
            NSLog(error.localizedDescription)
            return []
        }
    }
    
    func handleWriteToFile(contents: [String]) {
        let fDefault = FileManager.default
        do {
            let tempPath = try fDefault.url(for: .cachesDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
            let path = tempPath.appendingPathComponent("temp.strings")
            let now = DateFormatter.localizedString(from: Date(), dateStyle: .short, timeStyle: .short)
            var resultText = "\n\n//-------------- Updated: \(now) --------------\n\n"
            for item in contents {
                resultText += "\(item) = \(item);\n"
            }
            
            if !resultText.isEmpty {
                try resultText.data(using: .utf8)!.write(to: path, options: .atomicWrite)
            }
        } catch {
            NSLog(error.localizedDescription)
        }
    }
    
    //    func handleRemoveFirstArg() {
    //        let fDefault = FileManager.default
    //        do {
    //            let outputPath = try fDefault.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
    //            let path = outputPath.appendingPathComponent("result_final.strings")
    //            let rsPath = outputPath.appendingPathComponent("result_en_text.trans")
    //            if fDefault.fileExists(atPath: path.path) {
    //                var resultText = ""
    //                if let data = fDefault.contents(atPath: path.path),
    //                    let text = String(data: data, encoding: .utf8) {
    //                    let textInLine = text.split(separator: "\n")
    //                    for item in textInLine {
    //                        let str = String(item).split(separator: "=").first!.trimmingCharacters(in: .whitespaces)
    //                        let newItem = str + ";\n"
    //                        resultText += newItem
    //                    }
    //                }
    //
    //                if !resultText.isEmpty {
    //                    if !fDefault.fileExists(atPath: rsPath.path) {
    //                        fDefault.createFile(atPath: rsPath.path, contents: resultText.data(using: .utf8), attributes: [:])
    //                    }
    //                    else {
    //                        if let fileHandler = try? FileHandle(forWritingTo: rsPath) {
    //                            fileHandler.seekToEndOfFile()
    //                            fileHandler.write(resultText.data(using: .utf8)!)
    //                            fileHandler.closeFile()
    //                        }
    //                    }
    //                }
    //            }
    //        } catch {
    //            NSLog(error.localizedDescription)
    //        }
    //    }
    //
    //    func handleMergeTransFile() {
    //        let fDefault = FileManager.default
    //        do {
    //            let outputPath = try fDefault.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
    //            let aPath = outputPath.appendingPathComponent("result_en_text.txt")
    //            let bPath = outputPath.appendingPathComponent("result_vn_text.txt")
    //            let rsPath = outputPath.appendingPathComponent("result_final_trans.strings")
    //            if fDefault.fileExists(atPath: aPath.path),
    //                fDefault.fileExists(atPath: bPath.path) {
    //                var resultText = ""
    //                if let aData = fDefault.contents(atPath: aPath.path),
    //                    let aText = String(data: aData, encoding: .utf8),
    //                    let bData = fDefault.contents(atPath: bPath.path),
    //                    let bText = String(data: bData, encoding: .utf8) {
    //                    let aSlip = aText.split(separator: "\n")
    //                    let bSlip = bText.split(separator: "\n")
    //                    if bSlip.count == aSlip.count {
    //                        for i in 0..<aSlip.count {
    //                            var firstText = aSlip[i].trimmingCharacters(in: .whitespaces)
    //                            firstText.removeLast()
    //                            resultText += "\(firstText) = \(bSlip[i].trimmingCharacters(in: .whitespaces))\n"
    //                        }
    //                    }
    //                }
    //
    //                if !resultText.isEmpty {
    //                    if !fDefault.fileExists(atPath: rsPath.path) {
    //                        fDefault.createFile(atPath: rsPath.path, contents: resultText.data(using: .utf8), attributes: [:])
    //                    }
    //                    else {
    //                        if let fileHandler = try? FileHandle(forWritingTo: rsPath) {
    //                            fileHandler.seekToEndOfFile()
    //                            fileHandler.write(resultText.data(using: .utf8)!)
    //                            fileHandler.closeFile()
    //                        }
    //                    }
    //                }
    //            }
    //        } catch {
    //            NSLog(error.localizedDescription)
    //        }
    //    }
}

