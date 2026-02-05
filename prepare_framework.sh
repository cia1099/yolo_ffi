#!/bin/bash
set -e
cd $PWD/..
# --- Configuration ---
FRAMEWORK_NAME="yolo_ffi"
IOS_FRAMEWORKS_DIR="ios/Frameworks"
BUILD_DIR="build"
SRC_DIR="src"
TARGET_OS="13.0"
ARCHS="arm64"

# --- Clean up previous builds ---
echo "🧹 Cleaning up previous builds..."
rm -rf "$BUILD_DIR"
rm -rf "$IOS_FRAMEWORKS_DIR/${FRAMEWORK_NAME}.xcframework"


# --- Build for iOS Device ---
echo "🚀 Starting build for iOS Device..."
cmake -DCMAKE_OSX_SYSROOT=iphoneos \
  -DCMAKE_OSX_DEPLOYMENT_TARGET="$TARGET_OS" \
  -DCMAKE_OSX_ARCHITECTURES=$ARCHS \
-S "$SRC_DIR" -B "$BUILD_DIR" -G Xcode && \
cmake --build "$BUILD_DIR" --config Release -t yolo_ffi -j$(nproc) && \
echo "✅ Build for iOS complete, 📱 Platform name: iphoneos"
# --- Build for iOS Simulator ---
echo "🚀 Starting build for iOS Simulator..."
cmake -DCMAKE_OSX_SYSROOT=iphonesimulator \
  -DCMAKE_OSX_DEPLOYMENT_TARGET="$TARGET_OS" \
  -DCMAKE_OSX_ARCHITECTURES=$ARCHS \
-S "$SRC_DIR" -B "$BUILD_DIR" -G Xcode && \
cmake --build "$BUILD_DIR" --config Release -t yolo_ffi -j$(nproc) && \
echo "✅ Build for iOS complete, 📱 Platform name: iphonesimulator."


# --- Prepare final destination ---
echo "📦 Preparing destination directory: $IOS_FRAMEWORKS_DIR"
mkdir -p "$IOS_FRAMEWORKS_DIR"
# --- Create XCFramework ---
echo "🏗 Creating XCFramework..."
xcodebuild -create-xcframework \
    -library "$BUILD_DIR/Release-iphonesimulator/lib$FRAMEWORK_NAME.a" \
    -library "$BUILD_DIR/Release-iphoneos/lib$FRAMEWORK_NAME.a" \
    -output "$IOS_FRAMEWORKS_DIR/${FRAMEWORK_NAME}.xcframework"

echo "✅ XCFramework created."


# --- Clean up build directories ---
rm -rf "$BUILD_DIR"
echo "🎉 Framework preparation complete!"
