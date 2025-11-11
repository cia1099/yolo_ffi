#!/bin/bash
set -e
cd $PWD/..

# --- Configuration ---
FRAMEWORK_NAME="yolo_ffi.framework"
IOS_FRAMEWORKS_DIR="ios/Frameworks"
BUILD_DIR="build"
SRC_DIR="src"
TARGET_OS="16.0"

# --- Build for iOS Simulator ---
SIMULATOR_BUILD_DIR="$BUILD_DIR/simulator"
SIMULATOR_ARCH="arm64" # For Intel Macs. Use "arm64" for Apple Silicon Macs.

echo "🚀 Starting build for iOS Simulator ($SIMULATOR_ARCH)..."
rm -rf build

cmake -S "$SRC_DIR" -B "$SIMULATOR_BUILD_DIR" -G Xcode \
  -DCMAKE_OSX_SYSROOT=$(xcode-select -p)/Platforms/iPhoneSimulator.platform/Developer/SDKs/iPhoneSimulator.sdk \
  -DCMAKE_OSX_DEPLOYMENT_TARGET="$TARGET_OS" \
  -DCMAKE_OSX_ARCHITECTURES="$SIMULATOR_ARCH"

cmake --build "$SIMULATOR_BUILD_DIR" --config Release
echo "✅ Build for iOS Simulator complete."

# --- TODO: Build for iOS Device ---
# When you are ready to build for a real device, uncomment the following section.
# You will also need to update the "Create Universal Framework" section below.
#
# DEVICE_BUILD_DIR="$BUILD_DIR/device"
# DEVICE_ARCH="arm64"
#
# echo "🚀 Starting build for iOS Device ($DEVICE_ARCH)..."
# cmake -S "$SRC_DIR" -B "$DEVICE_BUILD_DIR" -G Xcode \
#   -DCMAKE_OSX_SYSROOT=$(xcode-select -p)/Platforms/iPhoneOS.platform/Developer/SDKs/iPhoneOS.sdk \
#   -DCMAKE_OSX_DEPLOYMENT_TARGET="$TARGET_OS" \
#   -DCMAKE_OSX_ARCHITECTURES="$DEVICE_ARCH"

# cmake --build "$DEVICE_BUILD_DIR" --config Release
# echo "✅ Build for iOS Device complete."


# --- Prepare final destination ---
echo "📦 Preparing destination directory: $IOS_FRAMEWORKS_DIR"
rm -rf "$IOS_FRAMEWORKS_DIR/$FRAMEWORK_NAME"
mkdir -p "$IOS_FRAMEWORKS_DIR"

# --- Copy Simulator Framework (Temporary) ---
# This step just copies the simulator framework.
# When you enable the device build, you should replace this with the
# "Create Universal Framework" section below.

echo "🏗 Copying simulator framework..."
cp -r "$SIMULATOR_BUILD_DIR/Release-iphonesimulator/$FRAMEWORK_NAME" "$IOS_FRAMEWORKS_DIR/"


# --- TODO: Create Universal (Fat) Framework ---
# When you have both simulator and device builds, comment out the "Copy Simulator"
# section above and uncomment this section.
#
# echo "🏗 Creating universal (fat) framework..."
#
# # 1. Copy the framework structure from the device build
# cp -R "$DEVICE_BUILD_DIR/Release-iphoneos/$FRAMEWORK_NAME" "$IOS_FRAMEWORKS_DIR/"
#
# # 2. Use `lipo` to merge the binaries
# lipo -create \
#   "$SIMULATOR_BUILD_DIR/Release-iphonesimulator/$FRAMEWORK_NAME/yolo_ffi" \
#   "$DEVICE_BUILD_DIR/Release-iphoneos/$FRAMEWORK_NAME/yolo_ffi" \
#   -output "$IOS_FRAMEWORKS_DIR/$FRAMEWORK_NAME/yolo_ffi"
#
# echo "✅ Universal framework created."


rm -rf build
echo "🎉 Framework preparation complete!"
