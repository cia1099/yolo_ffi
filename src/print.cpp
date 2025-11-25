#include "print.h"

#ifdef __ANDROID__

#include <jni.h>

// Global JavaVM pointer, initialized on library load.
static JavaVM* g_vm = NULL;
// Global JNI class reference for the plugin, set via the `setup` function.
static jclass g_plugin_class = NULL;

/**
 * @brief Sends a message to the Android platform via JNI.
 *
 * This function calls a static Java method `sendMessage` on the registered
 * plugin class. The Java implementation of this method is expected to forward
 * the message to Dart using an EventChannel.
 *
 * @param message The string message to send.
 */
void print_message(const char* message) {
	if (!g_vm || !g_plugin_class) {
		return;
	}

	JNIEnv* env = NULL;
	bool thread_attached_by_us = false;

	// Check if the current thread is already attached to the JVM.
	jint get_env_result = g_vm->GetEnv((void**)&env, JNI_VERSION_1_6);

	if (get_env_result == JNI_EDETACHED) {
		// The thread is not attached, so we need to attach it.
		if (g_vm->AttachCurrentThread(&env, NULL) != 0) {
			// Failed to attach the thread.
			return;
		}
		thread_attached_by_us = true;
	} else if (get_env_result != JNI_OK) {
		// An error occurred trying to get the JNI environment.
		return;
	}

	// At this point, `env` should be valid.
	if (env) {
		// Find the static method `printMessage` with the signature `(Ljava/lang/String;)V`.
		jmethodID method = env->GetStaticMethodID(g_plugin_class, "printMessage", "(Ljava/lang/String;)V");
		if (method) {
			jstring jmessage = env->NewStringUTF(message);
			env->CallStaticVoidMethod(g_plugin_class, method, jmessage);
			env->DeleteLocalRef(jmessage);

			if (env->ExceptionCheck()) {
				env->ExceptionDescribe();
			}
		}
	}

	// Only detach the thread if we attached it in this function call.
	if (thread_attached_by_us) {
		g_vm->DetachCurrentThread();
	}
}

extern "C" {

/**
 * @brief Called by the JNI when the library is loaded.
 *
 * Stores the global JavaVM pointer.
 */
jint JNI_OnLoad(JavaVM* vm, void* reserved) {
	g_vm = vm;
	return JNI_VERSION_1_6;
}

/**
 * @brief Called by the JNI when the library is unloaded.
 */
void JNI_OnUnload(JavaVM* vm, void* reserved) {
	g_vm = NULL;
}

/**
 * @brief Sets up the communication bridge from C++ to Java.
 *
 * This function must be called from the Java side to provide the plugin class.
 * The name of this function is critical and must match the package and class
 * name of your Flutter plugin.
 *
 * For example, if your plugin class is `com.example.yolo_ffi.YoloFfiPlugin`,
 * the function name must be `Java_com_example_yolo_1ffi_YoloFfiPlugin_setup`.
 * You will likely need to update this function name.
 */
JNIEXPORT void JNICALL
Java_com_cia1099_yolo_1ffi_YoloFfiPlugin_setup(JNIEnv* env, jobject /* thiz */, jclass plugin) {
	if (g_plugin_class) {
		env->DeleteGlobalRef(g_plugin_class);
		g_plugin_class = NULL;
	}
	if (plugin) {
		g_plugin_class = (jclass)env->NewGlobalRef(plugin);
	}
}

}  // extern "C"

#else  // iOS

#include <objc/runtime.h>
#include <stdio.h>

// Defines the function pointer type for the Objective-C method call.
typedef void (*IMP_printMessage)(Class, SEL, const char* message);

/**
 * @brief Sends a message to the iOS platform via the Objective-C runtime.
 *
 * This function calls a class method `printMessage:` on the `YoloFfiPlugin`
 * class. The Objective-C implementation of this method is expected to forward
 * the message to Dart using an FlutterEventChannel.
 *
 * Note: The class name "YoloFfiPlugin" is assumed. You may need to change this
 * to match your actual iOS plugin class name.
 *
 * @param message The string message to send.
 */
void print_message(const char* message) {
	Class pluginClass = objc_getClass("YoloFfiPlugin");

	SEL selector = sel_registerName("printMessage:");

	IMP_printMessage imp = (IMP_printMessage)method_getImplementation(class_getClassMethod(pluginClass, selector));

	imp(pluginClass, selector, message);

	// MARK:- Debug print
	// Class pluginClass = objc_getClass("YoloFfiPlugin");
	// if (!pluginClass) {
	// 	printf("ERROR: objc_getClass(\"YoloFfiPlugin\") returned nil.\n");
	// 	return;
	// } else {
	// 	printf("SUCCESS: Found class YoloFfiPlugin.\n");
	// }

	// SEL selector = sel_registerName("printMessage:");
	// if (!selector) {
	// 	printf("ERROR: sel_registerName(\"printMessage:\") returned nil.\n");
	// 	return;
	// }

	// IMP_printMessage printMessageImp = (IMP_printMessage)method_getImplementation(class_getClassMethod(pluginClass, selector));
	// if (!printMessageImp) {
	// 	printf("ERROR: method_getImplementation for printMessage: returned nil.\n");
	// 	return;
	// } else {
	// 	printf("SUCCESS: Found method implementation for printMessage:.\n");
	// }

	// printMessageImp(pluginClass, selector, message);
}

#endif