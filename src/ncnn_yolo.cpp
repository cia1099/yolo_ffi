#include "ncnn_yolo.h"
#include <chrono>
#include <filesystem>
#include <opencv2/dnn.hpp>
#include "print.h"

// Creates and returns a new NCNN container.
// It is the caller's responsibility to call close_net on the returned pointer.
NcnnContainer* create_net(const char* model_path) {
	auto* container = new NcnnContainer;
	container->net = new ncnn::Net();

	std::filesystem::path p(model_path);
	auto ext = p.extension().string();

	if (ext == ".param") {
		container->net->load_param(model_path);
	} else if (ext == ".bin") {
		container->net->load_model(model_path);
	} else {
		delete container->net;
		delete container;
		print_message("Failed to load NCNN param file.");
		return nullptr;
	}

	return container;
}

std::vector<Detection> run_ncnn(NcnnContainer* container, cv::InputArray image, float conf_threshold, float nms_threshold) {
	if (!container || !container->net) {
		return {};
	}

	using namespace std::chrono;
	const int INPUT_WIDTH = 640;
	const int INPUT_HEIGHT = 640;

	// Preprocessing
	auto tic = high_resolution_clock::now();
	cv::Mat input_image;
	image.getMat().copyTo(input_image);
	int w = input_image.cols;
	int h = input_image.rows;
	float scale = 1.f;
	if (w > h) {
		scale = (float)INPUT_WIDTH / w;
		w = INPUT_WIDTH;
		h = h * scale;
	} else {
		scale = (float)INPUT_HEIGHT / h;
		h = INPUT_HEIGHT;
		w = w * scale;
	}
	cv::Mat resized_image;
	cv::resize(input_image, resized_image, cv::Size(w, h));

	cv::Mat padded_image(INPUT_HEIGHT, INPUT_WIDTH, CV_8UC3, cv::Scalar(114, 114, 114));
	resized_image.copyTo(padded_image(cv::Rect(0, 0, w, h)));

	ncnn::Mat in = ncnn::Mat::from_pixels(padded_image.data, ncnn::Mat::PIXEL_RGB, INPUT_WIDTH, INPUT_HEIGHT);
	const float mean_vals[3] = {0, 0, 0};
	const float norm_vals[3] = {1 / 255.f, 1 / 255.f, 1 / 255.f};
	in.substract_mean_normalize(mean_vals, norm_vals);

	auto toc = high_resolution_clock::now();
	auto pre_elapsed = duration_cast<milliseconds>(toc - tic);

	// Inference
	tic = high_resolution_clock::now();
	ncnn::Extractor ex = container->net->create_extractor();
	ex.input("images", in);
	ncnn::Mat out;
	ex.extract("output", out);
	toc = high_resolution_clock::now();
	auto infer_elapsed = duration_cast<milliseconds>(toc - tic);

	// Post-processing
	tic = high_resolution_clock::now();
	std::vector<Detection> detections;
	int output_height = out.h;

	std::vector<cv::Rect> boxes;
	std::vector<float> confidences;
	std::vector<int> class_ids;

	for (int i = 0; i < output_height; i++) {
		const float* values = out.row(i);

		float confidence = values[4];
		if (confidence >= conf_threshold) {
			float class_score = 0;
			int class_id = 0;
			for (int j = 5; j < out.w; j++) {
				if (values[j] > class_score) {
					class_score = values[j];
					class_id = j - 5;
				}
			}

			if (class_score > 0.25f) {  // Second confidence check
				float cx = values[0];
				float cy = values[1];
				float w_box = values[2];
				float h_box = values[3];

				int left = static_cast<int>((cx - 0.5 * w_box) / scale);
				int top = static_cast<int>((cy - 0.5 * h_box) / scale);
				int width = static_cast<int>(w_box / scale);
				int height = static_cast<int>(h_box / scale);

				boxes.emplace_back(left, top, width, height);
				confidences.emplace_back(confidence);
				class_ids.emplace_back(class_id);
			}
		}
	}

	std::vector<int> nms_indices;
	cv::dnn::NMSBoxes(boxes, confidences, conf_threshold, nms_threshold, nms_indices);

	for (int idx : nms_indices) {
		Detection result;
		result.box = boxes[idx];
		result.confidence = confidences[idx];
		result.class_id = class_ids[idx];
		detections.push_back(result);
	}

	toc = high_resolution_clock::now();
	auto post_elapsed = duration_cast<milliseconds>(toc - tic);

	char buffer[1024];
	auto total = pre_elapsed + infer_elapsed + post_elapsed;
	sprintf(buffer, "Elapsed Time(%lld ms): preprocess: %lld ms, inference: %lld ms, postprocess: %lld ms", total.count(), pre_elapsed.count(), infer_elapsed.count(), post_elapsed.count());
	print_message(buffer);

	return detections;
}

// Closes the ncnn net and frees the container.
void close_net(NcnnContainer* container) {
	if (container) {
		delete container->net;
		delete container;
	}
}