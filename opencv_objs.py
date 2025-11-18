from pathlib import Path
import os, sys

if __name__ == "__main__":
    builded_lib = sys.argv[1]

    if not os.path.isfile(builded_lib):
        raise IsADirectoryError(f"Expected a file, but got a directory: {builded_lib}")

    cv_build_dir = "/Users/otto/project/deploy_mobile/cpp_yolo/opencv/build/build"
    dirs = [
        folder.path
        for folder in os.scandir(cv_build_dir)
        if folder.is_dir() and "opencv" in folder.name
    ]
    # print("\n".join(dirs))
    obj_files = []
    for folder in dirs:
        for parent, _, files in os.walk(os.path.join(folder, "Release-iphoneos")):
            if "arm64" == Path(parent).name:
                obj_files += [
                    os.path.join(parent, file)
                    for file in files
                    if (Path(parent) / file).is_file() and Path(file).suffix == ".o"
                ]
                break
    # print("\n".join(obj_files))
    cmd = f"ar -rcs {builded_lib} {' '.join(obj_files)}"
    os.system(cmd)
    # os.system(f"cp {builded_lib} ios/lib")
