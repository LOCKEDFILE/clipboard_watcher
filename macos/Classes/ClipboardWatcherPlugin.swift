import Cocoa
import FlutterMacOS

public class ClipboardWatcherPlugin: NSObject, FlutterPlugin {
    private var channel: FlutterMethodChannel!
    
    private let pasteboard = NSPasteboard.general
    private var changeCount: Int = -1
    
    private var timer: Timer?
    
    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(name: "clipboard_watcher", binaryMessenger: registrar.messenger)
        let instance = ClipboardWatcherPlugin()
        instance.channel = channel
        registrar.addMethodCallDelegate(instance, channel: channel)
    }
    
    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "start":
            start(call, result: result)
            return
        case "stop":
            stop(call, result: result)
            return
        default:
            result(FlutterMethodNotImplemented)
        }
    }
    
    public func start(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        timer = Timer.scheduledTimer(
            timeInterval: 0.1,
            target: self,
            selector: #selector(self.checkForChangesInPasteboard),
            userInfo: nil,
            repeats: true
        )
        result(true)
    }
    
    public func stop(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        timer?.invalidate()
        timer = nil
        result(true)
    }
    
    @objc private func checkForChangesInPasteboard() {
        if pasteboard.changeCount != changeCount {
            changeCount = pasteboard.changeCount
            
            // Check for string data
            if let copiedString = pasteboard.string(forType: .string) {
                let args: NSDictionary = ["type": "text", "data": copiedString]
                channel.invokeMethod("onClipboardChanged", arguments: args, result: nil)
                return
            }
            
            // Check for image data
            if let imageData = pasteboard.data(forType: .tiff),
               let image = NSImage(data: imageData) {
                if let imagePath = saveImageToTemporaryDirectory(image: image) {
                    let args: NSDictionary = ["type": "image", "data": imagePath]
                    channel.invokeMethod("onClipboardChanged", arguments: args, result: nil)
                    return
                }
            }
            
            // No recognizable data found
            let args: NSDictionary = ["type": "unknown"]
            channel.invokeMethod("onClipboardChanged", arguments: args, result: nil)
        }
    }
    
    private func saveImageToTemporaryDirectory(image: NSImage) -> String? {
        guard let tiffData = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData),
              let pngData = bitmap.representation(using: .png, properties: [:]) else {
            return nil
        }
        
        let tempDirectory = NSTemporaryDirectory()
        let uniqueName = UUID().uuidString + ".png"
        let filePath = (tempDirectory as NSString).appendingPathComponent(uniqueName)
        
        do {
            try pngData.write(to: URL(fileURLWithPath: filePath))
            return filePath
        } catch {
            print("Failed to save image: \(error)")
            return nil
        }
    }
}
