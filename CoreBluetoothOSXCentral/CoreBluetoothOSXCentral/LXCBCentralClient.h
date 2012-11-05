#import <Foundation/Foundation.h>
#import <IOBluetooth/IOBluetooth.h>

@protocol LXCBCentralClientDelegate;

@interface LXCBCentralClient : NSObject

// Specify here which services you want to connect to and characteristics
// you want to read from.
@property (nonatomic, strong) NSString *serviceName;
@property (nonatomic, strong) NSArray *serviceUUIDs;  // CBUUIDs
@property (nonatomic, strong) NSArray *characteristicUUIDs;  // CBUUIDs

@property (nonatomic, weak) id<LXCBCentralClientDelegate> delegate;

- (id)initWithDelegate:(id<LXCBCentralClientDelegate>)delegate;

// Tries to scan and connect to any peripheral.
- (void)connect;

// Disconnects all connected services and peripherals.
- (void)disconnect;

// Subscribe to characteristics defined in characteristicUUIDs.
- (void)subscribe;

// Unsubscribe from characteristics defined in characteriticUUIDs
- (void)unsubscribe;

@end

@protocol LXCBCentralClientDelegate <NSObject>

- (void)centralClient:(LXCBCentralClient *)central
       connectDidFail:(NSError *)error;

- (void)centralClient:(LXCBCentralClient *)central
        requestForCharacteristic:(CBCharacteristic *)characteristic
              didFail:(NSError *)error;

- (void)centralClientDidConnect:(LXCBCentralClient *)central;
- (void)centralClientDidDisconnect:(LXCBCentralClient *)central;

- (void)centralClientDidSubscribe:(LXCBCentralClient *)central;
- (void)centralClientDidUnsubscribe:(LXCBCentralClient *)central;

- (void)centralClient:(LXCBCentralClient *)central
       characteristic:(CBCharacteristic *)characteristic
       didUpdateValue:(NSData *)value;

@end
