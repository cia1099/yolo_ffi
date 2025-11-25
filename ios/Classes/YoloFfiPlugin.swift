import Flutter

@objc(YoloFfiPlugin)
public class YoloFfiPlugin: NSObject, FlutterPlugin, FlutterStreamHandler {
    // Static variable to hold the event sink.
    private static var eventSink: FlutterEventSink?

    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterEventChannel(name: "com.cia1099.yolo_ffi/print", binaryMessenger: registrar.messenger())
        let instance = YoloFfiPlugin()
        channel.setStreamHandler(instance)
    }

    // --- FlutterStreamHandler Implementation ---

    public func onListen(withArguments _: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        YoloFfiPlugin.eventSink = events
        return nil
    }

    public func onCancel(withArguments _: Any?) -> FlutterError? {
        YoloFfiPlugin.eventSink = nil
        return nil
    }

    /**
     * This class method is called from the C++ `print_message` function.
     * The `@objc` attribute makes it visible to the Objective-C runtime.
     * The method name must match the one used in `print.cpp`.
     */
    @objc
    public static func printMessage(_ message: UnsafePointer<CChar>) {
        // The incoming 'message' might be a wrapper around a C-style char*
        // whose lifetime is not guaranteed across async calls.
        // Creating a new String from it forces an immediate deep copy,
        // ensuring the data is safely managed by Swift ARC and lives long enough
        // for the async block to execute.
        let messageCopy = String(cString: message)

        guard let sink = eventSink else {
            // Optional: Add a log here if needed for debugging why the sink is nil.
            print("YoloFfiPlugin: eventSink is nil, dropping message.")
            return
        }

        // Ensure the event is sent on the main thread.
        DispatchQueue.main.async {
            sink(messageCopy)
        }
    }
}
