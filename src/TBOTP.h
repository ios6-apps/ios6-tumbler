#import <Foundation/Foundation.h>

/* One-time-password core: base32, RFC 4226 / 6238 codes, otpauth:// and Google Authenticator migration parsing. */

NSData *TBBase32Decode(NSString *s);        /* nil when the text has characters outside the base32 alphabet */
NSString *TBBase32Encode(NSData *d);
NSData *TBBase64Decode(NSString *s);        /* standard or URL-safe alphabet, padding optional */

@interface TBAccount : NSObject
@property (nonatomic, copy) NSString *issuer;
@property (nonatomic, copy) NSString *name;
@property (nonatomic, copy) NSString *secret;       /* base32, upper case, no spaces */
@property (nonatomic, copy) NSString *algorithm;    /* SHA1, SHA256 or SHA512 */
@property (nonatomic) int digits;                   /* 6..8 */
@property (nonatomic) int period;                   /* seconds, TOTP only */
@property (nonatomic) BOOL counterBased;            /* HOTP */
@property (nonatomic) long long counter;

+ (TBAccount *)accountFromURI:(NSString *)uri;
/* every account found in the text: otpauth:// lines, otpauth-migration:// payloads, or a bare base32 secret */
+ (NSArray *)accountsFromText:(NSString *)text;
+ (TBAccount *)accountFromDictionary:(NSDictionary *)d;
- (NSDictionary *)dictionary;
- (NSString *)URIString;
- (NSString *)title;                                /* issuer, or the account name when there is no issuer */
- (BOOL)isValid;

- (NSString *)codeAtTime:(NSTimeInterval)t;         /* TOTP */
- (NSString *)codeForCounter:(unsigned long long)c; /* HOTP, also the TOTP primitive */
- (double)secondsLeftAtTime:(NSTimeInterval)t;
- (BOOL)isSameKeyAs:(TBAccount *)o;
@end
