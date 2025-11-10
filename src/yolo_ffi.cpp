#include "yolo_ffi.h"
#include "yolo_onnx.h"

// Global pointer to the session container.
static struct OrtSessionContainer* session_container = nullptr;

extern "C" {

FFI_PLUGIN_EXPORT void load_model(const char* model_path) {
	// If a model is already loaded, close it before loading a new one.
	if (session_container) {
		close_session(session_container);
	}
	session_container = create_session(model_path);
}

const char* get_model_input_name() {
	if (session_container) {
		return get_input_name(session_container);
	}
	return nullptr;
}

FFI_PLUGIN_EXPORT void free_string(const char* str) {
	if (str) {
		// free((void *)str);
		delete[] str;
	}
}

FFI_PLUGIN_EXPORT void close_model() {
	if (session_container) {
		close_session(session_container);
		session_container = nullptr;
	}
}
}
