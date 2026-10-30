#import "TBFormController.h"
#import "TBStore.h"

@interface TBInset : UIView @end
@implementation TBInset
- (id)initWithFrame:(CGRect)f { if ((self = [super initWithFrame:f])) { self.backgroundColor = [UIColor clearColor]; self.userInteractionEnabled = NO; } return self; }
- (void)drawRect:(CGRect)r {
    CGContextRef c = UIGraphicsGetCurrentContext();
    CGRect b = CGRectInset(self.bounds, 1, 1);
    [[UIColor colorWithRed:1 green:0.8 blue:0.7 alpha:0.18] setFill];
    TBRoundRectPath(c, CGRectOffset(b, 0, 1), 7); CGContextFillPath(c);
    CGContextSaveGState(c);
    TBRoundRectPath(c, b, 7); CGContextClip(c);
    TBFillGradient(c, b, TBRGB(16, 10, 8), TBRGB(40, 26, 20));
    TBFillGradient(c, CGRectMake(b.origin.x, b.origin.y, b.size.width, 9), [UIColor colorWithWhite:0 alpha:0.7], [UIColor colorWithWhite:0 alpha:0]);
    CGContextRestoreGState(c);
    TBRoundRectPath(c, b, 7); [TBRGB(0, 0, 0) set]; CGContextSetLineWidth(c, 1); CGContextStrokePath(c);
}
@end

@interface TBLabel : UILabel @end
@implementation TBLabel
- (void)drawTextInRect:(CGRect)r {
    CGContextRef c = UIGraphicsGetCurrentContext();
    CGContextSaveGState(c);
    CGContextSetShadowWithColor(c, CGSizeMake(0, -1), 0, [UIColor colorWithWhite:0 alpha:0.9].CGColor);
    [super drawTextInRect:r];
    CGContextRestoreGState(c);
}
@end

@implementation TBFormController {
    TBAccount *_acct;
    NSInteger _index;
    UIScrollView *_scroll;
    UITextField *_issuer, *_name, *_secret;
    TBSegmented *_type, *_alg, *_digits, *_period;
    TBLabel *_periodLabel;
    UILabel *_error;
    BOOL _customPeriod;
}

- (id)initWithAccount:(TBAccount *)a index:(NSInteger)i {
    if ((self = [super init])) { _acct = a; _index = i; }
    return self;
}

- (UITextField *)fieldAt:(CGFloat)y label:(NSString *)label placeholder:(NSString *)ph text:(NSString *)text {
    CGFloat w = self.content.bounds.size.width;
    TBLabel *l = [[TBLabel alloc] initWithFrame:CGRectMake(24, y, w - 48, 16)];
    l.backgroundColor = [UIColor clearColor]; l.font = TBFont(@"HelveticaNeue-Bold", 12); l.textColor = TBRGB(214, 184, 150);
    l.text = [label uppercaseString];
    [_scroll addSubview:l];
    TBInset *in = [[TBInset alloc] initWithFrame:CGRectMake(14, y + 19, w - 28, 42)];
    in.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    [_scroll addSubview:in];
    UITextField *t = [[UITextField alloc] initWithFrame:CGRectMake(26, y + 19, w - 52, 42)];
    t.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    t.contentVerticalAlignment = UIControlContentVerticalAlignmentCenter;
    t.font = TBFont(@"HelveticaNeue", 17); t.textColor = TB_CREAM;
    t.placeholder = ph;
    if ([t respondsToSelector:@selector(setAttributedPlaceholder:)])
        t.attributedPlaceholder = [[NSAttributedString alloc] initWithString:ph attributes:[NSDictionary dictionaryWithObject:TBRGB(128, 104, 90) forKey:NSForegroundColorAttributeName]];
    t.text = text;
    t.autocorrectionType = UITextAutocorrectionTypeNo;
    t.autocapitalizationType = UITextAutocapitalizationTypeNone;
    t.keyboardAppearance = UIKeyboardAppearanceAlert;
    t.returnKeyType = UIReturnKeyNext;
    t.clearButtonMode = UITextFieldViewModeWhileEditing;
    t.delegate = self;
    [_scroll addSubview:t];
    return t;
}

- (TBSegmented *)segmentAt:(CGFloat)y label:(NSString *)label items:(NSArray *)items {
    CGFloat w = self.content.bounds.size.width;
    TBLabel *l = [[TBLabel alloc] initWithFrame:CGRectMake(24, y, w - 48, 16)];
    l.backgroundColor = [UIColor clearColor]; l.font = TBFont(@"HelveticaNeue-Bold", 12); l.textColor = TBRGB(214, 184, 150);
    l.text = [label uppercaseString];
    [_scroll addSubview:l];
    TBSegmented *s = [[TBSegmented alloc] initWithItems:items];
    s.frame = CGRectMake(14, y + 19, w - 28, 34);
    s.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    [_scroll addSubview:s];
    return s;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    BOOL edit = _acct != nil;
    [self setScreenTitle:edit ? @"Edit Account" : @"Add Account"];
    self.leftButton = [[TBButton alloc] initWithTitle:@"Cancel" tone:0];
    [self.leftButton addTarget:self action:@selector(dismissScreen) forControlEvents:UIControlEventTouchUpInside];
    self.rightButton = [[TBButton alloc] initWithTitle:@"Save" tone:1];
    [self.rightButton addTarget:self action:@selector(save) forControlEvents:UIControlEventTouchUpInside];

    _scroll = [[UIScrollView alloc] initWithFrame:self.content.bounds];
    _scroll.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    _scroll.alwaysBounceVertical = YES;
    [self.content addSubview:_scroll];
    CGFloat y = 14;
    _issuer = [self fieldAt:y label:@"Service" placeholder:@"GitHub, Google, ..." text:_acct.issuer]; y += 72;
    _name = [self fieldAt:y label:@"Account" placeholder:@"you@example.com" text:_acct.name]; y += 72;
    _secret = [self fieldAt:y label:@"Secret key" placeholder:@"JBSW Y3DP EHPK 3PXP" text:_acct.secret];
    _secret.autocapitalizationType = UITextAutocapitalizationTypeAllCharacters;
    _secret.returnKeyType = UIReturnKeyDone;
    _secret.font = TBFont(@"Courier-Bold", 17);
    y += 72;
    _error = [[UILabel alloc] initWithFrame:CGRectMake(24, y - 6, self.content.bounds.size.width - 48, 18)];
    _error.backgroundColor = [UIColor clearColor]; _error.font = TBFont(@"HelveticaNeue-Bold", 13); _error.textColor = TBRGB(255, 130, 110);
    [_scroll addSubview:_error];
    y += 22;
    _type = [self segmentAt:y label:@"Kind" items:@[@"Time based", @"Counter based"]]; y += 62;
    _type.selectedIndex = _acct.counterBased ? 1 : 0;
    [_type addTarget:self action:@selector(typeChanged) forControlEvents:UIControlEventValueChanged];
    _alg = [self segmentAt:y label:@"Algorithm" items:@[@"SHA-1", @"SHA-256", @"SHA-512"]]; y += 62;
    _alg.selectedIndex = [_acct.algorithm isEqualToString:@"SHA256"] ? 1 : [_acct.algorithm isEqualToString:@"SHA512"] ? 2 : 0;
    _digits = [self segmentAt:y label:@"Digits" items:@[@"6", @"7", @"8"]]; y += 62;
    _digits.selectedIndex = (_acct ? _acct.digits : 6) - 6;
    _period = [self segmentAt:y label:@"Refresh every" items:@[@"15 s", @"30 s", @"60 s"]]; y += 62;
    int p = _acct ? _acct.period : 30;
    _period.selectedIndex = p == 15 ? 0 : p == 60 ? 2 : 1;
    _customPeriod = _acct && p != 15 && p != 30 && p != 60;   /* custom period from a QR code: keep it as is */
    if (_acct) {
        TBButton *del = [[TBButton alloc] initWithTitle:@"Delete this account" tone:2];
        del.frame = CGRectMake(14, y + 8, self.content.bounds.size.width - 28, 44);
        del.autoresizingMask = UIViewAutoresizingFlexibleWidth;
        [del addTarget:self action:@selector(confirmDelete) forControlEvents:UIControlEventTouchUpInside];
        [_scroll addSubview:del];
        y += 64;
    }
    [self typeChanged];
    _scroll.contentSize = CGSizeMake(self.content.bounds.size.width, y + 20);
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(kb:) name:UIKeyboardWillChangeFrameNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(kb:) name:UIKeyboardWillShowNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(kbHide) name:UIKeyboardWillHideNotification object:nil];
    if (!edit) [_issuer performSelector:@selector(becomeFirstResponder) withObject:nil afterDelay:0.4];
}

- (void)kb:(NSNotification *)n {
    CGRect r = [[n.userInfo objectForKey:UIKeyboardFrameEndUserInfoKey] CGRectValue];
    _scroll.contentInset = UIEdgeInsetsMake(0, 0, r.size.height, 0);
    _scroll.scrollIndicatorInsets = _scroll.contentInset;
}
- (void)kbHide { _scroll.contentInset = UIEdgeInsetsZero; _scroll.scrollIndicatorInsets = UIEdgeInsetsZero; }

- (void)typeChanged {
    BOOL hotp = _type.selectedIndex == 1;
    BOOL locked = hotp || _customPeriod;
    _period.alpha = locked ? 0.35 : 1;
    _period.userInteractionEnabled = !locked;
}

- (BOOL)textFieldShouldReturn:(UITextField *)t {
    if (t == _issuer) [_name becomeFirstResponder];
    else if (t == _name) [_secret becomeFirstResponder];
    else [t resignFirstResponder];
    return NO;
}

- (void)save {
    TBAccount *a = [[TBAccount alloc] init];
    a.issuer = [_issuer.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    a.name = [_name.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    a.secret = _secret.text;
    a.algorithm = _alg.selectedIndex == 1 ? @"SHA256" : _alg.selectedIndex == 2 ? @"SHA512" : @"SHA1";
    a.digits = 6 + (int)_digits.selectedIndex;
    a.counterBased = _type.selectedIndex == 1;
    a.counter = _acct ? _acct.counter : 0;
    a.period = _customPeriod ? _acct.period : (_period.selectedIndex == 0 ? 15 : _period.selectedIndex == 2 ? 60 : 30);
    if (!a.secret.length) { _error.text = @"Type the secret key the website gave you."; return; }
    if (!TBBase32Decode(a.secret)) { _error.text = @"The key may only have the letters A-Z and digits 2-7."; return; }
    if (!a.isValid) { _error.text = @"That key is too short to be valid."; return; }
    if (!a.issuer.length && !a.name.length) a.issuer = @"Account";
    if (_acct && _index >= 0) [[TBStore shared] replaceAccountAtIndex:_index with:a];
    else if (![[TBStore shared] addAccount:a]) { _error.text = @"This key is already in your list."; return; }
    [[NSNotificationCenter defaultCenter] postNotificationName:TBStoreChanged object:[TBStore shared]];
    [self dismissScreen];
}

- (void)confirmDelete {
    UIAlertView *al = [[UIAlertView alloc] initWithTitle:[NSString stringWithFormat:@"Delete %@?", _acct.title]
        message:@"Codes for this account stop being generated here. Make sure you can still sign in some other way first."
        delegate:self cancelButtonTitle:@"Keep" otherButtonTitles:@"Delete", nil];
    [al show];
}

- (void)alertView:(UIAlertView *)a clickedButtonAtIndex:(NSInteger)i {
    if (i == a.cancelButtonIndex || _index < 0) return;
    [[TBStore shared] removeAccountAtIndex:_index];
    [[NSNotificationCenter defaultCenter] postNotificationName:TBStoreChanged object:[TBStore shared]];
    [self dismissScreen];
}

- (void)dealloc { [[NSNotificationCenter defaultCenter] removeObserver:self]; }

@end
