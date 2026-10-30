#import <UIKit/UIKit.h>
#import "TBStyle.h"

/* steel / brass push button; either a title or an icon (TBDrawIcon kind) */
@interface TBButton : UIControl
@property (nonatomic, copy) NSString *title;
@property (nonatomic) int iconKind;         /* -1 none */
@property (nonatomic) int tone;             /* 0 steel, 1 brass, 2 red */
@property (nonatomic) BOOL flat;            /* footer style: no plate, glowing glyph */
@property (nonatomic) BOOL round;           /* keypad key: circular, large digit */
- (id)initWithTitle:(NSString *)t tone:(int)tone;
- (id)initWithIcon:(int)kind title:(NSString *)t flat:(BOOL)flat;
@end

/* glossy segmented switch */
@interface TBSegmented : UIControl
@property (nonatomic) NSInteger selectedIndex;
- (id)initWithItems:(NSArray *)items;
@end

/* Base for every screen: steel header with title and two button slots over leather. Subclasses add views to `content`. */
@interface TBScreen : UIViewController
@property (nonatomic, readonly) UIView *content;
@property (nonatomic, strong) TBButton *leftButton;
@property (nonatomic, strong) TBButton *rightButton;
- (void)setScreenTitle:(NSString *)t;
- (void)dismissScreen;
@end

void TBToast(UIView *host, NSString *text, BOOL good);
