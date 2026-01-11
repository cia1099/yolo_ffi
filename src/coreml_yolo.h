#ifndef COREML_YOLO_H
#define COREML_YOLO_H

#include <opencv2/core.hpp>
#include <vector>

struct MlContainer {
	// Using void* to hold the model makes the struct C-compatible
	// and hides the Objective-C details from the header.
	void* model;
};

struct Detection {
	cv::Rect box;
	int class_id;
	float confidence;
};

std::vector<Detection> perform_inference(MlContainer* container, cv::InputArray image, float conf_threshold, float nms_threshold);

extern "C" {
struct MlContainer* initialize_model(const char* model_path);
void shutdown_model(MlContainer* container);
}

#endif
