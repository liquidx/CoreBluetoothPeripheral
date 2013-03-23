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

  // Playing around with attempting to connect to a Fitbit One. While I
  // can scan it, odd things happen. For instance, there is a service UUID (1)
  // that it advertises, but when you connect to the peripheral, that service
  // UUID disappears and another set appears.
  NSArray *fitBitOneServiceUUIDs = @[
    [CBUUID UUIDWithString:@"ba5689a6-fabf-a2bd-0146-7d6ed16babad"], // (1) unavailable after scanning.
    [CBUUID UUIDWithString:@"adab6bd1-6e7d-4601-bda2-bffaa68956ba"], // (2) no characteristics
    [CBUUID UUIDWithString:@"180a"],  // (3) no characteristics.
  ];

  // CoreBluetoothiOSPeripheral service UUIDs.
  NSArray *coreBluetoothiOSPeripheralServiceUUIDs = @[[CBUUID UUIDWithString:@"7e57"]];

  self.central.serviceUUIDs = fitBitOneServiceUUIDs;
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
