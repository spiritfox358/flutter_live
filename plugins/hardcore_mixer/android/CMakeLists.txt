# 指定 CMake 最低版本
cmake_minimum_required(VERSION 3.4.1)

# 定义工程名
project(hardcore_mixer)

# 🚀 跨平台魔法：定义 iOS 源码的相对路径
# 因为 CMakeLists.txt 在 android/ 目录下，所以跳出一级到 ios/Classes
set(CORE_SRC_DIR ../ios/Classes)

include_directories(${CORE_SRC_DIR})

# 1. 告诉 C++ 编译器：头文件去哪里找？(解决 file not found)
include_directories(${CMAKE_CURRENT_SOURCE_DIR}/src/main/cpp/ffmpeg/include)

# 2. 告诉 C++ 编译器：底层 .so 动态库去哪里找？
set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -L${CMAKE_CURRENT_SOURCE_DIR}/src/main/cpp/ffmpeg/libs/${ANDROID_ABI}")

add_library(
        hardcore_mixer
        SHARED
        src/main/cpp/hardcore_jni.cpp
        ${CORE_SRC_DIR}/HardcoreDecoder.cpp # 你的核心 C++ 代码
)

find_library(log-lib log)
find_library(gles2-lib GLESv2)

# 3. 强行链接！把 FFmpeg 绑定到你的引擎上！
target_link_libraries(
        hardcore_mixer

        # 写入库的名字 (掐头去尾，比如 libavformat.so 就写 avformat)
        avformat
        avcodec
        avutil
        swscale
        swresample

        ${log-lib}
        ${gles2-lib}
)