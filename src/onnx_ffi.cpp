#include "onnx_yolo.h"
#include "yolo_ffi.h"

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

FFI_PLUGIN_EXPORT DetectionResult yolo_detect(uint8_t* image_data, int height, int width, float conf_threshold, float nms_threshold) {
	if (!session_container) {
		return {nullptr, 0};
	}

	// Create a cv::Mat from the raw image data without copying.
	// The data is expected to be in RGBA format.
	cv::Mat image(height, width, CV_8UC4, image_data);

	std::vector<Detection> detections = run_inference(session_container, image, conf_threshold, nms_threshold);

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
}

const char* get_model_input_name() {
	if (session_container) {
		return get_input_name(session_container);
	}
	return nullptr;
}

FFI_PLUGIN_EXPORT void close_model() {
	if (session_container) {
		close_session(session_container);
		session_container = nullptr;
	}
}
}