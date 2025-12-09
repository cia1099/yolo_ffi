#ifndef COREML_YOLO_H
#define COREML_YOLO_H

#import <Vision/Vision.h>
#include <opencv2/opencv.hpp>
#include <vector>

struct MlContainer {
	VNCoreMLModel* model;
};

struct Detection {
	cv::Rect box;
	int class_id;
	float confidence;
};

std::vector<Detection>
perform_inference(MlContainer* container, cv::InputArray image, float conf_threshold, float nms_threshold);

extern "C" {
struct MlContainer* initialize_model(const char* model_path);
void shutdown_model(MlContainer* container);
}

#endif