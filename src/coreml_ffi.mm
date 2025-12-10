#include "coreml_yolo.h"
#include "print.h"
#include "yolo_ffi.h"
// #import <Foundation/Foundation.h>

// Global pointer to the session container.
static struct MlContainer* mlmodel_container = nullptr;

extern "C" {
FFI_PLUGIN_EXPORT void load_model(const char* model_path) {
	// dispatch_async(dispatch_get_global_queue(0, 0), ^{
	// @autoreleasepool {
	// If a model is already loaded, close it before loading a new one.
	if (mlmodel_container) {
		shutdown_model(mlmodel_container);
	}
	mlmodel_container = initialize_model(model_path);
	// }});
}

FFI_PLUGIN_EXPORT DetectionResult yolo_detect(uint8_t* image_data, int height, int width, float conf_threshold, float nms_threshold) {
	// dispatch_async(dispatch_get_global_queue(0, 0), ^{@autoreleasepool{
	if (!mlmodel_container || !mlmodel_container->model) {
		print_message("model load fail");
		return {nullptr, 0};
	}

	// Create a cv::Mat from the raw image data without copying.
	// The data is expected to be in RGBA format.
	cv::Mat image(height, width, CV_8UC4, image_data);
	print_message("we have model");
	// @autoreleasepool{
	// 	NSLog(@"model is: %@", "shit");
	// }
	// shutdown_model(mlmodel_container);
	return {nullptr, 0};

	std::vector<Detection> detections = perform_inference(mlmodel_container, image, conf_threshold, nms_threshold);

	int num_detections = detections.size();
	if (num_detections == 0) {
		return {nullptr, 0};
	}

	// Allocate memory for the flat array of detection results.
	// Each detection has 6 floats: [x, y, w, h, class_id, conf]
	float* const bboxes = new float[num_detections * 6];

	for (int i = 0; i < num_detections; ++i) {
		bboxes[i * 6 + 0] = detections[i].box.x;
		bboxes[i * 6 + 1] = detections[i].box.y;
		bboxes[i * 6 + 2] = detections[i].box.br().x;
		bboxes[i * 6 + 3] = detections[i].box.br().y;
		bboxes[i * 6 + 4] = static_cast<float>(detections[i].class_id);
		bboxes[i * 6 + 5] = detections[i].confidence;
	}

	return {bboxes, num_detections};
	// }});
}

FFI_PLUGIN_EXPORT void close_model() {
	// dispatch_async(dispatch_get_global_queue(0, 0), ^{
	// @autoreleasepool {
	if (mlmodel_container) {
		shutdown_model(mlmodel_container);
		mlmodel_container = nullptr;
	}
	// }});
}

const char* get_model_input_name() {
	return nullptr;
}
}