#import "YoloFfiPlugin.h"
#import <Foundation/Foundation.h>

// Define a separate Stream Handler class
@interface PrintStreamHandler : NSObject <FlutterStreamHandler>
@end

// The event sink is static, managed by the stream handler.
static FlutterEventSink eventSink = nil;

@implementation YoloFfiPlugin

+ (void)registerWithRegistrar:(NSObject<FlutterPluginRegistrar>*)registrar {
    FlutterEventChannel* channel = [FlutterEventChannel
        eventChannelWithName:@"com.cia1099.yolo_ffi/logging"
             binaryMessenger:[registrar messenger]];
    
    // Use a separate stream handler instance.
    PrintStreamHandler* streamHandler = [[PrintStreamHandler alloc] init];
    [channel setStreamHandler:streamHandler];
}

/**
 * @brief This is the method that will be called from C++.
 *
 * Its signature `+ (void)printMessage:(const char *)message` is designed to be
 * directly callable from the IMP in `print.cpp`, avoiding any fragile bridging
 * that caused previous crashes.
 */
+ (void)printMessage:(const char *)message {
    if (eventSink) {
        // Inside this method, we safely convert the C string to an NSString.
        NSString *nsMessage = [NSString stringWithUTF8String:message];
        if (nsMessage) {
            // Ensure the event is sent on the main thread.
            dispatch_async(dispatch_get_main_queue(), ^{
                eventSink(nsMessage);
            });
        }
    }
}

@end

#pragma mark - Stream Handler Implementation

@implementation PrintStreamHandler

- (FlutterError* _Nullable)onListenWithArguments:(id _Nullable)arguments
                                       eventSink:(FlutterEventSink)events {
    // Set the static eventSink when Dart starts listening.
    eventSink = events;
    return nil;
}

- (FlutterError* _Nullable)onCancelWithArguments:(id _Nullable)arguments {
    // Clear the static eventSink when Dart stops listening.
    eventSink = nil;
    return nil;
}
@end