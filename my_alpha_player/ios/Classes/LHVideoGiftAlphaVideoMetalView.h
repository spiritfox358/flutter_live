#import <UIKit/UIKit.h>
#import <CoreVideo/CoreVideo.h>

NS_ASSUME_NONNULL_BEGIN

@interface LHVideoGiftAlphaVideoMetalView : UIView

// 暴露给 Swift 调用的接口
- (void)displayPixelBuffer:(CVPixelBufferRef)pixelBuffer;
- (void)clear;

@end

        NS_ASSUME_NONNULL_END