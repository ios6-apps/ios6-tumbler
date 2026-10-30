#import <UIKit/UIKit.h>
#import "TBOTP.h"

/* One account as a brushed-steel plate: watch dial, label-tape issuer and an amber seven-segment display. */
@interface TBCardView : UIView
@property (nonatomic, strong) TBAccount *account;
@property (nonatomic) BOOL covered;
@property (nonatomic, copy) void (^onAdvance)(void);    /* HOTP knob pressed */
- (void)tick:(NSTimeInterval)now;
@end

@interface TBAccountCell : UITableViewCell
@property (nonatomic, readonly) TBCardView *card;
@end
