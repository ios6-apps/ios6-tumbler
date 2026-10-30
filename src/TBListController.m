#import "TBListController.h"
#import "TBCards.h"
#import "TBStore.h"
#import "TBScanController.h"
#import "TBFormController.h"
#import "TBSettingsController.h"
#import "TBAppDelegate.h"

static const CGFloat kRow = 112;

@interface TBFooter : UIView @end
@implementation TBFooter
- (id)initWithFrame:(CGRect)f { if ((self = [super initWithFrame:f])) { self.backgroundColor = [UIColor clearColor]; self.opaque = NO; } return self; }
- (void)drawRect:(CGRect)r { TBFooterBackground(UIGraphicsGetCurrentContext(), self.bounds); }
@end

@interface TBEmptyView : UIView @end
@implementation TBEmptyView
- (void)drawRect:(CGRect)r {
    CGFloat w = self.bounds.size.width;
    [TBPadlockImage(116) drawInRect:CGRectMake((w - 116) / 2, 10, 116, 116)];
    TBDrawText(@"Nothing locked up yet", CGRectMake(20, 142, w - 40, 26), TBFont(@"Georgia-Bold", 20), TB_CREAM, [UIColor colorWithWhite:0 alpha:0.8], -1, NSTextAlignmentCenter);
    TBDrawText(@"Scan the QR code a website shows you when you turn on two-step verification, or type the key in by hand.",
               CGRectMake(34, 176, w - 68, 70), TBFont(@"HelveticaNeue", 14), TBRGB(206, 178, 160), [UIColor colorWithWhite:0 alpha:0.8], -1, NSTextAlignmentCenter);
}
@end

@implementation TBListController {
    UITableView *_table;
    TBEmptyView *_empty;
    TBFooter *_footer;
    NSTimer *_timer;
    NSMutableDictionary *_revealed;     /* account index -> reveal expiry */
}

- (void)viewDidLoad {
    [super viewDidLoad];
    [self setScreenTitle:@"Tumbler"];
    _revealed = [NSMutableDictionary dictionary];
    CGRect cb = self.content.bounds;
    _table = [[UITableView alloc] initWithFrame:CGRectMake(0, 0, cb.size.width, cb.size.height - 49) style:UITableViewStylePlain];
    _table.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    _table.backgroundColor = [UIColor clearColor];
    _table.separatorStyle = UITableViewCellSeparatorStyleNone;
    _table.rowHeight = kRow;
    _table.dataSource = self; _table.delegate = self;
    _table.contentInset = UIEdgeInsetsMake(8, 0, 6, 0);
    _table.scrollIndicatorInsets = UIEdgeInsetsMake(0, 0, 0, 0);
    [self.content addSubview:_table];

    _empty = [[TBEmptyView alloc] initWithFrame:CGRectMake(0, 24, cb.size.width, 260)];
    _empty.backgroundColor = [UIColor clearColor];
    _empty.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    [self.content addSubview:_empty];

    _footer = [[TBFooter alloc] initWithFrame:CGRectMake(0, cb.size.height - 49, cb.size.width, 49)];
    _footer.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleTopMargin;
    NSArray *spec = @[@[@0, @"Scan", @"scan"], @[@1, @"Add", @"add"], @[@2, @"Settings", @"settings"]];
    CGFloat bw = cb.size.width / 3;
    for (NSUInteger i = 0; i < spec.count; i++) {
        TBButton *b = [[TBButton alloc] initWithIcon:[spec[i][0] intValue] title:spec[i][1] flat:YES];
        b.frame = CGRectMake(bw * i, 0, bw, 49);
        b.autoresizingMask = UIViewAutoresizingFlexibleWidth;
        [b addTarget:self action:NSSelectorFromString([spec[i][2] stringByAppendingString:@":"]) forControlEvents:UIControlEventTouchUpInside];
        [_footer addSubview:b];
    }
    [self.content addSubview:_footer];

    self.leftButton = [[TBButton alloc] initWithTitle:@"Edit" tone:0];
    [self.leftButton addTarget:self action:@selector(toggleEdit:) forControlEvents:UIControlEventTouchUpInside];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(storeChanged) name:TBStoreChanged object:nil];
    [self refresh];
}

- (void)refresh {
    BOOL has = [TBStore shared].accounts.count > 0;
    _empty.hidden = has;
    _table.hidden = !has;
    self.leftButton.hidden = !has;
    if (!has && _table.editing) [self toggleEdit:nil];
    [self updateLockButton];
    [_table reloadData];
}

- (void)updateLockButton {
    if ([TBStore shared].hasPIN && !self.rightButton) {
        TBButton *b = [[TBButton alloc] initWithIcon:3 title:nil flat:NO];
        b.frame = CGRectMake(0, 0, 44, 30);
        [b addTarget:self action:@selector(lockNow) forControlEvents:UIControlEventTouchUpInside];
        self.rightButton = b;
    } else if (![TBStore shared].hasPIN && self.rightButton) self.rightButton = nil;
}

- (void)storeChanged { [self refresh]; }

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self refresh];
    [self startTimer];
}

- (void)viewDidDisappear:(BOOL)animated { [super viewDidDisappear:animated]; }

- (void)startTimer {
    [_timer invalidate];
    _timer = [NSTimer timerWithTimeInterval:0.1 target:self selector:@selector(tick) userInfo:nil repeats:YES];
    [[NSRunLoop mainRunLoop] addTimer:_timer forMode:NSRunLoopCommonModes];
}

- (void)tick {
    NSTimeInterval now = [TBStore now];
    BOOL expired = NO;
    for (NSNumber *k in [_revealed allKeys]) if ([[_revealed objectForKey:k] doubleValue] < now) { [_revealed removeObjectForKey:k]; expired = YES; }
    for (UITableViewCell *cell in _table.visibleCells) {
        if (![cell isKindOfClass:[TBAccountCell class]]) continue;
        TBCardView *card = [(TBAccountCell *)cell card];
        if (expired) { NSIndexPath *ip = [_table indexPathForCell:cell]; if (ip) card.covered = [self coveredAt:ip.row]; }
        [card tick:now];
    }
}

- (BOOL)coveredAt:(NSInteger)i {
    return [TBStore shared].coverCodes && ![_revealed objectForKey:[NSNumber numberWithInteger:i]];
}

- (void)toggleEdit:(id)s {
    BOOL on = !_table.editing;
    [_table setEditing:on animated:YES];
    self.leftButton.title = on ? @"Done" : @"Edit";
    [self.leftButton setNeedsDisplay];
}

#pragma mark table

- (NSInteger)tableView:(UITableView *)t numberOfRowsInSection:(NSInteger)s { return [TBStore shared].accounts.count; }

- (UITableViewCell *)tableView:(UITableView *)t cellForRowAtIndexPath:(NSIndexPath *)ip {
    TBAccountCell *cell = [t dequeueReusableCellWithIdentifier:@"acct"];
    if (!cell) cell = [[TBAccountCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"acct"];
    TBAccount *a = [[TBStore shared].accounts objectAtIndex:ip.row];
    cell.card.account = a;
    cell.card.covered = [self coveredAt:ip.row];
    __weak TBListController *me = self;
    __weak TBCardView *card = cell.card;
    cell.card.onAdvance = ^{
        a.counter++;
        [[TBStore shared] save];
        [card tick:[TBStore now]];
        [me copyCodeOf:a];
    };
    return cell;
}

- (void)copyCodeOf:(TBAccount *)a {
    NSString *code = [a codeAtTime:[TBStore now]];
    [UIPasteboard generalPasteboard].string = code;
    TBToast(self.view, @"Code copied", YES);
}

- (void)tableView:(UITableView *)t didSelectRowAtIndexPath:(NSIndexPath *)ip {
    [t deselectRowAtIndexPath:ip animated:NO];
    TBAccount *a = [[TBStore shared].accounts objectAtIndex:ip.row];
    if (t.editing) {
        TBFormController *f = [[TBFormController alloc] initWithAccount:a index:ip.row];
        [self presentViewController:f animated:YES completion:nil];
        return;
    }
    if ([self coveredAt:ip.row]) {
        [_revealed setObject:[NSNumber numberWithDouble:[TBStore now] + 15] forKey:[NSNumber numberWithInteger:ip.row]];
        [(TBAccountCell *)[t cellForRowAtIndexPath:ip] card].covered = NO;
        return;
    }
    if (!a.counterBased) [self copyCodeOf:a];
    else TBToast(self.view, @"Press the knob for the next code", YES);
}

- (BOOL)tableView:(UITableView *)t canEditRowAtIndexPath:(NSIndexPath *)ip { return YES; }
- (BOOL)tableView:(UITableView *)t canMoveRowAtIndexPath:(NSIndexPath *)ip { return YES; }
- (UITableViewCellEditingStyle)tableView:(UITableView *)t editingStyleForRowAtIndexPath:(NSIndexPath *)ip { return t.editing ? UITableViewCellEditingStyleDelete : UITableViewCellEditingStyleNone; }
- (BOOL)tableView:(UITableView *)t shouldIndentWhileEditingRowAtIndexPath:(NSIndexPath *)ip { return YES; }

- (void)tableView:(UITableView *)t moveRowAtIndexPath:(NSIndexPath *)from toIndexPath:(NSIndexPath *)to {
    [[TBStore shared] moveAccountFromIndex:from.row toIndex:to.row];
    [_revealed removeAllObjects];
}

- (void)tableView:(UITableView *)t commitEditingStyle:(UITableViewCellEditingStyle)style forRowAtIndexPath:(NSIndexPath *)ip {
    if (style != UITableViewCellEditingStyleDelete) return;
    /* the red minus plus its Delete button already is a two-step confirmation */
    [[TBStore shared] removeAccountAtIndex:ip.row];
    [_revealed removeAllObjects];
    [t deleteRowsAtIndexPaths:@[ip] withRowAnimation:UITableViewRowAnimationLeft];
    if (![TBStore shared].accounts.count) [self performSelector:@selector(refresh) withObject:nil afterDelay:0.35];
}

#pragma mark actions

- (void)scan:(id)s {
    TBScanController *sc = [[TBScanController alloc] init];
    [self presentViewController:sc animated:YES completion:nil];
}

- (void)add:(id)s {
    UIActionSheet *sh = [[UIActionSheet alloc] initWithTitle:@"Add an account" delegate:self cancelButtonTitle:nil destructiveButtonTitle:nil otherButtonTitles:@"Enter a key by hand", @"QR code from a photo", @"Paste from clipboard", nil];
    [sh addButtonWithTitle:@"Cancel"];
    sh.cancelButtonIndex = sh.numberOfButtons - 1;
    sh.actionSheetStyle = UIActionSheetStyleBlackOpaque;
    [sh showInView:self.view];
}

- (void)actionSheet:(UIActionSheet *)sh clickedButtonAtIndex:(NSInteger)i {
    if (i == sh.cancelButtonIndex) return;
    if (i == 0) [self presentViewController:[[TBFormController alloc] initWithAccount:nil index:-1] animated:YES completion:nil];
    else if (i == 1) { TBScanController *sc = [[TBScanController alloc] init]; sc.startWithPhoto = YES; [self presentViewController:sc animated:YES completion:nil]; }
    else [self pasteClipboard];
}

- (void)pasteClipboard {
    NSArray *list = [TBAccount accountsFromText:[UIPasteboard generalPasteboard].string];
    if (!list.count) { TBToast(self.view, @"No 2FA key on the clipboard", NO); return; }
    NSUInteger n = [[TBStore shared] addAccounts:list];
    TBToast(self.view, n ? [NSString stringWithFormat:@"Added %lu account%@", (unsigned long)n, n == 1 ? @"" : @"s"] : @"Already in your list", n > 0);
}

- (void)settings:(id)s { [self presentViewController:[[TBSettingsController alloc] init] animated:YES completion:nil]; }

- (void)lockNow { [(TBAppDelegate *)[UIApplication sharedApplication].delegate lock]; }

@end
