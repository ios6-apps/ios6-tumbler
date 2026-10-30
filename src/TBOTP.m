#import "TBOTP.h"
#import <CommonCrypto/CommonHMAC.h>

static const char kB32[] = "ABCDEFGHIJKLMNOPQRSTUVWXYZ234567";
static const char kB64[] = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";

NSData *TBBase32Decode(NSString *s) {
    NSMutableData *out = [NSMutableData data];
    unsigned long acc = 0;
    int bits = 0;
    for (NSUInteger i = 0; i < s.length; i++) {
        unichar ch = [s characterAtIndex:i];
        if (ch == ' ' || ch == '-' || ch == '=' || ch == '\n' || ch == '\r' || ch == '\t') continue;
        if (ch >= 'a' && ch <= 'z') ch -= 32;
        const char *p = ch < 128 && ch ? strchr(kB32, (char)ch) : NULL;
        if (!p) return nil;
        acc = (acc << 5) | (unsigned long)(p - kB32);
        bits += 5;
        if (bits >= 8) {
            bits -= 8;
            uint8_t b = (uint8_t)((acc >> bits) & 0xff);
            [out appendBytes:&b length:1];
        }
    }
    return out;
}

NSString *TBBase32Encode(NSData *d) {
    NSMutableString *out = [NSMutableString string];
    const uint8_t *p = d.bytes;
    unsigned long acc = 0;
    int bits = 0;
    for (NSUInteger i = 0; i < d.length; i++) {
        acc = (acc << 8) | p[i];
        bits += 8;
        while (bits >= 5) {
            bits -= 5;
            [out appendFormat:@"%c", kB32[(acc >> bits) & 31]];
        }
    }
    if (bits) [out appendFormat:@"%c", kB32[(acc << (5 - bits)) & 31]];
    return out;
}

NSData *TBBase64Decode(NSString *s) {
    NSMutableData *out = [NSMutableData data];
    unsigned long acc = 0;
    int bits = 0;
    for (NSUInteger i = 0; i < s.length; i++) {
        unichar ch = [s characterAtIndex:i];
        if (ch == '=' || ch == '\n' || ch == '\r' || ch == ' ') continue;
        if (ch == '-') ch = '+';
        if (ch == '_') ch = '/';
        const char *p = ch < 128 && ch ? strchr(kB64, (char)ch) : NULL;
        if (!p) return nil;
        acc = (acc << 6) | (unsigned long)(p - kB64);
        bits += 6;
        if (bits >= 8) {
            bits -= 8;
            uint8_t b = (uint8_t)((acc >> bits) & 0xff);
            [out appendBytes:&b length:1];
        }
    }
    return out;
}

static NSString *unescape(NSString *s) {
    return [[s stringByReplacingOccurrencesOfString:@"+" withString:@" "] stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding] ?: s;
}

static NSString *escape(NSString *s) {
    return (__bridge_transfer NSString *)CFURLCreateStringByAddingPercentEscapes(NULL, (__bridge CFStringRef)s, NULL, CFSTR(":/?#[]@!$&'()*+,;= %"), kCFStringEncodingUTF8);
}

static NSString *trimmed(NSString *s) { return [s stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]]; }

/* --- protobuf (just enough for Google Authenticator's export: nested messages, varints, bytes, strings) --- */

static BOOL readVarint(const uint8_t *p, NSUInteger n, NSUInteger *pos, unsigned long long *v) {
    unsigned long long r = 0;
    int shift = 0;
    while (*pos < n && shift < 64) {
        uint8_t b = p[(*pos)++];
        r |= (unsigned long long)(b & 0x7f) << shift;
        if (!(b & 0x80)) { *v = r; return YES; }
        shift += 7;
    }
    return NO;
}

static TBAccount *migrationEntry(NSData *d) {
    const uint8_t *p = d.bytes;
    NSUInteger n = d.length, pos = 0;
    TBAccount *a = [[TBAccount alloc] init];
    NSData *secret = nil;
    int type = 2;
    while (pos < n) {
        unsigned long long key, v;
        if (!readVarint(p, n, &pos, &key)) return nil;
        int field = (int)(key >> 3), wire = (int)(key & 7);
        if (wire == 0) {
            if (!readVarint(p, n, &pos, &v)) return nil;
            if (field == 4) a.algorithm = v == 2 ? @"SHA256" : v == 3 ? @"SHA512" : @"SHA1";
            else if (field == 5) a.digits = v == 2 ? 8 : 6;
            else if (field == 6) type = (int)v;
            else if (field == 7) a.counter = (long long)v;
        } else if (wire == 2) {
            if (!readVarint(p, n, &pos, &v) || pos + v > n) return nil;
            NSData *chunk = [NSData dataWithBytes:p + pos length:(NSUInteger)v];
            pos += (NSUInteger)v;
            if (field == 1) secret = chunk;
            else if (field == 2) a.name = [[NSString alloc] initWithData:chunk encoding:NSUTF8StringEncoding];
            else if (field == 3) a.issuer = [[NSString alloc] initWithData:chunk encoding:NSUTF8StringEncoding];
        } else if (wire == 1) pos += 8;
        else if (wire == 5) pos += 4;
        else return nil;
    }
    if (!secret.length || type == 0) return nil;
    a.secret = TBBase32Encode(secret);
    a.counterBased = type == 1;
    return a.isValid ? a : nil;
}

static NSArray *migrationAccounts(NSString *uri) {
    NSRange q = [uri rangeOfString:@"data="];
    if (q.location == NSNotFound) return @[];
    NSString *b64 = [uri substringFromIndex:NSMaxRange(q)];
    NSRange amp = [b64 rangeOfString:@"&"];
    if (amp.location != NSNotFound) b64 = [b64 substringToIndex:amp.location];
    b64 = [b64 stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding] ?: b64;
    b64 = [b64 stringByReplacingOccurrencesOfString:@" " withString:@"+"];
    NSData *d = TBBase64Decode(b64);
    NSMutableArray *list = [NSMutableArray array];
    const uint8_t *p = d.bytes;
    NSUInteger n = d.length, pos = 0;
    while (pos < n) {
        unsigned long long key, v;
        if (!readVarint(p, n, &pos, &key)) break;
        int field = (int)(key >> 3), wire = (int)(key & 7);
        if (wire == 2) {
            if (!readVarint(p, n, &pos, &v) || pos + v > n) break;
            if (field == 1) {
                TBAccount *a = migrationEntry([NSData dataWithBytes:p + pos length:(NSUInteger)v]);
                if (a) [list addObject:a];
            }
            pos += (NSUInteger)v;
        } else if (wire == 0) { if (!readVarint(p, n, &pos, &v)) break; }
        else if (wire == 1) pos += 8;
        else if (wire == 5) pos += 4;
        else break;
    }
    return list;
}

@implementation TBAccount

- (id)init {
    if ((self = [super init])) {
        _issuer = @""; _name = @""; _secret = @""; _algorithm = @"SHA1"; _digits = 6; _period = 30;
    }
    return self;
}

- (void)setSecret:(NSString *)s {
    NSMutableString *m = [NSMutableString string];
    for (NSUInteger i = 0; i < s.length; i++) {
        unichar ch = [s characterAtIndex:i];
        if (ch == ' ' || ch == '-' || ch == '=' || ch == '\n' || ch == '\r' || ch == '\t') continue;
        [m appendFormat:@"%C", ch];
    }
    _secret = [m uppercaseString];
}

- (BOOL)isValid {
    NSData *k = TBBase32Decode(_secret);
    return k.length > 0 && _digits >= 6 && _digits <= 8 && (_counterBased || _period > 0);
}

- (NSString *)title { return _issuer.length ? _issuer : (_name.length ? _name : @"Account"); }

+ (TBAccount *)accountFromURI:(NSString *)uri {
    uri = trimmed(uri);
    if (![[uri lowercaseString] hasPrefix:@"otpauth://"]) return nil;
    NSString *rest = [uri substringFromIndex:10];
    NSRange qm = [rest rangeOfString:@"?"];
    NSString *head = qm.location == NSNotFound ? rest : [rest substringToIndex:qm.location];
    NSString *query = qm.location == NSNotFound ? @"" : [rest substringFromIndex:qm.location + 1];
    NSRange fr = [query rangeOfString:@"#"];
    if (fr.location != NSNotFound) query = [query substringToIndex:fr.location];
    NSRange sl = [head rangeOfString:@"/"];
    NSString *type = [(sl.location == NSNotFound ? head : [head substringToIndex:sl.location]) lowercaseString];
    NSString *label = sl.location == NSNotFound ? @"" : unescape([head substringFromIndex:sl.location + 1]);
    if (![type isEqualToString:@"totp"] && ![type isEqualToString:@"hotp"]) return nil;

    TBAccount *a = [[TBAccount alloc] init];
    a.counterBased = [type isEqualToString:@"hotp"];
    NSString *labelIssuer = nil;
    NSRange colon = [label rangeOfString:@":"];
    if (colon.location != NSNotFound) {
        labelIssuer = trimmed([label substringToIndex:colon.location]);
        a.name = trimmed([label substringFromIndex:colon.location + 1]);
    } else a.name = trimmed(label);
    for (NSString *pair in [query componentsSeparatedByString:@"&"]) {
        NSRange eq = [pair rangeOfString:@"="];
        if (eq.location == NSNotFound) continue;
        NSString *k = [[pair substringToIndex:eq.location] lowercaseString];
        NSString *v = [pair substringFromIndex:eq.location + 1];
        if ([k isEqualToString:@"secret"]) a.secret = [v stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding] ?: v;
        else if ([k isEqualToString:@"issuer"]) a.issuer = trimmed(unescape(v));
        else if ([k isEqualToString:@"algorithm"]) {
            NSString *u = [[v uppercaseString] stringByReplacingOccurrencesOfString:@"-" withString:@""];
            if ([u isEqualToString:@"SHA256"] || [u isEqualToString:@"SHA512"] || [u isEqualToString:@"SHA1"]) a.algorithm = u;
        }
        else if ([k isEqualToString:@"digits"]) a.digits = [v intValue];
        else if ([k isEqualToString:@"period"]) a.period = [v intValue];
        else if ([k isEqualToString:@"counter"]) a.counter = [v longLongValue];
    }
    if (!a.issuer.length && labelIssuer.length) a.issuer = labelIssuer;
    return a.isValid ? a : nil;
}

+ (NSArray *)accountsFromText:(NSString *)text {
    NSMutableArray *out = [NSMutableArray array];
    NSString *t = trimmed(text ?: @"");
    for (NSString *line in [t componentsSeparatedByCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]]) {
        NSString *l = [line lowercaseString];
        if ([l hasPrefix:@"otpauth-migration://"]) [out addObjectsFromArray:migrationAccounts(line)];
        else if ([l hasPrefix:@"otpauth://"]) { TBAccount *a = [self accountFromURI:line]; if (a) [out addObject:a]; }
    }
    if (!out.count) {   /* a bare secret key, e.g. "JBSW Y3DP EHPK 3PXP" */
        TBAccount *a = [[TBAccount alloc] init];
        a.secret = t;
        if (t.length >= 8 && a.isValid) [out addObject:a];
    }
    return out;
}

+ (TBAccount *)accountFromDictionary:(NSDictionary *)d {
    TBAccount *a = [[TBAccount alloc] init];
    a.issuer = [d objectForKey:@"issuer"] ?: @"";
    a.name = [d objectForKey:@"name"] ?: @"";
    a.secret = [d objectForKey:@"secret"] ?: @"";
    a.algorithm = [d objectForKey:@"algorithm"] ?: @"SHA1";
    a.digits = [[d objectForKey:@"digits"] intValue] ?: 6;
    a.period = [[d objectForKey:@"period"] intValue] ?: 30;
    a.counterBased = [[d objectForKey:@"hotp"] boolValue];
    a.counter = [[d objectForKey:@"counter"] longLongValue];
    return a.isValid ? a : nil;
}

- (NSDictionary *)dictionary {
    return [NSDictionary dictionaryWithObjectsAndKeys:_issuer, @"issuer", _name, @"name", _secret, @"secret", _algorithm, @"algorithm",
            [NSNumber numberWithInt:_digits], @"digits", [NSNumber numberWithInt:_period], @"period",
            [NSNumber numberWithBool:_counterBased], @"hotp", [NSNumber numberWithLongLong:_counter], @"counter", nil];
}

- (NSString *)URIString {
    NSString *label = _issuer.length ? [NSString stringWithFormat:@"%@:%@", escape(_issuer), escape(_name)] : escape(_name);
    NSMutableString *u = [NSMutableString stringWithFormat:@"otpauth://%@/%@?secret=%@", _counterBased ? @"hotp" : @"totp", label, _secret];
    if (_issuer.length) [u appendFormat:@"&issuer=%@", escape(_issuer)];
    if (![_algorithm isEqualToString:@"SHA1"]) [u appendFormat:@"&algorithm=%@", _algorithm];
    if (_digits != 6) [u appendFormat:@"&digits=%d", _digits];
    if (_counterBased) [u appendFormat:@"&counter=%lld", _counter];
    else if (_period != 30) [u appendFormat:@"&period=%d", _period];
    return u;
}

- (NSString *)codeForCounter:(unsigned long long)c {
    NSData *key = TBBase32Decode(_secret);
    if (!key.length) return nil;
    uint8_t msg[8];
    for (int i = 7; i >= 0; i--) { msg[i] = (uint8_t)(c & 0xff); c >>= 8; }
    CCHmacAlgorithm alg = kCCHmacAlgSHA1;
    size_t len = CC_SHA1_DIGEST_LENGTH;
    if ([_algorithm isEqualToString:@"SHA256"]) { alg = kCCHmacAlgSHA256; len = CC_SHA256_DIGEST_LENGTH; }
    else if ([_algorithm isEqualToString:@"SHA512"]) { alg = kCCHmacAlgSHA512; len = CC_SHA512_DIGEST_LENGTH; }
    uint8_t mac[CC_SHA512_DIGEST_LENGTH];
    CCHmac(alg, key.bytes, key.length, msg, 8, mac);
    int off = mac[len - 1] & 0x0f;
    uint32_t bin = ((uint32_t)(mac[off] & 0x7f) << 24) | ((uint32_t)mac[off + 1] << 16) | ((uint32_t)mac[off + 2] << 8) | mac[off + 3];
    uint32_t mod = 1;
    for (int i = 0; i < _digits; i++) mod *= 10;
    return [NSString stringWithFormat:@"%0*u", _digits, bin % mod];
}

- (NSString *)codeAtTime:(NSTimeInterval)t {
    if (_counterBased) return [self codeForCounter:(unsigned long long)_counter];
    return [self codeForCounter:(unsigned long long)(t / _period)];
}

- (double)secondsLeftAtTime:(NSTimeInterval)t {
    return _period - fmod(t, _period);
}

- (BOOL)isSameKeyAs:(TBAccount *)o {
    return [_secret isEqualToString:o.secret] && [_issuer isEqualToString:o.issuer] && [_name isEqualToString:o.name];
}

@end
