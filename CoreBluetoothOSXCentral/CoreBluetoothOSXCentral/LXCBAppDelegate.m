#import "LXCBAppDelegate.h"
#import "LXCBCentralClient.h"

@interface LXCBAppDelegate () <LXCBCentralClientDelegate>

@property (nonatomic, strong) LXCBCentralClient *central;

@end

@implementation LXCBAppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
  // Set up Bluetooth Central implementation
  self.central = [[LXCBCentralClient alloc] initWithDelegate:self];
  self.central.serviceName = @"Test";
  self.central.serviceUUIDs = @[
      [CBUUID UUIDWithString:@"7e57"]];
  self.central.characteristicUUIDs = @[
      [CBUUID UUIDWithString:@"b71e"]];

  // Set up some basic hooks in the interface.
  self.textView.font = [NSFont fontWithName:@"Monaco" size:12];
}

- (void)applicationWillTerminate:(NSNotification *)notification {
  [self.central disconnect];
}

- (void)appendLogMessage:(NSString *)message {
  self.textView.string = [self.textView.string stringByAppendingFormat:@"%@\n", message];
  [self.textView performSelector:@selector(scrollPageDown:) withObject:nil afterDelay:0];
}

- (IBAction)buttonDidPress:(id)sender {
  [self.central connect];
  [self.central subscribe];
}

#pragma mark - LXCBCentralClientDelegate

- (void)centralClientDidConnect:(LXCBCentralClient *)central {
  [self appendLogMessage:@"Connnected to Peripheral"];
  [self.central subscribe];
}

- (void)centralClientDidDisconnect:(LXCBCentralClient *)central {
  [self appendLogMessage:@"Disconnected to Peripheral"];
}

- (void)centralClientDidSubscribe:(LXCBCentralClient *)central {
  [self appendLogMessage:@"Subscribed to Characteristic"];
}

- (void)centralClientDidUnsubscribe:(LXCBCentralClient *)central {
  [self appendLogMessage:@"Unsubscribed to Characteristic"];
}


- (void)centralClient:(LXCBCentralClient *)central
       characteristic:(CBCharacteristic *)characteristic
       didUpdateValue:(NSData *)value {
  NSString *printable = [[NSString alloc] initWithData:value encoding:NSUTF8StringEncoding];
  NSLog(@"didUpdateValue: %@", printable);
  [self appendLogMessage:[NSString stringWithFormat:@" >> Received Data: %@", printable]];
  [self.central unsubscribe];
}

- (void)centralClient:(LXCBCentralClient *)central connectDidFail:(NSError *)error {
  NSLog(@"Error: %@", error);
  [self appendLogMessage:[error description]];
}

- (void)centralClient:(LXCBCentralClient *)central
requestForCharacteristic:(CBCharacteristic *)characteristic
              didFail:(NSError *)error {
  NSLog(@"Error: %@", error);
  [self appendLogMessage:[error description]];
}

@end
