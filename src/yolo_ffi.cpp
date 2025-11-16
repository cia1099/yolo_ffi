#include "yolo_ffi.h"
#include <opencv2/opencv.hpp>
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

FFI_PLUGIN_EXPORT void free_result(DetectionResult result) {
	if (result.bboxes) {
		delete[] result.bboxes;
	}
}

const char* get_model_input_name() {
	if (session_container) {
		return get_input_name(session_container);
	}
	return nullptr;
}

FFI_PLUGIN_EXPORT void free_string(const char* str) {
	if (str) {
		delete[] str;
	}
}

FFI_PLUGIN_EXPORT void close_model() {
	if (session_container) {
		close_session(session_container);
		session_container = nullptr;
	}
}

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
    bool isAndroid) {
	cv::Mat rgba_image = cv::Mat4b::zeros(height, width);

	switch (format) {
		case YUV420: {
			// For YUV420, we have 3 planes (Y, U, V).
			// We need to construct the YUV image before converting to RGBA.
			cv::Mat y(height, width, CV_8UC1, plane0, bytesPerRow0);
			cv::Mat u(height / 2, width / 2, CV_8UC1, plane1, bytesPerRow1);
			cv::Mat v(height / 2, width / 2, CV_8UC1, plane2, bytesPerRow2);

			cv::Mat yuv_image;
			// This is a bit tricky. We need to merge the planes.
			// I420 format has Y plane first, then U, then V.
			// Let's create a single Mat for YUV data.
			cv::Mat yuv_mat(height * 3 / 2, width, CV_8UC1);
			// Copy Y plane
			y.copyTo(yuv_mat(cv::Rect(0, 0, width, height)));
			// Copy U plane
			u.copyTo(yuv_mat(cv::Rect(0, height, width / 2, height / 2)));
			// Copy V plane
			v.copyTo(yuv_mat(cv::Rect(width / 2, height, width / 2, height / 2)));

			cv::cvtColor(yuv_mat, rgba_image, cv::COLOR_YUV2RGBA_I420);
			break;
		}
		case NV21: {
			// For NV21, we have 2 planes (Y, UV).
			cv::Mat yuv_image(height + height / 2, width, CV_8UC1, plane0);
			cv::cvtColor(yuv_image, rgba_image, cv::COLOR_YUV2RGBA_NV21);
			break;
		}
		case BGRA8888: {
			cv::Mat bgra_image(height, width, CV_8UC4, plane0, bytesPerRow0);
			cv::cvtColor(bgra_image, rgba_image, cv::COLOR_BGRA2RGBA);
			break;
		}
	}

	if (isAndroid) {
		cv::rotate(rgba_image, rgba_image, cv::ROTATE_90_CLOCKWISE);
	}

	int size = rgba_image.total() * rgba_image.elemSize();
	uint8_t* data = new uint8_t[size];
	memcpy(data, rgba_image.data, size);

	return data;
}

FFI_PLUGIN_EXPORT void free_rgba_buffer(uint8_t* buffer) {
	if (buffer) {
		delete[] buffer;
	}
}
}
