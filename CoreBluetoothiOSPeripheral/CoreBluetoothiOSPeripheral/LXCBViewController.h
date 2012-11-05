#import <UIKit/UIKit.h>

@interface LXCBViewController : UIViewController

@property (strong) UILabel *label;

- (void)centralDidConnect;
- (void)centralDidDisconnect;

@end
