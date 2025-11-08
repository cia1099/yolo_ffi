#ifndef YOLO_ONNX_H
#define YOLO_ONNX_H

#ifdef __cplusplus
#include <onnxruntime_cxx_api.h>

// A struct to hold the ONNX Runtime session and environment objects.
// This helps manage their lifecycle together.
struct OrtSessionContainer {
    Ort::Session* session;
    Ort::Env* env;
};
#else
// Forward declare the struct for C code.
struct OrtSessionContainer;
#endif

#ifdef __cplusplus
extern "C" {
#endif

#ifdef __cplusplus
extern "C" {
#endif

// Functions to be called from C FFI layer.
struct OrtSessionContainer* create_session(const char* model_path);
const char* get_input_name(struct OrtSessionContainer* container);
void close_session(struct OrtSessionContainer* container);

#ifdef __cplusplus
}
#endif

#ifdef __cplusplus
}
#endif

#endif // YOLO_ONNX_H