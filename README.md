CoreBluetooth Peripheral Example
================================

A demonstration of using CoreBluetooth (using Bluetoothe 4.0 LE) on the OSX and iOS.

On the OSX side, CoreBluetoothOSXCentral implements a CoreBluetooth Central implementation that scans for suitable Bluetooth 4.0 LE peripherals. Once it discovers one, it will try and connect and subscribe to a fixed service characterstic. Once it receives a notification from the Peripheral it subscribes to, it will immediately unsubscribe.

On the iOS side, CoreBluetootheiOSPeripheral implements a CoreBluetooth Peripheral implementation that advertises a fixed service characteristic. Once a Central (OSX) connects to the service and subscribes to notifications on the characteristic, it will send a "Hello" message to the subscriber.

Terminology
-----------

 * Bluetooth Central: This is the node that is trying to connect to a data source. Think of this as the _client_.
 * Bluetooth Peripheral: This is the node that is providing the primary data source. Think of this as the _server_.
 * Characteristic: A characteristic can be considered a variable.
 * Service: A group of characteristics live under a "Service".


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


Currently Uimplemented
-----------------------

To keep the implementation simple, this demonstration does not implement:

 * Static read/write characteristics.
 * Multiple characteristics.


Implementation Notes and Caveats
--------------------------------

To be filled in.

Other Resources
---------------

- <https://github.com/KhaosT/CBPeripheralManager-Demo>

The code only works for readValue and writeValue, but not seemingly for subscribe.

- <https://github.com/timburks/iOSHealthThermometer>
- <https://github.com/timburks/CBSample>

Sample Code:

- <http://lists.apple.com/archives/bluetooth-dev/2012/Sep/msg00084.html>


Sources of Discussion
~~~~~~~~~~~~~~~~~~~~~

- <https://devforums.apple.com/community/ios/core/cbt>
- <https://lists.apple.com/archives/bluetooth-dev/2012>
- <http://www.bluetooth.org/Technical/Specifications/adopted.htm>

Important Threads
~~~~~~~~~~~~~~~~~

Rebooting phone fixes not-notifying on subscribable properties.
- <https://devforums.apple.com/message/736002#736002>




