#include <jni.h>
#include <string>
#include <android/log.h>

// 引入你的核心跨平台代码
#include "HardcoreDecoder.hpp"

#define TAG "HardcoreJNI"
#define LOGD(...) __android_log_print(ANDROID_LOG_DEBUG, TAG, __VA_ARGS__)

extern "C" JNIEXPORT void JNICALL
Java_com_example_hardcore_1mixer_HardcoreMixerPlugin_nativeInitEngine(JNIEnv *env, jobject thiz) {
LOGD("🔥 成功从 Kotlin 穿透到了 C++ 层！");

// 你可以在这里调用 HardcoreDecoder 的方法测试一下
// HardcoreDecoder* decoder = new HardcoreDecoder();
}