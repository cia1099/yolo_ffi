# The Flutter tooling requires that developers have CMake 3.10 or later
# installed. You should not increase this version, as doing so will cause
# the plugin to fail to compile for some customers of the plugin.
cmake_minimum_required(VERSION 3.14)

project(yolo_ffi_library VERSION 1.0.0 LANGUAGES CXX)
include(FetchContent)
set(CMAKE_BUILD_TYPE Release CACHE STRING "Build type" FORCE)
cmake_policy(SET CMP0077 NEW)
# cmake_policy(SET CMP0177 SILENT)

FetchContent_Declare(
  opencv
  GIT_REPOSITORY https://github.com/opencv/opencv.git
  GIT_TAG        4.12.0
  GIT_SHALLOW    TRUE
)

# Set the SHARED_LIBS for iOS and Android
if(APPLE OR IOS)
  set(BUILD_SHARED_LIBS OFF CACHE BOOL "")
else()
  set(BUILD_SHARED_LIBS ON CACHE BOOL "")
  FetchContent_Declare(
    ncnn
    GIT_REPOSITORY https://github.com/Tencent/ncnn.git
    GIT_TAG        20250916
    GIT_SHALLOW    TRUE
    GIT_SUBMODULES_RECURSE TRUE
  )
endif()

# MARK:- OpenCV configuration
set(CMAKE_CXX_STANDARD 17 CACHE STRING "C++ standard (>= 17 required)")
set(BUILD_LIST "core;imgproc;dnn" CACHE STRING "")
set(BUILD_JAVA OFF CACHE BOOL "")
set(BUILD_ANDROID_EXAMPLES OFF CACHE BOOL "")
set(BUILD_DOCS OFF CACHE BOOL "")
set(BUILD_opencv_apps OFF CACHE BOOL "")
set(BUILD_opencv_gapi OFF CACHE BOOL "")
set(BUILD_ZLIB OFF CACHE BOOL "")
set(BUILD_OPENJPEG OFF CACHE BOOL "")
set(WITH_JPEG OFF CACHE BOOL "")
set(WITH_PNG OFF CACHE BOOL "")
set(WITH_WEBP OFF CACHE BOOL "")
set(WITH_OPENJPEG OFF CACHE BOOL "")
set(WITH_OPENEXR OFF CACHE BOOL "")
set(WITH_TIFF OFF CACHE BOOL "")
set(WITH_JASPER OFF CACHE BOOL "")
set(WITH_IPP OFF CACHE BOOL "")
set(WITH_TBB OFF CACHE BOOL "")
set(WITH_ITT OFF CACHE BOOL "")
set(WITH_ADE OFF CACHE BOOL "")
set(WITH_CAROTENE OFF CACHE BOOL "")
set(WITH_PROTOBUF OFF CACHE BOOL "")
set(WITH_FLATBUFFERS OFF CACHE BOOL "")
set(WITH_OPENCL OFF CACHE BOOL "")
set(WITH_EIGEN OFF CACHE BOOL "")
set(WITH_CUDA OFF CACHE BOOL "")
set(WITH_AVFOUNDATION OFF CACHE BOOL "")
if(CMAKE_CXX_STANDARD LESS 17)
  message(FATAL_ERROR "C++17 or newer is required")
endif()
FetchContent_MakeAvailable(opencv)
if(IOS OR APPLE)
  find_library(FOUNDATION Foundation)
  find_library(COREML CoreML)
  find_library(COREVIDEO CoreVideo)
  find_library(VISION Vision)
else()
# MARK:- ncnn configuration
  set(NCNN_AVX OFF CACHE BOOL "" FORCE)
  set(NCNN_SHARED_LIB ON CACHE BOOL "" FORCE)
  FetchContent_MakeAvailable(ncnn)
endif()

set(HEADERS "yolo_ffi.h;print.h")
set(SOURCES
  "yolo_ffi.cpp"
  "print.cpp"
  # "onnx_yolo.cpp"
  # "onnx_ffi.cpp"
)
if(IOS OR APPLE)
  list(APPEND SOURCES "coreml_yolo.mm" "coreml_ffi.mm")
  list(APPEND HEADERS "coreml_yolo.h")
else()
  list(APPEND SOURCES "ncnn_yolo.cpp" "ncnn_ffi.cpp")
  list(APPEND HEADERS "ncnn_yolo.h")
endif()

if(APPLE)
  set(LIB_TYPE STATIC)
else()
  set(LIB_TYPE SHARED)
endif()
add_library(yolo_ffi ${LIB_TYPE} ${SOURCES})


foreach(module ${BUILD_LIST})
  target_include_directories(yolo_ffi PRIVATE ${opencv_SOURCE_DIR}/modules/${module}/include)
  target_link_libraries(yolo_ffi opencv_${module})
endforeach()

target_include_directories(yolo_ffi PRIVATE
  ${opencv_SOURCE_DIR}/include
  ${CMAKE_BINARY_DIR}
)

if(APPLE)
  target_link_libraries(yolo_ffi ${FOUNDATION} ${COREML} ${VISION} ${COREVIDEO})
else()
  target_link_libraries(yolo_ffi ncnn)
endif()
set_property(TARGET yolo_ffi PROPERTY
  PUBLIC_HEADER ${HEADERS}
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
  # target_include_directories(yolo_ffi PRIVATE ${CMAKE_OSX_SYSROOT}/System/Library/Frameworks)
  
  set(OPENCV_STATIC_LIBS "")
  foreach(module ${BUILD_LIST})
    list(APPEND OPENCV_STATIC_LIBS ${opencv_BINARY_DIR}/lib/${CMAKE_BUILD_TYPE}/libopencv_${module}.a)
  endforeach()

  add_custom_command(
    TARGET yolo_ffi
    POST_BUILD
    COMMAND /usr/bin/libtool
            -static
            -o ${CMAKE_BINARY_DIR}/${CMAKE_BUILD_TYPE}-${CMAKE_OSX_SYSROOT}/libyolo_ffi.a
            ${CMAKE_BINARY_DIR}/${CMAKE_BUILD_TYPE}-${CMAKE_OSX_SYSROOT}/libyolo_ffi.a
            ${OPENCV_STATIC_LIBS}
    COMMENT "Merging libyolo_ffi.a with OpenCV static libraries"
    VERBATIM
  )
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
  PUBLIC_HEADER DESTINATION ${CMAKE_INSTALL_INCLUDEDIR}/yolo_ffi
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
