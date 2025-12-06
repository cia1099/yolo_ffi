# The Flutter tooling requires that developers have CMake 3.10 or later
# installed. You should not increase this version, as doing so will cause
# the plugin to fail to compile for some customers of the plugin.
cmake_minimum_required(VERSION 3.10)

project(yolo_ffi_library VERSION 0.1.0 LANGUAGES CXX)

if(CMAKE_OSX_SYSROOT MATCHES "iphonesimulator")
    set(SIMULATOR ON)
endif()

# Set the onnxruntime_DIR to point directly to the package config files
if(ANDROID)
    set(onnxruntime_DIR ${CMAKE_SOURCE_DIR}/../../onnxruntime/android/lib/cmake/onnxruntime)
    set(OpenCV_DIR ${CMAKE_SOURCE_DIR}/../../opencv/android/sdk/native/jni/abi-arm64-v8a)
    set(ncnn_DIR ${CMAKE_SOURCE_DIR}/../../ncnn/android/lib/cmake/ncnn)
elseif(APPLE OR IOS)
  if(SIMULATOR)
    set(IOS_DIR sim_ios)
    # set(onnxruntime_DIR ${CMAKE_SOURCE_DIR}/../ort/sim_ios/lib/cmake/onnxruntime)
    # set(OpenCV_DIR ${CMAKE_SOURCE_DIR}/../../opencv/sim_ios/lib/cmake/opencv4)
  else()
    set(IOS_DIR ios)
  endif()
    set(onnxruntime_DIR ${CMAKE_SOURCE_DIR}/../../onnxruntime/${IOS_DIR}/lib/cmake/onnxruntime)
    set(OpenCV_DIR ${CMAKE_SOURCE_DIR}/../../opencv/${IOS_DIR}/lib/cmake/opencv4)
endif()

find_package(onnxruntime REQUIRED)
find_package(OpenCV REQUIRED)
find_package(ncnn REQUIRED)

if((IOS OR APPLE) AND NOT SIMULATOR)
  set(LIB_TYPE STATIC)
else()
  set(LIB_TYPE SHARED)
endif()
add_library(yolo_ffi ${LIB_TYPE}
  "yolo_ffi.cpp"
  "print.cpp"
  # "onnx_yolo.cpp"
  # "onnx_ffi.cpp"
  "ncnn_yolo.cpp"
  "ncnn_ffi.cpp"
)

# target_link_libraries(yolo_ffi ${OpenCV_LIBS} onnxruntime::onnxruntime)
target_link_libraries(yolo_ffi ${OpenCV_LIBS} ncnn)

set_target_properties(yolo_ffi PROPERTIES
# PUBLIC_HEADER "yolo_ffi.h;yolo_onnx.h"
  PUBLIC_HEADER "yolo_ffi.h;print.h"
  OUTPUT_NAME "yolo_ffi"
  # CXX_STANDARD 17
)
# Used Frameworks to make iOS support multiple Apple devices
if(APPLE OR IOS)
  set_target_properties(yolo_ffi PROPERTIES
    PUBLIC_HEADER "yolo_ffi.h;print.h"
    OUTPUT_NAME "yolo_ffi"
    # FRAMEWORK TRUE
    MACOSX_FRAMEWORK_IDENTIFIER "com.cia1099.yoloFfi"
    # INSTALL_RPATH "@rpath"
    # avoid symbol strip
    # MACH_O_TYPE "mh_dylib"
    # XCODE_ATTRIBUTE_DEAD_CODE_STRIPPING "NO"
    # XCODE_ATTRIBUTE_STRIP_STYLE "non-global"
    # XCODE_ATTRIBUTE_STRIP_INSTALLED_PRODUCT "NO"
    # XCODE_ATTRIBUTE_ENABLE_BITCODE "NO"  # 若 iOS >= 15 可省略
    # XCODE_ATTRIBUTE_GCC_SYMBOLS_PRIVATE_EXTERN "NO"
  )
endif()

target_compile_definitions(yolo_ffi PUBLIC DART_SHARED_LIB)

if (ANDROID)
  # Support Android 15 16k page size
  target_link_options(yolo_ffi PRIVATE "-Wl,-z,max-page-size=16384")
endif()
