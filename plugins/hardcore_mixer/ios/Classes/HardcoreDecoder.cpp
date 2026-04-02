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
    _isVideoDead = false;
    _totalAudioSamples = 0;
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

bool HardcoreDecoder::hasVideoFrame() {
    std::lock_guard <std::mutex> lock(_frameMutex);
    return _currentFrame != nullptr;
}

bool HardcoreDecoder::isVideoDead() {
    return _isVideoDead;
}

void HardcoreDecoder::decodeLoop() {
    // 错峰发车，防瞬间高并发锁
    if (_index > 0) {
        std::this_thread::sleep_for(std::chrono::milliseconds(_index * 10));
    }

    while (_isRunning) {
        avformat_network_init();
        _formatCtx = avformat_alloc_context();

        AVDictionary *options = nullptr;
        av_dict_set(&options, "fflags", "nobuffer+fastseek+flush_packets", 0);
        av_dict_set(&options, "flags", "low_delay", 0);
        av_dict_set(&options, "timeout", "3000000", 0);
        av_dict_set(&options, "probesize", "32768", 0);
        av_dict_set(&options, "analyzeduration", "0", 0);

        if (avformat_open_input(&_formatCtx, _url.c_str(), nullptr, &options) != 0) {
            if (_formatCtx) {
                avformat_free_context(_formatCtx);
                _formatCtx = nullptr;
            }
            std::this_thread::sleep_for(std::chrono::milliseconds(200));
            continue;
        }

        if (avformat_find_stream_info(_formatCtx, nullptr) < 0) {
            if (_formatCtx) {
                avformat_close_input(&_formatCtx);
                _formatCtx = nullptr;
            }
            std::this_thread::sleep_for(std::chrono::milliseconds(200));
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
            AVCodecParameters *vpar = _formatCtx->streams[_videoStreamIndex]->codecpar;
            const AVCodec *vcodec = nullptr;

            if (vpar->codec_id == AV_CODEC_ID_H264) {
                vcodec = avcodec_find_decoder_by_name("h264_videotoolbox");
            } else if (vpar->codec_id == AV_CODEC_ID_HEVC) {
                vcodec = avcodec_find_decoder_by_name("hevc_videotoolbox");
            }
            if (!vcodec) vcodec = avcodec_find_decoder(vpar->codec_id);

            _videoCodecCtx = avcodec_alloc_context3(vcodec);
            avcodec_parameters_to_context(_videoCodecCtx, vpar);

            // 极致硬核参数：去他妈的 B 帧，去他妈的多线程排队！
            _videoCodecCtx->flags |= AV_CODEC_FLAG_LOW_DELAY;
            _videoCodecCtx->thread_type = FF_THREAD_SLICE;
            _videoCodecCtx->skip_frame = AVDISCARD_NONREF;
            _videoCodecCtx->skip_loop_filter = AVDISCARD_ALL;

            avcodec_open2(_videoCodecCtx, vcodec, nullptr);
        }

        if (_audioStreamIndex != -1) {
            AVCodecParameters *apar = _formatCtx->streams[_audioStreamIndex]->codecpar;
            const AVCodec *acodec = avcodec_find_decoder(apar->codec_id);
            _audioCodecCtx = avcodec_alloc_context3(acodec);
            avcodec_parameters_to_context(_audioCodecCtx, apar);
            avcodec_open2(_audioCodecCtx, acodec, nullptr);

            AVChannelLayout out_ch_layout;
            av_channel_layout_default(&out_ch_layout, 1);
            swr_alloc_set_opts2(&_swrCtx, &out_ch_layout, AV_SAMPLE_FMT_FLT, 44100,
                                &apar->ch_layout, (enum AVSampleFormat) apar->format, apar->sample_rate, 0, nullptr);
            swr_init(_swrCtx);
        }

        AVPacket *packet = av_packet_alloc();
        AVFrame *frame = av_frame_alloc();

        auto start_time = std::chrono::steady_clock::now();
        double first_pts_sec = -1.0;

        // 🚀 核心修复：追踪状态机的两个标志位
        bool is_catching_up = false;    // 是否正在疯狂丢包追赶
        bool need_clock_reset = false;  // 是否需要在下一个画面重置时钟（防止死锁）

        while (_isRunning) {
            int ret = av_read_frame(_formatCtx, packet);
            if (ret >= 0) {

                // 🚀🚀🚀 终极大招：追赶模式下，音视频包一起丢！防音频队列膨胀导致的不同步！
                if (is_catching_up) {
                    if (packet->stream_index == _videoStreamIndex && (packet->flags & AV_PKT_FLAG_KEY)) {
                        is_catching_up = false;   // 摸到关键帧，停止丢包
                        need_clock_reset = true;  // 标记：必须立刻把时钟重置到这个关键帧的时刻！
                    } else {
                        av_packet_unref(packet);
                        continue; // 无论是音频包还是非关键帧视频包，直接毁灭！
                    }
                }

                // 📺 解码视频
                if (packet->stream_index == _videoStreamIndex && _videoCodecCtx) {
                    if (avcodec_send_packet(_videoCodecCtx, packet) == 0) {
                        while (avcodec_receive_frame(_videoCodecCtx, frame) == 0) {

                            double pts = frame->best_effort_timestamp == AV_NOPTS_VALUE ? 0 : frame->best_effort_timestamp;
                            double pts_sec = pts * av_q2d(_formatCtx->streams[_videoStreamIndex]->time_base);

                            if (first_pts_sec < 0) {
                                first_pts_sec = pts_sec;
                                start_time = std::chrono::steady_clock::now(); // 精准记录第一帧的现实降生时间
                            }
                            pts_sec -= first_pts_sec; // 将时间轴归零

                            auto now = std::chrono::steady_clock::now();

                            // 🚀 核心修复：解除死锁的钥匙！强制对齐时钟！
                            if (need_clock_reset) {
                                start_time = now - std::chrono::milliseconds((long long)(pts_sec * 1000.0));
                                need_clock_reset = false;
                            }

                            double elapsed_sec = std::chrono::duration<double>(now - start_time).count();

                            // 🚨 落后判定：如果画面落后现实超过 400 毫秒
                            if (elapsed_sec - pts_sec > 0.4) {
                                is_catching_up = true; // 立刻拉闸进入追赶模式
                                continue; // 这张废帧直接跳过
                            }

                            // 正常播放时的微小同步等待
                            if (pts_sec > elapsed_sec) {
                                std::this_thread::sleep_for(std::chrono::milliseconds((int)((pts_sec - elapsed_sec) * 1000)));
                            }

                            // 送去渲染
                            {
                                std::lock_guard <std::mutex> lock(_frameMutex);
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

                            // 🚀 核心音画对齐：在视频第一张画面出来之前，所有的音频包强制闭嘴！绝不抢跑！
                            if (first_pts_sec < 0) {
                                continue;
                            }

                            if (_audioCallback && _swrCtx) {
                                int out_samples = av_rescale_rnd(swr_get_delay(_swrCtx, frame->sample_rate) + frame->nb_samples, 44100, frame->sample_rate, AV_ROUND_UP);
                                float *out_buffer = (float *) av_malloc(out_samples * sizeof(float));
                                uint8_t *out_ptrs[1] = {(uint8_t *) out_buffer};

                                int real_out_samples = swr_convert(_swrCtx, out_ptrs, out_samples, (const uint8_t **) frame->data, frame->nb_samples);

                                if (real_out_samples > 0) {
                                    for (int k = 0; k < real_out_samples; k++) {
                                        float sample = out_buffer[k];
                                        if (_totalAudioSamples < 52920) {
                                            if (_totalAudioSamples < 8820) sample = 0.0f;
                                            else {
                                                float progress = (float) (_totalAudioSamples - 8820) / 44100.0f;
                                                sample *= (progress * progress);
                                            }
                                            _totalAudioSamples++;
                                        }
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
                break;
            }
        }

        // 清理与重试兜底
        if (frame) av_frame_free(&frame);
        if (packet) av_packet_free(&packet);
        if (_swrCtx) { swr_free(&_swrCtx); _swrCtx = nullptr; }
        if (_videoCodecCtx) { avcodec_free_context(&_videoCodecCtx); _videoCodecCtx = nullptr; }
        if (_audioCodecCtx) { avcodec_free_context(&_audioCodecCtx); _audioCodecCtx = nullptr; }
        if (_formatCtx) { avformat_close_input(&_formatCtx); _formatCtx = nullptr; }

        if (_isRunning) {
            std::this_thread::sleep_for(std::chrono::milliseconds(500));
        }
    }
}