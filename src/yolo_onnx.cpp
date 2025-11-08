#include "yolo_onnx.h"
#include <cstring> // For strlen and strcpy

// Creates and returns a new session container.
// It is the caller's responsibility to call close_session on the returned pointer.
OrtSessionContainer* create_session(const char* model_path) {
    auto* container = new OrtSessionContainer;
    container->env = new Ort::Env(ORT_LOGGING_LEVEL_WARNING, "yolo_ffi_ort_env");

    Ort::SessionOptions session_options;
    session_options.SetIntraOpNumThreads(1);

    try {
        container->session = new Ort::Session(*container->env, model_path, session_options);
    } catch (const Ort::Exception& e) {
        // If session creation fails, clean up and return null.
        delete container->env;
        delete container;
        // Optionally, log the error message e.what()
        return nullptr;
    }

    return container;
}

// Returns the input name of the model.
// The caller is responsible for freeing the returned C-string.
const char* get_input_name(OrtSessionContainer* container) {
    if (!container || !container->session) {
        return nullptr;
    }

    Ort::AllocatorWithDefaultOptions allocator;
    // GetInputNameAllocated returns a smart pointer that manages the memory of the string.
    Ort::AllocatedStringPtr input_name_ptr = container->session->GetInputNameAllocated(0, allocator);
    const char* input_name = input_name_ptr.get();

    // We must copy the string, because the memory managed by input_name_ptr will be
    // freed when it goes out of scope at the end of this function.
    char* name_copy = (char*)malloc(strlen(input_name) + 1);
    if (name_copy) {
        strcpy(name_copy, input_name);
    }

    return name_copy;
}

// Closes the session and frees the container and its contents.
void close_session(OrtSessionContainer* container) {
    if (container) {
        delete container->session;
        delete container->env;
        delete container;
    }
}