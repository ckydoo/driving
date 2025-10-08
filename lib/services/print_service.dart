// lib/services/print_service.dart
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import '../controllers/settings_controller.dart';
import '../models/user.dart';
import '../models/course.dart';

class PrintService {
  static const platform = MethodChannel('com.codzlabzim.driving/printing');
  // Discover printers by specific type
  static Future<List<PrinterInfo>> discoverPrintersByType(String type) async {
    try {
      print('🔍 Discovering $type printers...');

      // Call the method that EXISTS in MainActivity.kt
      final List<dynamic> result =
          await platform.invokeMethod('discoverPrinters', {
        'type': type,
      });

      final printers = result.map((printer) {
        return PrinterInfo(
          name: printer['name'] as String,
          type: printer['type'] as String,
          description: printer['description'] as String? ?? '',
        );
      }).toList();

      print('✅ Found ${printers.length} $type printers');
      return printers;
    } catch (e) {
      print('❌ Error discovering $type printers: $e');
      return [];
    }
  }

  // Keep your existing discoverPrinters() method for backward compatibility
  static Future<List<PrinterInfo>> discoverAllPrinters() async {
    final allPrinters = <PrinterInfo>[];

    try {
      final bluetooth = await discoverPrintersByType('bluetooth');
      final usb = await discoverPrintersByType('usb');
      final network = await discoverPrintersByType('network');

      allPrinters.addAll(bluetooth);
      allPrinters.addAll(usb);
      allPrinters.addAll(network);
    } catch (e) {
      print('❌ Error discovering all printers: $e');
    }

    return allPrinters;
  }

  // Verify printer connection
  static Future<bool> verifyPrinter(String printerName) async {
    try {
      final result = await platform.invokeMethod('verifyPrinter', {
        'printerName': printerName,
      });
      return result == true;
    } catch (e) {
      print('❌ Error verifying printer: $e');
      return false;
    }
  }

  // Print Receipt after payment
  static Future<void> printReceipt({
    required String receiptNumber,
    required User student,
    required List<ReceiptItem> items,
    required double total,
    required String paymentMethod,
    String? notes,
  }) async {
    final settingsController = Get.find<SettingsController>();

    try {
      // Get number of copies
      final copies = settingsController.receiptCopiesValue;

      // Print the specified number of copies
      for (int i = 0; i < copies; i++) {
        await _printSingleReceipt(
          receiptNumber: receiptNumber,
          student: student,
          items: items,
          total: total,
          paymentMethod: paymentMethod,
          notes: notes,
          copyNumber: copies > 1 ? i + 1 : null,
          totalCopies: copies > 1 ? copies : null,
        );

        // Small delay between copies
        if (i < copies - 1) {
          await Future.delayed(Duration(milliseconds: 500));
        }
      }

      print(
          '✅ Receipt printed successfully (${copies} ${copies > 1 ? 'copies' : 'copy'})');
    } catch (e) {
      print('❌ Error printing receipt: $e');
      throw Exception('Failed to print receipt: $e');
    }
  }

  static Future<void> _printSingleReceipt({
    required String receiptNumber,
    required User student,
    required List<ReceiptItem> items,
    required double total,
    required String paymentMethod,
    String? notes,
    int? copyNumber,
    int? totalCopies,
  }) async {
    final settingsController = Get.find<SettingsController>();

    // Build receipt content
    final receiptContent = _buildReceiptContent(
      receiptNumber: receiptNumber,
      student: student,
      items: items,
      total: total,
      paymentMethod: paymentMethod,
      notes: notes,
      copyNumber: copyNumber,
      totalCopies: totalCopies,
    );

    try {
      // Send to native platform for printing
      await platform.invokeMethod('printReceipt', {
        'content': receiptContent,
        'printerName': settingsController.printerNameValue,
        'paperSize': settingsController.printerPaperSizeValue,
      });
    } catch (e) {
      // If native printing fails, try ESC/POS commands directly
      await _printWithEscPos(receiptContent);
    }
  }

  static String _buildReceiptContent({
    required String receiptNumber,
    required User student,
    required List<ReceiptItem> items,
    required double total,
    required String paymentMethod,
    String? notes,
    int? copyNumber,
    int? totalCopies,
  }) {
    final settingsController = Get.find<SettingsController>();
    final now = DateTime.now();
    final dateFormat = DateFormat('MM/dd/yyyy hh:mm a');

    // Get paper width (58mm = 32 chars, 80mm = 48 chars)
    final paperWidth =
        settingsController.printerPaperSizeValue == '58mm' ? 32 : 48;

    StringBuffer receipt = StringBuffer();

    // Header
    receipt.writeln(_center(settingsController.businessNameValue, paperWidth));
    receipt
        .writeln(_center(settingsController.businessAddressValue, paperWidth));
    receipt.writeln(_center(settingsController.businessCityValue, paperWidth));
    receipt.writeln(
        _center('Tel: ${settingsController.businessPhoneValue}', paperWidth));
    receipt.writeln(_divider(paperWidth));
    receipt.writeln();

    // Receipt Header Text
    if (settingsController.receiptHeaderValue.isNotEmpty) {
      receipt
          .writeln(_center(settingsController.receiptHeaderValue, paperWidth));
      receipt.writeln();
    }

    // Receipt Info
    receipt.writeln('Receipt #: $receiptNumber');
    receipt.writeln('Date: ${dateFormat.format(now)}');
    receipt.writeln('Student: ${student.fullName}');

    // Copy indication
    if (copyNumber != null && totalCopies != null) {
      receipt.writeln('Copy $copyNumber of $totalCopies');
    }

    receipt.writeln(_divider(paperWidth));
    receipt.writeln();

    // Items
    receipt.writeln(_leftRight('ITEM', 'AMOUNT', paperWidth));
    receipt.writeln(_divider(paperWidth));

    for (var item in items) {
      // Item name
      receipt.writeln(item.itemName);

      // Quantity and price
      final qtyPrice =
          '${item.quantity} x \$${item.unitPrice.toStringAsFixed(2)}';
      final itemTotal = '\$${item.totalPrice.toStringAsFixed(2)}';
      receipt.writeln(_leftRight(qtyPrice, itemTotal, paperWidth));
    }

    receipt.writeln(_divider(paperWidth));
    receipt.writeln();

    // Totals
    receipt.writeln(
        _leftRight('SUBTOTAL:', '\$${total.toStringAsFixed(2)}', paperWidth));
    receipt.writeln(_leftRight('TAX:', '\$0.00', paperWidth));
    receipt.writeln(_divider(paperWidth));
    receipt.writeln(_leftRight(
        'TOTAL:', '\$${total.toStringAsFixed(2)}', paperWidth,
        bold: true));
    receipt.writeln(_divider(paperWidth));
    receipt.writeln();

    // Payment Method
    receipt.writeln(_leftRight('Payment Method:', paymentMethod, paperWidth));
    receipt.writeln(_leftRight(
        'Amount Paid:', '\$${total.toStringAsFixed(2)}', paperWidth));
    receipt.writeln();

    // Notes
    if (notes?.isNotEmpty ?? false) {
      receipt.writeln(_divider(paperWidth));
      receipt.writeln('Notes: $notes');
      receipt.writeln();
    }

    // Footer
    receipt.writeln(_divider(paperWidth));
    if (settingsController.receiptFooterValue.isNotEmpty) {
      receipt
          .writeln(_center(settingsController.receiptFooterValue, paperWidth));
    }
    receipt.writeln(_center('DriveSync Pro', paperWidth));
    receipt.writeln(_center('+263784666891', paperWidth));
    receipt.writeln();
    receipt.writeln();
    receipt.writeln();

    return receipt.toString();
  }

  // Helper methods for formatting
  static String _center(String text, int width) {
    if (text.length >= width) return text.substring(0, width);
    final padding = (width - text.length) ~/ 2;
    return '${' ' * padding}$text';
  }

  static String _leftRight(String left, String right, int width,
      {bool bold = false}) {
    final totalLength = left.length + right.length;
    if (totalLength >= width) {
      return '$left$right'.substring(0, width);
    }
    final spaces = width - totalLength;
    return '$left${' ' * spaces}$right';
  }

  static String _divider(int width) {
    return '-' * width;
  }

  // ESC/POS printing fallback
  static Future<void> _printWithEscPos(String content) async {
    // This would require ESC/POS commands
    // For now, just print to console as fallback
    print('=== RECEIPT ===');
    print(content);
    print('===============');
  }

  // Test print
  static Future<void> printTestReceipt() async {
    final settingsController = Get.find<SettingsController>();

    final testStudent = User(
      fname: 'Test',
      lname: 'Student',
      email: 'test@example.com',
      password: 'password123',
      phone: '123-456-7890',
      gender: 'Male',
      address: '123 Test St',
      date_of_birth: DateTime.now(),
      role: 'student',
      status: 'active',
      idnumber: 'TEST123',
      created_at: DateTime.now(),
    );

    final testItems = [
      ReceiptItem(
        itemName: 'Driving Lesson Package',
        quantity: 10,
        unitPrice: 25.0,
        totalPrice: 250.0,
      ),
    ];

    await printReceipt(
      receiptNumber: 'TEST-${DateTime.now().millisecondsSinceEpoch}',
      student: testStudent,
      items: testItems,
      total: 250.0,
      paymentMethod: 'Cash',
      notes: 'This is a test receipt',
    );
  }
}

// Receipt Item Model
class ReceiptItem {
  final String itemName;
  final int quantity;
  final double unitPrice;
  final double totalPrice;

  ReceiptItem({
    required this.itemName,
    required this.quantity,
    required this.unitPrice,
    required this.totalPrice,
  });
}

// Printer Info Model
class PrinterInfo {
  final String name;
  final String type; // USB, Network, Bluetooth
  final String description;
  final String? address; // For network printers

  PrinterInfo({
    required this.name,
    required this.type,
    this.description = '',
    this.address,
  });

  factory PrinterInfo.fromMap(Map<String, dynamic> map) {
    return PrinterInfo(
      name: map['name'] ?? 'Unknown Printer',
      type: map['type'] ?? 'Unknown',
      description: map['description'] ?? '',
      address: map['address'],
    );
  }
}
