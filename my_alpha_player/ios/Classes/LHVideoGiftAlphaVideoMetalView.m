#import "LHVideoGiftAlphaVideoMetalView.h"
#import <Metal/Metal.h>
@import simd;

// 顶点数据：左边是坐标(xy)，右边是纹理(uv)
// 这里的 uv 只映射了 0.0~0.5 (即视频的左半部分)
float lh_cubeVertexData[16] = {
        -1.0, -1.0,  0.0, 1.0,
        1.0, -1.0,  0.5, 1.0,
        -1.0,  1.0,  0.0, 0.0,
        1.0,  1.0,  0.5, 0.0,
};

@interface LHVideoGiftAlphaVideoMetalView()
@property (nonatomic, strong) CAMetalLayer *metalLayer;
@property (nonatomic, strong) id<MTLDevice> device;
@property (nonatomic, strong) id<MTLCommandQueue> commandQueue;
@property (nonatomic, strong) id<MTLRenderPipelineState> pipelineState;
@property (nonatomic, strong) id<MTLBuffer> vertexBuffer;
@property (nonatomic, strong) id<MTLTexture> textureBGRA;
@property (nonatomic, assign) CVMetalTextureCacheRef textureCache;
@property (nonatomic, assign) BOOL settedup;

// 🟢 必须缓存这个强引用，防止底层画面内存被提前回收导致撕裂闪烁
@property (nonatomic, assign) CVMetalTextureRef currentCVTexture;
@end

@implementation LHVideoGiftAlphaVideoMetalView

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        self.backgroundColor = [UIColor clearColor];
        self.opaque = NO;
    }
    return self;
}

- (void)dealloc {
    if (_currentCVTexture) {
        CFRelease(_currentCVTexture);
    }
    if (_textureCache) {
        CFRelease(_textureCache);
    }
}

- (void)prepareMetalEnv {
    if (self.settedup) return;

    self.contentScaleFactor = [UIScreen mainScreen].scale;
    _device = MTLCreateSystemDefaultDevice();
    _commandQueue = [_device newCommandQueue];

    // 加载 Metal 库
    id<MTLLibrary> defaultLibrary = [_device newDefaultLibrary];
    if (!defaultLibrary) {
        NSBundle *bundle = [NSBundle bundleForClass:[self class]];
        // 增加更健壮的寻找方式，防止 Flutter 插件下找不到 Library
        NSURL *url = [bundle URLForResource:@"default" withExtension:@"metallib"];
        if (url) {
            defaultLibrary = [_device newLibraryWithURL:url error:nil];
        } else {
            defaultLibrary = [_device newDefaultLibraryWithBundle:bundle error:nil];
        }
    }

    _metalLayer = [CAMetalLayer layer];
    _metalLayer.device = _device;
    _metalLayer.pixelFormat = MTLPixelFormatBGRA8Unorm;
    _metalLayer.opaque = NO;
    _metalLayer.framebufferOnly = YES;
    _metalLayer.frame = self.layer.bounds;
    _metalLayer.contentsScale = [UIScreen mainScreen].scale;
    [self.layer addSublayer:_metalLayer];

    CVMetalTextureCacheCreate(NULL, NULL, _device, NULL, &_textureCache);

    id<MTLFunction> fragmentProgram = [defaultLibrary newFunctionWithName:@"lh_fragmentShader"];
    id<MTLFunction> vertexProgram = [defaultLibrary newFunctionWithName:@"lh_vertexShader"];

    if (!fragmentProgram || !vertexProgram) {
        NSLog(@"❌ Shader Function Not Found! Please check .metal file.");
        return; // 这里如果不成功不能置为 YES，否则后续直接崩溃
    }

    _vertexBuffer = [_device newBufferWithBytes:lh_cubeVertexData length:sizeof(lh_cubeVertexData) options:MTLResourceOptionCPUCacheModeDefault];

    MTLRenderPipelineDescriptor *pipelineStateDescriptor = [[MTLRenderPipelineDescriptor alloc] init];
    pipelineStateDescriptor.vertexFunction = vertexProgram;
    pipelineStateDescriptor.fragmentFunction = fragmentProgram;
    pipelineStateDescriptor.colorAttachments[0].pixelFormat = MTLPixelFormatBGRA8Unorm;

    // 🟢 混合模式修复：正确处理 Alpha 叠加，去除边缘黑边
    pipelineStateDescriptor.colorAttachments[0].blendingEnabled = YES;
    pipelineStateDescriptor.colorAttachments[0].rgbBlendOperation = MTLBlendOperationAdd;
    pipelineStateDescriptor.colorAttachments[0].alphaBlendOperation = MTLBlendOperationAdd;
    pipelineStateDescriptor.colorAttachments[0].sourceRGBBlendFactor = MTLBlendFactorSourceAlpha;
    // Alpha 通道保持 1.0 比例相乘，不要用 SourceAlpha，否则透明度会错误衰减
    pipelineStateDescriptor.colorAttachments[0].sourceAlphaBlendFactor = MTLBlendFactorOne;
    pipelineStateDescriptor.colorAttachments[0].destinationRGBBlendFactor = MTLBlendFactorOneMinusSourceAlpha;
    pipelineStateDescriptor.colorAttachments[0].destinationAlphaBlendFactor = MTLBlendFactorOneMinusSourceAlpha;

    _pipelineState = [_device newRenderPipelineStateWithDescriptor:pipelineStateDescriptor error:nil];

    // 只有所有流程都无误，才标记成功
    self.settedup = YES;
}

- (void)layoutSubviews {
    [super layoutSubviews];
    if (_metalLayer) {
        _metalLayer.frame = self.bounds;
        CGSize drawableSize = self.bounds.size;
        drawableSize.width *= self.contentScaleFactor;
        drawableSize.height *= self.contentScaleFactor;
        _metalLayer.drawableSize = drawableSize;
    }
}

- (void)renderPixelBuffer:(CVPixelBufferRef)pixelBuffer {
    [self prepareMetalEnv];
    if (!self.settedup) return; // 防御性保护

    [self generateTexture:pixelBuffer];

    id<MTLCommandBuffer> commandBuffer = [_commandQueue commandBuffer];
    id<CAMetalDrawable> drawable = [_metalLayer nextDrawable];

    if (!drawable || !_textureBGRA) return;

    MTLRenderPassDescriptor *passDescriptor = [MTLRenderPassDescriptor renderPassDescriptor];
    passDescriptor.colorAttachments[0].texture = drawable.texture;
    passDescriptor.colorAttachments[0].loadAction = MTLLoadActionClear;
    passDescriptor.colorAttachments[0].clearColor = MTLClearColorMake(0, 0, 0, 0);
    passDescriptor.colorAttachments[0].storeAction = MTLStoreActionStore;

    id<MTLRenderCommandEncoder> renderEncoder = [commandBuffer renderCommandEncoderWithDescriptor:passDescriptor];
    [renderEncoder setRenderPipelineState:_pipelineState];
    [renderEncoder setVertexBuffer:_vertexBuffer offset:0 atIndex:0];
    [renderEncoder setFragmentTexture:_textureBGRA atIndex:0];
    [renderEncoder drawPrimitives:MTLPrimitiveTypeTriangleStrip vertexStart:0 vertexCount:4];
    [renderEncoder endEncoding];

    [commandBuffer presentDrawable:drawable];
    [commandBuffer commit];
}

- (void)generateTexture:(CVImageBufferRef)pixelBuffer {
    size_t width = CVPixelBufferGetWidth(pixelBuffer);
    size_t height = CVPixelBufferGetHeight(pixelBuffer);
    CVMetalTextureRef texture = NULL;
    CVMetalTextureCacheCreateTextureFromImage(NULL, _textureCache, pixelBuffer, NULL, MTLPixelFormatBGRA8Unorm, width, height, 0, &texture);

    if (texture) {
        // 🟢 核心内存修复：释放上一帧的缓存，持稳当前帧的引用
        if (_currentCVTexture) {
            CFRelease(_currentCVTexture);
        }
        _currentCVTexture = texture; // 必须由全局变量强引用！

        _textureBGRA = CVMetalTextureGetTexture(texture);
        // 绝不能在这里 CFRelease(texture) !
    }
    CVMetalTextureCacheFlush(_textureCache, 0);
}

// 🟢 GPU 级清空画面：提交一帧全透明渲染彻底洗刷显存
- (void)clear {
    if (!_commandQueue || !_metalLayer) {
        self.metalLayer.contents = nil;
        return;
    }

    id<MTLCommandBuffer> commandBuffer = [_commandQueue commandBuffer];
    id<CAMetalDrawable> drawable = [_metalLayer nextDrawable];
    if (drawable) {
        MTLRenderPassDescriptor *passDescriptor = [MTLRenderPassDescriptor renderPassDescriptor];
        passDescriptor.colorAttachments[0].texture = drawable.texture;
        passDescriptor.colorAttachments[0].loadAction = MTLLoadActionClear;
        passDescriptor.colorAttachments[0].clearColor = MTLClearColorMake(0, 0, 0, 0);
        passDescriptor.colorAttachments[0].storeAction = MTLStoreActionStore;

        id<MTLRenderCommandEncoder> renderEncoder = [commandBuffer renderCommandEncoderWithDescriptor:passDescriptor];
        [renderEncoder endEncoding];

        [commandBuffer presentDrawable:drawable];
        [commandBuffer commit];
    }

    _textureBGRA = nil;
    if (_currentCVTexture) {
        CFRelease(_currentCVTexture);
        _currentCVTexture = NULL;
    }
}

@end