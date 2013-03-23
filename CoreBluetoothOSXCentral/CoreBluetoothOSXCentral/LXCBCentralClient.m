#import "LXCBCentralClient.h"

#ifndef LXCBLog
# define LXCBLog NSLog
#endif  // LXCBLog

static const NSTimeInterval kLXCBScanningTimeout = 10.0;
static const NSTimeInterval kLXCBConnectingTimeout = 10.0;
static const NSTimeInterval kLXCBRequestTimeout = 20.0;

#pragma mark -

@interface LXCBCentralClient () <CBCentralManagerDelegate, CBPeripheralDelegate>

@property(nonatomic, strong) CBCentralManager *manager;

// Session information
@property(nonatomic, strong) CBPeripheral *connectedPeripheral;
@property(nonatomic, strong) CBService *connectedService;

// Flags to turn on while waiting for CBCentralManager to get ready.
@property(nonatomic, assign) BOOL subscribeWhenCharacteristicsFound;
@property(nonatomic, assign) BOOL connectWhenReady;

@end

@implementation LXCBCentralClient

+ (NSError *)errorWithDescription:(NSString *)description {
  static NSString * const kLXCBCentralClientErrorDomain = @"net.liquidx.LXCBCentralClient";
  NSDictionary *userInfo = @{NSLocalizedDescriptionKey : description};
  return [NSError errorWithDomain:kLXCBCentralClientErrorDomain
                             code:-1
                         userInfo:userInfo];
}

- (id)init {
  return [self initWithDelegate:nil];
}

- (id)initWithDelegate:(id<LXCBCentralClientDelegate>)delegate {
  self = [super init];
  if (self) {
    self.delegate = delegate;
    self.manager = [[CBCentralManager alloc] initWithDelegate:self
                                                        queue:dispatch_get_current_queue()];
  }
  return self;
}


#pragma mark - Public Methods

- (void)scanForPeripherals {
  if (self.manager.state != CBCentralManagerStatePoweredOn) {
    // Defer scanning until manager comes online.
    self.connectWhenReady = YES;
    return;
  }

  LXCBLog(@"Scanning ...");
  [self startScanningTimeoutMonitor];

  // By turning on allow duplicates, it allows us to scan more reliably, but
  // if it finds a peripheral that does not have the services we like or
  // recognize, we'll continually see it again and again in the didDiscover
  // callback.
  NSDictionary *scanningOptions =
      @{ CBCentralManagerScanOptionAllowDuplicatesKey : @YES };

  // We could pass in the set of serviceUUIDs when scanning like Apple
  // recommends, but if the application we're scanning for is in the background
  // on the iOS device, then it occassionally will not see any services.
  //
  // So instead, we do the opposite of what Apple recommends and scan
  // with no service UUID restrictions.
  [self.manager scanForPeripheralsWithServices:nil
                                       options:scanningOptions];
  self.connectWhenReady = NO;
  self.subscribeWhenCharacteristicsFound = NO;
}

- (void)cancelScanForPeripherals {
  [self.manager stopScan];
}

// Does all the necessary things to find the device and make a connection.
- (void)connect {
  NSAssert(self.serviceUUIDs.count > 0, @"Need to specify services");
  NSAssert(self.characteristicUUIDs.count > 0, @"Need to specify characteristics UUID");

  // Check if there is a Bluetooth LE subsystem turned on.
  if (self.manager.state != CBCentralManagerStatePoweredOn) {
    self.connectWhenReady = YES;
    return;
  }

  if (!self.connectedPeripheral) {
    self.connectWhenReady = YES;
    [self scanForPeripherals];
    return;
  }

  if (!self.connectedService) {
    self.connectWhenReady = YES;
    [self discoverServices:self.connectedPeripheral];
    return;
  }
}

- (void)disconnect {
  [self cancelScanForPeripherals];
  [self.manager cancelPeripheralConnection:self.connectedPeripheral];
  self.connectedPeripheral = nil;
}

// Once connected, subscribes to all the charactersitics that are subscribe-able.
- (void)subscribe {
  if (!self.connectedService) {
    NSLog(@"No connected services for peripheralat all. Unable to subscribe");
    return;
  }

  if (self.connectedService.characteristics.count < 1) {
    self.subscribeWhenCharacteristicsFound = YES;
    [self discoverServiceCharacteristics:self.connectedService];
    return;
  }

  self.subscribeWhenCharacteristicsFound = NO;
  for (CBCharacteristic *characteristic in self.connectedService.characteristics) {
    if (characteristic.properties & CBCharacteristicPropertyNotify) {
      [self.connectedPeripheral setNotifyValue:YES
                             forCharacteristic:characteristic];
    }
  }
  [self.delegate centralClientDidSubscribe:self];
}

- (void)unsubscribe {
  if (!self.connectedService) return;
  
  for (CBCharacteristic *characteristic in self.connectedService.characteristics) {
    if (characteristic.properties & CBCharacteristicPropertyNotify) {
      [self.connectedPeripheral setNotifyValue:NO
                             forCharacteristic:characteristic];
    }
  }
  [self.delegate centralClientDidUnsubscribe:self];
}


#pragma mark - Service/Characteristic Methods.

- (void)discoverServices:(CBPeripheral *)peripheral {
  [peripheral setDelegate:self];

  // By specifying the actual services we want to connect to, this will
  // work for iOS apps that are in the background.
  //
  // If you specify nil in the list of services and the application is in the
  // background, it may sometimes only discover the Generic Access Profile
  // and the Generic Attribute Profile services.
  //[peripheral discoverServices:nil];

  [peripheral discoverServices:self.serviceUUIDs];
}

- (void)discoverServiceCharacteristics:(CBService *)service {
  [self.connectedPeripheral discoverCharacteristics:self.characteristicUUIDs
                                         forService:service];
}

#pragma mark - Connection Timeout

- (void)startScanningTimeoutMonitor {
  [self cancelScanningTimeoutMonitor];
  [self performSelector:@selector(scanningDidTimeout)
             withObject:nil
             afterDelay:kLXCBScanningTimeout];
}

- (void)cancelScanningTimeoutMonitor {
  [NSObject cancelPreviousPerformRequestsWithTarget:self
                                           selector:@selector(scanningDidTimeout)
                                             object:nil];
}

- (void)scanningDidTimeout {
  LXCBLog(@"Scanning did timeout");
  NSError *error = [[self class] errorWithDescription:@"Unable to find a BTLE device."];

  [self.delegate centralClient:self connectDidFail:error];
  [self cancelScanForPeripherals];
}

#pragma mark -

- (void)startConnectionTimeoutMonitor:(CBPeripheral *)peripheral {
  [self cancelConnectionTimeoutMonitor:peripheral];
  [self performSelector:@selector(connectionDidTimeout:)
             withObject:peripheral
             afterDelay:kLXCBConnectingTimeout];
}

- (void)cancelConnectionTimeoutMonitor:(CBPeripheral *)peripheral {
  [NSObject cancelPreviousPerformRequestsWithTarget:self
                                           selector:@selector(connectionDidTimeout:)
                                             object:peripheral];
}

- (void)connectionDidTimeout:(CBPeripheral *)peripheral {
  LXCBLog(@"connectionDidTimeout: %@", peripheral.UUID);
  NSError *error = [[self class] errorWithDescription:@"Unable to connect to BTLE device."];
  [self.delegate centralClient:self connectDidFail:error];
  [self.manager cancelPeripheralConnection:peripheral];
}

#pragma mark -

- (void)startRequestTimeout:(CBCharacteristic *)characteristic {
  [self cancelRequestTimeoutMonitor:characteristic];
  [self performSelector:@selector(requestDidTimeout:)
             withObject:characteristic
             afterDelay:kLXCBRequestTimeout];
}

- (void)cancelRequestTimeoutMonitor:(CBCharacteristic *)characteristic {
  [NSObject cancelPreviousPerformRequestsWithTarget:self
                                           selector:@selector(requestDidTimeout:)
                                             object:characteristic];
}

- (void)requestDidTimeout:(CBCharacteristic *)characteristic {
  LXCBLog(@"requestDidTimeout: %@", characteristic);
  NSError *error = [[self class] errorWithDescription:@"Unable to request data from BTLE device."];

  [self.delegate centralClient:self
       requestForCharacteristic:characteristic
                       didFail:error];
  [self.connectedPeripheral setNotifyValue:NO
                         forCharacteristic:characteristic];
}


#pragma mark - CBCentralManagerDelegate

- (void)centralManagerDidUpdateState:(CBCentralManager *)central {
  switch (central.state) {
    case CBCentralManagerStatePoweredOn:
      if (self.subscribeWhenCharacteristicsFound) {
        if (self.connectedService) {
          [self subscribe];
          return;
        }
      }
      
      if (self.connectWhenReady) {
        [self connect];
        return;
      }
      break;
    default:
      LXCBLog(@"centralManager did update: %ld", central.state);
      break;
  }
}

- (void)centralManager:(CBCentralManager *)central
 didDiscoverPeripheral:(CBPeripheral *)peripheral
     advertisementData:(NSDictionary *)advertisementData
                  RSSI:(NSNumber *)RSSI {

  CBUUID *peripheralUUID = [CBUUID UUIDWithCFUUID:peripheral.UUID];
  LXCBLog(@"didDiscoverPeripheral: Peripheral CFUUID: %@", peripheral.UUID);
  LXCBLog(@"didDiscoverPeripheral: Peripheral CBUUID: %@", peripheralUUID);
  LXCBLog(@"didDiscoverPeripheral: Name: %@", peripheral.name);
  LXCBLog(@"didDiscoverPeripheral: Advertisment Data: %@", advertisementData);
  LXCBLog(@"didDiscoverPeripheral: RSSI: %@", RSSI);

  BOOL foundSuitablePeripheral = NO;


  // Figure out whether this device has the right service.
  if (!foundSuitablePeripheral) {
    NSArray *serviceUUIDs =
        [advertisementData objectForKey:CBAdvertisementDataServiceUUIDsKey];
    for (CBUUID *foundServiceUUIDs in serviceUUIDs) {
      if ([self.serviceUUIDs containsObject:foundServiceUUIDs]) {
        foundSuitablePeripheral = YES;
        break;
      }
    }
  }

  // When the iOS app is in background, the advertisments sometimes does not
  // contain the service UUIDs you advertise(!). So we fallback to just
  // check whether the name of the device is the correct one.
  if (!foundSuitablePeripheral) {
    NSString *peripheralName =
        [advertisementData objectForKey:CBAdvertisementDataLocalNameKey];
    foundSuitablePeripheral = [self.serviceName isEqualToString:peripheralName];
  }

  // At this point, if we still haven't found one, chances are the
  // iOS app has been killed in the background and the service is not
  // responding any more.
  //
  // There isn't much you can do at this point since connecting the the
  // peripheral won't really do anything if you can't spot the service.
  //
  // TODO: check what alternatives there are, maybe opening up bluetooth-central
  //       as a UIBackgroundModes will work.


  // If we found something to connect to, start connecting to it.
  // TODO: This does not deal with multiple devices advertising the same service
  //       yet.
  if (foundSuitablePeripheral) {
    [self cancelScanningTimeoutMonitor];
    [self.manager stopScan];
    LXCBLog(@"Connecting ... %@", peripheralUUID);
    [self.manager connectPeripheral:peripheral options:nil];

    // !!! NOTE: If you don't retain the CBPeripheral during the connection,
    //           this request will silently fail. The below method
    //           will retain peripheral for timeout purposes.
    [self startConnectionTimeoutMonitor:peripheral];
  }
}

- (void)centralManager:(CBCentralManager *)central
  didConnectPeripheral:(CBPeripheral *)peripheral {
  LXCBLog(@"didConnect: %@", peripheral.name);
  [self cancelConnectionTimeoutMonitor:peripheral];
  self.connectedPeripheral = peripheral;
  [self discoverServices:peripheral];
}

- (void)centralManager:(CBCentralManager *)central
didFailToConnectPeripheral:(CBPeripheral *)peripheral
                 error:(NSError *)error {
  LXCBLog(@"failedToConnect: %@", peripheral);
  [self cancelConnectionTimeoutMonitor:peripheral];
  [self.delegate centralClient:self connectDidFail:error];
}

- (void)centralManager:(CBCentralManager *)central
didDisconnectPeripheral:(CBPeripheral *)peripheral
                 error:(NSError *)error {
  self.connectedPeripheral = nil;
  self.connectedService = nil;
  LXCBLog(@"peripheralDidDisconnect: %@", peripheral);
  [self.delegate centralClientDidDisconnect:self];
}

#pragma mark - CBPeripheralDelegate

- (void)peripheral:(CBPeripheral *)peripheral
        didDiscoverServices:(NSError *)error {
  if (error) {
    [self.delegate centralClient:self connectDidFail:error];
    LXCBLog(@"didDiscoverServices: Error: %@", error);
    // TODO: Need to deal with resetting the state at this point.
    return;
  }

  LXCBLog(@"didDiscoverServices: %@ (Services Count: %ld)",
          peripheral.name, peripheral.services.count);

  for (CBService *service in peripheral.services) {
    LXCBLog(@"didDiscoverServices: Service: %@", service.UUID);

    // Still iterate through all the services for logging purposes, but if
    // we found one, don't bother doing anything more.
    if (self.connectedService) continue;

    if ([self.serviceUUIDs containsObject:service.UUID]) {
      self.connectedService = service;
    }
  }
  [self.delegate centralClientDidConnect:self];
}

- (void)peripheral:(CBPeripheral *)peripheral
        didDiscoverCharacteristicsForService:(CBService *)service
             error:(NSError *)error {
  if (error) {
    [self.delegate centralClient:self connectDidFail:error];
    LXCBLog(@"didDiscoverChar: Error: %@", error);
    return;
  }

  // For logging, just print out all the discovered services.
  LXCBLog(@"didDiscoverChar: Found %ld characteristic(s)", service.characteristics.count);
  for (CBCharacteristic *characteristic in service.characteristics) {
    LXCBLog(@"didDiscoverChar:  Characteristic: %@", characteristic.UUID);
  }

  // If we did discover characteristics, these will get remembered in the
  // CBService instance, so there's no need to do anything more here
  // apart from remembering the service, in case it changed.
  self.connectedService = service;

  if (service.characteristics.count < 1) {
    NSLog(@"didDiscoverChar: did not discover any characterestics for service. aborting.");
    [self disconnect];
    return;
  }

  if (self.subscribeWhenCharacteristicsFound) {
    [self subscribe];
  }
}

- (void)peripheral:(CBPeripheral *)peripheral
        didUpdateValueForCharacteristic:(CBCharacteristic *)characteristic
             error:(NSError *)error {
  [self cancelRequestTimeoutMonitor:characteristic];

  if (error) {
    LXCBLog(@"didUpdateValueError: %@", error);
    [self.delegate centralClient:self requestForCharacteristic:characteristic didFail:error];
    return;
  }

  LXCBLog(@"didUpdateValueForChar: Value: %@", characteristic.value);
  [self.delegate centralClient:self
                characteristic:characteristic
                didUpdateValue:characteristic.value];
}

@end