#ifndef YOLO_FFI_H
#define YOLO_FFI_H

#include <stdint.h>

#if _WIN32
#define FFI_PLUGIN_EXPORT __declspec(dllexport)
#else
#define FFI_PLUGIN_EXPORT
#endif

#ifdef __cplusplus
extern "C"
{
#endif

    FFI_PLUGIN_EXPORT void load_model(const char *model_path);
    FFI_PLUGIN_EXPORT const char *get_model_input_name();
    FFI_PLUGIN_EXPORT void free_string(const char *str);
    FFI_PLUGIN_EXPORT void close_model();

#ifdef __cplusplus
}
#endif

#endif // YOLO_FFI_H
