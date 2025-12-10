#include "coreml_yolo.h"
#include <chrono>
#include <opencv2/dnn.hpp>
#include "print.h"
#import <CoreML/CoreML.h>
#import <Vision/Vision.h>
#import <Foundation/Foundation.h>

// Helper function to convert cv::Mat to CVPixelBufferRef
CVPixelBufferRef matToCVPixelBuffer(const cv::Mat& mat) {
    CVPixelBufferRef pixelBuffer = nullptr;
    NSDictionary *options = @{
        (NSString*)kCVPixelBufferCGImageCompatibilityKey: @YES,
        (NSString*)kCVPixelBufferCGBitmapContextCompatibilityKey: @YES,
        (NSString*)kCVPixelBufferIOSurfacePropertiesKey: [NSDictionary dictionary]
    };

    // Ensure the input Mat is continuous
    if (!mat.isContinuous()) {
        print_message("Error: Input cv::Mat is not continuous.");
        return nullptr;
    }

    CVReturn status = CVPixelBufferCreateWithBytes(
        kCFAllocatorDefault,
        mat.cols,
        mat.rows,
        kCVPixelFormatType_24RGB, // Model expects RGB
        mat.data,
        mat.step,
        nil,
        nil,
        (__bridge CFDictionaryRef)options,
        &pixelBuffer
    );

    if (status != kCVReturnSuccess) {
        char buffer[256];
        sprintf(buffer, "Failed to create CVPixelBuffer. Status: %d", status);
        print_message(buffer);
        return nullptr;
    }

    return pixelBuffer;
}


MlContainer* initialize_model(const char* model_path){
    NSString* modelPath = [NSString stringWithUTF8String:model_path];
    NSURL* modelURL = [NSURL fileURLWithPath:modelPath];
    NSError* error = nil;

    // Compile the model if it's not already compiled
    NSURL* compiledURL = [MLModel compileModelAtURL:modelURL error:&error];
    if (error) {
        print_message([[NSString stringWithFormat:@"Error compiling model: %@", error.localizedDescription] UTF8String]);
        return nullptr;
    }

    // Load the compiled model
    MLModel* mlModel = [MLModel modelWithContentsOfURL:compiledURL error:&error];
    if (!mlModel || error) {
        print_message([[NSString stringWithFormat:@"Error loading model: %@", error.localizedDescription] UTF8String]);
        return nullptr;
    }

    // Create a Vision model from the CoreML model
    VNCoreMLModel* visionModel = [VNCoreMLModel modelForMLModel:mlModel error:&error];
    if (!visionModel || error) {
        print_message([[NSString stringWithFormat:@"Error creating Vision model: %@", error.localizedDescription] UTF8String]);
        return nullptr;
    }
    [visionModel retain];

    MlContainer* container = new MlContainer;
    // Bridge the Objective-C model object to a C pointer and retain it.
    // This transfers ownership to the caller of this function.
    container->model = (__bridge_retained void*)visionModel;
    
    return container;
}

std::vector<Detection> perform_inference(MlContainer* container, cv::InputArray image, float conf_threshold, float nms_threshold){
    if (!container || !container->model) {
        return {};
    }

    using namespace std::chrono;
	const int INPUT_WIDTH = 640;
	const int INPUT_HEIGHT = 640;

    // Preprocessing
    auto tic = high_resolution_clock::now();
    cv::Mat resized_img;
    cv::Mat input_image = image.getMat();
    cv::resize(input_image, resized_img, cv::Size(INPUT_WIDTH, INPUT_HEIGHT));
    cv::cvtColor(resized_img, resized_img, cv::COLOR_RGBA2RGB);

    // Convert cv::Mat to CVPixelBufferRef
    CVPixelBufferRef pixelBuffer = matToCVPixelBuffer(resized_img);
    if (!pixelBuffer) {
        return {};
    }
    auto toc = high_resolution_clock::now();
	auto pre_elapsed = duration_cast<milliseconds>(toc - tic);


    // Inference
    tic = high_resolution_clock::now();
    __block NSArray* observations = @[];
    dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);

    // Bridge the C pointer back to an Objective-C object without transferring ownership.
    VNCoreMLModel* visionModel = (__bridge VNCoreMLModel*)container->model;
    // Create a Vision request
    VNCoreMLRequest* request = [[VNCoreMLRequest alloc] initWithModel:visionModel completionHandler:^(VNRequest * _Nonnull req, NSError * _Nullable err) {
        if (err) {
            print_message([[NSString stringWithFormat:@"Inference error: %@", err.localizedDescription] UTF8String]);
        } else {
            observations = req.results;
        }
        dispatch_semaphore_signal(semaphore);
    }];
    
    // Create a handler and perform the request
    NSError* error = nil;
    VNImageRequestHandler* handler = [[VNImageRequestHandler alloc] initWithCVPixelBuffer:pixelBuffer options:@{}];
    [handler performRequests:@[request] error:&error];
    if (error) {
        print_message([[NSString stringWithFormat:@"Error performing request: %@", error.localizedDescription] UTF8String]);
        CVPixelBufferRelease(pixelBuffer);
        return {};
    }

    // Wait for the completion handler to finish
    dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER);
    CVPixelBufferRelease(pixelBuffer);
    dispatch_release(semaphore);

    toc = high_resolution_clock::now();
	auto infer_elapsed = duration_cast<milliseconds>(toc - tic);

    // Post-processing
    tic = high_resolution_clock::now();
    if (observations.count == 0) {
        return {};
    }

    VNCoreMLFeatureValueObservation* rawOutput = (VNCoreMLFeatureValueObservation*)observations[0];
    MLMultiArray* multiArray = rawOutput.featureValue.multiArrayValue;

    if (!multiArray) {
        print_message("Model output is not an MLMultiArray.");
        return {};
    }

    const float* raw_output = (const float*)multiArray.dataPointer;
    const int num_classes = [multiArray.shape[1] intValue];
    const int num_detections = [multiArray.shape[2] intValue];

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

void shutdown_model(MlContainer* container){
    if (container) {
        if (container->model) {
            // This transfers ownership of the model back to ARC, which will then
            // release the object, decrementing its retain count.
            id model = (__bridge_transfer id)container->model;
            [model release];
            // model = nil;
            container->model = nil;
        }
        delete container;
    }
}
