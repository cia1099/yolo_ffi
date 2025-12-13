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
PLATFORM_NAME="iphoneos"
# PLATFORM_NAME="iphonesimulator"

# --- Clean up previous builds ---
echo "🧹 Cleaning up previous builds..."
rm -rf "$BUILD_DIR"
rm -rf "$IOS_FRAMEWORKS_DIR/${FRAMEWORK_NAME}.xcframework"
rm -rf "$IOS_FRAMEWORKS_DIR/${FRAMEWORK_NAME}.framework"


if [[ "$PLATFORM_NAME" == *"iphonesimulator"* ]]; then
  # --- Build for iOS Simulator ---
  echo "🚀 Starting build for iOS Simulator..."
  cmake -S "$SRC_DIR" -B "$BUILD_DIR" -G Xcode \
    -DCMAKE_SYSTEM_NAME=iOS \
    -DCMAKE_OSX_SYSROOT=$(xcode-select -p)/Platforms/iPhoneSimulator.platform/Developer/SDKs/iPhoneSimulator.sdk \
    -DCMAKE_OSX_DEPLOYMENT_TARGET="$TARGET_OS" \
    -DCMAKE_OSX_ARCHITECTURES=$ARCHS
else
  # --- Build for iOS Device ---
  echo "🚀 Starting build for iOS Device..."
  cmake -S "$SRC_DIR" -B "$BUILD_DIR" -G Xcode \
    -DCMAKE_SYSTEM_NAME=iOS \
    -DCMAKE_OSX_SYSROOT=$(xcode-select -p)/Platforms/iPhoneOS.platform/Developer/SDKs/iPhoneOS.sdk \
    -DCMAKE_OSX_DEPLOYMENT_TARGET="$TARGET_OS" \
    -DCMAKE_OSX_ARCHITECTURES=$ARCHS
fi
cmake --build "$BUILD_DIR" --config Release
echo "✅ Build for iOS complete, 📱 Platform name: $PLATFORM_NAME"



# --- Merge OpenCV libs ---
echo "🦾 Merging OpenCV libraries..."
python3 opencv_objs.py "$BUILD_DIR/Release-$PLATFORM_NAME/libyolo_ffi.a"
echo "✅ OpenCV libraries merged into libyolo_ffi.a."

# --- Copy merged library to ios/lib ---
echo "📦 Copying merged library to ios/lib..."
mkdir -p "ios/lib"
cp "$BUILD_DIR/Release-$PLATFORM_NAME/libyolo_ffi.a" "ios/lib/libyolo_ffi.a"
echo "✅ Merged library copied."


# --- Prepare final destination ---
# echo "📦 Preparing destination directory: $IOS_FRAMEWORKS_DIR"
# mkdir -p "$IOS_FRAMEWORKS_DIR"

# echo "🏗 Copying simulator framework..."
# cp -r "$SIMULATOR_BUILD_DIR/Release-iphonesimulator/${FRAMEWORK_NAME}.framework" "$IOS_FRAMEWORKS_DIR"
# echo "✅ Simulator framework copied."

# echo "🏗 Copying real device framework..."
# cp -r "$BUILD_DIR/Release-iphoneos/${FRAMEWORK_NAME}.framework" "$IOS_FRAMEWORKS_DIR"
# echo "✅ Device framework copied."

# --- Create XCFramework ---
# echo "🏗 Creating XCFramework..."
# xcodebuild -create-xcframework \
#     -framework "$SIMULATOR_BUILD_DIR/Release-iphonesimulator/${FRAMEWORK_NAME}.framework" \
#     -framework "$BUILD_DIR/Release-iphoneos/${FRAMEWORK_NAME}.framework" \
#     -output "$IOS_FRAMEWORKS_DIR/${FRAMEWORK_NAME}.xcframework"

# echo "✅ XCFramework created."


# --- Clean up build directories ---
rm -rf "$BUILD_DIR"
echo "🎉 Framework preparation complete!"
