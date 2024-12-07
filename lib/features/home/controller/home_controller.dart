import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_libserialport/flutter_libserialport.dart';
import 'package:get/get.dart';

class HomeController extends GetxController {
  var availPort = <String>[].obs;
  RxString selectedPort = 'no port available'.obs;
  //serial communication
  RxString serialData = "00.00".obs;
  String _buffer = '';
  SerialPort? _port;
  late SerialPortReader _reader;
  late StreamSubscription<Uint8List> _dataSubscription;
  final _baudrate = 9600;

  @override
  void onInit() {
    super.onInit();
    _getAvailablePorts();
  }

  void _getAvailablePorts() {
    availPort.value = SerialPort.availablePorts;
    if (availPort.isNotEmpty) {
      selectedPort.value = availPort.first;
    }
  }

  void setSelectedPort(String port) {
    selectedPort.value = port;
  }

  Future<void> initializeSerialPort({required String portName}) async {
    _port ??= SerialPort(portName);
    final config = SerialPortConfig();
    config.baudRate = _baudrate;
    config.parity = 0;
    config.bits = 8;
    config.stopBits = 1;
    config.dtr = 1;
    config.rts = 1;
    _port!.config = config;
  }

  Future<void> readSerialData({required String portName}) async {
    await initializeSerialPort(portName: portName);

    _reader = SerialPortReader(_port!, timeout: 20000);

    Stream<Uint8List> upcomingData = _reader.stream;

    try {
      if (_port!.isOpen) {
        _port!.close();
      }
      _port!.openReadWrite();

      var config = _port!.config;
      config.baudRate = _baudrate;
      _port!.config = config;


      Get.dialog(
        AlertDialog(
          backgroundColor: Colors.blueGrey[900], // Background color
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20), // Rounded corners
          ),
          title: Text(
            'Connection Successful',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Text(
            'Successfully connected to the port.',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 16,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Get.back(),  // Close the dialog
              child: Text(
                'OK',
                style: TextStyle(
                  color: Colors.blueAccent, // Customize the button text color
                  fontSize: 16,
                ),
              ),
            ),
          ],
        ),
        barrierDismissible: false, // Prevent closing by tapping outside
      );


      _dataSubscription = upcomingData.listen((data) {
        _buffer += String.fromCharCodes(data);

        int newlineIndex = _buffer.indexOf('\n');
        if (newlineIndex != -1) {
          String completeMessage =
              _buffer.toString().substring(0, newlineIndex).trim();

          completeMessage = completeMessage
              .replaceAll("\\r", "")
              .replaceAll("\\n", "")
              .replaceAll("'", "")
              .replaceAll("b", "")
              .replaceAll(",", " ")
              .replaceAll("+", "")
              .replaceAll("Kg", "")
              .replaceAll("kg", "");

          if (kDebugMode) {
            print(completeMessage);
          }
          updateSerialData(completeMessage);
          _buffer = _buffer.substring(newlineIndex + 1);
        }
      });
    } on SerialPortError catch (err, _) {
      if (kDebugMode) {
        print('SerialPortError: $err');
      }
      Get.dialog(
        AlertDialog(
          backgroundColor: Colors.red[900], // Background color for failure
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20), // Rounded corners
          ),
          title: Text(
            'Connection Failed',
            style: TextStyle(
              color: Colors.white, // Title text color
              fontSize: 20,         // Title font size
              fontWeight: FontWeight.bold, // Title font weight
            ),
          ),
          content: Text(
            'Failed to connect to the port: $err',
            style: TextStyle(
              color: Colors.white70, // Content text color
              fontSize: 16,          // Content font size
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Get.back(), // Close the dialog
              child: Text(
                'OK',
                style: TextStyle(
                  color: Colors.redAccent, // Button text color
                  fontSize: 16,             // Button font size
                ),
              ),
            ),
          ],
        ),
        barrierDismissible: false, // Prevent closing by tapping outside
      );


      _port!.close();
      initializeSerialPort(portName: portName);
    }
  }

  /// Updates the serial data value and triggers a UI update.
  void updateSerialData(String data) {
    serialData.value = data;
    update();
  }

  /// Stops reading the serial data and closes the serial port.
  void stopReading() {
    _dataSubscription.cancel();
    _port?.close();
    updateSerialData('00.00');
  }

  @override
  void onClose() {
    stopReading();
    super.onClose();
  }
}
