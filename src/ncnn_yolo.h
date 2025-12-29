#ifndef NCNN_YOLO_H
#define NCNN_YOLO_H

#include <net.h>
#include <opencv2/core.hpp>
#include <vector>

struct NcnnContainer {
	ncnn::Net* net;
};

struct Detection {
	cv::Rect box;
	int class_id;
	float confidence;
};

std::vector<Detection>
run_ncnn(NcnnContainer* container, cv::InputArray image, float conf_threshold, float nms_threshold);

extern "C" {
struct NcnnContainer* create_net(const char* model_path);
void close_net(NcnnContainer* container);
}

#endif