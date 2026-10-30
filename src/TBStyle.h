#import <UIKit/UIKit.h>

/* Drawing helpers for the vault look: oxblood leather, brushed steel plates, brass, dymo label tape, seven-segment amber LCD.
   Everything is drawn in code, no image assets besides the app icon. */

UIColor *TBRGB(int r, int g, int b);
UIFont *TBFont(NSString *name, CGFloat size);

#define TB_BRASS TBRGB(214, 170, 82)
#define TB_BRASS_DK TBRGB(122, 86, 28)
#define TB_AMBER TBRGB(255, 176, 38)
#define TB_ENGRAVE TBRGB(58, 62, 70)
#define TB_CREAM TBRGB(244, 236, 214)

UIImage *TBLeatherImage(void);
void TBFillGradient(CGContextRef c, CGRect r, UIColor *top, UIColor *bottom);
void TBRoundRectPath(CGContextRef c, CGRect r, CGFloat radius);
void TBBrushedSteel(CGContextRef c, CGRect r, BOOL dark);        /* fills the rect with brushed metal */
void TBPlate(CGContextRef c, CGRect r, CGFloat radius);           /* raised steel plate with bevel and drop shadow */
void TBScrew(CGContextRef c, CGPoint p, CGFloat radius, CGFloat angle);
void TBDymo(CGContextRef c, CGRect r, NSString *text);            /* embossed label tape */
void TBLCDPanel(CGContextRef c, CGRect r);                        /* recessed black glass with bezel */
void TBDrawSegments(CGContextRef c, CGRect r, NSString *digits, UIColor *lit, BOOL ghost);   /* digits and spaces; ghost draws the unlit segments */
void TBDrawText(NSString *s, CGRect r, UIFont *font, UIColor *color, UIColor *shadow, CGFloat shadowDY, NSTextAlignment align);
void TBGlassButton(CGContextRef c, CGRect r, CGFloat radius, int tone, BOOL pressed);   /* tone 0 steel, 1 brass, 2 red */
void TBBarBackground(CGContextRef c, CGRect r);                   /* header: brushed steel, dark underside */
void TBFooterBackground(CGContextRef c, CGRect r);                /* footer: leather with a steel edge */
void TBDrawIcon(CGContextRef c, int kind, CGRect r, UIColor *color);  /* 0 scan, 1 add, 2 settings, 3 lock, 4 image, 5 clipboard, 6 key */
UIImage *TBPadlockImage(CGFloat size);                            /* the app's padlock, drawn live (lock screen, empty state) */
