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

---

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






