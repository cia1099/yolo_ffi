# The Flutter tooling requires that developers have CMake 3.10 or later
# installed. You should not increase this version, as doing so will cause
# the plugin to fail to compile for some customers of the plugin.
cmake_minimum_required(VERSION 3.14)

project(yolo_ffi_library VERSION 1.0.0 LANGUAGES CXX)
include(FetchContent)
set(CMAKE_BUILD_TYPE Release)

# MARK:- OpenCV clone from github
FetchContent_Declare(
  opencv
  GIT_REPOSITORY https://github.com/opencv/opencv.git
  GIT_TAG        4.13.0
  GIT_SHALLOW    TRUE
)
set(CMAKE_CXX_STANDARD 17 CACHE INTERNAL "")
set(BUILD_LIST "core;imgproc;dnn" CACHE INTERNAL "")
set(BUILD_JAVA OFF CACHE INTERNAL "")
set(BUILD_ANDROID_EXAMPLES OFF CACHE INTERNAL "")
set(BUILD_DOCS OFF CACHE INTERNAL "")
set(BUILD_opencv_apps OFF CACHE INTERNAL "")
set(BUILD_opencv_gapi OFF CACHE INTERNAL "")
set(BUILD_ZLIB OFF CACHE INTERNAL "")
set(BUILD_OPENJPEG OFF CACHE INTERNAL "")
set(WITH_JPEG OFF CACHE INTERNAL "")
set(WITH_PNG OFF CACHE INTERNAL "")
set(WITH_WEBP OFF CACHE INTERNAL "")
set(WITH_OPENJPEG OFF CACHE INTERNAL "")
set(WITH_OPENEXR OFF CACHE INTERNAL "")
set(WITH_TIFF OFF CACHE INTERNAL "")
set(WITH_JASPER OFF CACHE INTERNAL "")
set(WITH_IPP OFF CACHE INTERNAL "")
set(WITH_TBB OFF CACHE INTERNAL "")
set(WITH_ITT OFF CACHE INTERNAL "")
set(WITH_ADE OFF CACHE INTERNAL "")
set(WITH_CAROTENE OFF CACHE INTERNAL "")
set(WITH_PROTOBUF OFF CACHE INTERNAL "")
set(WITH_FLATBUFFERS OFF CACHE INTERNAL "")
set(WITH_OPENCL OFF CACHE INTERNAL "")
set(WITH_EIGEN OFF CACHE INTERNAL "")
set(WITH_CUDA OFF CACHE INTERNAL "")
set(WITH_AVFOUNDATION OFF CACHE INTERNAL "")

# Set the $LIBRARIES_DIR to point directly to the package config files
if(ANDROID)
    set(BUILD_SHARED_LIBS ON CACHE INTERNAL "")
    # MARK:- NCNN clone from github
    set(NCNN_VULKAN OFF CACHE BOOL "" FORCE)
    set(NCNN_AVX OFF CACHE BOOL "" FORCE)
    set(NCNN_SHARED_LIB ON CACHE BOOL "" FORCE)
    set(NCNN_BUILD_BENCHMARK OFF CACHE BOOL "" FORCE)
    FetchContent_Declare(
      ncnn
      GIT_REPOSITORY https://github.com/Tencent/ncnn.git
      GIT_TAG        20250916
      GIT_SHALLOW    TRUE
      GIT_SUBMODULES_RECURSE TRUE
    )
elseif(APPLE OR IOS)
  set(BUILD_SHARED_LIBS OFF CACHE INTERNAL "")
endif()

FetchContent_MakeAvailable(opencv)
if(IOS OR APPLE)
  find_library(FOUNDATION Foundation)
  find_library(COREML CoreML)
  find_library(COREVIDEO CoreVideo)
  find_library(VISION Vision)
else()
  FetchContent_MakeAvailable(ncnn)
endif()

set(SOURCES
  "yolo_ffi.cpp"
  "print.cpp"
  # "onnx_yolo.cpp"
  # "onnx_ffi.cpp"
)
if(IOS OR APPLE)
  enable_language(OBJCXX)
  list(APPEND SOURCES "coreml_yolo.mm" "coreml_ffi.mm")
else()
  list(APPEND SOURCES "ncnn_yolo.cpp" "ncnn_ffi.cpp")
endif()

if(ANDROID)
  set(LIB_TYPE SHARED)
else()
  set(LIB_TYPE STATIC)
endif()
add_library(yolo_ffi ${LIB_TYPE} ${SOURCES})


# <<<< Debug
message(STATUS "OpenCV Source: ${opencv_SOURCE_DIR}")
message(STATUS "OpenCV Binary: ${opencv_BINARY_DIR}")
message(STATUS "OpenCV Config Dir: ${OPENCV_CONFIG_FILE_INCLUDE_DIR}")
file(GLOB_RECURSE FOUND_MODULE_HPP "${opencv_BINARY_DIR}/opencv2/opencv_modules.hpp")
message(STATUS "Real path of modules.hpp: ${FOUND_MODULE_HPP}")
# <<<<

target_include_directories(yolo_ffi PRIVATE
  ${opencv_SOURCE_DIR}/include
  ${opencv_SOURCE_DIR}/modules/core/include
  ${opencv_SOURCE_DIR}/modules/imgproc/include
  ${opencv_SOURCE_DIR}/modules/dnn/include
  ${OPENCV_CONFIG_FILE_INCLUDE_DIR}
)
target_link_libraries(yolo_ffi opencv_core opencv_imgproc opencv_dnn)
if(ANDROID)
  target_link_libraries(yolo_ffi ncnn)
else()
  target_link_libraries(yolo_ffi ${FOUNDATION} ${COREML} ${VISION} ${COREVIDEO})
endif()
set_target_properties(yolo_ffi PROPERTIES
  PUBLIC_HEADER "yolo_ffi.h;print.h"
  OUTPUT_NAME "yolo_ffi"
  # CXX_STANDARD 17
)
# Used Frameworks to make iOS support multiple Apple devices
if(APPLE OR IOS)
  set_target_properties(yolo_ffi PROPERTIES
    # FRAMEWORK TRUE
    MACOSX_FRAMEWORK_IDENTIFIER "com.cia1099.yoloFfi"
    XCODE_ATTRIBUTE_CLANG_ENABLE_OBJC_ARC YES
    # XCODE_ATTRIBUTE_CODE_SIGNING_REQUIRED NO  # when build .dylib
    # XCODE_ATTRIBUTE_CODE_SIGNING_ALLOWED NO  # when build .dylib
    # XCODE_ATTRIBUTE_DEVELOPMENT_TEAM "your team ID"  # for distribute
    # XCODE_ATTRIBUTE_CODE_SIGN_STYLE "Automatic"
    # XCODE_ATTRIBUTE_CODE_SIGN_IDENTITY "Apple Distribution"
    # INSTALL_RPATH "@rpath"
    # avoid symbol strip
    # MACH_O_TYPE "mh_dylib"
    # XCODE_ATTRIBUTE_DEAD_CODE_STRIPPING "NO"
    # XCODE_ATTRIBUTE_STRIP_STYLE "non-global"
    # XCODE_ATTRIBUTE_STRIP_INSTALLED_PRODUCT "NO"
    # XCODE_ATTRIBUTE_ENABLE_BITCODE "NO"
    # XCODE_ATTRIBUTE_GCC_SYMBOLS_PRIVATE_EXTERN "NO"
  )
  target_include_directories(yolo_ffi PRIVATE ${CMAKE_OSX_SYSROOT}/System/Library/Frameworks)
endif()

target_compile_definitions(yolo_ffi PUBLIC DART_SHARED_LIB)

if (ANDROID)
  # Support Android 15 16k page size
  target_link_options(yolo_ffi PRIVATE "-Wl,-z,max-page-size=16384")
endif()

# MARK:- Install this yolo_ffi library
include(GNUInstallDirs)
include(CMakePackageConfigHelpers)

install(TARGETS yolo_ffi
  EXPORT yolo_ffi_export_set
  ARCHIVE DESTINATION ${CMAKE_INSTALL_LIBDIR}
  LIBRARY DESTINATION ${CMAKE_INSTALL_LIBDIR}
  RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR}
  FRAMEWORK DESTINATION ${CMAKE_INSTALL_LIBDIR}
  PUBLIC_HEADER DESTINATION ${CMAKE_INSTALL_INCLUDEDIR}
)

install(EXPORT yolo_ffi_export_set
  FILE yolo_ffiTargets.cmake
  # NAMESPACE yolo_ffi::
  DESTINATION ${CMAKE_INSTALL_LIBDIR}/cmake/yolo_ffi
)

write_basic_package_version_file(
  ${CMAKE_CURRENT_BINARY_DIR}/yolo_ffiConfigVersion.cmake
  VERSION ${PROJECT_VERSION}
  COMPATIBILITY AnyNewerVersion
)

configure_package_config_file(
  cmake/yolo_ffiConfig.cmake.in
  ${CMAKE_CURRENT_BINARY_DIR}/yolo_ffiConfig.cmake
  INSTALL_DESTINATION ${CMAKE_INSTALL_LIBDIR}/cmake/yolo_ffi
  PATH_VARS CMAKE_INSTALL_INCLUDEDIR CMAKE_INSTALL_LIBDIR
)

install(FILES
  ${CMAKE_CURRENT_BINARY_DIR}/yolo_ffiConfig.cmake
  ${CMAKE_CURRENT_BINARY_DIR}/yolo_ffiConfigVersion.cmake
  DESTINATION ${CMAKE_INSTALL_LIBDIR}/cmake/yolo_ffi
)
