#include "HardcoreDecoder.hpp"
#include <chrono>

HardcoreDecoder::HardcoreDecoder(int index) {
    _index = index;
    _currentFrame = nullptr;
    _isRunning = false;
    _formatCtx = nullptr;
    _videoCodecCtx = nullptr;
    _audioCodecCtx = nullptr;
    _swrCtx = nullptr;
    _videoStreamIndex = -1;
    _audioStreamIndex = -1;
    _audioCallback = nullptr;
    _isVideoDead = false; // 🚀 初始化
    _totalAudioSamples = 0; // 🚀 初始化
}

HardcoreDecoder::~HardcoreDecoder() {
    stop();
}

void HardcoreDecoder::setAudioCallback(AudioPCMCallback callback) {
    _audioCallback = callback;
}

void HardcoreDecoder::start(const std::string &url) {
    _url = url;
    _isRunning = true;
    _decodeThread = std::thread(&HardcoreDecoder::decodeLoop, this);
}

void HardcoreDecoder::stop() {
    _isRunning = false;
    if (_decodeThread.joinable()) {
        _decodeThread.join();
    }

    std::lock_guard <std::mutex> lock(_frameMutex);
    if (_currentFrame) {
        av_frame_free(&_currentFrame);
        _currentFrame = nullptr;
    }
}

// 🚀 新增实现：更新坑位索引，保证声音还能从正确的喇叭里出来
void HardcoreDecoder::setIndex(int index) {
    _index = index;
}

AVFrame *HardcoreDecoder::getLatestFrame() {
    std::lock_guard <std::mutex> lock(_frameMutex);
    if (_currentFrame) {
        return av_frame_clone(_currentFrame);
    }
    return nullptr;
}

// 🚀 新增：极其轻量级的就绪探针
bool HardcoreDecoder::hasVideoFrame() {
    std::lock_guard <std::mutex> lock(_frameMutex);
    return _currentFrame != nullptr;
}

bool HardcoreDecoder::isVideoDead() {
    return _isVideoDead;
}

void HardcoreDecoder::decodeLoop() {
    // 🚀 1. 错峰点火防网络拥堵
    if (_index > 0) {
        std::this_thread::sleep_for(std::chrono::milliseconds(_index * 100));
    }

    // ==========================================
    // 🦅 2. 不死鸟外层循环：无论网络怎么断，绝不自杀！无限重连！
    // ==========================================
    while (_isRunning) {
        avformat_network_init();
        _formatCtx = avformat_alloc_context();

        AVDictionary* options = nullptr;
        av_dict_set(&options, "fflags", "nobuffer", 0);
        av_dict_set(&options, "timeout", "5000000", 0); // 5秒超时

        if (avformat_open_input(&_formatCtx, _url.c_str(), nullptr, &options) != 0) {
            if (_formatCtx) { avformat_free_context(_formatCtx); _formatCtx = nullptr; }
            std::this_thread::sleep_for(std::chrono::seconds(2)); // 连不上？休息2秒继续冲！
            continue;
        }
        if (avformat_find_stream_info(_formatCtx, nullptr) < 0) {
            if (_formatCtx) { avformat_close_input(&_formatCtx); _formatCtx = nullptr; }
            std::this_thread::sleep_for(std::chrono::seconds(2));
            continue;
        }

        _videoStreamIndex = -1;
        _audioStreamIndex = -1;

        for (int i = 0; i < _formatCtx->nb_streams; i++) {
            if (_formatCtx->streams[i]->codecpar->codec_type == AVMEDIA_TYPE_VIDEO && _videoStreamIndex == -1) {
                _videoStreamIndex = i;
            }
            if (_formatCtx->streams[i]->codecpar->codec_type == AVMEDIA_TYPE_AUDIO && _audioStreamIndex == -1) {
                _audioStreamIndex = i;
            }
        }

        if (_videoStreamIndex != -1) {
            AVCodecParameters* vpar = _formatCtx->streams[_videoStreamIndex]->codecpar;
            const AVCodec* vcodec = avcodec_find_decoder(vpar->codec_id);
            _videoCodecCtx = avcodec_alloc_context3(vcodec);
            avcodec_parameters_to_context(_videoCodecCtx, vpar);
            _videoCodecCtx->skip_loop_filter = AVDISCARD_ALL;
            _videoCodecCtx->thread_count = 1;
            avcodec_open2(_videoCodecCtx, vcodec, nullptr);
        }

        if (_audioStreamIndex != -1) {
            AVCodecParameters* apar = _formatCtx->streams[_audioStreamIndex]->codecpar;
            const AVCodec* acodec = avcodec_find_decoder(apar->codec_id);
            _audioCodecCtx = avcodec_alloc_context3(acodec);
            avcodec_parameters_to_context(_audioCodecCtx, apar);
            avcodec_open2(_audioCodecCtx, acodec, nullptr);

            int64_t in_ch_layout = apar->channel_layout;
            if (in_ch_layout == 0) in_ch_layout = av_get_default_channel_layout(apar->channels);

            _swrCtx = swr_alloc_set_opts(nullptr,
                                         AV_CH_LAYOUT_MONO, AV_SAMPLE_FMT_FLT, 44100,
                                         in_ch_layout, (AVSampleFormat)apar->format, apar->sample_rate,
                                         0, nullptr);
            swr_init(_swrCtx);
        }

        AVPacket* packet = av_packet_alloc();
        AVFrame* frame = av_frame_alloc();

        auto start_time = std::chrono::steady_clock::now();
        double first_pts_sec = -1.0;

        // ==========================================
        // 🎞️ 3. 内层循环：疯狂解帧
        // ==========================================
        while (_isRunning) {
            int ret = av_read_frame(_formatCtx, packet);
            if (ret >= 0) {
                // 📺 解码视频
                if (packet->stream_index == _videoStreamIndex && _videoCodecCtx) {
                    if (avcodec_send_packet(_videoCodecCtx, packet) == 0) {
                        while (avcodec_receive_frame(_videoCodecCtx, frame) == 0) {
                            double pts = frame->best_effort_timestamp == AV_NOPTS_VALUE ? 0 : frame->best_effort_timestamp;
                            double pts_sec = pts * av_q2d(_formatCtx->streams[_videoStreamIndex]->time_base);

                            if (first_pts_sec < 0) first_pts_sec = pts_sec;
                            pts_sec -= first_pts_sec;

                            auto now = std::chrono::steady_clock::now();
                            double elapsed_sec = std::chrono::duration<double>(now - start_time).count();

                            if (elapsed_sec - pts_sec > 0.2) {
                                start_time = now - std::chrono::milliseconds((long long)(pts_sec * 1000.0));
                                elapsed_sec = pts_sec;
                            }
                            if (pts_sec > elapsed_sec) {
                                std::this_thread::sleep_for(std::chrono::milliseconds((int)((pts_sec - elapsed_sec) * 1000)));
                            }
                            {
                                std::lock_guard<std::mutex> lock(_frameMutex);
                                if (_currentFrame) av_frame_free(&_currentFrame);
                                _currentFrame = av_frame_clone(frame);
                            }
                        }
                    }
                }
                    // 🎵 解码音频
                else if (packet->stream_index == _audioStreamIndex && _audioCodecCtx) {
                    if (avcodec_send_packet(_audioCodecCtx, packet) == 0) {
                        while (avcodec_receive_frame(_audioCodecCtx, frame) == 0) {

                            // 🔪 幽灵猎手：丢弃早于视频画面的声音，防止声画不同步！
                            double a_pts = frame->best_effort_timestamp == AV_NOPTS_VALUE ? 0 : frame->best_effort_timestamp;
                            double a_pts_sec = a_pts * av_q2d(_formatCtx->streams[_audioStreamIndex]->time_base);
                            if (_videoStreamIndex != -1 && (first_pts_sec < 0 || a_pts_sec < (first_pts_sec - 0.1))) {
                                continue;
                            }

                            if (_audioCallback && _swrCtx) {
                                int out_samples = av_rescale_rnd(swr_get_delay(_swrCtx, frame->sample_rate) + frame->nb_samples, 44100, frame->sample_rate, AV_ROUND_UP);
                                float* out_buffer = (float*)av_malloc(out_samples * sizeof(float));
                                uint8_t* out_ptrs[1] = { (uint8_t*)out_buffer };

                                int real_out_samples = swr_convert(_swrCtx, out_ptrs, out_samples, (const uint8_t**)frame->data, frame->nb_samples);

                                if (real_out_samples > 0) {
                                    for (int k = 0; k < real_out_samples; k++) {
                                        float sample = out_buffer[k];

                                        // 🚀🚀🚀 终极防爆音：0.2秒绝对静音 + 1.0秒平滑曲线淡入
                                        // 44100 采样率下：0.2秒 = 8820个点，1.2秒 = 52920个点
                                        if (_totalAudioSamples < 52920) {

                                            if (_totalAudioSamples < 8820) {
                                                // 🔪 第一段：前 0.2 秒的 FFmpeg 脏数据/电流音，无情抹零！
                                                sample = 0.0f;
                                            } else {
                                                // 🎼 第二段：剩下的 1.0 秒 (44100 采样点)，执行丝滑的抛物线淡入
                                                float progress = (float)(_totalAudioSamples - 8820) / 44100.0f;
                                                // 抛物线 Ease-In 算法 (progress * progress)，比直线听起来舒服无数倍！
                                                sample *= (progress * progress);
                                            }

                                            _totalAudioSamples++;
                                        }

                                        // 兜底：防止后续正常播放时的破音削波
                                        if (sample > 1.0f) sample = 1.0f;
                                        else if (sample < -1.0f) sample = -1.0f;

                                        out_buffer[k] = sample;
                                    }
                                    _audioCallback(out_buffer, real_out_samples, _index);
                                }
                                av_free(out_buffer);
                            }
                        }
                    }
                }
                av_packet_unref(packet);
            } else {
                // 💥 读流失败/断流：立刻跳出内层循环，进入打扫战场阶段！
                break;
            }
        }

        // ==========================================
        // 🧹 4. 彻底打扫战场，为下一次“满血复活”腾出内存！
        // ==========================================
        if (frame) av_frame_free(&frame);
        if (packet) av_packet_free(&packet);
        if (_swrCtx) { swr_free(&_swrCtx); _swrCtx = nullptr; }
        if (_videoCodecCtx) { avcodec_free_context(&_videoCodecCtx); _videoCodecCtx = nullptr; }
        if (_audioCodecCtx) { avcodec_free_context(&_audioCodecCtx); _audioCodecCtx = nullptr; }
        if (_formatCtx) { avformat_close_input(&_formatCtx); _formatCtx = nullptr; }

        // 断网了？休息 2 秒后外层循环会自动发起冲锋重连！
        if (_isRunning) {
            std::this_thread::sleep_for(std::chrono::seconds(2));
        }
    }
}