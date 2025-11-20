#include "yolo_onnx.h"
#include <cstring>  // For strlen and strcpy
#include <opencv2/dnn.hpp>
#include <vector>
#include "yolo_ffi.h"
#if __ANDROID__
#include <nnapi_provider_factory.h>
#endif

// Creates and returns a new session container.
// It is the caller's responsibility to call close_session on the returned pointer.
OrtSessionContainer* create_session(const char* model_path) {
	auto* container = new OrtSessionContainer;
	container->env = new Ort::Env(ORT_LOGGING_LEVEL_WARNING, "yolo_ffi_ort_env");

	Ort::SessionOptions session_options;
	session_options.SetIntraOpNumThreads(1);

#if __iOS__
	// Use Core ML execution provider for iOS/macOS.
	std::unordered_map<std::string, std::string> provider_options;
	provider_options["ModelFormat"] = "MLProgram";
	provider_options["MLComputeUnits"] = "ALL";
	provider_options["RequireStaticInputShapes"] = "0";
	provider_options["EnableOnSubgraphs"] = "0";
	session_options.AppendExecutionProvider("CoreML", provider_options);
#elif __ANDROID__
	// Use NNAPI execution provider for Android.
	uint32_t nnapi_flags = 0;  // NNAPI_FLAG_CPU_DISABLED;
	Ort::ThrowOnError(OrtSessionOptionsAppendExecutionProvider_Nnapi(session_options, nnapi_flags));
#endif

	try {
		container->session = new Ort::Session(*container->env, model_path, session_options);
	} catch (const Ort::Exception& e) {
		// If session creation fails, clean up and return null.
		delete container->env;
		delete container;
		// Optionally, log the error message e.what()
		return nullptr;
	}

	return container;
}

// Returns the input name of the model.
// The caller is responsible for freeing the returned C-string.
const char* get_input_name(OrtSessionContainer* container) {
	if (!container || !container->session) {
		return nullptr;
	}

	Ort::AllocatorWithDefaultOptions allocator;
	// GetInputNameAllocated returns a smart pointer that manages the memory of the string.
	Ort::AllocatedStringPtr input_name_ptr = container->session->GetInputNameAllocated(0, allocator);
	const char* input_name = input_name_ptr.get();

	// We must copy the string, because the memory managed by input_name_ptr will be
	// freed when it goes out of scope at the end of this function.
	char* name_copy = new char[strlen(input_name) + 1];
	if (name_copy) {
		strcpy(name_copy, input_name);
	}

	return name_copy;
}

std::vector<Detection> run_inference(OrtSessionContainer* container, cv::InputArray image, float conf_threshold, float nms_threshold) {
	if (!container || !container->session) {
		return {};
	}
	const int INPUT_WIDTH = 640;
	const int INPUT_HEIGHT = 640;

	// Preprocessing
	cv::Mat3b input_image;
	cv::cvtColor(image, input_image, cv::COLOR_RGBA2RGB);

	cv::Mat blob;
	cv::dnn::blobFromImage(input_image, blob, 1. / 255., cv::Size(INPUT_WIDTH, INPUT_HEIGHT), cv::Scalar(), true, false);

	// Create input tensor
	Ort::AllocatorWithDefaultOptions allocator;
	Ort::AllocatedStringPtr input_name_ptr = container->session->GetInputNameAllocated(0, allocator);
	const char* input_name = input_name_ptr.get();
	Ort::AllocatedStringPtr output_name_ptr = container->session->GetOutputNameAllocated(0, allocator);
	const char* output_name = output_name_ptr.get();

	std::vector<int64_t> input_shape = {1, 3, INPUT_HEIGHT, INPUT_WIDTH};

	Ort::MemoryInfo memory_info = Ort::MemoryInfo::CreateCpu(OrtArenaAllocator, OrtMemTypeDefault);
	Ort::Value input_tensor = Ort::Value::CreateTensor<float>(memory_info, blob.ptr<float>(), blob.total(), input_shape.data(), input_shape.size());

	// Run session
	std::vector<Ort::Value> output_tensors = container->session->Run(Ort::RunOptions{nullptr}, &input_name, &input_tensor, 1, &output_name, 1);

	// Post-processing
	const float* raw_output = output_tensors[0].GetTensorData<float>();
	auto output_shape = output_tensors[0].GetTensorTypeAndShapeInfo().GetShape();  // Should be [1, 84, N]
	const int num_classes = static_cast<int>(output_shape[1]);
	const int num_detections = static_cast<int>(output_shape[2]);

	// Transpose [1, 84, N] to [1, N, 84]
	std::vector<float> transposed_output(1 * num_detections * num_classes);
	for (int i = 0; i < num_detections; ++i) {
		for (int j = 0; j < num_classes; ++j) {
			transposed_output[i * num_classes + j] = raw_output[j * num_detections + i];
		}
	}
	// cv::Mat1f transposed_output = cv::Mat1f(num_classes, num_detections, const_cast<float*>(raw_output)).t();

	std::vector<cv::Rect> boxes;
	std::vector<float> confidences;
	std::vector<int> class_ids;

	for (int i = 0; i < num_detections; ++i) {
		const float* detection = transposed_output.data() + i * num_classes;
		const float* class_scores = detection + 4;

		int class_id = -1;
		float max_score = 0.0f;
		for (int j = 0; j < 84 - 4; ++j) {
			if (class_scores[j] > max_score) {
				max_score = class_scores[j];
				class_id = j;
			}
		}

		if (max_score > conf_threshold) {
			float cx = detection[0];
			float cy = detection[1];
			float w = detection[2];
			float h = detection[3];

			int left = static_cast<int>(std::round(cx - 0.5 * w));
			int top = static_cast<int>(std::round(cy - 0.5 * h));
			int width = static_cast<int>(std::round(w));
			int height = static_cast<int>(std::round(h));

			boxes.emplace_back(left, top, width, height);
			confidences.push_back(max_score);
			class_ids.push_back(class_id);
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

	return detections;
}

// Closes the session and frees the container and its contents.
void close_session(OrtSessionContainer* container) {
	if (container) {
		delete container->session;
		delete container->env;
		delete container;
	}
}