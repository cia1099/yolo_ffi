# Installation & Setup
### Prerequisites
Before proceeding, install the necessary modules for downloading and exporting pre-trained models:
```sh
cd path/to/yolo_ffi
python3 venv .venv
source .venv/bin/activate
pip install ultralytics coremltools pnnx
```

### Model Conversion
Convert the Torch model to your desired target platform.
#### 1. Exporting to ncnn
Refer to the [ncnn Wiki](https://github.com/Tencent/ncnn/wiki/use-ncnn-with-pytorch-or-onnxt) for detailed integration. Run the following command to export the model and generate the PNNX files:
```sh
mkdir -p assets && cd assets &&\
yolo export model=yolo11n.pt &&\
python3 -c "from ultralytics import YOLO;model = YOLO('yolo11n.pt');model.export(format='torchscript')" &&\
pnnx yolo11n.torchscript "inputshape=[1,3,640,640]" ncnnpy=ncnn_example.py
```

#### 2. Exporting to CoreML (mlmodel)
For iOS deployment, use the following command:
```sh
mkdir -p assets && cd assets &&\
yolo export model=yolo11n.pt format=mlmodel
```
For a full list of supported formats, see the [Ultralytics Export Documentation](https://docs.ultralytics.com/yolov5/tutorials/model_export/#supported-export-formats).

### Android Configuration
To ensure compatibility with your environment, update the NDK version and ABI filters in the following files.
* `android/build.gradle`
```gradle
android {
    ndkVersion = "<your_ndk_version>" // e.g., "25.1.8937393"
    defaultConfig {
        minSdk = 24
        consumerProguardFiles "consumer-rules.pro"
        ndk {
            abiFilters "arm64-v8a" // Update to your target architecture (e.g., x86_64)
        }
    }
}
```
* `example/android/app/build.gradle.kts`
```gradle
android {
    ndkVersion = "<your_ndk_version>"
    defaultConfig {
    //....
        ndk {
            abiFilters.clear()
            abiFilters.add("arm64-v8a")
        }
    }
}
```
### Troubleshooting NDK
To check your installed NDK versions, run:
```sh
sdkmanager --list_installed | grep ndk
```
If the `sdkmanager` command is not found, ensure you have installed cmdline-tools via Android Studio, then create a symbolic link:
```sh
sudo ln -s $HOME/Android/Sdk/cmdline-tools/latest/bin/sdkmanager /usr/local/bin
```
---

## Asset Configuration
Update the asset paths in `pubspec.yaml` according to your target platform:
```yaml
assets:
#ios
- assets/yolo11n.mlmodel
#android
# - assets/yolo11n.ncnn.bin
# - assets/yolo11n.ncnn.param
```

## Running the Example
Follow these steps to initialize and run the example project:
```sh
# Navigate to the project root
cd path/to/yolo_ffi

# Initialize the example app
flutter create --platforms=android,ios example
cd example

# Install dependencies and run
flutter pub get
flutter run -d <device_id>
```

---
# Buy Me A Coffee

<a href="https://www.buymeacoffee.com/cia1099" target="_blank"><img src="https://cdn.buymeacoffee.com/buttons/v2/default-yellow.png" alt="Buy Me A Coffee" style="height: 60px !important;width: 217px !important;" ></a>

<a href="https://ko-fi.com/cia1099" target="_blank"><img src="https://encrypted-tbn0.gstatic.com/images?q=tbn:ANd9GcQeccT1LUVKmhw2m4zv8fXN8G_bNRaCCYh3sA&s" alt="Ko-fi Me A Coffee" style="height: 60px !important;width: 217px !important;" ></a>

<a href="https://paypal.me/cia1099" target="_blank"><img src="https://www.paypalobjects.com/webstatic/mktg/Logo/pp-logo-150px.png" alt="Pay pal Me A Coffee" style="height: 60px !important;width: 217px !important;" ></a>

# Sponsors