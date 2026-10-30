#import "TBLockView.h"
#import "TBChrome.h"
#import "TBStore.h"

@interface TBDots : UIView
@property (nonatomic) int count;
@end
@implementation TBDots
- (id)initWithFrame:(CGRect)f { if ((self = [super initWithFrame:f])) { self.backgroundColor = [UIColor clearColor]; } return self; }
- (void)setCount:(int)n { _count = n; [self setNeedsDisplay]; }
- (void)drawRect:(CGRect)r {
    CGContextRef c = UIGraphicsGetCurrentContext();
    for (int i = 0; i < 4; i++) {
        CGRect d = CGRectMake(i * 44 + 4, 4, 30, 30);
        /* a recessed socket, filled by a brass bolt head */
        CGContextSaveGState(c);
        [[UIColor colorWithWhite:1 alpha:0.25] setFill]; CGContextFillEllipseInRect(c, CGRectOffset(d, 0, 1));
        CGContextAddEllipseInRect(c, d); CGContextClip(c);
        TBFillGradient(c, d, TBRGB(0, 0, 0), TBRGB(40, 28, 20));
        CGContextRestoreGState(c);
        if (i < _count) {
            CGRect h = CGRectInset(d, 3, 3);
            CGContextSaveGState(c);
            CGContextSetShadowWithColor(c, CGSizeMake(0, 2), 3, [UIColor colorWithWhite:0 alpha:0.8].CGColor);
            [TB_BRASS_DK setFill]; CGContextFillEllipseInRect(c, h);
            CGContextRestoreGState(c);
            CGContextSaveGState(c);
            CGContextAddEllipseInRect(c, h); CGContextClip(c);
            TBFillGradient(c, h, TBRGB(252, 226, 150), TBRGB(160, 110, 30));
            TBFillGradient(c, CGRectMake(h.origin.x, h.origin.y, h.size.width, h.size.height / 2), [UIColor colorWithWhite:1 alpha:0.5], [UIColor colorWithWhite:1 alpha:0.05]);
            CGContextRestoreGState(c);
        }
    }
}
@end

@implementation TBLockView {
    BOOL (^_onEntry)(NSString *);
    void (^_cancel)(void);
    NSMutableString *_pin;
    TBDots *_dots;
    UILabel *_prompt;
    TBButton *_del;
}

+ (TBLockView *)presentIn:(UIWindow *)window prompt:(NSString *)prompt onEntry:(BOOL (^)(NSString *))onEntry cancel:(void (^)(void))cancel {
    TBLockView *v = [[TBLockView alloc] initWithFrame:window.bounds];
    v->_onEntry = [onEntry copy]; v->_cancel = [cancel copy];
    v.prompt = prompt;
    [v build];
    v.alpha = 0;
    [window addSubview:v];
    [UIView animateWithDuration:0.2 animations:^{ v.alpha = 1; }];
    return v;
}

- (id)initWithFrame:(CGRect)f {
    if ((self = [super initWithFrame:f])) {
        self.backgroundColor = [UIColor colorWithPatternImage:TBLeatherImage()];
        self.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        _pin = [NSMutableString string];
    }
    return self;
}

- (NSString *)prompt { return _prompt.text ?: _promptText; }
- (void)setPrompt:(NSString *)p { _promptText = [p copy]; _prompt.text = p; }
- (void)clearEntry { [_pin setString:@""]; _dots.count = 0; [self updateDelete]; }
@synthesize promptText = _promptText;

- (void)build {
    CGFloat w = self.bounds.size.width, h = self.bounds.size.height;
    BOOL tall = h > 500;
    CGFloat top = tall ? 36 : 14;
    UIImageView *lock = [[UIImageView alloc] initWithImage:TBPadlockImage(tall ? 92 : 60)];
    lock.center = CGPointMake(w / 2, top + (tall ? 46 : 30) + 10);
    [self addSubview:lock];
    _prompt = [[UILabel alloc] initWithFrame:CGRectMake(0, CGRectGetMaxY(lock.frame) + 4, w, 28)];
    _prompt.backgroundColor = [UIColor clearColor]; _prompt.textAlignment = NSTextAlignmentCenter;
    _prompt.font = TBFont(@"Georgia-Bold", 19); _prompt.textColor = TB_CREAM;
    _prompt.shadowColor = [UIColor blackColor]; _prompt.shadowOffset = CGSizeMake(0, -1);
    _prompt.text = _promptText;
    [self addSubview:_prompt];
    _dots = [[TBDots alloc] initWithFrame:CGRectMake((w - 172) / 2, CGRectGetMaxY(_prompt.frame) + 8, 172, 38)];
    [self addSubview:_dots];
    CGFloat key = tall ? 70 : 58, gap = tall ? 16 : 10;
    CGFloat gridW = key * 3 + gap * 2, x0 = (w - gridW) / 2, y0 = CGRectGetMaxY(_dots.frame) + (tall ? 22 : 10);
    NSArray *labels = @[@"1", @"2", @"3", @"4", @"5", @"6", @"7", @"8", @"9", @"", @"0", @""];
    for (int i = 0; i < 12; i++) {
        NSString *t = labels[i];
        int row = i / 3, col = i % 3;
        CGRect fr = CGRectMake(x0 + col * (key + gap), y0 + row * (key + gap), key, key);
        if (!t.length) {
            if (i == 11) {
                _del = [[TBButton alloc] initWithTitle:_cancel ? @"Cancel" : @"Delete" tone:0];
                _del.frame = CGRectMake(fr.origin.x, fr.origin.y + key / 2 - 15, key, 30);
                [_del addTarget:self action:@selector(deleteTap) forControlEvents:UIControlEventTouchUpInside];
                [self addSubview:_del];
            }
            continue;
        }
        TBButton *b = [[TBButton alloc] initWithTitle:t tone:0];
        b.round = YES;
        b.frame = fr;
        [b addTarget:self action:@selector(keyTap:) forControlEvents:UIControlEventTouchUpInside];
        [self addSubview:b];
    }
    [self updateDelete];
}

- (void)updateDelete {
    if (_pin.length) _del.title = @"Delete"; else _del.title = _cancel ? @"Cancel" : @"";
    _del.hidden = !_pin.length && !_cancel;
    [_del setNeedsDisplay];
}

- (void)keyTap:(TBButton *)b {
    if (_pin.length >= 4) return;
    [_pin appendString:b.title];
    _dots.count = (int)_pin.length;
    [self updateDelete];
    if (_pin.length == 4) {
        NSString *entry = [_pin copy];
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.12 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            BOOL ok = _onEntry ? _onEntry(entry) : YES;
            if (ok) { [self dismissAnimated]; return; }
            if (_pin.length) [self fail];   /* the set-passcode flow clears the entry itself between its two steps */
        });
    }
}

- (void)deleteTap {
    if (!_pin.length) { if (_cancel) { void (^c)(void) = _cancel; [self dismissAnimated]; c(); } return; }
    [_pin deleteCharactersInRange:NSMakeRange(_pin.length - 1, 1)];
    _dots.count = (int)_pin.length;
    [self updateDelete];
}

- (void)fail {
    [_pin setString:@""];
    _dots.count = 0;
    [self updateDelete];
    CAKeyframeAnimation *a = [CAKeyframeAnimation animationWithKeyPath:@"transform.translation.x"];
    a.values = @[@0, @-14, @14, @-10, @10, @-5, @5, @0];
    a.duration = 0.4;
    [_dots.layer addAnimation:a forKey:@"shake"];
}

- (void)dismissAnimated {
    [UIView animateWithDuration:0.2 animations:^{ self.alpha = 0; } completion:^(BOOL f) { [self removeFromSuperview]; }];
}

@end

void TBLockSetNewPIN(UIWindow *w, void (^done)(NSString *)) {
    __block NSString *first = nil;
    __block TBLockView *v = nil;
    v = [TBLockView presentIn:w prompt:@"Choose a passcode" onEntry:^BOOL(NSString *pin) {
        if (!first) {
            first = pin;
            v.prompt = @"Enter it again";
            [v clearEntry];
            return NO;
        }
        if ([pin isEqualToString:first]) { done(pin); return YES; }
        first = nil;
        v.prompt = @"Did not match, start over";
        return NO;
    } cancel:^{ done(nil); }];
}

void TBLockVerifyPIN(UIWindow *w, NSString *prompt, void (^done)(BOOL)) {
    [TBLockView presentIn:w prompt:prompt onEntry:^BOOL(NSString *pin) {
        if ([[TBStore shared] checkPIN:pin]) { done(YES); return YES; }
        return NO;
    } cancel:^{ done(NO); }];
}
