# The Flutter tooling requires that developers have CMake 3.10 or later
# installed. You should not increase this version, as doing so will cause
# the plugin to fail to compile for some customers of the plugin.
cmake_minimum_required(VERSION 3.10)

project(yolo_ffi_library VERSION 1.0.0 LANGUAGES CXX)

# Set the $LIBRARIES_DIR to point directly to the package config files
if(ANDROID)
    # set(onnxruntime_DIR ${CMAKE_SOURCE_DIR}/../../onnxruntime/android/lib/cmake/onnxruntime)
    set(OpenCV_DIR ${CMAKE_SOURCE_DIR}/../../opencv/android/sdk/native/jni/abi-arm64-v8a)
    set(ncnn_DIR ${CMAKE_SOURCE_DIR}/../../ncnn/android/lib/cmake/ncnn)
elseif(APPLE OR IOS)
  if(CMAKE_OSX_SYSROOT MATCHES "iphonesimulator")
    set(IOS_DIR sim_ios)
    # set(onnxruntime_DIR ${CMAKE_SOURCE_DIR}/../ort/sim_ios/lib/cmake/onnxruntime)
  else()
    set(IOS_DIR ios)
  endif()
    # set(onnxruntime_DIR ${CMAKE_SOURCE_DIR}/../../onnxruntime/${IOS_DIR}/lib/cmake/onnxruntime)
    set(OpenCV_DIR ${CMAKE_SOURCE_DIR}/../../opencv/${IOS_DIR}/lib/cmake/opencv4)
endif()

# find_package(onnxruntime REQUIRED)
find_package(OpenCV REQUIRED COMPONENTS core imgproc dnn)
if(IOS OR APPLE)
  find_library(FOUNDATION Foundation)
  find_library(COREML CoreML)
  find_library(COREVIDEO CoreVideo)
  find_library(VISION Vision)
else()
  find_package(ncnn REQUIRED)
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

# target_include_directories(yolo_ffi PUBLIC ${OpenCV_INCLUDE_DIRS})
# target_link_libraries(yolo_ffi ${OpenCV_LIBS} onnxruntime::onnxruntime)
target_link_libraries(yolo_ffi ${OpenCV_LIBS})
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
    # XCODE_ATTRIBUTE_ENABLE_BITCODE "NO"  # 若 iOS >= 15 可省略
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
