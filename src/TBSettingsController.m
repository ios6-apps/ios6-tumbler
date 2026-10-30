#import "TBSettingsController.h"
#import "TBStore.h"
#import "TBLockView.h"

/* a steel plate row: title, caption, and an accessory (switch or button) added by the controller */
@interface TBRow : UIView
@property (nonatomic, copy) NSString *title;
@property (nonatomic, copy) NSString *caption;
@end
@implementation TBRow
- (id)initWithFrame:(CGRect)f { if ((self = [super initWithFrame:f])) { self.backgroundColor = [UIColor clearColor]; self.contentMode = UIViewContentModeRedraw; } return self; }
- (void)drawRect:(CGRect)r {
    CGContextRef c = UIGraphicsGetCurrentContext();
    CGRect b = self.bounds; b.size.height -= 6;
    TBPlate(c, b, 9);
    TBDrawText(_title, CGRectMake(16, _caption.length ? 10 : (b.size.height - 20) / 2, b.size.width - 130, 20), TBFont(@"HelveticaNeue-Bold", 16), TBRGB(236, 238, 244), [UIColor colorWithWhite:0 alpha:0.85], -1, NSTextAlignmentLeft);
    if (_caption.length) TBDrawText(_caption, CGRectMake(16, 31, b.size.width - 112, b.size.height - 6 - 36), TBFont(@"HelveticaNeue", 12), TBRGB(166, 172, 184), [UIColor colorWithWhite:0 alpha:0.8], -1, NSTextAlignmentLeft);
}
@end

@implementation TBSettingsController {
    UIScrollView *_scroll;
    TBRow *_lockRow, *_clockRow;
    TBButton *_lockBtn, *_clockBtn;
    UISwitch *_cover;
    UIActionSheet *_pinSheet, *_exportSheet;
}

- (TBRow *)rowAt:(CGFloat)y height:(CGFloat)h title:(NSString *)t caption:(NSString *)c {
    TBRow *r = [[TBRow alloc] initWithFrame:CGRectMake(10, y, self.content.bounds.size.width - 20, h)];
    r.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    r.title = t; r.caption = c;
    [_scroll addSubview:r];
    return r;
}

- (TBButton *)buttonIn:(TBRow *)r title:(NSString *)t tone:(int)tone action:(SEL)a {
    TBButton *b = [[TBButton alloc] initWithTitle:t tone:tone];
    b.center = CGPointMake(r.bounds.size.width - 14 - b.bounds.size.width / 2, (r.bounds.size.height - 6) / 2);
    b.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin;
    [b addTarget:self action:a forControlEvents:UIControlEventTouchUpInside];
    [r addSubview:b];
    return b;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    [self setScreenTitle:@"Settings"];
    self.leftButton = nil;
    self.rightButton = [[TBButton alloc] initWithTitle:@"Done" tone:1];
    [self.rightButton addTarget:self action:@selector(dismissScreen) forControlEvents:UIControlEventTouchUpInside];
    _scroll = [[UIScrollView alloc] initWithFrame:self.content.bounds];
    _scroll.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    _scroll.alwaysBounceVertical = YES;
    [self.content addSubview:_scroll];
    CGFloat y = 14;
    _lockRow = [self rowAt:y height:80 title:@"Passcode lock" caption:@"Ask for a four-digit code whenever Tumbler opens."];
    _lockBtn = [self buttonIn:_lockRow title:@"Turn on" tone:0 action:@selector(lockTap)];
    y += 86;
    TBRow *cv = [self rowAt:y height:80 title:@"Cover codes" caption:@"Show codes only after you tap an account."];
    _cover = [[UISwitch alloc] init];
    _cover.center = CGPointMake(cv.bounds.size.width - 14 - _cover.bounds.size.width / 2, (cv.bounds.size.height - 6) / 2);
    _cover.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin;
    _cover.on = [TBStore shared].coverCodes;
    [_cover addTarget:self action:@selector(coverChanged) forControlEvents:UIControlEventValueChanged];
    [cv addSubview:_cover];
    y += 86;
    _clockRow = [self rowAt:y height:98 title:@"Clock" caption:@""];
    _clockBtn = [self buttonIn:_clockRow title:@"Sync" tone:0 action:@selector(syncTap)];
    y += 104;
    TBRow *ex = [self rowAt:y height:80 title:@"Copy all keys" caption:@"Backup as text. Anyone who reads it can make your codes."];
    [self buttonIn:ex title:@"Copy" tone:0 action:@selector(exportTap)];
    y += 86;
    TBRow *im = [self rowAt:y height:84 title:@"Paste keys" caption:@"Add 2FA links or a Google Authenticator export from the clipboard."];
    [self buttonIn:im title:@"Paste" tone:0 action:@selector(importTap)];
    y += 90;
    TBRow *ab = [self rowAt:y height:70 title:@"Tumbler 1.0" caption:@"Codes are made on this phone, no network needed. RFC 6238."];
    (void)ab;
    y += 76;
    _scroll.contentSize = CGSizeMake(self.content.bounds.size.width, y + 10);
    [self refresh];
}

- (void)refresh {
    BOOL on = [TBStore shared].hasPIN;
    _lockBtn.title = on ? @"Change" : @"Turn on";
    _lockBtn.tone = on ? 1 : 0;
    [_lockBtn setNeedsDisplay];
    double off = [TBStore shared].clockOffset;
    NSDateFormatter *f = [[NSDateFormatter alloc] init];
    f.dateFormat = @"HH:mm:ss";
    NSString *time = [f stringFromDate:[NSDate dateWithTimeIntervalSince1970:[TBStore now]]];
    _clockRow.caption = fabs(off) < 0.5 ? [NSString stringWithFormat:@"Phone clock %@. Codes only work when the time is right; Sync checks it against a web server.", time]
        : [NSString stringWithFormat:@"The phone's clock is %@ %@. Tumbler corrects for it, so codes stay right. Fix it in Settings > General > Date & Time.", [TBStore describeOffset:off], off < 0 ? @"ahead" : @"behind"];
    [_clockRow setNeedsDisplay];
}

- (void)coverChanged { [TBStore shared].coverCodes = _cover.on; [[NSNotificationCenter defaultCenter] postNotificationName:TBStoreChanged object:[TBStore shared]]; }

- (void)syncTap {
    _clockBtn.enabled = NO;
    _clockRow.caption = @"Asking the time server...";
    [_clockRow setNeedsDisplay];
    [[TBStore shared] syncClock:^(BOOL ok, double off) {
        _clockBtn.enabled = YES;
        [self refresh];
        if (ok) TBToast(self.view, fabs(off) < 1 ? @"Clock is right" : [NSString stringWithFormat:@"Clock was %@ off, corrected", [TBStore describeOffset:off]], YES);
        else TBToast(self.view, @"Could not reach the time server", NO);
    }];
}

- (void)lockTap {
    UIWindow *w = self.view.window;
    if (![TBStore shared].hasPIN) {
        TBLockSetNewPIN(w, ^(NSString *pin) { if (pin) { [[TBStore shared] setPIN:pin]; [self refresh]; TBToast(self.view, @"Passcode on", YES); } });
        return;
    }
    _pinSheet = [[UIActionSheet alloc] initWithTitle:nil delegate:self cancelButtonTitle:nil destructiveButtonTitle:@"Turn passcode off" otherButtonTitles:@"Change passcode", nil];
    [_pinSheet addButtonWithTitle:@"Cancel"];
    _pinSheet.cancelButtonIndex = _pinSheet.numberOfButtons - 1;
    _pinSheet.actionSheetStyle = UIActionSheetStyleBlackOpaque;
    [_pinSheet showInView:self.view];
}

- (void)exportTap {
    if (![TBStore shared].accounts.count) { TBToast(self.view, @"Nothing to copy yet", NO); return; }
    _exportSheet = [[UIActionSheet alloc] initWithTitle:@"The clipboard will hold every secret key in plain text." delegate:self cancelButtonTitle:nil destructiveButtonTitle:nil otherButtonTitles:@"Copy keys", nil];
    [_exportSheet addButtonWithTitle:@"Cancel"];
    _exportSheet.cancelButtonIndex = 1;
    _exportSheet.actionSheetStyle = UIActionSheetStyleBlackOpaque;
    [_exportSheet showInView:self.view];
}

- (void)importTap {
    NSArray *list = [TBAccount accountsFromText:[UIPasteboard generalPasteboard].string];
    if (!list.count) { TBToast(self.view, @"No 2FA key on the clipboard", NO); return; }
    NSUInteger n = [[TBStore shared] addAccounts:list];
    TBToast(self.view, n ? [NSString stringWithFormat:@"Added %lu account%@", (unsigned long)n, n == 1 ? @"" : @"s"] : @"Already in your list", n > 0);
}

- (void)actionSheet:(UIActionSheet *)sh clickedButtonAtIndex:(NSInteger)i {
    if (i == sh.cancelButtonIndex) return;
    UIWindow *w = self.view.window;
    if (sh == _exportSheet) {
        [UIPasteboard generalPasteboard].string = [TBStore shared].exportText;
        TBToast(self.view, @"Keys copied", YES);
        return;
    }
    BOOL off = i == sh.destructiveButtonIndex;
    TBLockVerifyPIN(w, off ? @"Enter passcode to turn off" : @"Enter current passcode", ^(BOOL ok) {
        if (!ok) return;
        if (off) { [[TBStore shared] setPIN:nil]; [self refresh]; TBToast(self.view, @"Passcode off", YES); }
        else TBLockSetNewPIN(w, ^(NSString *pin) { if (pin) { [[TBStore shared] setPIN:pin]; TBToast(self.view, @"Passcode changed", YES); } });
    });
}

@end
