#ifndef YOLO_FFI_H
#define YOLO_FFI_H

#include <stdbool.h>
#include <stdint.h>

#if defined(_WIN32)
#define FFI_PLUGIN_EXPORT __declspec(dllexport)
#else
#define FFI_PLUGIN_EXPORT __attribute__((visibility("default"))) __attribute__((used))
#endif

// Forward declare the session container struct.
struct OrtSessionContainer;

typedef struct {
	const float* bboxes;
	int count;
} DetectionResult;

typedef enum {
	YUV420 = 1,
	BGRA8888 = 2,
	NV21 = 4,
} ImageFormat;

#ifdef __cplusplus
extern "C" {
#endif

FFI_PLUGIN_EXPORT void load_model(const char* model_path);

FFI_PLUGIN_EXPORT const char* get_model_input_name();

FFI_PLUGIN_EXPORT void free_string(const char* str);

FFI_PLUGIN_EXPORT void close_model();

FFI_PLUGIN_EXPORT DetectionResult yolo_detect(uint8_t* image_data, int height, int width, float conf_threshold, float nms_threshold);

FFI_PLUGIN_EXPORT void free_result(DetectionResult result);

FFI_PLUGIN_EXPORT uint8_t* convert_image(
    ImageFormat format,
    uint8_t* plane0,
    uint8_t* plane1,
    uint8_t* plane2,
    int bytesPerRow0,
    int bytesPerRow1,
    int bytesPerRow2,
    int bytesPerPixel1,
    int bytesPerPixel2,
    int width,
    int height,
    bool isAndroid);

FFI_PLUGIN_EXPORT void free_rgba_buffer(uint8_t* buffer);

#ifdef __cplusplus
}
#endif

#endif  // YOLO_FFI_H
