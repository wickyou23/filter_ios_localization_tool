//
//  MergeViewController.swift
//  FilterText
//
//  Created by Apple on 12/23/20.
//  Copyright © 2020 thangphung. All rights reserved.
//

import Cocoa

class MergeViewController: NSViewController {
    
    @IBOutlet weak var TF1: NSTextField!
    @IBOutlet weak var TF2: NSTextField!
    @IBOutlet weak var input1: NSButton!
    @IBOutlet weak var input2: NSButton!
    @IBOutlet weak var merge: NSButton!
    
    var input1Url: URL?
    var input2Url: URL?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Do any additional setup after loading the view.
    }
    
    override var representedObject: Any? {
        didSet {
            // Update the view, if already loaded.
        }
    }
    
    @IBAction func handleClickInput1(_ sender: NSObject) {
        self.handleSelecteInputFile(sender)
    }
    
    @IBAction func handleClickInput2(_ sender: NSObject) {
        self.handleSelecteInputFile(sender)
    }
    
    @IBAction func handleClickMerge(_ sender: NSObject) {
        self.run()
    }
    
    func handleSelecteInputFile(_ sender: NSObject) {
        let dialog = NSOpenPanel()
        dialog.title = "Selected File"
        dialog.showsResizeIndicator    = true
        dialog.showsHiddenFiles        = false
        dialog.canChooseDirectories    = false
        dialog.canCreateDirectories    = false
        dialog.allowsMultipleSelection = false
        dialog.allowedFileTypes = ["strings"]
        
        if (dialog.runModal() == .OK) {
            let result = dialog.url // Pathname of the file
            if (result != nil) {
                if sender == self.input1 {
                    self.input1Url = result
                    let path = result!.path
                    self.TF1.stringValue = path
                }
                else {
                    self.input2Url = result
                    let path = result!.path
                    self.TF2.stringValue = path
                }
            }
        }
    }
    
    func handleSaveFile() {
        let fDefault = FileManager.default
        let outputPath = try? fDefault.url(for: .cachesDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
        guard let tempPath = outputPath?.appendingPathComponent("temp_merge.strings").path,
              fDefault.fileExists(atPath: tempPath),
              let data = fDefault.contents(atPath: tempPath) else { return }
        let sPanel = NSSavePanel()
        sPanel.title = "Save to"
        sPanel.directoryURL = try? fDefault.url(for: .desktopDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
        sPanel.showsResizeIndicator = true
        sPanel.showsHiddenFiles = false
        sPanel.canCreateDirectories = true
        sPanel.nameFieldStringValue = "merge.strings"
        sPanel.begin { (result) in
            if result == .OK {
                try? data.write(to: sPanel.url!, options: .atomicWrite)
                try? fDefault.removeItem(atPath: tempPath)
            }
        }
    }
    
    func run() {
        guard let _ = self.input1Url, let _ = self.input2Url else { return }
        DispatchQueue.global().async {
            [unowned self] in
            let newContent = self.mergeContent()
            self.handleWriteToFile(content: newContent)
            DispatchQueue.main.async {
                [unowned self] in
                self.handleSaveFile()
            }
        }
    }
    
    func handleWriteToFile(content: String) {
        let fDefault = FileManager.default
        do {
            let tempPath = try fDefault.url(for: .cachesDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
            let path = tempPath.appendingPathComponent("temp_merge.strings")
            try content.data(using: .utf8)?.write(to: path, options: .atomic)
        } catch {
            NSLog(error.localizedDescription)
        }
    }
    
    func mergeContent() -> String {
        guard let url1 = self.input1Url, let url2 = self.input2Url,
              let str1 = try? String(contentsOf: url1, encoding: .utf8),
              let str2 = try? String(contentsOf: url2, encoding: .utf8)
        else { return "" }
        
        var dict1 = str1.split(separator: "\n").reduce(into: [String: String]()) { (rs, sb) in
            let sub = sb.split(separator: "=")
            print("-----------\(sub.count): \(sb)")
            if sub.count >= 2 {
                let k = String(sub[0]).trimmingCharacters(in: .whitespacesAndNewlines)
                let vl = String(sub[1]).trimmingCharacters(in: .whitespacesAndNewlines)
                rs[k] = String(vl)
            }
        }
        
        var dict2 = str2.split(separator: "\n").reduce(into: [String: String]()) { (rs, sb) in
            let sub = sb.split(separator: "=")
            if sub.count >= 2 {
                let k = String(sub[0]).trimmingCharacters(in: .whitespacesAndNewlines)
                let vl = String(sub[1]).trimmingCharacters(in: .whitespacesAndNewlines)
                rs[k] = String(vl)
            }
        }
        
        for d in dict2 {
            if let _ = dict1[d.key] {
                dict1.removeValue(forKey: d.key)
            }
            else {
                dict2.removeValue(forKey: d.key)
            }
        }
        
        let now = DateFormatter.localizedString(from: Date(), dateStyle: .short, timeStyle: .short)
        var rsStr = dict2.sorted(by: { (a, b) -> Bool in
            return a.key.compare(b.key) == .orderedAscending
        })
        .reduce(into: String()) { (rs, d) in
            rs += "\(d.key) = \(d.value)\n"
        }
        
        rsStr += "\n\n//-------------- Updated: \(now) --------------\n\n"
        
        rsStr += dict1.sorted(by: { (a, b) -> Bool in
            return a.key.compare(b.key) == .orderedAscending
        })
        .reduce(into: String()) { (rs, d) in
            rs += "\(d.key) = \(d.value)\n"
        }
        
        return rsStr
    }
}
