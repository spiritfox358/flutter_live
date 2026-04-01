#ifndef HardcoreDecoder_hpp
#define HardcoreDecoder_hpp

#ifdef __cplusplus

#include <string>
#include <thread>
#include <atomic>
#include <mutex>
#include <chrono>
// 🚀 核心魔法：解决 Apple 和 FFmpeg 命名冲突
#define AVMediaType FF_AVMediaType

extern "C" {
#include <libavformat/avformat.h>
#include <libavcodec/avcodec.h>
#include <libswresample/swresample.h> // 🚀 引入 FFmpeg 最强音频重采样器
}

#undef AVMediaType

// 🚀 定义一条高压电缆：把洗干净的 PCM 音频电流，直接打进 OC 调音台！
// 参数：pcm数据指针，样本数量，解码器编号
typedef void (*AudioPCMCallback)(float* pcmData, int numFrames, int playerIndex);

class HardcoreDecoder {
public:
    HardcoreDecoder(int index);
    ~HardcoreDecoder();

    void start(const std::string& url);
    void stop();

    // 供 OpenGL 层提取最新的一帧 YUV 画面
    AVFrame* getLatestFrame();

    // 🚀 新增：让解码器知道自己换座位了！
    void setIndex(int index);

    bool hasVideoFrame();

    bool isVideoDead();
    // 供 OC 层插入音频接收线缆
    void setAudioCallback(AudioPCMCallback callback);

private:
    void decodeLoop();

    int _index;
    std::string _url;
    std::atomic<bool> _isRunning;
    std::thread _decodeThread;
    std::atomic<bool> _isVideoDead;
    AVFormatContext* _formatCtx;

    // 📺 视频相关
    AVCodecContext* _videoCodecCtx;
    int _videoStreamIndex;
    AVFrame* _currentFrame;
    std::mutex _frameMutex;

    // 🚀 新增：用于防爆音的采样点计数器
    long long _totalAudioSamples;

    // 🎵 音频相关 (绞肉机核心配件)
    AVCodecContext* _audioCodecCtx;
    int _audioStreamIndex;
    SwrContext* _swrCtx;
    AudioPCMCallback _audioCallback;
};

#endif /* __cplusplus */
#endif /* HardcoreDecoder_hpp */