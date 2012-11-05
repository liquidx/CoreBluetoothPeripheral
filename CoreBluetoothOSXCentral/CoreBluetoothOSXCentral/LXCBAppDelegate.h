#import <Cocoa/Cocoa.h>

@interface LXCBAppDelegate : NSObject <NSApplicationDelegate>

@property (assign) IBOutlet NSWindow *window;
@property (assign) IBOutlet NSTextView *textView;
@property (assign) IBOutlet NSButton *button;

- (IBAction)buttonDidPress:(id)sender;

@end
