# The Flutter tooling requires that developers have CMake 3.10 or later
# installed. You should not increase this version, as doing so will cause
# the plugin to fail to compile for some customers of the plugin.
cmake_minimum_required(VERSION 3.10)

project(yolo_ffi_library VERSION 0.0.1 LANGUAGES CXX)

# Set the onnxruntime_DIR to point directly to the package config files
if(ANDROID)
    set(onnxruntime_DIR ${CMAKE_SOURCE_DIR}/../ort/android/lib/cmake/onnxruntime)
elseif(APPLE AND IOS)
    set(onnxruntime_DIR ${CMAKE_SOURCE_DIR}/../ort/ios/lib/cmake/onnxruntime)
endif()

find_package(onnxruntime REQUIRED)

add_library(yolo_ffi SHARED
  "yolo_ffi.c"
  "yolo_onnx.cpp"
)

target_link_libraries(yolo_ffi onnxruntime::onnxruntime)

set_target_properties(yolo_ffi PROPERTIES
  PUBLIC_HEADER yolo_ffi.h
  OUTPUT_NAME "yolo_ffi"
)

target_compile_definitions(yolo_ffi PUBLIC DART_SHARED_LIB)

if (ANDROID)
  # Support Android 15 16k page size
  target_link_options(yolo_ffi PRIVATE "-Wl,-z,max-page-size=16384")
endif()
