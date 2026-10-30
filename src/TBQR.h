#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>

/* QR decoding on top of the bundled quirc library (iOS 6 has no AVCaptureMetadataOutput). */
@interface TBQRDecoder : NSObject
/* 8-bit luma image, rows `stride` bytes apart. Returns the decoded payloads (usually zero or one). */
- (NSArray *)decodeGray:(const uint8_t *)gray width:(int)w height:(int)h stride:(int)stride;
/* decodes a picture, scaled down to at most `maxSide` pixels on its long edge */
- (NSArray *)decodeImage:(CGImageRef)image maxSide:(int)maxSide;
@end
