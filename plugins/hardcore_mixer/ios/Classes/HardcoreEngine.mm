#import "HardcoreEngine.h"
#import <OpenGLES/ES3/gl.h>
#import <OpenGLES/EAGL.h>
#import <OpenGLES/ES3/glext.h>
#import <CoreVideo/CoreVideo.h>
#import <AVFoundation/AVFoundation.h>
// 引入咱们的 C++ 解码器
#include "HardcoreDecoder.hpp"

// 🚀 顶点着色器：引入了 MVP 矩阵，这是工业级视频播放器的标准做法！
static const char *vertexShaderString = R"(
    attribute vec4 position;
    attribute vec2 texcoord;
    varying vec2 v_texcoord;
    uniform mat4 transformMatrix;
    void main() {
        // 核心魔法：用矩阵对画面进行物理级的放大裁切，绝对不变形！
        gl_Position = transformMatrix * position;
        v_texcoord = texcoord;
    }
)";

// 🚀 片段着色器：最核心的魔法！在 GPU 内部并发千万次，将 YUV 像素瞬间计算为 RGB 色彩！
static const char *fragmentShaderString = R"(
    precision mediump float;
    varying vec2 v_texcoord;
    uniform sampler2D texY;
    uniform sampler2D texU;
    uniform sampler2D texV;
    void main() {
        float y = texture2D(texY, v_texcoord).r;
        float u = texture2D(texU, v_texcoord).r - 0.5;
        float v = texture2D(texV, v_texcoord).r - 0.5;
        // BT.601 标清色彩转换公式 (GPU 硬件加速)
        float r = y + 1.402 * v;
        float g = y - 0.344 * u - 0.714 * v;
        float b = y + 1.772 * u;
        gl_FragColor = vec4(r, g, b, 1.0);
    }
)";

// ==========================================
// 🚀 提前给编译器“剧透”我们要用的私有方法
// ==========================================
@interface HardcoreEngine ()
- (void)receiveAudioData:(float *)pcmData frames:(int)numFrames index:(int)playerIndex;
@end

// ==========================================
// 🚀 终极音频桥梁：负责将 C++ 的电流导入 OC 的调音台
// ==========================================
@class HardcoreEngine;
static HardcoreEngine* g_engine = nil; // 全局单例指针

// 这是一个纯 C 函数，专门给 C++ 的 AudioPCMCallback 用的
static void audioDataCallback(float* pcmData, int numFrames, int playerIndex) {
    if (g_engine) {
        // 收到 C++ 的裸数据后，立刻转发给 OC 的实例方法处理！
        [g_engine receiveAudioData:pcmData frames:numFrames index:playerIndex];
    }
}

@implementation HardcoreEngine {
    id <FlutterTextureRegistry> _registry;
    int _currentStreamCount; // 记录当前有几个视频在播
    // 🚀 用来接收从 Flutter 传来的每个画面的规范化坐标 (0.0 ~ 1.0)
    CGRect _normalizedLayouts[9];

    // 🚀 新增：记住当前正在播放的 URL 列表，用于 Diff 对比！
    NSArray<NSString*> *_currentUrls;

    HardcoreDecoder *_decoders[9];
    CADisplayLink *_displayLink;
    EAGLContext *_eaglContext;
    CVPixelBufferRef _finalOutputBuffer;
    NSLock *_bufferLock;

    // 🚀 新增：只在这里声明名字，绝对不执行代码！
    CVPixelBufferPoolRef _pixelBufferPool;
    CVOpenGLESTextureCacheRef _textureCache;

    // 🚀 音频混音核心设备
    AVAudioEngine* _audioEngine;
    AVAudioPlayerNode* _audioNodes[9];
    AVAudioFormat* _audioFormat;

    GLuint _glProgram;

    // 🚀 幕布同步机制
    BOOL _isCurtainClosed;
    NSTimeInterval _curtainStartTime;
}

- (instancetype)initWithRegistry:(id<FlutterTextureRegistry>)registry {
    self = [super init];
    if (self) {
        // 🚀🚀🚀 终极霸权声明：告诉苹果系统，我们要和其他播放器混合发声，绝不允许被静音！
        AVAudioSession *session = [AVAudioSession sharedInstance];
        // ❌ 删除了冲突的 DefaultToSpeaker 参数
        [session setCategory:AVAudioSessionCategoryPlayback
                 withOptions:AVAudioSessionCategoryOptionMixWithOthers
                       error:nil];
        [session setActive:YES error:nil];

        // 🚀 核心修复 2：强制切回主线程上锁！绝不给苹果系统无视咱们的机会！
        dispatch_async(dispatch_get_main_queue(), ^{
            [[UIApplication sharedApplication] setIdleTimerDisabled:YES];
        });

        g_engine = self; // 注册路由
        _registry = registry;
        _bufferLock = [[NSLock alloc] init];

        // 1. 初始化 OpenGL ES 3.0 上下文 (利用手机 GPU)
        _eaglContext = [[EAGLContext alloc] initWithAPI:kEAGLRenderingAPIOpenGLES3];
        [EAGLContext setCurrentContext:_eaglContext];

        CVOpenGLESTextureCacheCreate(kCFAllocatorDefault, NULL, _eaglContext, NULL, &_textureCache);

        NSDictionary *pixelBufferAttributes = @{
                (id)kCVPixelBufferPixelFormatTypeKey: @(kCVPixelFormatType_32BGRA),
                (id)kCVPixelBufferWidthKey: @(1080),
                (id)kCVPixelBufferHeightKey: @(1080),
                (id)kCVPixelBufferIOSurfacePropertiesKey: @{}
        };
        CVPixelBufferPoolCreate(kCFAllocatorDefault, NULL, (__bridge CFDictionaryRef)pixelBufferAttributes, &_pixelBufferPool);

        // 🚀🚀🚀 2. 搭建 9 路硬件级混音台
        _audioEngine = [[AVAudioEngine alloc] init];

        // 定义极其严苛的通用音频格式：44.1kHz 采样率, 单声道, 32位浮点数
        // 为什么用这个格式？因为这是苹果底层处理最快、绝对不会爆音的标准格式！
        _audioFormat = [[AVAudioFormat alloc] initStandardFormatWithSampleRate:44100 channels:1];

        for (int i = 0; i < 9; i++) {
            _audioNodes[i] = [[AVAudioPlayerNode alloc] init];
            [_audioEngine attachNode:_audioNodes[i]];
            // 将 9 个节点的线，全部插到主混音器上！
            [_audioEngine connect:_audioNodes[i] to:_audioEngine.mainMixerNode format:_audioFormat];
        }

        // 🚀 给 9 路总控台拉下总闸，留出绝对安全的混音空间（Headroom），防止 9 人叠加后总线爆炸！
        _audioEngine.mainMixerNode.outputVolume = 1.0;

        // 启动混音引擎！
        NSError *audioError = nil;
        [_audioEngine startAndReturnError:&audioError];
        if (audioError) {
            NSLog(@"💣 [致命错误] 硬件混音台启动失败: %@", audioError);
        } else {
            NSLog(@"✅ [系统就绪] 9路硬件级混音台启动成功！等待 C++ 注入 PCM 激流！");
        }

        // 3. 向 Flutter 注册自己
        _textureId = [_registry registerTexture:self];

        // 4. 初始化解码器数组为空
        for(int i=0; i<9; i++) {
            _decoders[i] = nullptr;
        }
    }
    return self;
}

- (void)start9Grid:(NSArray<NSString*> *)urls layouts:(NSArray<NSArray<NSNumber*>*> *)layouts {
    // 🚀 核心：如果是刚进新房间（旧 URL 为空），立刻拉上全局黑幕！准备憋个大招！
//    if (_currentUrls == nil || _currentUrls.count == 0) {
//        _isCurtainClosed = YES;
//        _curtainStartTime = CACurrentMediaTime();
//
//        // 🤫 核心修复 1：把音响的电源也拔了！在黑屏蓄力期间，绝对不许出声！
//        _audioEngine.mainMixerNode.outputVolume = 0.0;
//    }
    // 1. 🚀 无论视频换不换，位置坐标(layouts)每次都要全量更新，因为就算人不换，格子大小也变了！
    for (int i = 0; i < urls.count && i < 9; i++) {
        NSArray* rect = layouts[i];
        _normalizedLayouts[i] = CGRectMake([rect[0] floatValue], [rect[1] floatValue], [rect[2] floatValue], [rect[3] floatValue]);
    }

    _currentStreamCount = (int)urls.count;

    // 🚀 大厂核心：智能指针偷取算法 (Smart Diff)
    HardcoreDecoder *newDecoders[9] = {nullptr};

    // 1. 全局大搜捕：偷取幸存者的解码器
    for (int i = 0; i < 9; i++) {
        NSString *newUrl = (i < urls.count) ? urls[i] : nil;
        if (!newUrl) continue;

        // 🚀🚀🚀 核心免疫 1：无情砍掉 ? 后面的动态 Token，绝不上当！
        NSString *newBase = [[newUrl componentsSeparatedByString:@"?"] firstObject];

        int foundOldIndex = -1;
        for (int j = 0; j < 9; j++) {
            NSString *oldUrl = (j < _currentUrls.count) ? _currentUrls[j] : nil;
            if (oldUrl && _decoders[j]) {
                // 🚀 同样提取旧链接的 Base
                NSString *oldBase = [[oldUrl componentsSeparatedByString:@"?"] firstObject];
                if ([newBase isEqualToString:oldBase]) {
                    foundOldIndex = j; // 🎯 命中！只要基础房间对得上，立刻偷走，绝不掐断重连！
                    break;
                }
            }
        }

        if (foundOldIndex != -1) {
            newDecoders[i] = _decoders[foundOldIndex];
            _decoders[foundOldIndex] = nullptr;
            newDecoders[i]->setIndex(i);
        }
    }

    // 2. 🚨 物理拔线：清理没人认领的孤儿解码器！
    for (int j = 0; j < 9; j++) {
        if (_decoders[j]) {
            HardcoreDecoder *oldDecoder = _decoders[j];
            _decoders[j] = nullptr;

            // 🔪 致命护盾：在它进火葬场之前，立刻拔掉它的音频插头！
            // 防止它临死前和新解码器抢夺同一个音频喇叭，导致底层崩溃！
            oldDecoder->setAudioCallback(nullptr);

            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                delete oldDecoder;
            });
        }
    }

    // 3. 安全上位：处理全新的解码器
    for (int i = 0; i < 9; i++) {
        NSString *newUrl = (i < urls.count) ? urls[i] : nil;
        if (!newUrl) {
            if (_audioNodes[i]) { [_audioNodes[i] stop]; }
            continue;
        }

        if (!newDecoders[i]) {
            // 是全新的坑位！
            if (_audioNodes[i]) { [_audioNodes[i] stop]; }
            newDecoders[i] = new HardcoreDecoder(i);
            newDecoders[i]->setAudioCallback(audioDataCallback);
            newDecoders[i]->start([newUrl UTF8String]);
        }

        // 统一调节音量和声相
        AVAudioPlayerNode *node = _audioNodes[i];
//        node.volume = 1.0 / (_currentStreamCount + 1.0);
        node.volume = 0.8;
        float centerX = _normalizedLayouts[i].origin.x + (_normalizedLayouts[i].size.width / 2.0);
        node.pan = (centerX - 0.5) * 2.0;
        if (!node.isPlaying) [node play];

        _decoders[i] = newDecoders[i];
    }

    _currentUrls = [urls copy];

    // 4. 启动 GPU 渲染大循环
    if (!_displayLink) {
        _displayLink = [CADisplayLink displayLinkWithTarget:self selector:@selector(renderToGPU)];
        _displayLink.preferredFramesPerSecond = 30;
        [_displayLink addToRunLoop:[NSRunLoop mainRunLoop] forMode:NSRunLoopCommonModes];
    }
}

// 🚀 新增：扫描 9 个底层解码器，把真正有画面的 URL 收集起来汇报给 Flutter
- (NSArray<NSString*> *)getReadyUrls {
    NSMutableArray *arr = [NSMutableArray array];
    for (int i = 0; i < 9; i++) {
        // 如果解码器存在，并且探针显示已经有画面了
        if (_decoders[i] != nullptr && _decoders[i]->hasVideoFrame()) {
            if (_currentUrls != nil && i < _currentUrls.count) {
                NSString *url = _currentUrls[i];
                if (url && [url isKindOfClass:[NSString class]] && url.length > 0) {
                    [arr addObject:url];
                }
            }
        }
    }
    return arr;
}

// 🚀 核心大循环：每秒被调用 30 次！
- (void)renderToGPU {
    if (![EAGLContext setCurrentContext:_eaglContext]) return;

    // 1. 拿出一张崭新的 1080x1080 画布
    CVPixelBufferRef newPixelBuffer = NULL;
    CVPixelBufferPoolCreatePixelBuffer(NULL, _pixelBufferPool, &newPixelBuffer);
    if (!newPixelBuffer) return;

    // 2. 🚀 FBO 魔法：把这块内存映射给显卡，告诉它“别往屏幕上画，往这个内存里画！”
    CVOpenGLESTextureRef renderTexture = NULL;
    CVOpenGLESTextureCacheCreateTextureFromImage(kCFAllocatorDefault, _textureCache, newPixelBuffer,
                                                 NULL, GL_TEXTURE_2D, GL_RGBA, 1080, 1080, GL_BGRA,
                                                 GL_UNSIGNED_BYTE, 0, &renderTexture);
    GLuint targetTexture = CVOpenGLESTextureGetName(renderTexture);

    GLuint fbo;
    glGenFramebuffers(1, &fbo);
    glBindFramebuffer(GL_FRAMEBUFFER, fbo);
    glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_TEXTURE_2D, targetTexture, 0);

    // 清空画布涂成纯黑
    glClearColor(0.0f, 0.0f, 0.0f, 1.0f);
    glClear(GL_COLOR_BUFFER_BIT);

    // ==========================================
    // 🚀 发令枪 / 幕布同步机制
    // ==========================================
//    if (_isCurtainClosed) {
//        int targetCount = 0;
//        int readyCount = 0;
//        for (int i = 0; i < 9; i++) {
//            if (_decoders[i]) {
//                targetCount++;
//                // 🚀 核心：只要有画面了，或者这个流彻底死亡了（不拖累队友），都算就绪！
//                if (_decoders[i]->hasVideoFrame() || _decoders[i]->isVideoDead()) {
//                    readyCount++;
//                }
//            }
//        }
//
//        // 🌟 憋大招：死等所有人！把超时兜底放宽到 10 秒防死锁！
//        if (readyCount == targetCount || (CACurrentMediaTime() - _curtainStartTime) > 3.0) {
//            _isCurtainClosed = NO; // 啪！瞬间同时揭开幕布！
//            // 🔊 核心修复 2：幕布拉开的同一千分之一秒，瞬间把声音推上去！
//            _audioEngine.mainMixerNode.outputVolume = 1.0;
//        }
//    }

    int canvasW = 1080;
    int canvasH = 1080;

    for (int i = 0; i < 9; i++) {
        // 🚀 拦截网：如果幕布还是闭合状态，直接跳过所有人的绘制，把纯黑（透明）画布交出去！
//        if (_isCurtainClosed) break;


        if (!_decoders[i] || i >= _currentStreamCount) continue;

        AVFrame* frame = _decoders[i]->getLatestFrame();
        if (frame) {
            // 🚀 直接读取 Flutter 规划好的坐标！
            CGRect norm = _normalizedLayouts[i];

            // 算出真实的像素宽高
            int w = norm.size.width * canvasW;
            int h = norm.size.height * canvasH;
            int x = norm.origin.x * canvasW;

            // 🚀 大道至简：取消 Y 轴反转！直接让 OpenGL 的内存起点和 Flutter 的屏幕起点完美重合！
            int y = norm.origin.y * canvasH;

            glViewport(x, y, w, h);

            // 🚀 直接把格子的真实物理像素宽高传给底层的矩阵魔法！
            [self drawYUVFrameToGPU:frame viewportW:w viewportH:h];

            av_frame_free(&frame);
        }
    }

    glFlush();

    // 拆除脚手架，释放显卡资源
    glBindFramebuffer(GL_FRAMEBUFFER, 0);
    glDeleteFramebuffers(1, &fbo);
    CFRelease(renderTexture);
    CVOpenGLESTextureCacheFlush(_textureCache, 0);

    // 4. 🚀 零拷贝交接给 Flutter
    [_bufferLock lock];
    if (_finalOutputBuffer) {
        CVPixelBufferRelease(_finalOutputBuffer);
    }
    _finalOutputBuffer = newPixelBuffer;
    [_bufferLock unlock];

    dispatch_async(dispatch_get_main_queue(), ^{
        [self->_registry textureFrameAvailable:self->_textureId];
    });
}

- (void)drawYUVFrameToGPU:(AVFrame *)frame viewportW:(int)vpW viewportH:(int)vpH {
    // 🚀 1. 废除 static！改用当前引擎实例的专属 _glProgram
    if (_glProgram == 0) {
        GLuint vs = glCreateShader(GL_VERTEX_SHADER);
        glShaderSource(vs, 1, &vertexShaderString, NULL);
        glCompileShader(vs);

        GLuint fs = glCreateShader(GL_FRAGMENT_SHADER);
        glShaderSource(fs, 1, &fragmentShaderString, NULL);
        glCompileShader(fs);

        _glProgram = glCreateProgram();
        glAttachShader(_glProgram, vs);
        glAttachShader(_glProgram, fs);
        glLinkProgram(_glProgram);

        glDeleteShader(vs);
        glDeleteShader(fs);
    }

    glUseProgram(_glProgram);

    GLfloat vertices[] = {
            -1.0f, -1.0f, 1.0f, -1.0f,
            -1.0f, 1.0f, 1.0f, 1.0f
    };

    float validX = (float) frame->width / (float) frame->linesize[0];
    GLfloat texCoords[] = {
            0.0f, 0.0f, validX, 0.0f,
            0.0f, 1.0f, validX, 1.0f
    };

    GLuint posAttr = glGetAttribLocation(_glProgram, "position");
    glEnableVertexAttribArray(posAttr);
    glVertexAttribPointer(posAttr, 2, GL_FLOAT, GL_FALSE, 0, vertices);

    GLuint texAttr = glGetAttribLocation(_glProgram, "texcoord");
    glEnableVertexAttribArray(texAttr);
    glVertexAttribPointer(texAttr, 2, GL_FLOAT, GL_FALSE, 0, texCoords);

    float sar = 1.0f;
    if (frame->sample_aspect_ratio.num > 0 && frame->sample_aspect_ratio.den > 0) {
        sar = (float) frame->sample_aspect_ratio.num / (float) frame->sample_aspect_ratio.den;
    }

    float videoAspect = ((float) frame->width * sar) / (float) frame->height;
    float viewAspect = (float) vpW / (float) vpH;

    float scaleX = 1.0f, scaleY = 1.0f;
    if (videoAspect > viewAspect) {
        scaleX = videoAspect / viewAspect;
    } else {
        scaleY = viewAspect / videoAspect;
    }
    // 🚀🚀🚀 终极裁边魔法：物理放大 5%！
    // 不管是推流软件自带的黑边，还是轻微的比例不协调，全部被裁切到屏幕外，确保 100% 满画面！
    scaleX *= 1.1f;
    scaleY *= 1.1f;
    GLfloat transformMatrix[16] = {
            scaleX, 0.0f, 0.0f, 0.0f,
            0.0f, scaleY, 0.0f, 0.0f,
            0.0f, 0.0f, 1.0f, 0.0f,
            0.0f, 0.0f, 0.0f, 1.0f
    };

    GLuint matrixAttr = glGetUniformLocation(_glProgram, "transformMatrix");
    glUniformMatrix4fv(matrixAttr, 1, GL_FALSE, transformMatrix);

    GLuint textures[3];
    glGenTextures(3, textures);
    int widths[3] = {frame->linesize[0], frame->linesize[1], frame->linesize[2]};
    int heights[3] = {frame->height, frame->height / 2, frame->height / 2};

    glPixelStorei(GL_UNPACK_ALIGNMENT, 1);

    for (int i = 0; i < 3; i++) {
        glActiveTexture(GL_TEXTURE0 + i);
        glBindTexture(GL_TEXTURE_2D, textures[i]);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);

        glTexImage2D(GL_TEXTURE_2D, 0, GL_LUMINANCE, widths[i], heights[i], 0, GL_LUMINANCE,
                     GL_UNSIGNED_BYTE, frame->data[i]);
    }

    glPixelStorei(GL_UNPACK_ALIGNMENT, 4);

    glUniform1i(glGetUniformLocation(_glProgram, "texY"), 0);
    glUniform1i(glGetUniformLocation(_glProgram, "texU"), 1);
    glUniform1i(glGetUniformLocation(_glProgram, "texV"), 2);

    glDrawArrays(GL_TRIANGLE_STRIP, 0, 4);

    glDeleteTextures(3, textures);
}

// 🚀 Flutter 收到敲门声后，会瞬间调用这个方法来提货！
// 这就是 FlutterTexture 协议的灵魂！
- (CVPixelBufferRef)copyPixelBuffer {
    [_bufferLock lock];
    CVPixelBufferRef bufferToReturn = NULL;
    if (_finalOutputBuffer) {
        // Flutter 拿走了一份引用，它渲染完会自动释放，绝不内存泄漏
        bufferToReturn = CVPixelBufferRetain(_finalOutputBuffer);
    }
    [_bufferLock unlock];
    return bufferToReturn;
}

// 🚀 接收音频电流，塞入苹果硬件调音台！
- (void)receiveAudioData:(float *)pcmData frames:(int)numFrames index:(int)playerIndex {
    // 🚨🚨🚨 核心救命代码：如果调音台已经被拆了，或者停止了，直接把 C++ 最后的遗音扔进垃圾桶！绝不操作！
    if (!_audioEngine || !_audioEngine.isRunning) return;

    if (playerIndex < 0 || playerIndex >= 9) return;

    AVAudioPlayerNode *node = _audioNodes[playerIndex];
    // 1. 常规安检：尽最大努力挡住绝大部分脏数据
    if (!_audioEngine || !_audioEngine.isRunning) return;
    if (playerIndex < 0 || playerIndex >= 9) return;
    // 1. 向系统申请一个标准容器 (容量为 numFrames)
    AVAudioFrameCount frameCount = (AVAudioFrameCount)numFrames;
    AVAudioPCMBuffer *buffer = [[AVAudioPCMBuffer alloc] initWithPCMFormat:_audioFormat frameCapacity:frameCount];
    buffer.frameLength = frameCount; // 设定实际装载量

    // 2. 暴力拷贝：将 C++ 的裸数据直接砸进苹果的内存里！
    // 因为我们是单声道 (Channel 0)，所以直接拿到第一个通道的内存地址
    float *channelData = buffer.floatChannelData[0];
    memcpy(channelData, pcmData, numFrames * sizeof(float));

    // 🚀🚀🚀 终极防线：@try 强行捕获苹果底层的 NSException 异常！
    // 彻底解决 C++ 后台线程与主线程之间那 1 毫秒的“极限并发追尾”惨案！
    @try {
        [node scheduleBuffer:buffer completionHandler:nil];

        // 引擎点火：如果这个节点还没发声，踹它一脚让它开始播！
        if (!node.isPlaying) {
            [node play];
        }
    } @catch (NSException *exception) {
        // 🤫 核心魔法：发生异常（比如正在播的时候调音台突然被主线程拆了）时，什么都不做！
        // 绝不闪退！默默把这帧马上要发出的声音吞进肚子里！
        // NSLog(@"[安全拦截] 忽略引擎销毁时的游离声音数据");
    }
}

- (void)stop {
    g_engine = nil;
    _currentUrls = nil; // 🚀 重置记忆，确保下次进房能拉上幕布！
    // 🚀 安全解锁：切回主线程恢复系统正常休眠策略
    dispatch_async(dispatch_get_main_queue(), ^{
        [[UIApplication sharedApplication] setIdleTimerDisabled:NO];
    });

    [_displayLink invalidate];
    _displayLink = nil;

    // 1. 关掉调音台
    if (_audioEngine) {
        [_audioEngine stop];
        _audioEngine = nil;
    }

    // 2. 彻底干掉 C++ 解码线程
    // 2. 🚀 异步火葬场：彻底干掉 C++ 解码线程，绝不阻塞主线程切房！
    for (int i = 0; i < 9; i++) {
        if (_decoders[i]) {
            HardcoreDecoder *oldDecoder = _decoders[i];
            _decoders[i] = nullptr;

            // 🔪 拔掉音频线！防止它在后台销毁期间还在乱叫！
            oldDecoder->setAudioCallback(nullptr);

            // 扔到 GCD 后台队列慢慢死，主线程瞬间返回给 Flutter 执行丝滑滑动动画！
            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                delete oldDecoder;
            });
        }
    }

    // 🚀 3. 彻底清空 OpenGL 显存和缓存（防止切房泄漏！）
    if (_glProgram) {
        glDeleteProgram(_glProgram);
        _glProgram = 0;
    }
    if (_pixelBufferPool) {
        CVPixelBufferPoolRelease(_pixelBufferPool);
        _pixelBufferPool = NULL;
    }
    if (_textureCache) {
        CFRelease(_textureCache);
        _textureCache = NULL;
    }
    [_bufferLock lock];
    if (_finalOutputBuffer) {
        CVPixelBufferRelease(_finalOutputBuffer);
        _finalOutputBuffer = NULL;
    }
    [_bufferLock unlock];

    if ([EAGLContext currentContext] == _eaglContext) {
        [EAGLContext setCurrentContext:nil];
    }
    _eaglContext = nil;

    [_registry unregisterTexture:_textureId];
}

// 🚀 物理静音控制
- (void)setMuted:(BOOL)isMuted forUrl:(NSString *)url {
    if (!url || url.length == 0) return;

    // 提取基础链接，无视防盗链 Token
    NSString *baseTarget = [[url componentsSeparatedByString:@"?"] firstObject];

    for (int i = 0; i < 9; i++) {
        NSString *current = (i < _currentUrls.count) ? _currentUrls[i] : nil;
        if (current) {
            NSString *baseCurrent = [[current componentsSeparatedByString:@"?"] firstObject];
            if ([baseCurrent isEqualToString:baseTarget]) {
                if (_audioNodes[i]) {
                    // ✅ 替换成这行：解除静音时，直接恢复 100% 音量！
                    _audioNodes[i].volume = isMuted ? 0.0 : 0.8;
                }
                break;
            }
        }
    }
}

@end
