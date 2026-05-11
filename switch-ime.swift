import Carbon
import Foundation

func currentInputSourceID() -> String? {
    guard let src = TISCopyCurrentKeyboardInputSource()?.takeRetainedValue(),
          let ptr = TISGetInputSourceProperty(src, kTISPropertyInputSourceID)
    else { return nil }
    return Unmanaged<CFString>.fromOpaque(ptr).takeUnretainedValue() as String
}

func selectInputSource(id: String) -> Bool {
    guard let list = TISCreateInputSourceList(nil, false)?.takeRetainedValue() as? [TISInputSource] else {
        return false
    }
    for src in list {
        guard let ptr = TISGetInputSourceProperty(src, kTISPropertyInputSourceID) else { continue }
        let sid = Unmanaged<CFString>.fromOpaque(ptr).takeUnretainedValue() as String
        if sid == id {
            return TISSelectInputSource(src) == noErr
        }
    }
    return false
}

let args = CommandLine.arguments

if args.count < 2 || args[1] == "get" {
    if let id = currentInputSourceID() {
        print(id)
        exit(0)
    }
    FileHandle.standardError.write("failed to read current input source\n".data(using: .utf8)!)
    exit(1)
}

if args[1] == "set" {
    guard args.count >= 3 else {
        FileHandle.standardError.write("usage: switch-ime set <input-source-id>\n".data(using: .utf8)!)
        exit(2)
    }
    let target = args[2]
    if selectInputSource(id: target) {
        exit(0)
    }
    FileHandle.standardError.write("input source not found: \(target)\n".data(using: .utf8)!)
    exit(3)
}

FileHandle.standardError.write("usage: switch-ime [get | set <input-source-id>]\n".data(using: .utf8)!)
exit(2)
