CoreBluetooth Peripheral Example
================================

- Author: <a href="http://liquidx.net/">Alastair Tse</a> (<a href="http://twitter.com/liquidx/">@liquidx</a>)
- Updated: *4 November 2012*

A demonstration of using CoreBluetooth (using Bluetoothe 4.0 LE) on the OSX and iOS.

On the OSX side, CoreBluetoothOSXCentral implements the client as a CoreBluetooth Central that scans for suitable Bluetooth 4.0 LE peripherals. Once it discovers one, it will try and connect and subscribe to a fixed service characterstic. Once it receives a notification from the Peripheral it subscribes to, it will immediately unsubscribe.

On the iOS side, CoreBluetootheiOSPeripheral implements the server as a CoreBluetooth Peripheral that advertises a fixed service characteristic. Once a Central (OSX) connects to the service and subscribes to notifications on the characteristic, it will send a "Hello" message to the subscriber.

Basic Bluetooth 4.0 Terminology
-------------------------------

 * **Bluetooth Central**: This is the node that is trying to connect to a data source. Think of this as the *client*.
 * **Bluetooth Peripheral**: This is the node that is providing the primary data source. Think of this as the *server*.
 * **Characteristic**: A characteristic can be considered a variable.
 * **Service**: A group of characteristics live under a "Service".


Implemented
-----------

 * Central
   * Scanning for peripherals
   * Connecting to a peripheral
   * Disconnecting from a peripheral
   * Discovering services
   * Discovering characteristics of a service
   * Subscribing to a characteristic
   * Receiving data from a characteristic

 * Peripheral
   * Advertising a service and characteristic
   * Adding service and characteristic to the PeripheralManager
   * Detecting of new subscribers to a characteristics
   * Detecting of unsubscribing
   * Handling of unready state of the device.


Currently Unimplemented
-----------------------

To keep the implementation simple, this demonstration does not implement:

 * Static read/write characteristics.
 * Multiple characteristics.


Implementation Notes and Caveats
--------------------------------

### UIBackgroundModes ###

According to Apple, if you add `bluetooth-central` or `bluetooth-peripheral` to `UIBackgroundModes` in the `Info.plist`, the application will continue to run in the background and receive `CBCentralManagerDelegate` and/or `CBPeripheralManagerDelegate` events.

I've not fully discovered the behaviour here, but I've advertised services disappear from the advertisments even though the application is still running in the background. Some times they exist with no hassles at all, sometimes the services are dropped by the service name still exists. Sometimes everything is dropped, even the generic services.

It's quite mysterious when it is working and when it is not.


*More investigation needed.*

### Peripheral Mode on OSX ###

As of OSX 10.8, the CoreBluetooth APIs only allow you to have your Mac act as a Central. On iOS 6.0, the iOS device can act as either a Peripheral or a Central.

### Service UUIDs ###

If an iOS device is implementing a *peripheral*, consider using UUIDs that are only 4 characters short (2-bytes). 

        CBUUID *serviceUUID = [CBUUID UUIDWithString:@"1234"];


The advertisement packet sent is max 28-bytes (or 38 bytes including the name). If your UUIDs exceed that, then the service will not be discoverable if `CBCentralManager` scans with no specific service UUIDs:

        [managed scanForPeripheralsWithServices:nil ...];

See `CBPeripheralManager.h` for details.

### Overflow in Advertisments (iOS only) ###

If you are implementing the CBCentralManager on iOS, you can also look in the overflow advertisment data field (`CBAdvertisementDataOverflowServiceUUIDsKey`) in the `advertismentData` dictionary.

        - (void)centralManager:(CBCentralManager *)central
                didDiscoverPeripheral:(CBPeripheral *)peripheral
                advertisementData:(NSDictionary *)advertisementData
                RSSI:(NSNumber *)RSSI {
          NSArray *overflowServiceUUIDs = [advertismentData objectForKey:
              CBAdvertisementDataOverflowServiceUUIDsKey];
          ...
        }

### Scanning for Services ###

When scanning for peripherals from CBCentralManager, when you receive a `centralManager:didDiscoverPeripheral:advertismentData:RSSI:` message, you should look in the `advertismentData` dictionary for the `CBAdvertisementDataServiceUUIDsKey` for the advertised services rather than in the `peripheral.services` property.

The `peripheral.services` property will not be filled in until you call `[CBCentralManager discoverServices:]`.


        - (void)centralManager:(CBCentralManager *)central
                didDiscoverPeripheral:(CBPeripheral *)peripheral
                advertisementData:(NSDictionary *)advertisementData
                RSSI:(NSNumber *)RSSI {
          NSArray *serviceUUIDs = [advertismentData objectForKey:
              CBAdvertisementDataServiceUUIDsKey];
          for (CBUUID *foundServiceUUIDs in serviceUUIDs) {
            if ([self.serviceUUIDs containsObject:foundServiceUUIDs]) {
              foundSuitablePeripheral = YES;
              break;
          }
          ...
        }

### Calling [CBPeripheral discoverServices:] ###

Sometimes, if the iOS application acting as the peripheral is in the background, the services for it removed from the advertisment packet. In that case, if you call `[CBPeripheral discoverServices:]` with an array of services, it may not return any services.


### Endianness with UUIDs ###

If you use long UUIDs (eg, using `uuidgen`), then you will run in to endianess issues between iOS and the Mac. This is a bug in Xcode 4.5 and reportedly fixed in Xcode 4.5.1.

### No centralDidConnect: and centralDidDisconnect: messages ###

Despite that was said in the WWDC talk, the subsequent betas for iOS 6.0 will not call `centralDidConnect:` and `centralDidDisconnect:` on the `CBPeripheralManagerDelegate`.

### CBMutableCharacteristics.properties is a bitmask ###

You can have a characteristic that is both readable and notifiable. This example does not do this, but presumably you can set the property of using the bitmask:

      (CBCharacteristicPropertyRead | CBCharacteristicPropertyNotify)


### Bluetooth popups on background ###

See: <http://lists.apple.com/archives/bluetooth-dev/2012/Oct/msg00053.html>

### [CBCentralManager connectPeripheral:] silently fails ###

If you do not retain the `CBPeripheral` you get in the Central implementation, when you call connectPeripheral, it will silently fail. This is surprising because you'd think `connectPeripheral:` would retain the `CBPeripheral`. 

In the demo, you'll note that I retain the `CBPeripheral` for time out purposes, but if I didn't do that, `[CBCentralManager connectPeripheral:]` will silently fail.

### Device UUID changes if Bluetooth is enabled/disabled or device is rebooted ###

In the WWDC presentation, reconnecting to the device by UUID is mentiond. However, if the peripheral is an iPhone, the UUID changes if Bluetooth is turned on and off again on the device. The UUID stays consistent if the app is killed and restarted.

### Beware of adding and removing services while running ###

If you remove a service while a Central is connected to the Peripheral, like through a subscribed characteristic, then the Central does not get a disconnection. The peripheral will also lose track of the subscribers for a characteristic, even if the characteristic has the same UUID. That is, don't do this:

        [self.peripheralManager removeService:self.currentService];
        [self.peripheralManager addService:self.currentService];

I ran in to this when I would listen for didSubscribe and then prompt the user to bring the Peripheral implementation to the foreground. When I returned to the foreground, I had code that re-enabled the service that would check if `self.currentService` existed, and if so, removed the service and readded it again. That was not a good idea.


Other Resources
---------------

- <https://github.com/KhaosT/CBPeripheralManager-Demo>

The code only works for readValue and writeValue, but not seemingly for subscribe.

- <https://github.com/timburks/iOSHealthThermometer>
- <https://github.com/timburks/CBSample>

Sample Code:

- <http://lists.apple.com/archives/bluetooth-dev/2012/Sep/msg00084.html>

### Sources of Discussion ###


- <https://devforums.apple.com/community/ios/core/cbt>
- <https://lists.apple.com/archives/bluetooth-dev/2012>
- <http://www.bluetooth.org/Technical/Specifications/adopted.htm>

### Important Threads ###

Rebooting phone fixes not-notifying on subscribable properties.
- <https://devforums.apple.com/message/736002#736002>




