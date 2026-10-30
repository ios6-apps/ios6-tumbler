#import "TBStore.h"
#import <CommonCrypto/CommonDigest.h>

NSString *const TBStoreChanged = @"TBStoreChanged";

@implementation TBStore {
    NSMutableArray *_accounts;
}

+ (TBStore *)shared {
    static TBStore *s;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ s = [[TBStore alloc] init]; });
    return s;
}

static NSString *path(void) {
    NSString *dir = [NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES) objectAtIndex:0];
    [[NSFileManager defaultManager] createDirectoryAtPath:dir withIntermediateDirectories:YES attributes:nil error:NULL];
    return [dir stringByAppendingPathComponent:@"accounts.plist"];
}

- (id)init {
    if ((self = [super init])) {
        _accounts = [NSMutableArray array];
        for (NSDictionary *d in [NSArray arrayWithContentsOfFile:path()]) {
            TBAccount *a = [TBAccount accountFromDictionary:d];
            if (a) [_accounts addObject:a];
        }
    }
    return self;
}

- (NSArray *)accounts { return _accounts; }

- (void)changed {
    [self save];
    [[NSNotificationCenter defaultCenter] postNotificationName:TBStoreChanged object:self];
}

- (void)save {
    NSMutableArray *list = [NSMutableArray array];
    for (TBAccount *a in _accounts) [list addObject:a.dictionary];
    NSString *p = path();
    [list writeToFile:p atomically:YES];
    /* protect the file with the device passcode when there is one (needs a data-protection capable device) */
    [[NSFileManager defaultManager] setAttributes:[NSDictionary dictionaryWithObject:NSFileProtectionComplete forKey:NSFileProtectionKey] ofItemAtPath:p error:NULL];
}

- (BOOL)addAccount:(TBAccount *)a {
    for (TBAccount *o in _accounts) if ([o isSameKeyAs:a]) return NO;
    [_accounts addObject:a];
    [self changed];
    return YES;
}

- (NSUInteger)addAccounts:(NSArray *)list {
    NSUInteger n = 0;
    for (TBAccount *a in list) {
        BOOL dup = NO;
        for (TBAccount *o in _accounts) if ([o isSameKeyAs:a]) { dup = YES; break; }
        if (!dup) { [_accounts addObject:a]; n++; }
    }
    if (n) [self changed];
    return n;
}

- (void)removeAccountAtIndex:(NSUInteger)i {
    if (i >= _accounts.count) return;
    [_accounts removeObjectAtIndex:i];
    [self save];
}

- (void)moveAccountFromIndex:(NSUInteger)from toIndex:(NSUInteger)to {
    if (from >= _accounts.count || to >= _accounts.count) return;
    TBAccount *a = [_accounts objectAtIndex:from];
    [_accounts removeObjectAtIndex:from];
    [_accounts insertObject:a atIndex:to];
    [self save];
}

- (void)replaceAccountAtIndex:(NSUInteger)i with:(TBAccount *)a {
    if (i >= _accounts.count) return;
    [_accounts replaceObjectAtIndex:i withObject:a];
    [self save];
}

- (NSString *)exportText {
    NSMutableArray *lines = [NSMutableArray array];
    for (TBAccount *a in _accounts) [lines addObject:a.URIString];
    return [lines componentsJoinedByString:@"\n"];
}

+ (NSTimeInterval)now { return [[NSDate date] timeIntervalSince1970] + [TBStore shared].clockOffset; }

/* The offset is only trusted while the phone's clock has run steadily since it was measured: if the user changed the time
   (or the phone rebooted) the stored pair of uptime and wall clock no longer agrees and the offset is dropped. */
- (double)clockOffset {
    NSUserDefaults *u = [NSUserDefaults standardUserDefaults];
    double off = [u doubleForKey:@"tb.offset"];
    if (off == 0) return 0;
    double up = [[NSProcessInfo processInfo] systemUptime], dev = [[NSDate date] timeIntervalSince1970];
    double up0 = [u doubleForKey:@"tb.syncUp"], dev0 = [u doubleForKey:@"tb.syncDev"];
    if (up < up0 || fabs((dev - dev0) - (up - up0)) > 2) return 0;
    return off;
}
- (void)setClockOffset:(double)o {
    NSUserDefaults *u = [NSUserDefaults standardUserDefaults];
    [u setDouble:o forKey:@"tb.offset"];
    [u setDouble:[[NSProcessInfo processInfo] systemUptime] forKey:@"tb.syncUp"];
    [u setDouble:[[NSDate date] timeIntervalSince1970] forKey:@"tb.syncDev"];
    [u synchronize];
}

+ (NSString *)describeOffset:(double)off {
    long t = (long)llround(fabs(off));
    if (fabs(off) < 10) return [NSString stringWithFormat:@"%.1f s", fabs(off)];
    if (t < 120) return [NSString stringWithFormat:@"%ld s", t];
    if (t < 3600) return [NSString stringWithFormat:@"%ld min %ld s", t / 60, t % 60];
    return t % 3600 < 30 || t % 3600 > 3570 ? [NSString stringWithFormat:@"%ld h", (t + 30) / 3600] : [NSString stringWithFormat:@"%ld h %ld min", t / 3600, (t % 3600) / 60];
}

/* Asks plain-HTTP "connectivity check" endpoints for their Date header, trying the next host when one is unreachable or answers from a cache (Age header). */
- (void)syncClock:(void (^)(BOOL, double))done {
    [self syncClockFromHost:0 done:done];
}

- (void)syncClockFromHost:(NSUInteger)i done:(void (^)(BOOL, double))done {
    NSArray *urls = @[@"http://www.google.com/generate_204", @"http://cp.cloudflare.com/generate_204", @"http://connectivitycheck.gstatic.com/generate_204"];
    if (i >= urls.count) { done(NO, 0); return; }
    NSMutableURLRequest *r = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:urls[i]] cachePolicy:NSURLRequestReloadIgnoringLocalCacheData timeoutInterval:8];
    r.HTTPMethod = @"HEAD";
    NSDate *sent = [NSDate date];
    [NSURLConnection sendAsynchronousRequest:r queue:[NSOperationQueue mainQueue] completionHandler:^(NSURLResponse *resp, NSData *d, NSError *e) {
        NSDictionary *h = [resp isKindOfClass:[NSHTTPURLResponse class]] ? [(NSHTTPURLResponse *)resp allHeaderFields] : nil;
        NSString *date = [h objectForKey:@"Date"];
        NSDateFormatter *f = [[NSDateFormatter alloc] init];
        f.locale = [[NSLocale alloc] initWithLocaleIdentifier:@"en_US_POSIX"];
        f.timeZone = [NSTimeZone timeZoneWithName:@"GMT"];
        f.dateFormat = @"EEE, dd MMM yyyy HH:mm:ss 'GMT'";
        NSDate *server = date ? [f dateFromString:date] : nil;
        if (!server || [h objectForKey:@"Age"]) { [self syncClockFromHost:i + 1 done:done]; return; }
        /* the Date header has whole-second resolution and was produced about half a round trip ago */
        NSTimeInterval rtt = -[sent timeIntervalSinceNow];
        double off = [server timeIntervalSince1970] + 0.5 + rtt / 2 - [[NSDate date] timeIntervalSince1970];
        if (fabs(off) < 1.5) off = 0;   /* within the noise of a whole-second header */
        self.clockOffset = off;
        done(YES, off);
    }];
}

- (BOOL)coverCodes { return [[NSUserDefaults standardUserDefaults] boolForKey:@"tb.cover"]; }
- (void)setCoverCodes:(BOOL)on { [[NSUserDefaults standardUserDefaults] setBool:on forKey:@"tb.cover"]; [[NSUserDefaults standardUserDefaults] synchronize]; }

static NSString *pinHash(NSString *pin, NSString *salt) {
    NSData *d = [[salt stringByAppendingString:pin] dataUsingEncoding:NSUTF8StringEncoding];
    uint8_t h[CC_SHA256_DIGEST_LENGTH];
    CC_SHA256(d.bytes, (CC_LONG)d.length, h);
    NSMutableString *s = [NSMutableString string];
    for (int i = 0; i < CC_SHA256_DIGEST_LENGTH; i++) [s appendFormat:@"%02x", h[i]];
    return s;
}

- (BOOL)hasPIN { return [[NSUserDefaults standardUserDefaults] stringForKey:@"tb.pin"] != nil; }

- (BOOL)checkPIN:(NSString *)pin {
    NSUserDefaults *u = [NSUserDefaults standardUserDefaults];
    NSString *h = [u stringForKey:@"tb.pin"], *salt = [u stringForKey:@"tb.salt"];
    return h && salt && [h isEqualToString:pinHash(pin, salt)];
}

- (void)setPIN:(NSString *)pin {
    NSUserDefaults *u = [NSUserDefaults standardUserDefaults];
    if (!pin) { [u removeObjectForKey:@"tb.pin"]; [u removeObjectForKey:@"tb.salt"]; }
    else {
        NSString *salt = [NSString stringWithFormat:@"%08x%08x", arc4random(), arc4random()];
        [u setObject:salt forKey:@"tb.salt"];
        [u setObject:pinHash(pin, salt) forKey:@"tb.pin"];
    }
    [u synchronize];
}

@end
