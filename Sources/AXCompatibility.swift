import Foundation

// macOS exposes this Accessibility attribute at runtime, but some SDK/Swift
// combinations do not export a kAXFullScreenAttribute symbol.
let kAXFullScreenAttribute = "AXFullScreen"
