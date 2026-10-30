#import "TBChrome.h"

@implementation TBButton

- (id)initWithTitle:(NSString *)t tone:(int)tone {
    if ((self = [super initWithFrame:CGRectMake(0, 0, MAX(54, [t sizeWithFont:TBFont(@"HelveticaNeue-Bold", 13)].width + 24), 30)])) {
        _title = [t copy]; _tone = tone; _iconKind = -1;
        self.backgroundColor = [UIColor clearColor];
    }
    return self;
}

- (id)initWithIcon:(int)kind title:(NSString *)t flat:(BOOL)flat {
    if ((self = [super initWithFrame:CGRectMake(0, 0, 80, flat ? 49 : 30)])) {
        _title = [t copy]; _iconKind = kind; _flat = flat;
        self.backgroundColor = [UIColor clearColor];
    }
    return self;
}

- (void)setHighlighted:(BOOL)h { [super setHighlighted:h]; [self setNeedsDisplay]; }
- (void)setEnabled:(BOOL)e { [super setEnabled:e]; self.alpha = e ? 1 : 0.5; }

- (void)drawRect:(CGRect)rect {
    CGContextRef c = UIGraphicsGetCurrentContext();
    CGRect b = self.bounds;
    if (_flat) {
        CGPoint m = CGPointMake(b.size.width / 2, 17);
        if (self.highlighted) {   /* a pressed footer key glows brass */
            CGContextSaveGState(c);
            CGFloat gc[8] = {1, 0.75, 0.3, 0.55, 1, 0.75, 0.3, 0};
            CGColorSpaceRef cs = CGColorSpaceCreateDeviceRGB();
            CGGradientRef g = CGGradientCreateWithColorComponents(cs, gc, NULL, 2);
            CGContextDrawRadialGradient(c, g, m, 0, m, 30, 0);
            CGGradientRelease(g); CGColorSpaceRelease(cs);
            CGContextRestoreGState(c);
        }
        CGRect ir = CGRectMake(m.x - 12, m.y - 12, 24, 24);
        TBDrawIcon(c, _iconKind, CGRectOffset(ir, 0, -1), [UIColor colorWithWhite:0 alpha:0.9]);
        TBDrawIcon(c, _iconKind, ir, self.highlighted ? TBRGB(255, 226, 150) : TBRGB(222, 190, 112));
        TBDrawText(_title, CGRectMake(0, 33, b.size.width, 14), TBFont(@"HelveticaNeue-Bold", 10), self.highlighted ? TBRGB(255, 226, 150) : TBRGB(190, 164, 106), [UIColor colorWithWhite:0 alpha:0.9], -1, NSTextAlignmentCenter);
        return;
    }
    TBGlassButton(c, b, _round ? b.size.height / 2 : 5, _tone, self.highlighted);
    UIColor *fg = _tone == 1 ? TBRGB(60, 36, 4) : [UIColor whiteColor];
    UIColor *sh = _tone == 1 ? [UIColor colorWithWhite:1 alpha:0.5] : [UIColor colorWithWhite:0 alpha:0.7];
    if (_iconKind >= 0 && !_title.length) {
        TBDrawIcon(c, _iconKind, CGRectInset(b, 6, 4), fg);
    } else {
        UIFont *f = _round ? TBFont(@"Georgia-Bold", 28) : TBFont(@"HelveticaNeue-Bold", 13);
        CGSize sz = [_title sizeWithFont:f];
        TBDrawText(_title, CGRectMake(0, (b.size.height - sz.height) / 2, b.size.width, sz.height), f, fg, sh, _tone == 1 ? 1 : -1, NSTextAlignmentCenter);
    }
}

@end

@implementation TBSegmented {
    NSArray *_items;
}

- (id)initWithItems:(NSArray *)items {
    if ((self = [super initWithFrame:CGRectMake(0, 0, 200, 32)])) {
        _items = items;
        self.backgroundColor = [UIColor clearColor];
    }
    return self;
}

- (void)setSelectedIndex:(NSInteger)i { _selectedIndex = i; [self setNeedsDisplay]; }

- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)e {
    CGPoint p = [[touches anyObject] locationInView:self];
    if (!CGRectContainsPoint(self.bounds, p)) return;
    NSInteger i = MIN((NSInteger)_items.count - 1, MAX(0, (NSInteger)(p.x / (self.bounds.size.width / _items.count))));
    if (i != _selectedIndex) { _selectedIndex = i; [self setNeedsDisplay]; [self sendActionsForControlEvents:UIControlEventValueChanged]; }
}

- (void)drawRect:(CGRect)rect {
    CGContextRef c = UIGraphicsGetCurrentContext();
    CGRect b = CGRectInset(self.bounds, 0.5, 0.5);
    CGContextSaveGState(c);
    TBRoundRectPath(c, b, 6); CGContextClip(c);
    TBFillGradient(c, b, TBRGB(12, 12, 14), TBRGB(34, 34, 38));
    CGFloat w = b.size.width / _items.count;
    for (NSUInteger i = 0; i < _items.count; i++) {
        CGRect seg = CGRectMake(b.origin.x + w * i, b.origin.y, w, b.size.height);
        BOOL on = (NSInteger)i == _selectedIndex;
        if (on) {
            TBFillGradient(c, seg, TBRGB(244, 212, 128), TBRGB(184, 136, 50));
            TBFillGradient(c, CGRectMake(seg.origin.x, seg.origin.y, seg.size.width, seg.size.height / 2), [UIColor colorWithWhite:1 alpha:0.4], [UIColor colorWithWhite:1 alpha:0.05]);
        }
        if (i) { [[UIColor colorWithWhite:0 alpha:0.7] set]; CGContextFillRect(c, CGRectMake(seg.origin.x, seg.origin.y, 1, seg.size.height)); }
        UIFont *f = TBFont(@"HelveticaNeue-Bold", 13);
        CGSize sz = [_items[i] sizeWithFont:f];
        TBDrawText(_items[i], CGRectMake(seg.origin.x, (b.size.height - sz.height) / 2 + 0.5, seg.size.width, sz.height), f,
                   on ? TBRGB(58, 34, 4) : TBRGB(170, 174, 184), on ? [UIColor colorWithWhite:1 alpha:0.5] : [UIColor colorWithWhite:0 alpha:0.8], on ? 1 : -1, NSTextAlignmentCenter);
    }
    CGContextRestoreGState(c);
    TBRoundRectPath(c, b, 6); [TBRGB(0, 0, 0) set]; CGContextSetLineWidth(c, 1); CGContextStrokePath(c);
}

@end

@interface TBHeader : UIView
@property (nonatomic, copy) NSString *title;
@end

@implementation TBHeader
- (id)initWithFrame:(CGRect)f { if ((self = [super initWithFrame:f])) { self.backgroundColor = [UIColor clearColor]; self.opaque = NO; } return self; }
- (void)drawRect:(CGRect)rect {
    CGContextRef c = UIGraphicsGetCurrentContext();
    CGRect b = self.bounds;
    TBBarBackground(c, b);
    UIFont *f = TBFont(@"Georgia-Bold", 21);
    CGSize sz = [_title sizeWithFont:f];
    CGFloat avail = b.size.width - 2 * 82;
    TBDrawText(_title, CGRectMake((b.size.width - MIN(sz.width, avail)) / 2, 20 + (44 - sz.height) / 2 - 1, MIN(sz.width, avail), sz.height), f,
               TB_ENGRAVE, [UIColor colorWithWhite:1 alpha:0.9], 1, NSTextAlignmentCenter);
}
@end

@interface TBBackdrop : UIView @end
@implementation TBBackdrop
- (void)drawRect:(CGRect)rect {
    CGContextRef c = UIGraphicsGetCurrentContext();
    [[UIColor colorWithPatternImage:TBLeatherImage()] setFill];
    CGContextFillRect(c, self.bounds);
    /* vignette: the leather falls off to dark at the corners */
    CGFloat gc[8] = {0, 0, 0, 0, 0, 0, 0, 0.55};
    CGColorSpaceRef cs = CGColorSpaceCreateDeviceRGB();
    CGGradientRef g = CGGradientCreateWithColorComponents(cs, gc, NULL, 2);
    CGPoint m = CGPointMake(CGRectGetMidX(self.bounds), CGRectGetMidY(self.bounds));
    CGContextDrawRadialGradient(c, g, m, self.bounds.size.height * 0.28, m, self.bounds.size.height * 0.75, kCGGradientDrawsAfterEndLocation);
    CGGradientRelease(g); CGColorSpaceRelease(cs);
}
@end

@implementation TBScreen {
    TBHeader *_header;
    UIView *_content;
}

- (UIView *)content { return _content; }

- (void)loadView {
    CGRect f = [[UIScreen mainScreen] bounds];
    TBBackdrop *v = [[TBBackdrop alloc] initWithFrame:f];
    v.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.view = v;
    _content = [[UIView alloc] initWithFrame:CGRectMake(0, 64, f.size.width, f.size.height - 64)];
    _content.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [v addSubview:_content];
    _header = [[TBHeader alloc] initWithFrame:CGRectMake(0, 0, f.size.width, 64)];
    _header.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    _header.title = self.title;
    [v addSubview:_header];
}

- (void)setScreenTitle:(NSString *)t { self.title = t; _header.title = t; [_header setNeedsDisplay]; }

- (void)setLeftButton:(TBButton *)b {
    [_leftButton removeFromSuperview]; _leftButton = b;
    if (!b) return;
    b.center = CGPointMake(8 + b.bounds.size.width / 2, 20 + 22);
    [self.view addSubview:b];
}

- (void)setRightButton:(TBButton *)b {
    [_rightButton removeFromSuperview]; _rightButton = b;
    if (!b) return;
    b.center = CGPointMake(self.view.bounds.size.width - 8 - b.bounds.size.width / 2, 20 + 22);
    b.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin;
    [self.view addSubview:b];
}

- (id)init {
    if ((self = [super init])) { self.modalPresentationStyle = UIModalPresentationFullScreen; self.wantsFullScreenLayout = YES; }
    return self;
}

- (UIStatusBarStyle)preferredStatusBarStyle { return UIStatusBarStyleDefault; }
- (BOOL)shouldAutorotate { return NO; }
- (NSUInteger)supportedInterfaceOrientations { return UIInterfaceOrientationMaskPortrait; }

- (void)dismissScreen { [self dismissViewControllerAnimated:YES completion:nil]; }

@end

void TBToast(UIView *host, NSString *text, BOOL good) {
    UIFont *f = TBFont(@"HelveticaNeue-Bold", 14);
    CGSize sz = [text sizeWithFont:f];
    CGFloat w = MIN(host.bounds.size.width - 40, sz.width + 44), h = 40;
    UIView *t = [[UIView alloc] initWithFrame:CGRectMake((host.bounds.size.width - w) / 2, host.bounds.size.height - 150, w, h)];
    t.userInteractionEnabled = NO;
    t.backgroundColor = [UIColor clearColor];
    UIGraphicsBeginImageContextWithOptions(CGSizeMake(w, h), NO, 0);
    CGContextRef c = UIGraphicsGetCurrentContext();
    TBGlassButton(c, CGRectMake(1, 1, w - 2, h - 2), 10, good ? 1 : 2, NO);
    TBDrawText(text, CGRectMake(8, (h - sz.height) / 2, w - 16, sz.height), f, good ? TBRGB(60, 36, 4) : [UIColor whiteColor], good ? [UIColor colorWithWhite:1 alpha:0.5] : [UIColor colorWithWhite:0 alpha:0.6], good ? 1 : -1, NSTextAlignmentCenter);
    UIImageView *iv = [[UIImageView alloc] initWithImage:UIGraphicsGetImageFromCurrentImageContext()];
    UIGraphicsEndImageContext();
    [t addSubview:iv];
    t.layer.shadowColor = [UIColor blackColor].CGColor; t.layer.shadowOpacity = 0.6; t.layer.shadowRadius = 5; t.layer.shadowOffset = CGSizeMake(0, 3);
    t.alpha = 0;
    [host addSubview:t];
    [UIView animateWithDuration:0.18 animations:^{ t.alpha = 1; } completion:^(BOOL d) {
        [UIView animateWithDuration:0.35 delay:1.3 options:0 animations:^{ t.alpha = 0; t.transform = CGAffineTransformMakeTranslation(0, -12); } completion:^(BOOL d2) { [t removeFromSuperview]; }];
    }];
}
