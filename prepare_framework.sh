#!/bin/bash
set -e
cd $PWD/..
# --- Configuration ---
FRAMEWORK_NAME="yolo_ffi"
IOS_FRAMEWORKS_DIR="ios/Frameworks"
BUILD_DIR="build"
SRC_DIR="src"
TARGET_OS="13.0"

# --- Clean up previous builds ---
echo "🧹 Cleaning up previous builds..."
rm -rf "$BUILD_DIR"
rm -rf "$IOS_FRAMEWORKS_DIR/${FRAMEWORK_NAME}.xcframework"
rm -rf "$IOS_FRAMEWORKS_DIR/${FRAMEWORK_NAME}.framework"


# --- Build for iOS Simulator ---
SIMULATOR_BUILD_DIR="$BUILD_DIR/simulator"
SIMULATOR_ARCH="arm64" # For Apple Silicon Macs. Use "x86_64" for Intel Macs.

echo "🚀 Starting build for iOS Simulator ($SIMULATOR_ARCH)..."
cmake -S "$SRC_DIR" -B "$SIMULATOR_BUILD_DIR" -G Xcode \
  -DCMAKE_SYSTEM_NAME=iOS \
  -DCMAKE_OSX_SYSROOT=$(xcode-select -p)/Platforms/iPhoneSimulator.platform/Developer/SDKs/iPhoneSimulator.sdk \
  -DCMAKE_OSX_DEPLOYMENT_TARGET="$TARGET_OS" \
  -DCMAKE_OSX_ARCHITECTURES="$SIMULATOR_ARCH" \
  -DSIMULATOR=ON

cmake --build "$SIMULATOR_BUILD_DIR" --config Release
echo "✅ Build for iOS Simulator complete."


# --- Build for iOS Device ---
DEVICE_BUILD_DIR="$BUILD_DIR/device"
DEVICE_ARCH="arm64"

echo "🚀 Starting build for iOS Device ($DEVICE_ARCH)..."
cmake -S "$SRC_DIR" -B "$DEVICE_BUILD_DIR" -G Xcode \
  -DCMAKE_SYSTEM_NAME=iOS \
  -DCMAKE_OSX_SYSROOT=$(xcode-select -p)/Platforms/iPhoneOS.platform/Developer/SDKs/iPhoneOS.sdk \
  -DCMAKE_OSX_DEPLOYMENT_TARGET="$TARGET_OS" \
  -DCMAKE_OSX_ARCHITECTURES="$DEVICE_ARCH"

cmake --build "$DEVICE_BUILD_DIR" --config Release
echo "✅ Build for iOS Device complete."


# --- Prepare final destination ---
echo "📦 Preparing destination directory: $IOS_FRAMEWORKS_DIR"
mkdir -p "$IOS_FRAMEWORKS_DIR"


# --- Create XCFramework ---
echo "🏗 Creating XCFramework..."
xcodebuild -create-xcframework \
    -framework "$SIMULATOR_BUILD_DIR/Release-iphonesimulator/${FRAMEWORK_NAME}.framework" \
    -framework "$DEVICE_BUILD_DIR/Release-iphoneos/${FRAMEWORK_NAME}.framework" \
    -output "$IOS_FRAMEWORKS_DIR/${FRAMEWORK_NAME}.xcframework"

echo "✅ XCFramework created."


# --- Clean up build directories ---
rm -rf "$BUILD_DIR"
echo "🎉 Framework preparation complete!"
