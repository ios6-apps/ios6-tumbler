#import "TBQR.h"
#include "quirc.h"

@implementation TBQRDecoder {
    struct quirc *_q;
    int _w, _h;
}

- (void)dealloc { if (_q) quirc_destroy(_q); }

- (NSArray *)decodeGray:(const uint8_t *)gray width:(int)w height:(int)h stride:(int)stride {
    if (!_q) _q = quirc_new();
    if (!_q) return @[];
    if (w != _w || h != _h) {
        if (quirc_resize(_q, w, h) < 0) return @[];
        _w = w; _h = h;
    }
    int bw, bh;
    uint8_t *buf = quirc_begin(_q, &bw, &bh);
    for (int y = 0; y < h; y++) memcpy(buf + y * bw, gray + y * stride, w);
    quirc_end(_q);
    NSMutableArray *out = [NSMutableArray array];
    int n = quirc_count(_q);
    for (int i = 0; i < n; i++) {
        struct quirc_code code;
        struct quirc_data data;
        quirc_extract(_q, i, &code);
        if (quirc_decode(&code, &data) != QUIRC_SUCCESS) {
            /* mirrored codes (front camera, photos of screens) decode after a flip */
            quirc_flip(&code);
            if (quirc_decode(&code, &data) != QUIRC_SUCCESS) continue;
        }
        NSString *s = [[NSString alloc] initWithBytes:data.payload length:data.payload_len encoding:NSUTF8StringEncoding]
                   ?: [[NSString alloc] initWithBytes:data.payload length:data.payload_len encoding:NSISOLatin1StringEncoding];
        if (s) [out addObject:s];
    }
    return out;
}

- (NSArray *)decodeImage:(CGImageRef)image maxSide:(int)maxSide {
    size_t iw = CGImageGetWidth(image), ih = CGImageGetHeight(image);
    if (!iw || !ih) return @[];
    double k = MIN(1.0, (double)maxSide / MAX(iw, ih));
    int w = MAX(1, (int)(iw * k)), h = MAX(1, (int)(ih * k));
    uint8_t *px = calloc((size_t)w * h, 1);
    CGColorSpaceRef cs = CGColorSpaceCreateDeviceGray();
    CGContextRef c = CGBitmapContextCreate(px, w, h, 8, w, cs, (CGBitmapInfo)kCGImageAlphaNone);
    CGColorSpaceRelease(cs);
    NSArray *r = @[];
    if (c) {
        CGContextSetInterpolationQuality(c, kCGInterpolationHigh);
        CGContextDrawImage(c, CGRectMake(0, 0, w, h), image);
        CGContextRelease(c);
        r = [self decodeGray:px width:w height:h stride:w];
    }
    free(px);
    return r;
}

@end
