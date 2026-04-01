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
    // 🚀🚀🚀 优化 1：彻底废除“错峰点火”！
    // 现在的手机和网络完全扛得住 9 个线程并发，直接让它们瞬间同时起跑，告别排队！
    // if (_index > 0) {
    //     std::this_thread::sleep_for(std::chrono::milliseconds(_index * 100));
    // }

    // ==========================================
    // 🦅 2. 不死鸟外层循环：无论网络怎么断，绝不自杀！无限重连！
    // ==========================================
    while (_isRunning) {
        avformat_network_init();
        _formatCtx = avformat_alloc_context();

        AVDictionary *options = nullptr;
        av_dict_set(&options, "fflags", "nobuffer", 0);
        av_dict_set(&options, "timeout", "5000000", 0); // 5秒超时

        // 🚀🚀🚀 优化 2：终极加速魔法（限制 FFmpeg 的探针大小和分析时间）
        // 强行把探针大小从默认的 5MB 缩减到 32KB，把分析时间从 5秒 压到 0.5秒！
        // 这样 FFmpeg 只要摸到视频的第一帧，就会瞬间结束分析直接出画，速度比肩原生！
        av_dict_set(&options, "probesize", "32768", 0);
        av_dict_set(&options, "analyzeduration", "500000", 0);

        if (avformat_open_input(&_formatCtx, _url.c_str(), nullptr, &options) != 0) {
            if (_formatCtx) {
                avformat_free_context(_formatCtx);
                _formatCtx = nullptr;
            }
            std::this_thread::sleep_for(std::chrono::seconds(2));
            continue;
        }

        if (avformat_find_stream_info(_formatCtx, nullptr) < 0) {
            if (_formatCtx) {
                avformat_close_input(&_formatCtx);
                _formatCtx = nullptr;
            }
            std::this_thread::sleep_for(std::chrono::seconds(2));
            continue;
        }

        _videoStreamIndex = -1;
        _audioStreamIndex = -1;

        for (int i = 0; i < _formatCtx->nb_streams; i++) {
            if (_formatCtx->streams[i]->codecpar->codec_type == AVMEDIA_TYPE_VIDEO &&
                _videoStreamIndex == -1) {
                _videoStreamIndex = i;
            }
            if (_formatCtx->streams[i]->codecpar->codec_type == AVMEDIA_TYPE_AUDIO &&
                _audioStreamIndex == -1) {
                _audioStreamIndex = i;
            }
        }

        if (_videoStreamIndex != -1) {
            AVCodecParameters *vpar = _formatCtx->streams[_videoStreamIndex]->codecpar;
            const AVCodec *vcodec = avcodec_find_decoder(vpar->codec_id);
            _videoCodecCtx = avcodec_alloc_context3(vcodec);
            avcodec_parameters_to_context(_videoCodecCtx, vpar);
            _videoCodecCtx->skip_loop_filter = AVDISCARD_ALL;
            _videoCodecCtx->thread_count = 1;
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

            swr_alloc_set_opts2(&_swrCtx,
                                &out_ch_layout,
                                AV_SAMPLE_FMT_FLT,
                                44100,
                                &apar->ch_layout,
                                (enum AVSampleFormat) apar->format,
                                apar->sample_rate,
                                0, nullptr);
            swr_init(_swrCtx);
        }

        AVPacket *packet = av_packet_alloc();
        AVFrame *frame = av_frame_alloc();

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
                            double pts = frame->best_effort_timestamp == AV_NOPTS_VALUE ? 0
                                                                                        : frame->best_effort_timestamp;
                            double pts_sec =
                                    pts * av_q2d(_formatCtx->streams[_videoStreamIndex]->time_base);

                            if (first_pts_sec < 0) first_pts_sec = pts_sec;
                            pts_sec -= first_pts_sec;

                            auto now = std::chrono::steady_clock::now();
                            double elapsed_sec = std::chrono::duration<double>(
                                    now - start_time).count();

                            if (elapsed_sec - pts_sec > 0.2) {
                                start_time = now - std::chrono::milliseconds(
                                        (long long) (pts_sec * 1000.0));
                                elapsed_sec = pts_sec;
                            }
                            if (pts_sec > elapsed_sec) {
                                std::this_thread::sleep_for(std::chrono::milliseconds(
                                        (int) ((pts_sec - elapsed_sec) * 1000)));
                            }
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

                            double a_pts = frame->best_effort_timestamp == AV_NOPTS_VALUE ? 0
                                                                                          : frame->best_effort_timestamp;
                            double a_pts_sec = a_pts *
                                               av_q2d(_formatCtx->streams[_audioStreamIndex]->time_base);
                            if (_videoStreamIndex != -1 &&
                                (first_pts_sec < 0 || a_pts_sec < (first_pts_sec - 0.1))) {
                                continue;
                            }

                            if (_audioCallback && _swrCtx) {
                                int out_samples = av_rescale_rnd(
                                        swr_get_delay(_swrCtx, frame->sample_rate) +
                                        frame->nb_samples, 44100, frame->sample_rate, AV_ROUND_UP);
                                float *out_buffer = (float *) av_malloc(
                                        out_samples * sizeof(float));
                                uint8_t *out_ptrs[1] = {(uint8_t *) out_buffer};

                                int real_out_samples = swr_convert(_swrCtx, out_ptrs, out_samples,
                                                                   (const uint8_t **) frame->data,
                                                                   frame->nb_samples);

                                if (real_out_samples > 0) {
                                    for (int k = 0; k < real_out_samples; k++) {
                                        float sample = out_buffer[k];

                                        if (_totalAudioSamples < 52920) {

                                            if (_totalAudioSamples < 8820) {
                                                sample = 0.0f;
                                            } else {
                                                float progress =
                                                        (float) (_totalAudioSamples - 8820) /
                                                        44100.0f;
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

        // ==========================================
        // 🧹 4. 彻底打扫战场，为下一次“满血复活”腾出内存！
        // ==========================================
        if (frame) av_frame_free(&frame);
        if (packet) av_packet_free(&packet);
        if (_swrCtx) {
            swr_free(&_swrCtx);
            _swrCtx = nullptr;
        }
        if (_videoCodecCtx) {
            avcodec_free_context(&_videoCodecCtx);
            _videoCodecCtx = nullptr;
        }
        if (_audioCodecCtx) {
            avcodec_free_context(&_audioCodecCtx);
            _audioCodecCtx = nullptr;
        }
        if (_formatCtx) {
            avformat_close_input(&_formatCtx);
            _formatCtx = nullptr;
        }

        if (_isRunning) {
            std::this_thread::sleep_for(std::chrono::seconds(2));
        }
    }
}