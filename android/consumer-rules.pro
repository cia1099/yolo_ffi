# ProGuard rules for the yolo_ffi plugin.
# This file prevents the R8 code shrinker from removing classes and methods
# that are called from native code via JNI.

-keep class com.cia1099.yolo_ffi.YoloFfiPlugin {
    public static void printMessage(java.lang.String);
}
