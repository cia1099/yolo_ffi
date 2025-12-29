# yolo_ffi

## Common issues
* `extern "C"`: 只能作用在`.cpp`文件，这本来就是给C++的声明，让C能够识别

* 用Flutter建制安卓App，会将的C++库存在`build/app/intermediates/merged_native_libs/debug/mergeDebugNativeLibs/out/lib/arm64-v8a`，可以在这个文件夹下检查`extern "C"`是否有成功签署，让ffi可以识别这个函数:
```sh
nm libyolo_ffi.a
nm -D -C libyolo_ffi.so
#其实也可以直接
# nm libyolo_ffi.so
nm ios/Frameworks/yolo_ffi.framework/yolo_ffi 
```

* NDK资料夹下没有`libc++_shared.so`。烧录到**虚拟机**后可能链接不到，所以建库的时候不要选`-DANDROID_STL=c++_shared`。 如果是烧录到**实体手机**，是可以加上`-DANDROID_STL=c++_shared`参数。

* 编译OpenCV时，设定CMake参数`-DWITH_ADE=OFF`避免额外建制第3方库`libade.a`；`-DWITH_CAROTENE=OFF`避免第3方库`libtegra_hal.a`，通常只有在为Tegra设备（如Jetson系列）定制时才需要，绝大多数通用安卓或其他平台项目都不需要它。

* 千万不要编译`opencv_world`，因为那会附加很多不必要的库，例如highgui(GUI库)，所以如果追求最小化包体积，就只选必要的库编译。

* OpenCV里的`CMakeLists.txt`里面，find_package()可能会找到系统安装的依赖库，建立libopencv_xxx.a后引用时，就会发生找不到 include 的路径，因为被莫名依赖到了，也不知道是哪里来的，就被find_package()给找到了，自动被包含进来一起编译。可以检查从哪依赖过来：
```
grep -r "Eigen3" build/CMakeCache.txt
```
* 在`ios/yolo_ffi.podspec`强迫链接库，可以有效解决FFI找不到函数的问题[issue](https://github.com/dart-lang/sdk/issues/44328#issuecomment-855682903)
```podspec
s.vendored_libraries = 'lib/libyolo_ffi.a'
"OTHER_LDFLAGS" => "-force_load $(PODS_TARGET_SRCROOT)/lib/libyolo_ffi.a",
```
* 用CMake编译ObjC预设是没有开启ARC的，需要主动开启，不要以为代码有ARC的管理，预设是都没有的，要自己主动管理任何`alloc`, `new`, `copy`和`mutableCopy`的对象，管理`retain`和`release`，但开启了ARC后，这些方法就会被编译器禁用了。\
开启ARC：
```cmake
set_target_properties(yolo_ffi PROPERTIES
    XCODE_ATTRIBUTE_CLANG_ENABLE_OBJC_ARC YES
  )
```
注意：这个方法只在生成 Xcode 工程时有效，对 Makefile 或 Ninja 等其他 generator 不起作用。
所以其实还是所有对象都用`autorelease`最省事，因为从SDK返回的对象也不知道是不是从`alloc`来的，所以调用SDK基本都会包一层`@autoreleasepool{}`作用域。 

  * 通过源文件级别开启 ARC（可选）
如果你只想对某些 .m 文件开启 ARC，可以在 `set_source_files_properties` 里指定：
```cmake
set_source_files_properties(
    MyFile.m
    PROPERTIES
    COMPILE_FLAGS "-fobjc-arc"
)
```
`-fobjc-arc` 是 Clang 的编译器选项，强制对该文件使用 ARC。\
可以针对部分文件启用 ARC，而不影响整个 target。

## Getting Started
### Build iOS
已经用`prepare_framework.sh`来脚本编译iOS了，所以不需要再手动编译，将脚本的运行写在`ios/yolo_ffi.podspec`里面，通用其他开发者能够在不同PC上进行编译。
```sh
cmake -DCMAKE_OSX_ARCHITECTURES=arm64 \
-DCMAKE_INSTALL_PREFIX=$(pwd)/install \
-DCMAKE_OSX_SYSROOT=$(xcode-select -p)/Platforms/iPhoneSimulator.platform/Developer/SDKs/iPhoneSimulator.sdk \
-DCMAKE_OSX_DEPLOYMENT_TARGET=13.0 \
-Ssrc -Bbuild -GXcode
```

### Build opencv
* iOS Simulator
```sh
cmake -DCMAKE_OSX_ARCHITECTURES=arm64 \
-DCMAKE_INSTALL_PREFIX=$(pwd)/sim_ios \
-DCMAKE_OSX_SYSROOT=$(xcode-select -p)/Platforms/iPhoneSimulator.platform/Developer/SDKs/iPhoneSimulator.sdk \
-DCMAKE_OSX_DEPLOYMENT_TARGET=13.0 \
-DBUILD_SHARED_LIBS=OFF \
-DCMAKE_BUILD_TYPE=Release \
-DCMAKE_CXX_STANDARD=17 \
-DBUILD_LIST=core,imgproc,dnn \
-DWITH_JPEG=OFF -DWITH_PNG=OFF -DWITH_WEBP=OFF -DWITH_OPENJPEG=OFF \
-DWITH_OPENEXR=OFF -DWITH_AVFOUNDATION=OFF -DWITH_TIFF=OFF -DWITH_WEBP=OFF \
-DBUILD_ZLIB=OFF -DBUILD_OPENJPEG=OFF -DWITH_JASPER=OFF \
-DWITH_IPP=OFF -DWITH_TBB=OFF -DWITH_ITT=OFF \
-DBUILD_opencv_gapi=OFF -DWITH_ADE=OFF -DWITH_CAROTENE=OFF \
-DBUILD_DOCS=OFF -DWITH_PROTOBUF=OFF -DWITH_FLATBUFFERS=OFF  -DWITH_IPP=OFF -DWITH_TBB=OFF -DWITH_OPENCL=OFF -DWITH_CUDA=OFF \
-DWITH_EIGEN=OFF \
-S. -Bbuild -GXcode && cmake --build build --config Release -t install -j$(nproc)

# -DBUILD_EXAMPLES=OFF \
# -DBUILD_TESTS=OFF \
# -DBUILD_PERF_TESTS=OFF \
# -DBUILD_opencv_python3=OFF -DBUILD_opencv_python_bindings_generator=OFF \
# -DBUILD_opencv_js=OFF -DBUILD_opencv_objc=OFF -DBUILD_opencv_java=OFF -DBUILD_opencv_gapi=OFF -DBUILD_opencv_imgcodecs=OFF \
# -DWITH_IPP=OFF -DWITH_TBB=OFF -DWITH_OPENCL=OFF -DWITH_CUDA=OFF -DWITH_JAVA=OFF \
```
* iOS device
```sh
cmake -DCMAKE_OSX_ARCHITECTURES=arm64 \
-DCMAKE_INSTALL_PREFIX=$(pwd)/ios \
-DCMAKE_OSX_SYSROOT=$(xcode-select -p)/Platforms/iPhoneOS.platform/Developer/SDKs/iPhoneOS.sdk \
-DCMAKE_OSX_DEPLOYMENT_TARGET=13.0 \
-DBUILD_SHARED_LIBS=OFF \
-DCMAKE_BUILD_TYPE=Release \
-DCMAKE_CXX_STANDARD=17 \
-DBUILD_LIST=core,imgproc,dnn \
-DWITH_JPEG=OFF -DWITH_PNG=OFF -DWITH_WEBP=OFF -DWITH_OPENJPEG=OFF \
-DWITH_OPENEXR=OFF -DWITH_AVFOUNDATION=OFF -DWITH_TIFF=OFF -DWITH_WEBP=OFF \
-DBUILD_ZLIB=OFF -DBUILD_OPENJPEG=OFF -DWITH_JASPER=OFF -DBUILD_opencv_apps=OFF \
-DWITH_IPP=OFF -DWITH_TBB=OFF -DWITH_ITT=OFF \
-DBUILD_opencv_gapi=OFF -DWITH_ADE=OFF -DWITH_CAROTENE=OFF \
-DBUILD_DOCS=OFF -DWITH_PROTOBUF=OFF -DWITH_FLATBUFFERS=OFF  -DWITH_IPP=OFF -DWITH_TBB=OFF -DWITH_OPENCL=OFF -DWITH_CUDA=OFF -DWITH_EIGEN=OFF \
-DENABLE_APPLE_SIGNING=OFF \
-DCMAKE_XCODE_ATTRIBUTE_CODE_SIGNING_ALLOWED=NO \
-DCMAKE_XCODE_ATTRIBUTE_CODE_SIGNING_REQUIRED=NO \
-S. -Bbuild -GXcode && cmake --build build --config Release -t install -j$(nproc)
```
在iOS下，要编译为静态库，这样在链接opencv库的时候才不会报错。（onnxruntime可以是动态库，不知道为啥，微软就是屌），在苹果系统里，要链接动态库，会需要动态库的开发者签名才能链接，这也是为什么大多人都编译静态库，省得操心。因为是独立文件，会在 app 包内存在，Apple 要求每个可执行二进制都签名。
* 查看开发者签名：
```sh
security find-identity -v -p codesigning
# 签名
codesign --force --sign - path/to/libopencv_world.dylib

CODESIGN_IDENTITY="Apple Distribution: Otto Lin (ABCDE12345)"
codesign --force --sign $CODESIGN_IDENTITY path/to/libopencv_world.dylib
```
1. `--sign -`只能ad-hoc
2. 实际签署开发者才能用在生产

| 类型                     | 用途                                   |
| ---------------------- | ------------------------------------ |
| **Apple Development**  | 用于开发与测试签名（真机/模拟器都行）                  |
| **Apple Distribution** | 用于 App Store / TestFlight / AdHoc 发布 |


* 签名验证：
```sh
codesign -dvvv libopencv_dnn.dylib
```

* Android
```sh
cmake -DCMAKE_OSX_ARCHITECTURES=arm64 \
-DCMAKE_INSTALL_PREFIX=$(pwd)/android \
-DCMAKE_TOOLCHAIN_FILE=/Users/otto/Library/Android/sdk/ndk/28.0.12674087/build/cmake/android.toolchain.cmake \
-DANDROID_ABI=arm64-v8a -DCMAKE_BUILD_TYPE=Release \
-DANDROID_PLATFORM=android-24 \
-DBUILD_SHARED_LIBS=ON -DBUILD_JAVA=OFF \
-DBUILD_ANDROID_EXAMPLES=OFF \
-DCMAKE_CXX_STANDARD=17 \
-DBUILD_LIST=core,imgproc,dnn \
-DWITH_JPEG=OFF -DWITH_PNG=OFF -DWITH_WEBP=OFF -DWITH_OPENJPEG=OFF \
-DWITH_OPENEXR=OFF -DWITH_TIFF=OFF -DWITH_WEBP=OFF \
-DBUILD_ZLIB=OFF -DBUILD_OPENJPEG=OFF -DWITH_JASPER=OFF \
-DWITH_IPP=OFF -DWITH_TBB=OFF -DWITH_ITT=OFF \
-DBUILD_opencv_gapi=OFF -DWITH_ADE=OFF -DWITH_CAROTENE=OFF \
-DBUILD_DOCS=OFF -DWITH_PROTOBUF=OFF -DWITH_FLATBUFFERS=OFF -DWITH_OPENCL=OFF -DWITH_EIGEN=OFF \
-S. -Bbuild -GNinja && cmake --build build --config Release -t install -j$(nproc)

# -DANDROID_STL=c++_shared \ #For real devices
# -DANDROID_NDK=/Users/otto/Library/Android/sdk/ndk/28.0.12674087 \
```
* Start to build install target
```sh
cmake --build build --config Release -t install -j$(nproc)
```

### Build and install onnxruntime
```sh
git clone --recursive --depth=1 -b v1.23.2  https://github.com/Microsoft/onnxruntime.git
cd onnxruntime
```
[Build ONNX Runtime for inference](https://onnxruntime.ai/docs/build/inferencing.html)

* iphone simulator for onnxruntime
```sh
./build.sh --config Release --use_xcode --parallel \
--use_coreml --skip_tests \
--cmake_extra_defines CMAKE_OSX_ARCHITECTURES=arm64 CMAKE_INSTALL_PREFIX=$PWD/sim_ios \
--ios --apple_sysroot iphonesimulator --osx_arch arm64 --apple_deploy_target 13
# iphoneos
./build.sh --config Release --use_xcode --parallel \
--use_coreml --skip_tests \
--cmake_extra_defines CMAKE_OSX_ARCHITECTURES=arm64 CMAKE_INSTALL_PREFIX=$PWD/ios \
--ios --apple_sysroot iphoneos --osx_arch arm64 --apple_deploy_target 13
# install
cmake --install build/iOS/Release
```
编译iphoneos的`--minimal_build extended --use_coreml`可能会编译错误，需要最大编译才能编译出ios的库。
* android for onnxruntime
```sh
./build.sh --android --android_sdk_path /Users/otto/Library/Android/sdk \
--android_ndk_path /Users/otto/Library/Android/sdk/ndk/28.0.12674087 \
--config Release --build_shared_lib --parallel \
--minimal_build extended --use_xnnpack --use_nnapi --disable_ml_ops --disable_exceptions --skip_tests \
--cmake_generator "Ninja" \
--cmake_extra_defines CMAKE_OSX_ARCHITECTURES=arm64 CMAKE_INSTALL_PREFIX=$PWD/android \
--android_abi arm64-v8a --android_api 35
```

### Build ncnn
```sh
git clone --recursive --depth=1 -b 20250916 https://github.com/Tencent/ncnn.git
```
* Android
```sh
cmake -DCMAKE_TOOLCHAIN_FILE="$ANDROID_NDK/build/cmake/android.toolchain.cmake" \
-DANDROID_ABI="arm64-v8a" -DANDROID_ARM_NEON=ON \
-DANDROID_PLATFORM=android-21 -DNCNN_VULKAN=ON \
-DCMAKE_INSTALL_PREFIX=$PWD/android -DBUILD_SHARED_LIBS=ON \
-S. -Bbuild -G Ninja && \
cmake --build build --config Release -t install -j$(nproc)
```

* Export torchscript
[use ncnn with pytorch or onnx](https://github.com/Tencent/ncnn/wiki/use-ncnn-with-pytorch-or-onnx)
```sh
python3 -c "from ultralytics import YOLO;model = YOLO('yolo11n.pt');model.export(format='torchscript')"
pnnx yolo11n.torchscript "inputshape=[1,3,640,640]" ncnnpy=ncnn_example.py

```

* Build ncnnoptimize
```sh
cd ncnn/tools
cmake -S.. -Bbuild \
-DNCNN_BUILD_BENCHMARK=OFF \
-DNCNN_BUILD_EXAMPLES=OFF \
-DNCNN_BUILD_TOOLS=ON \
-DNCNN_BUILD_GPU=OFF \
-DNCNN_BUILD_TESTS=OFF \
-DNCNN_DISABLE_RTTI=ON \
-DNCNN_DISABLE_EXCEPTION=ON \
-DNCNN_SHARED_LIB=ON

# look all targets
cmake --build build -t help
cmake --build build --config Release -t ncnnoptimize -j$(nproc)
```

---

# CoreML
* export from ultralytics
```
pip install ultralytics coremltools
yolo export model=yolo11n.pt format=mlmodel
```
[see more support export formats](https://docs.ultralytics.com/yolov5/tutorials/model_export/#supported-export-formats)

---
# Upload test flight
后面的`-p`不知道是干啥的
```sh
flutter build ipa
xcrun altool --upload-app -t ios -f build/ios/ipa/*.ipa -u cia1099@icloud.com -p ojly-cxow-jazz-qtvb
```


### FFI tutorial
* [official](https://dart.dev/interop/c-interop)

---
This project is a starting point for a Flutter
[FFI plugin](https://flutter.dev/to/ffi-package),
a specialized package that includes native code directly invoked with Dart FFI.

## Project structure

This template uses the following structure:

* `src`: Contains the native source code, and a CmakeFile.txt file for building
  that source code into a dynamic library.

* `lib`: Contains the Dart code that defines the API of the plugin, and which
  calls into the native code using `dart:ffi`.

* platform folders (`android`, `ios`, `windows`, etc.): Contains the build files
  for building and bundling the native code library with the platform application.

## Building and bundling native code

The `pubspec.yaml` specifies FFI plugins as follows:

```yaml
  plugin:
    platforms:
      some_platform:
        ffiPlugin: true
```

This configuration invokes the native build for the various target platforms
and bundles the binaries in Flutter applications using these FFI plugins.

This can be combined with dartPluginClass, such as when FFI is used for the
implementation of one platform in a federated plugin:

```yaml
  plugin:
    implements: some_other_plugin
    platforms:
      some_platform:
        dartPluginClass: SomeClass
        ffiPlugin: true
```

A plugin can have both FFI and method channels:

```yaml
  plugin:
    platforms:
      some_platform:
        pluginClass: SomeName
        ffiPlugin: true
```

The native build systems that are invoked by FFI (and method channel) plugins are:

* For Android: Gradle, which invokes the Android NDK for native builds.
  * See the documentation in android/build.gradle.
* For iOS and MacOS: Xcode, via CocoaPods.
  * See the documentation in ios/yolo_ffi.podspec.
  * See the documentation in macos/yolo_ffi.podspec.
* For Linux and Windows: CMake.
  * See the documentation in linux/CMakeLists.txt.
  * See the documentation in windows/CMakeLists.txt.

## Binding to native code

To use the native code, bindings in Dart are needed.
To avoid writing these by hand, they are generated from the header file
(`src/yolo_ffi.h`) by `package:ffigen`.
Regenerate the bindings by running `dart run ffigen --config ffigen.yaml`.


---
更新简历

边缘设备的实时目标检测实践
内容：
1. 部署YOLO模型到手机设备，完成实时目标检测，无损主线程画面刷新和用户操作控制的屏幕
2. 使用NDK和CMake去跨平台编译ONNX，OpenCV，NCNN和MNN二进制函数库，供安卓应用链接和调用
3. 混合Object-C和C++混合编译以CoreML框架的iOS平台函数库，直接以FFi接口取代MethodChannel的通信，减少Dart和原生之间通信的序列化和反序列化的耗时开销，避免跨语言之间存在的资料拷贝造成的延迟，统一在C++的环境下完成推理的所有动作，图像前处理，推理，推理结果后处理完成后，再回调给Dart端
4. 优化资料类型转换和非必要拷贝操作，都在相同的内存空间下操作数据，不做额外不必要的配置新内存，提升CPU捕获快取的成功率，保持内存空间的连续性
5. 分离UI和模型推理的逻辑，利用Isolate独立运行模型的推理，不阻塞主线程的UI刷新，用无锁的queue保存相机传入的图像资料，保证模型推理不阻塞相机的串流影像显示在主UI上

业绩：
部署安卓和苹果的平台上执行实时的目标检测，达到60 FPS无损UI刷新画面的多工性，在边缘设备上可以记录每一画面的目标位置，不需要远程服务器负载任何推理程序

---
#### GPT modified
边缘设备实时目标检测系统（Flutter / C++ / CoreML / NDK）

角色： Flutter 资深工程师 / 跨平台性能优化负责人
技术栈： Flutter、Dart Isolate、C++17、NDK、CMake、ONNX、NCNN、MNN、OpenCV、CoreML、Objective-C++、FFI

项目概述：
设计并实现一套 高性能、低延迟的边缘端实时目标检测系统，在 Android 与 iOS 设备上以 Flutter 作为统一 UI 框架，通过原生 C++ 推理引擎与零拷贝内存设计，在不牺牲 UI 流畅度的前提下，实现 60 FPS 实时目标检测，完全脱离云端推理依赖。

核心技术实现：
1. 跨平台高性能推理架构设计
* 将 YOLO 系列模型部署至移动端边缘设备，统一在 C++ 推理层完成图像前处理、模型推理与后处理，避免多语言重复实现与性能损耗

* 针对 Android / iOS 平台差异，抽象统一的推理接口层，提升系统可维护性与可扩展性

2. Flutter ↔ 原生通信性能重构（FFI 替代 MethodChannel）

* 在 iOS 端采用 Objective-C++ + CoreML 混合编译，直接暴露 C ABI 给 Dart FFI

* 完全绕过 MethodChannel 的消息编解码与对象重建流程，避免 Dart VM 与原生层之间因序列化、内存复制及类型转换带来的额外开销

* 将推理全流程（preprocess → inference → postprocess）收敛至 C++ 层，仅回传最终结构化结果至 Dart

3. 极致内存管理与零拷贝优化

* 重构图像与张量数据结构，复用同一块连续内存区域完成图像采集、前处理与推理

* 避免不必要的 malloc / free 与中间 buffer 分配，显著降低 GC 与内存抖动


4. CPU / GPU / Neural Engine 调度优化

* 在 iOS 端基于 CoreML 的 Compute Units 策略，动态选择 CPU / GPU / Neural Engine，结合OpenCV库，对 ARM 架构优化运算处理图像数据

* 针对不同模型规模与设备性能，评估能耗与延迟表现，平衡实时性与功耗

* Android 端结合 NCNN / MNN 框架和OpenCV库，针对 ARM 架构优化算子执行路径

5. 多线程与并发模型设计（Flutter Isolate）

* 严格分离 UI 与模型推理逻辑

* 使用 Dart Isolate 独立运行推理任务，确保主线程专注于 UI 渲染与用户交互

* 通过 无锁（lock-free）队列 缓存相机帧数据，避免推理阻塞相机串流与画面显示

6. 原生库跨平台构建体系

* 使用 NDK + CMake 构建 Android 平台 ONNX、OpenCV、NCNN、MNN 等原生库

* 通过 Objective-C++ 在同一编译单元内直接调用 Apple 原生 SDK 与 C++ 推理与图像处理库，规避 JNI / FFI / PlatformChannel 等跨层通信模型，减少 ABI 边界、对象封装及内存拷贝带来的性能损耗

* 统一管理编译参数与 ABI，确保在多设备架构下的稳定性与性能一致性

项目成果（Impact）：

1. 在 Android 与 iOS 边缘设备 上实现 60 FPS 实时目标检测，UI 刷新零掉帧

2. 每一帧影像可实时记录目标位置与分类结果，无需依赖任何远程服务器推理

3. Flutter 应用在高负载 AI 推理场景下依然保持流畅交互体验

4. 显著降低跨语言通信开销与内存占用，系统整体延迟大幅下降

5. 架构具备高度可扩展性，可快速替换不同模型与推理后端




