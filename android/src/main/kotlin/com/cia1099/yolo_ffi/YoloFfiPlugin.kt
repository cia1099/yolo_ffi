package com.cia1099.yolo_ffi

import androidx.annotation.NonNull
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.EventChannel.EventSink
import android.os.Handler
import android.os.Looper

class YoloFfiPlugin : FlutterPlugin, EventChannel.StreamHandler {

    override fun onAttachedToEngine(@NonNull flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        val channel = EventChannel(flutterPluginBinding.binaryMessenger, "com.cia1099.yolo_ffi/print")
        channel.setStreamHandler(this)

        // Call the native setup function to pass the class reference to C++
        setup(YoloFfiPlugin::class.java)
    }

    override fun onDetachedFromEngine(@NonNull binding: FlutterPlugin.FlutterPluginBinding) {
        // Clean up the C++ side by passing null
        setup(null)
    }

    // --- StreamHandler Implementation ---

    override fun onListen(arguments: Any?, events: EventSink?) {
        // When Dart starts listening, set the static sink.
        setGlobalEventSink(events)
    }

    override fun onCancel(arguments: Any?) {
        // When Dart stops listening, clear the static sink.
        setGlobalEventSink(null)
    }

    companion object {
        // Load the native library
        init {
            System.loadLibrary("yolo_ffi")
        }

        private var globalEventSink: EventSink? = null
        private val handler = Handler(Looper.getMainLooper())

        // Update the static sink. Called from onListen/onCancel.
        @JvmStatic
        private fun setGlobalEventSink(sink: EventSink?) {
            globalEventSink = sink
        }

        /**
         * This method is called from the C++ `print_message` function.
         * The @JvmStatic annotation is crucial.
         */
        @JvmStatic
        fun printMessage(message: String) {
            // Post to the main thread to ensure Flutter can handle the event.
            handler.post {
                globalEventSink?.success(message)
            }
        }

        /**
         * Native method declaration for the JNI bridge setup.
         * This function is implemented in src/print.cpp.
         */
        @JvmStatic
        private external fun setup(pluginClass: Class<*>?)
    }
}
