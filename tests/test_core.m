#import <Foundation/Foundation.h>
#import <ImageIO/ImageIO.h>
#import <CoreImage/CoreImage.h>
#import "TBOTP.h"
#import "TBQR.h"

static int fails;
#define CHECK(cond, ...) do { if (!(cond)) { fails++; NSLog(@"FAIL: " __VA_ARGS__); } } while (0)

static TBAccount *acc(NSString *alg, NSString *secretAscii, int digits) {
    TBAccount *a = [[TBAccount alloc] init];
    a.secret = TBBase32Encode([secretAscii dataUsingEncoding:NSUTF8StringEncoding]);
    a.algorithm = alg; a.digits = digits;
    return a;
}

/* renders a QR code for `text` (CoreImage, macOS only) into a white-bordered 8-bit gray bitmap, `scale` pixels per module */
static NSData *qrGray(NSString *text, int scale, int *outSide) {
    CIFilter *f = [CIFilter filterWithName:@"CIQRCodeGenerator"];
    [f setValue:[text dataUsingEncoding:NSUTF8StringEncoding] forKey:@"inputMessage"];
    [f setValue:@"M" forKey:@"inputCorrectionLevel"];
    CIImage *ci = f.outputImage;
    int n = (int)ci.extent.size.width, side = (n + 8) * scale;
    CIContext *cictx = [CIContext contextWithOptions:nil];
    CGImageRef small = [cictx createCGImage:ci fromRect:ci.extent];
    NSMutableData *buf = [NSMutableData dataWithLength:side * side];
    memset(buf.mutableBytes, 255, buf.length);
    CGColorSpaceRef cs = CGColorSpaceCreateDeviceGray();
    CGContextRef c = CGBitmapContextCreate(buf.mutableBytes, side, side, 8, side, cs, (CGBitmapInfo)kCGImageAlphaNone);
    CGContextSetInterpolationQuality(c, kCGInterpolationNone);
    CGContextDrawImage(c, CGRectMake(4 * scale, 4 * scale, n * scale, n * scale), small);
    CGContextRelease(c); CGColorSpaceRelease(cs); CGImageRelease(small);
    *outSide = side;
    return buf;
}

int main(int argc, char **argv) {
    @autoreleasepool {
        /* RFC 6238 appendix B, 8 digits */
        struct { NSTimeInterval t; const char *s1, *s256, *s512; } v[] = {
            {59, "94287082", "46119246", "90693936"}, {1111111109, "07081804", "68084774", "25091201"},
            {1111111111, "14050471", "67062674", "99943326"}, {1234567890, "89005924", "91819424", "93441116"},
            {2000000000, "69279037", "90698825", "38618901"}, {20000000000, "65353130", "77737706", "47863826"}};
        for (int i = 0; i < 6; i++) {
            CHECK([[acc(@"SHA1", @"12345678901234567890", 8) codeAtTime:v[i].t] isEqualToString:@(v[i].s1)], @"sha1 t=%f", v[i].t);
            CHECK([[acc(@"SHA256", @"12345678901234567890123456789012", 8) codeAtTime:v[i].t] isEqualToString:@(v[i].s256)], @"sha256 t=%f", v[i].t);
            CHECK([[acc(@"SHA512", @"1234567890123456789012345678901234567890123456789012345678901234", 8) codeAtTime:v[i].t] isEqualToString:@(v[i].s512)], @"sha512 t=%f", v[i].t);
        }
        /* RFC 4226 appendix D */
        const char *h[] = {"755224", "287082", "359152", "969429", "338314", "254676", "287922", "162583", "399871", "520489"};
        for (int i = 0; i < 10; i++) CHECK([[acc(@"SHA1", @"12345678901234567890", 6) codeForCounter:i] isEqualToString:@(h[i])], @"hotp %d", i);
        /* base32 */
        CHECK(TBBase32Decode(@"MZXW6YTBOI======").length == 6, @"b32 len");
        CHECK(TBBase32Decode(@"mzxw 6ytb-oi").length == 6, @"b32 lenient");
        CHECK(TBBase32Decode(@"MZXW1") == nil, @"b32 reject 1");
        CHECK([TBBase32Encode([@"foobar" dataUsingEncoding:NSUTF8StringEncoding]) isEqualToString:@"MZXW6YTBOI"], @"b32 enc");
        /* URIs */
        TBAccount *a = [TBAccount accountFromURI:@"otpauth://totp/Example:alice@google.com?secret=JBSWY3DPEHPK3PXP&issuer=Example&algorithm=SHA256&digits=8&period=60"];
        CHECK(a && [a.issuer isEqualToString:@"Example"] && [a.name isEqualToString:@"alice@google.com"] && a.digits == 8 && a.period == 60 && [a.algorithm isEqualToString:@"SHA256"], @"uri parse");
        TBAccount *b = [TBAccount accountFromURI:@"otpauth://totp/Big%20Corp%3Abob%40x.com?secret=jbsw%20y3dp"];
        CHECK(b && [b.issuer isEqualToString:@"Big Corp"] && [b.name isEqualToString:@"bob@x.com"] && [b.secret isEqualToString:@"JBSWY3DP"], @"uri escapes %@ %@ %@", b.issuer, b.name, b.secret);
        TBAccount *rt = [TBAccount accountFromURI:a.URIString];
        CHECK(rt && [rt isSameKeyAs:a] && rt.digits == 8 && rt.period == 60, @"roundtrip %@", a.URIString);
        CHECK([TBAccount accountFromURI:@"otpauth://totp/x?secret=!!!"] == nil, @"bad secret");
        CHECK([TBAccount accountFromURI:@"https://example.com"] == nil, @"not otpauth");
        TBAccount *hotp = [TBAccount accountFromURI:@"otpauth://hotp/Foo:me?secret=GEZDGNBVGY3TQOJQGEZDGNBVGY3TQOJQ&counter=3"];
        CHECK(hotp && hotp.counterBased && hotp.counter == 3 && [[hotp codeAtTime:0] isEqualToString:@"969429"], @"hotp uri %@", [hotp codeAtTime:0]);
        CHECK([TBAccount accountsFromText:@"JBSW Y3DP EHPK 3PXP"].count == 1, @"bare secret");
        /* Google Authenticator migration payload built by the test script */
        NSString *mig = [NSString stringWithContentsOfFile:@"tests/migration.txt" encoding:NSUTF8StringEncoding error:NULL];
        NSArray *m = [TBAccount accountsFromText:mig];
        CHECK(m.count == 2, @"migration count %lu", (unsigned long)m.count);
        if (m.count == 2) {
            TBAccount *m0 = m[0], *m1 = m[1];
            CHECK([m0.issuer isEqualToString:@"Example"] && [m0.name isEqualToString:@"alice"] && [m0.secret isEqualToString:@"JBSWY3DPEHPK3PXP"], @"mig0 %@ %@ %@", m0.issuer, m0.name, m0.secret);
            CHECK([m1.algorithm isEqualToString:@"SHA256"] && m1.digits == 8 && m1.counterBased, @"mig1");
        }
        /* QR decode of generated images */
        TBQRDecoder *dec = [[TBQRDecoder alloc] init];
        {
            NSString *uri = @"otpauth://totp/Example:alice@example.com?secret=JBSWY3DPEHPK3PXP&issuer=Example";
            for (int scale = 3; scale <= 6; scale += 3) {
                int side = 0;
                NSData *g = qrGray(uri, scale, &side);
                NSArray *r = [dec decodeGray:g.bytes width:side height:side stride:side];
                CHECK(r.count == 1 && [r[0] isEqualToString:uri], @"generated qr scale %d -> %@", scale, r);
            }
        }
        for (int i = 1; i < argc; i++) {
            NSURL *u = [NSURL fileURLWithPath:@(argv[i])];
            CGImageSourceRef src = CGImageSourceCreateWithURL((__bridge CFURLRef)u, NULL);
            CGImageRef im = src ? CGImageSourceCreateImageAtIndex(src, 0, NULL) : NULL;
            NSArray *r = im ? [dec decodeImage:im maxSide:1024] : @[];
            NSLog(@"%s -> %@", argv[i], r);
            CHECK(r.count == 1 && [TBAccount accountsFromText:r[0]].count >= 1, @"qr %s", argv[i]);
        }
    }
    NSLog(fails ? @"%d FAILED" : @"ALL OK", fails);
    return fails ? 1 : 0;
}
