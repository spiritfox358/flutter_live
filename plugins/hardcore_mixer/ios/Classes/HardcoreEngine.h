#import <Foundation/Foundation.h>
#import <Flutter/Flutter.h>

@interface HardcoreEngine : NSObject <FlutterTexture>

@property(nonatomic, readonly) int64_t textureId;

- (instancetype)initWithRegistry:(id<FlutterTextureRegistry>)registry;

// 🚀 核心：必须在这里向 Swift 声明我们支持 layouts 参数！
- (void)start9Grid:(NSArray<NSString*> *)urls layouts:(NSArray<NSArray<NSNumber*>*> *)layouts;

- (void)stop;

// 🚀 新增：告诉外部哪些视频流已经真正画出画面了
- (NSArray<NSString*> *)getReadyUrls;

// 🚀 新增：精准静音控制
- (void)setMuted:(BOOL)isMuted forUrl:(NSString *)url;

@end