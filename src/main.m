#import <UIKit/UIKit.h>
#import "TBAppDelegate.h"
#import "TBListController.h"
#import "TBStore.h"
#import "TBLockView.h"
#import "TBChrome.h"
#import "TBFormController.h"

@implementation TBAppDelegate {
    TBLockView *_lock;
}

- (BOOL)application:(UIApplication *)app didFinishLaunchingWithOptions:(NSDictionary *)opts {
    [app setStatusBarStyle:UIStatusBarStyleDefault];
    self.window = [[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
    self.window.backgroundColor = [UIColor blackColor];
    TBListController *list = [[TBListController alloc] init];
    self.window.rootViewController = list;
    [self.window makeKeyAndVisible];
#ifdef TB_PREVIEW   /* simulator: TB_DEMO=1 fills the list, TB_SCREEN=add|settings|scan|keypad|form opens that screen, TB_COVER=1 covers codes, TB_EDIT=1 edit mode */
    if (getenv("TB_DEMO") && ![TBStore shared].accounts.count) {
        NSArray *uris = @[@"otpauth://totp/GitHub:alice?secret=JBSWY3DPEHPK3PXP&issuer=GitHub",
                          @"otpauth://totp/Google:alice@example.com?secret=GEZDGNBVGY3TQOJQGEZDGNBVGY3TQOJQ&issuer=Google",
                          @"otpauth://totp/Cloudflare:alice?secret=MFRGGZDFMZTWQ2LKNNWG23TPOBYXE43UOV3HO6DZPI&issuer=Cloudflare&digits=8",
                          @"otpauth://totp/AWS:root-account?secret=KRSXG5CTMVRXEZLUKN2XG2LBNZSXE&issuer=Amazon%20Web%20Services&algorithm=SHA256",
                          @"otpauth://hotp/Bank:alice?secret=GEZDGNBVGY3TQOJQGEZDGNBVGY3TQOJQ&issuer=Bank&counter=7"];
        for (NSString *u in uris) [[TBStore shared] addAccount:[TBAccount accountFromURI:u]];
    }
    if (getenv("TB_COVER")) [TBStore shared].coverCodes = YES;
    NSString *scr = getenv("TB_SCREEN") ? [NSString stringWithUTF8String:getenv("TB_SCREEN")] : nil;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.6 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        if (getenv("TB_EDIT")) [list performSelector:@selector(toggleEdit:) withObject:nil];
        if ([scr isEqualToString:@"add"]) [list performSelector:@selector(add:) withObject:nil];
        else if ([scr isEqualToString:@"settings"]) [list performSelector:@selector(settings:) withObject:nil];
        else if ([scr isEqualToString:@"scan"]) [list performSelector:@selector(scan:) withObject:nil];
        else if ([scr isEqualToString:@"keypad"]) [TBLockView presentIn:self.window prompt:@"Enter Passcode" onEntry:^BOOL(NSString *p) { return NO; } cancel:nil];
        else if ([scr isEqualToString:@"form"]) [list presentViewController:[[TBFormController alloc] initWithAccount:nil index:-1] animated:NO completion:nil];
    });
#endif
    if ([TBStore shared].hasPIN) [self lock];
    [self checkClock];
    return YES;
}

/* codes are only right when the time is, and old phones often have no network time: measure it against a web server */
- (void)checkClock {
    [[TBStore shared] syncClock:^(BOOL ok, double off) {
        if (ok && fabs(off) > 2) {
            UIView *host = self.window.rootViewController.presentedViewController.view ?: self.window.rootViewController.view;
            TBToast(host, [NSString stringWithFormat:@"Phone clock is %@ %@, codes are corrected", [TBStore describeOffset:off], off < 0 ? @"ahead" : @"behind"], NO);
        }
    }];
}

- (void)applicationWillEnterForeground:(UIApplication *)app { [self checkClock]; }

- (void)lock {
    if (_lock.superview || ![TBStore shared].hasPIN) return;
    __weak TBAppDelegate *me = self;
    _lock = [TBLockView presentIn:self.window prompt:@"Enter Passcode" onEntry:^BOOL(NSString *pin) {
        BOOL ok = [[TBStore shared] checkPIN:pin];
        TBAppDelegate *strong = me;
        if (ok && strong) strong->_lock = nil;
        return ok;
    } cancel:nil];
}

/* cover the app before iOS takes its multitasking snapshot */
- (void)applicationDidEnterBackground:(UIApplication *)app { [self lock]; }

- (BOOL)application:(UIApplication *)app openURL:(NSURL *)url sourceApplication:(NSString *)src annotation:(id)ann {
    [self handleText:url.absoluteString];
    return YES;
}

- (void)handleText:(NSString *)text {
    NSArray *list = [TBAccount accountsFromText:text];
    NSUInteger n = list.count ? [[TBStore shared] addAccounts:list] : 0;
    UIView *host = self.window.rootViewController.presentedViewController.view ?: self.window.rootViewController.view;
    TBToast(host, !list.count ? @"That is not a 2FA key" : n ? [NSString stringWithFormat:@"Added %lu account%@", (unsigned long)n, n == 1 ? @"" : @"s"] : @"Already in your list", n > 0);
}

@end

int main(int argc, char *argv[]) {
    @autoreleasepool {
        return UIApplicationMain(argc, argv, nil, NSStringFromClass([TBAppDelegate class]));
    }
}
