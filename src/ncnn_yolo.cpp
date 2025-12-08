#include "ncnn_yolo.h"
#include <chrono>
#include <opencv2/dnn.hpp>
#include "print.h"

// Creates and returns a new NCNN container.
// It is the caller's responsibility to call close_net on the returned pointer.
NcnnContainer* create_net(const char* model_stem) {
	auto* container = new NcnnContainer;
	container->net = new ncnn::Net();
	// container->net->opt.num_threads = 4;
	container->net->opt.use_packing_layout = true;
	container->net->opt.use_bf16_storage = true;
	// container->net->opt.use_winograd_convolution = true;
	// container->net->opt.use_sgemm_convolution = true;
	// container->net->opt.use_fp16_storage = true;

	// container->net->opt.use_vulkan_compute = true;
	// container->net->opt.use_fp16_packed = true;
	// container->net->opt.use_fp16_arithmetic = true;  // 如果设备支持 FP16

	char param_path[512];
	char bin_path[512];
	snprintf(param_path, sizeof(param_path), "%s.param", model_stem);
	snprintf(bin_path, sizeof(bin_path), "%s.bin", model_stem);

	// Load the NCNN model
	if (container->net->load_param(param_path) != 0) {
		delete container->net;
		delete container;
		print_message("Failed to load NCNN param file.");
		return nullptr;
	}
	if (container->net->load_model(bin_path) != 0) {
		delete container->net;
		delete container;
		print_message("Failed to load NCNN bin file.");
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

	cv::Mat img = image.getMat();
	ncnn::Mat in = ncnn::Mat::from_pixels_resize(img.data, ncnn::Mat::PIXEL_RGBA2RGB, img.cols, img.rows, INPUT_WIDTH, INPUT_HEIGHT);

	const float mean_vals[3] = {0, 0, 0};
	const float norm_vals[3] = {1 / 255.f, 1 / 255.f, 1 / 255.f};
	in.substract_mean_normalize(mean_vals, norm_vals);

	auto toc = high_resolution_clock::now();
	auto pre_elapsed = duration_cast<milliseconds>(toc - tic);

	// Inference
	tic = high_resolution_clock::now();
	ncnn::Extractor ex = container->net->create_extractor();
	ex.input("in0", in);
	ncnn::Mat out;
	ex.extract("out0", out);
	toc = high_resolution_clock::now();
	auto infer_elapsed = duration_cast<milliseconds>(toc - tic);

	// Post-processing
	tic = high_resolution_clock::now();

	int num_detections = out.w;
	int num_classes = out.h;
	// Output shape should be [1, 84, N]
	// char out_shape[128];
	// sprintf(out_shape, "output shape: [%d, %d, %d]", out.d, out.h, out.w);
	// print_message(out_shape);
	auto raw_output = (const float*)((unsigned char*)out.data);

	std::vector<cv::Rect> boxes;
	std::vector<float> confidences;
	std::vector<int> class_ids;

	for (int i = 0; i < num_detections; ++i) {
		const float* detection = raw_output + i;
		const float* class_scores = detection + 4 * num_detections;

		int class_id = -1;
		float max_score = 0.0f;
		for (int j = 0; j < num_classes - 4; ++j) {
			int idx = j * num_detections;
			if (class_scores[idx] > max_score) {
				max_score = class_scores[idx];
				class_id = j;
			}
		}

		if (max_score > conf_threshold) {
			float cx = detection[0 * num_detections];
			float cy = detection[1 * num_detections];
			float w = detection[2 * num_detections];
			float h = detection[3 * num_detections];

			int left = static_cast<int>(std::round(cx - 0.5 * w));
			int top = static_cast<int>(std::round(cy - 0.5 * h));
			int width = static_cast<int>(std::round(w));
			int height = static_cast<int>(std::round(h));

			boxes.emplace_back(left, top, width, height);
			confidences.emplace_back(max_score);
			class_ids.emplace_back(class_id);
		}
	}

	std::vector<int> nms_indices;
	cv::dnn::NMSBoxes(boxes, confidences, conf_threshold, nms_threshold, nms_indices);

	std::vector<Detection> detections;
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