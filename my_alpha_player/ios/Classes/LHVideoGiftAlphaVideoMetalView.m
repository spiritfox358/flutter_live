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
@end

@implementation LHVideoGiftAlphaVideoMetalView

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        // 这里的背景色设置很重要
        self.backgroundColor = [UIColor clearColor];
        self.opaque = NO;
    }
    return self;
}

- (void)dealloc {
    if (_textureCache) {
        CFRelease(_textureCache);
    }
}

- (void)prepareMetalEnv {
    if (self.settedup) return;
    self.settedup = YES;

    self.contentScaleFactor = [UIScreen mainScreen].scale;
    _device = MTLCreateSystemDefaultDevice();
    _commandQueue = [_device newCommandQueue];

    // 加载 Metal 库 (注意：在 Framework/Plugin 中加载默认库需要技巧，这里尝试 defaultLibrary)
    // 如果运行时报错找不到 Shader，需要修改这里为加载 Bundle 资源
    id<MTLLibrary> defaultLibrary = [_device newDefaultLibrary];
    if (!defaultLibrary) {
        // 尝试从 Bundle 加载 (针对 Flutter Plugin 的特殊处理)
        NSBundle *bundle = [NSBundle bundleForClass:[self class]];
        defaultLibrary = [_device newDefaultLibraryWithBundle:bundle error:nil];
    }

    _metalLayer = [CAMetalLayer layer];
    _metalLayer.device = _device;
    _metalLayer.pixelFormat = MTLPixelFormatBGRA8Unorm;
    _metalLayer.opaque = NO; // 透明关键
    _metalLayer.framebufferOnly = YES;
    _metalLayer.frame = self.layer.bounds;
    // 这一步设置 Layer 的内容缩放，防止模糊
    _metalLayer.contentsScale = [UIScreen mainScreen].scale;
    [self.layer addSublayer:_metalLayer];

    CVMetalTextureCacheCreate(NULL, NULL, _device, NULL, &_textureCache);

    // 对应 .metal 文件里的函数名
    id<MTLFunction> fragmentProgram = [defaultLibrary newFunctionWithName:@"lh_fragmentShader"];
    id<MTLFunction> vertexProgram = [defaultLibrary newFunctionWithName:@"lh_vertexShader"];

    if (!fragmentProgram || !vertexProgram) {
        NSLog(@"❌ Shader Function Not Found! Please check .metal file.");
        return;
    }

    _vertexBuffer = [_device newBufferWithBytes:lh_cubeVertexData length:sizeof(lh_cubeVertexData) options:MTLResourceOptionCPUCacheModeDefault];

    MTLRenderPipelineDescriptor *pipelineStateDescriptor = [[MTLRenderPipelineDescriptor alloc] init];
    pipelineStateDescriptor.vertexFunction = vertexProgram;
    pipelineStateDescriptor.fragmentFunction = fragmentProgram;
    pipelineStateDescriptor.colorAttachments[0].pixelFormat = MTLPixelFormatBGRA8Unorm;

    // 混合模式配置 (Alpha Blending)
    pipelineStateDescriptor.colorAttachments[0].blendingEnabled = YES;
    pipelineStateDescriptor.colorAttachments[0].rgbBlendOperation = MTLBlendOperationAdd;
    pipelineStateDescriptor.colorAttachments[0].alphaBlendOperation = MTLBlendOperationAdd;
    pipelineStateDescriptor.colorAttachments[0].sourceRGBBlendFactor = MTLBlendFactorSourceAlpha;
    pipelineStateDescriptor.colorAttachments[0].sourceAlphaBlendFactor = MTLBlendFactorSourceAlpha;
    pipelineStateDescriptor.colorAttachments[0].destinationRGBBlendFactor = MTLBlendFactorOneMinusSourceAlpha;
    pipelineStateDescriptor.colorAttachments[0].destinationAlphaBlendFactor = MTLBlendFactorOneMinusSourceAlpha;

    _pipelineState = [_device newRenderPipelineStateWithDescriptor:pipelineStateDescriptor error:nil];
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

- (void)displayPixelBuffer:(CVImageBufferRef)pixelBuffer {
    [self prepareMetalEnv];
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
        _textureBGRA = CVMetalTextureGetTexture(texture);
        CFRelease(texture);
    }
    CVMetalTextureCacheFlush(_textureCache, 0);
}

// 新增：强制清空画面
- (void)clear {
    // 简单粗暴：直接把 Layer 隐藏再显示，或者设为透明
    // 更好的做法是画一帧纯透明的纹理，但那样太慢了。
    // 直接操作 layer 的 contents 是最快的。
    self.metalLayer.contents = nil;

    // 或者如果你想更彻底，可以重新创建一个新的 passDescriptor 画透明色，
    // 但上面的方法通常对 CAMetalLayer 足够有效。
}

@end