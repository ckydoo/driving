import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import '../controllers/settings_controller.dart';
import '../models/user.dart';
import '../models/course.dart';
import '../models/fleet.dart';

class PrintService {
  static const platform = MethodChannel('com.codzlabzim.driving/printing');
  static Future<bool> validatePrinterReady(String printerName) async {
    try {
      // Check if printer name is set
      if (printerName.isEmpty) {
        Get.snackbar(
          'No Printer Selected',
          'Please select a printer in Settings',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.orange,
          colorText: Colors.white,
          icon: Icon(Icons.print_disabled, color: Colors.white),
        );
        return false;
      }

      // Verify printer connection
      final isConnected = await verifyPrinter(printerName);
      if (!isConnected) {
        Get.snackbar(
          'Printer Not Connected',
          'Please ensure $printerName is powered on and paired',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.red,
          colorText: Colors.white,
          icon: Icon(Icons.bluetooth_disabled, color: Colors.white),
          duration: Duration(seconds: 4),
        );
        return false;
      }

      print('✅ Printer validation passed: $printerName');
      return true;
    } catch (e) {
      print('❌ Printer validation failed: $e');
      Get.snackbar(
        'Printer Error',
        'Unable to connect to printer: ${e.toString()}',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red,
        colorText: Colors.white,
        icon: Icon(Icons.error_outline, color: Colors.white),
      );
      return false;
    }
  }

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
      // ✅ ADD VALIDATION HERE - before attempting to print
      final printerName = settingsController.printerNameValue;
      final isReady = await validatePrinterReady(printerName);

      if (!isReady) {
        throw Exception('Printer not ready');
      }

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

  // Print Invoice with Balance (Invoice Only - Not Paid)
  static Future<void> printInvoice({
    required String invoiceNumber,
    required User student,
    required List<ReceiptItem> items,
    required double total,
    required double amountPaid,
    String? notes,
  }) async {
    final settingsController = Get.find<SettingsController>();

    try {
      // Validate printer
      final printerName = settingsController.printerNameValue;
      final isReady = await validatePrinterReady(printerName);

      if (!isReady) {
        throw Exception('Printer not ready');
      }

      // Get number of copies
      final copies = settingsController.receiptCopiesValue;

      // Print the specified number of copies
      for (int i = 0; i < copies; i++) {
        await _printSingleInvoice(
          invoiceNumber: invoiceNumber,
          student: student,
          items: items,
          total: total,
          amountPaid: amountPaid,
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
          '✅ Invoice printed successfully (${copies} ${copies > 1 ? 'copies' : 'copy'})');
    } catch (e) {
      print('❌ Error printing invoice: $e');
      throw Exception('Failed to print invoice: $e');
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
      await platform.invokeMethod('printReceipt', {
        'content': receiptContent,
        'printerName': settingsController.printerNameValue,
        'paperSize': settingsController.printerPaperSizeValue,
      });
    } catch (e) {
      print('❌ Native printing failed: $e');
      Get.snackbar(
        'Print Error',
        'Failed to print: ${e.toString()}',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
      rethrow;
    }
  }

  static Future<void> _printSingleInvoice({
    required String invoiceNumber,
    required User student,
    required List<ReceiptItem> items,
    required double total,
    required double amountPaid,
    String? notes,
    int? copyNumber,
    int? totalCopies,
  }) async {
    final settingsController = Get.find<SettingsController>();

    // Build invoice content
    final invoiceContent = _buildInvoiceContent(
      invoiceNumber: invoiceNumber,
      student: student,
      items: items,
      total: total,
      amountPaid: amountPaid,
      notes: notes,
      copyNumber: copyNumber,
      totalCopies: totalCopies,
    );

    try {
      await platform.invokeMethod('printReceipt', {
        'content': invoiceContent,
        'printerName': settingsController.printerNameValue,
        'paperSize': settingsController.printerPaperSizeValue,
      });
    } catch (e) {
      print('❌ Native printing failed: $e');
      Get.snackbar(
        'Print Error',
        'Failed to print invoice: ${e.toString()}',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
      rethrow;
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
    final paperWidth = settingsController.printerPaperSizeValue == '58mm'
        ? 32
        : settingsController.printerPaperSizeValue == '80mm'
            ? 48
            : 32;
    StringBuffer receipt = StringBuffer();

    // Header
    receipt.writeln(_center(settingsController.businessNameValue, paperWidth));
    receipt
        .writeln(_center(settingsController.businessAddressValue, paperWidth));
    receipt.writeln(_center(settingsController.businessCityValue, paperWidth));
    receipt.writeln(
        _center('Phone: ${settingsController.businessPhoneValue}', paperWidth));
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

  static String _buildInvoiceContent({
    required String invoiceNumber,
    required User student,
    required List<ReceiptItem> items,
    required double total,
    required double amountPaid,
    String? notes,
    int? copyNumber,
    int? totalCopies,
  }) {
    final settingsController = Get.find<SettingsController>();
    final now = DateTime.now();
    final dateFormat = DateFormat('MM/dd/yyyy hh:mm a');
    final balance = total - amountPaid;

    // Get paper width (58mm = 32 chars, 80mm = 48 chars)
    final paperWidth = settingsController.printerPaperSizeValue == '58mm'
        ? 32
        : settingsController.printerPaperSizeValue == '80mm'
            ? 48
            : 32;
    StringBuffer invoice = StringBuffer();

    // Header
    invoice.writeln(_center(settingsController.businessNameValue, paperWidth));
    invoice
        .writeln(_center(settingsController.businessAddressValue, paperWidth));
    invoice.writeln(_center(settingsController.businessCityValue, paperWidth));
    invoice.writeln(
        _center('Phone: ${settingsController.businessPhoneValue}', paperWidth));
    invoice.writeln(_divider(paperWidth));
    invoice.writeln();

    // Invoice Title
    invoice.writeln(_center('INVOICE', paperWidth));
    if (settingsController.receiptHeaderValue.isNotEmpty) {
      invoice
          .writeln(_center(settingsController.receiptHeaderValue, paperWidth));
    }
    invoice.writeln();

    // Invoice Info
    invoice.writeln('Invoice #: $invoiceNumber');
    invoice.writeln('Date: ${dateFormat.format(now)}');
    invoice.writeln('Student: ${student.fullName}');
    if (student.phone.isNotEmpty) {
      invoice.writeln('Phone: ${student.phone}');
    }

    // Copy indication
    if (copyNumber != null && totalCopies != null) {
      invoice.writeln('Copy $copyNumber of $totalCopies');
    }

    invoice.writeln(_divider(paperWidth));
    invoice.writeln();

    // Items
    invoice.writeln(_leftRight('ITEM', 'AMOUNT', paperWidth));
    invoice.writeln(_divider(paperWidth));

    for (var item in items) {
      // Item name
      invoice.writeln(item.itemName);

      // Quantity and price
      final qtyPrice =
          '${item.quantity} x \$${item.unitPrice.toStringAsFixed(2)}';
      final itemTotal = '\$${item.totalPrice.toStringAsFixed(2)}';
      invoice.writeln(_leftRight(qtyPrice, itemTotal, paperWidth));
    }

    invoice.writeln(_divider(paperWidth));
    invoice.writeln();

    // Totals
    invoice.writeln(
        _leftRight('SUBTOTAL:', '\$${total.toStringAsFixed(2)}', paperWidth));
    invoice.writeln(_leftRight('TAX:', '\$0.00', paperWidth));
    invoice.writeln(_divider(paperWidth));
    invoice.writeln(_leftRight(
        'TOTAL:', '\$${total.toStringAsFixed(2)}', paperWidth,
        bold: true));
    invoice.writeln();

    // Payment Information
    invoice.writeln(_leftRight(
        'Amount Paid:', '\$${amountPaid.toStringAsFixed(2)}', paperWidth));
    invoice.writeln(_divider(paperWidth));
    invoice.writeln(_leftRight(
        'BALANCE DUE:', '\$${balance.toStringAsFixed(2)}', paperWidth,
        bold: true));
    invoice.writeln(_divider(paperWidth));
    invoice.writeln();

    // Due Date (30 days from now)
    final dueDate = now.add(Duration(days: 30));
    invoice.writeln('Due Date: ${DateFormat('MM/dd/yyyy').format(dueDate)}');
    invoice.writeln();

    // Notes
    if (notes?.isNotEmpty ?? false) {
      invoice.writeln(_divider(paperWidth));
      invoice.writeln('Notes: $notes');
      invoice.writeln();
    }

    // Payment Instructions
    invoice.writeln(_divider(paperWidth));
    invoice.writeln(_center('PAYMENT DUE', paperWidth));
    invoice.writeln('Please make payment before due date');
    invoice.writeln();

    // Footer
    invoice.writeln(_divider(paperWidth));
    if (settingsController.receiptFooterValue.isNotEmpty) {
      invoice
          .writeln(_center(settingsController.receiptFooterValue, paperWidth));
    }
    invoice.writeln(_center('DriveSync Pro', paperWidth));
    invoice.writeln(_center('+263784666891', paperWidth));
    invoice.writeln();
    invoice.writeln();
    invoice.writeln();

    return invoice.toString();
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

  // Print Booking Confirmation Slip
  static Future<void> printBookingConfirmation({
    required User student,
    required User instructor,
    required Course course,
    required DateTime startDateTime,
    required DateTime endDateTime,
    Fleet? vehicle,
    int? remainingLessons,
  }) async {
    final settingsController = Get.find<SettingsController>();

    try {
      // Validate printer
      final printerName = settingsController.printerNameValue;
      final isReady = await validatePrinterReady(printerName);

      if (!isReady) {
        throw Exception('Printer not ready');
      }

      // Build booking confirmation content
      final confirmationContent = _buildBookingConfirmationContent(
        student: student,
        instructor: instructor,
        course: course,
        startDateTime: startDateTime,
        endDateTime: endDateTime,
        vehicle: vehicle,
        remainingLessons: remainingLessons,
      );

      // Print the confirmation
      await platform.invokeMethod('printReceipt', {
        'content': confirmationContent,
        'printerName': settingsController.printerNameValue,
        'paperSize': settingsController.printerPaperSizeValue,
      });

      print('✅ Booking confirmation printed successfully');

      // Show success message
      Get.snackbar(
        'Print Success',
        'Booking confirmation printed',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.green,
        colorText: Colors.white,
        icon: Icon(Icons.check_circle, color: Colors.white),
        duration: Duration(seconds: 2),
      );
    } catch (e) {
      print('❌ Error printing booking confirmation: $e');
      Get.snackbar(
        'Print Error',
        'Failed to print booking confirmation: ${e.toString()}',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red,
        colorText: Colors.white,
        icon: Icon(Icons.error_outline, color: Colors.white),
      );
      rethrow;
    }
  }

  static String _buildBookingConfirmationContent({
    required User student,
    required User instructor,
    required Course course,
    required DateTime startDateTime,
    required DateTime endDateTime,
    Fleet? vehicle,
    int? remainingLessons,
  }) {
    final settingsController = Get.find<SettingsController>();
    final now = DateTime.now();
    final dateFormat = DateFormat('MM/dd/yyyy');
    final timeFormat = DateFormat('hh:mm a');
    final dateTimeFormat = DateFormat('MM/dd/yyyy hh:mm a');

    // Get paper width (58mm = 32 chars, 80mm = 48 chars)
    final paperWidth = settingsController.printerPaperSizeValue == '58mm'
        ? 32
        : settingsController.printerPaperSizeValue == '80mm'
            ? 48
            : 32;

    // Calculate duration
    final duration = endDateTime.difference(startDateTime);
    final durationHours = duration.inHours;
    final durationMinutes = duration.inMinutes.remainder(60);

    StringBuffer slip = StringBuffer();

    // Header
    slip.writeln(_center(settingsController.businessNameValue, paperWidth));
    slip.writeln(_center(settingsController.businessAddressValue, paperWidth));
    slip.writeln(_center(settingsController.businessCityValue, paperWidth));
    slip.writeln(
        _center('Phone: ${settingsController.businessPhoneValue}', paperWidth));
    slip.writeln(_divider(paperWidth));
    slip.writeln();

    // Title
    slip.writeln(_center('BOOKING CONFIRMATION', paperWidth));
    slip.writeln();
    slip.writeln(_divider(paperWidth));
    slip.writeln();

    // Booking Date/Time
    slip.writeln('Booked: ${dateTimeFormat.format(now)}');
    slip.writeln(_divider(paperWidth));
    slip.writeln();

    // Student Information
    slip.writeln('STUDENT DETAILS');
    slip.writeln('Name: ${student.fname} ${student.lname}');
    slip.writeln('Phone: ${student.phone}');
    if (student.email.isNotEmpty) {
      slip.writeln('Email: ${student.email}');
    }
    slip.writeln();
    slip.writeln(_divider(paperWidth));
    slip.writeln();

    // Lesson Details
    slip.writeln('LESSON DETAILS');
    slip.writeln('Course: ${course.name}');
    slip.writeln('Date: ${dateFormat.format(startDateTime)}');
    slip.writeln(
        'Time: ${timeFormat.format(startDateTime)} - ${timeFormat.format(endDateTime)}');
    slip.writeln('Duration: ${durationHours}h ${durationMinutes}m');
    slip.writeln();
    slip.writeln(_divider(paperWidth));
    slip.writeln();

    // Instructor Information
    slip.writeln('INSTRUCTOR');
    slip.writeln('${instructor.fname} ${instructor.lname}');
    if (instructor.phone.isNotEmpty) {
      slip.writeln('Phone: ${instructor.phone}');
    }
    slip.writeln();

    // Vehicle Information
    if (vehicle != null) {
      slip.writeln('VEHICLE');
      slip.writeln('${vehicle.make} ${vehicle.model}');
      slip.writeln('Plate: ${vehicle.carPlate}');
      slip.writeln();
    }

    slip.writeln(_divider(paperWidth));
    slip.writeln();

    // Remaining Lessons
    if (remainingLessons != null) {
      slip.writeln(_center('REMAINING BALANCE', paperWidth));
      slip.writeln(_center('$remainingLessons lesson(s)', paperWidth));
      slip.writeln();
      slip.writeln(_divider(paperWidth));
      slip.writeln();
    }

    // Important Notes
    slip.writeln('IMPORTANT NOTES:');
    slip.writeln('* Please arrive 10 minutes early');
    slip.writeln('* Bring your Provisional ');
    slip.writeln('* Wear comfortable clothing');
    slip.writeln('* Call to reschedule if needed');
    slip.writeln();
    slip.writeln(_divider(paperWidth));
    slip.writeln();

    // Footer
    slip.writeln(_center('Thank you for choosing', paperWidth));
    slip.writeln(_center(settingsController.businessNameValue, paperWidth));
    slip.writeln(_center('Drive Safe!', paperWidth));
    slip.writeln();
    slip.writeln();
    slip.writeln();

    return slip.toString();
  }

  // Print Recurring Schedule Confirmation
  static Future<void> printRecurringScheduleConfirmation({
    required User student,
    required User instructor,
    required Course course,
    required DateTime startDate,
    required TimeOfDay startTime,
    required TimeOfDay endTime,
    required String recurrencePattern,
    required int totalSchedules,
    Fleet? vehicle,
    int? remainingLessons,
  }) async {
    final settingsController = Get.find<SettingsController>();

    try {
      // Validate printer
      final printerName = settingsController.printerNameValue;
      final isReady = await validatePrinterReady(printerName);

      if (!isReady) {
        throw Exception('Printer not ready');
      }

      // Build recurring schedule confirmation content
      final confirmationContent = _buildRecurringScheduleConfirmationContent(
        student: student,
        instructor: instructor,
        course: course,
        startDate: startDate,
        startTime: startTime,
        endTime: endTime,
        recurrencePattern: recurrencePattern,
        totalSchedules: totalSchedules,
        vehicle: vehicle,
        remainingLessons: remainingLessons,
      );

      // Print the confirmation
      await platform.invokeMethod('printReceipt', {
        'content': confirmationContent,
        'printerName': settingsController.printerNameValue,
        'paperSize': settingsController.printerPaperSizeValue,
      });

      print('✅ Recurring schedule confirmation printed successfully');

      // Show success message
      Get.snackbar(
        'Print Success',
        'Recurring schedule confirmation printed',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.green,
        colorText: Colors.white,
        icon: Icon(Icons.check_circle, color: Colors.white),
        duration: Duration(seconds: 2),
      );
    } catch (e) {
      print('❌ Error printing recurring schedule confirmation: $e');
      Get.snackbar(
        'Print Error',
        'Failed to print confirmation: ${e.toString()}',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red,
        colorText: Colors.white,
        icon: Icon(Icons.error_outline, color: Colors.white),
      );
      rethrow;
    }
  }

  static String _buildRecurringScheduleConfirmationContent({
    required User student,
    required User instructor,
    required Course course,
    required DateTime startDate,
    required TimeOfDay startTime,
    required TimeOfDay endTime,
    required String recurrencePattern,
    required int totalSchedules,
    Fleet? vehicle,
    int? remainingLessons,
  }) {
    final settingsController = Get.find<SettingsController>();
    final now = DateTime.now();
    final dateFormat = DateFormat('MM/dd/yyyy');
    final timeFormat = DateFormat('hh:mm a');
    final dateTimeFormat = DateFormat('MM/dd/yyyy hh:mm a');

    // Get paper width (58mm = 32 chars, 80mm = 48 chars)
    final paperWidth = settingsController.printerPaperSizeValue == '58mm'
        ? 32
        : settingsController.printerPaperSizeValue == '80mm'
            ? 48
            : 32;

    // Format times
    final startDateTime = DateTime(
      startDate.year,
      startDate.month,
      startDate.day,
      startTime.hour,
      startTime.minute,
    );
    final endDateTime = DateTime(
      startDate.year,
      startDate.month,
      startDate.day,
      endTime.hour,
      endTime.minute,
    );

    // Calculate duration
    final duration = endDateTime.difference(startDateTime);
    final durationHours = duration.inHours;
    final durationMinutes = duration.inMinutes.remainder(60);

    StringBuffer slip = StringBuffer();

    // Header
    slip.writeln(_center(settingsController.businessNameValue, paperWidth));
    slip.writeln(_center(settingsController.businessAddressValue, paperWidth));
    slip.writeln(_center(settingsController.businessCityValue, paperWidth));
    slip.writeln(
        _center('Phone: ${settingsController.businessPhoneValue}', paperWidth));
    slip.writeln(_divider(paperWidth));
    slip.writeln();

    // Title
    slip.writeln(_center('RECURRING SCHEDULE', paperWidth));
    slip.writeln(_center('CONFIRMATION', paperWidth));
    slip.writeln();
    slip.writeln(_divider(paperWidth));
    slip.writeln();

    // Booking Date/Time
    slip.writeln('Created: ${dateTimeFormat.format(now)}');
    slip.writeln(_divider(paperWidth));
    slip.writeln();

    // Student Information
    slip.writeln('STUDENT DETAILS');
    slip.writeln('Name: ${student.fname} ${student.lname}');
    slip.writeln('Phone: ${student.phone}');
    if (student.email.isNotEmpty) {
      slip.writeln('Email: ${student.email}');
    }
    slip.writeln();
    slip.writeln(_divider(paperWidth));
    slip.writeln();

    // Schedule Details
    slip.writeln('SCHEDULE DETAILS');
    slip.writeln('Course: ${course.name}');
    slip.writeln('Pattern: ${recurrencePattern.toUpperCase()}');
    slip.writeln('Start Date: ${dateFormat.format(startDate)}');
    slip.writeln('Time: ${timeFormat.format(startDateTime)} - ${timeFormat.format(endDateTime)}');
    slip.writeln('Duration: ${durationHours}h ${durationMinutes}m');
    slip.writeln('Total Sessions: $totalSchedules');
    slip.writeln();
    slip.writeln(_divider(paperWidth));
    slip.writeln();

    // Instructor Information
    slip.writeln('INSTRUCTOR');
    slip.writeln('${instructor.fname} ${instructor.lname}');
    if (instructor.phone.isNotEmpty) {
      slip.writeln('Phone: ${instructor.phone}');
    }
    slip.writeln();

    // Vehicle Information
    if (vehicle != null) {
      slip.writeln('VEHICLE');
      slip.writeln('${vehicle.make} ${vehicle.model}');
      slip.writeln('Plate: ${vehicle.carPlate}');
      slip.writeln();
    }

    slip.writeln(_divider(paperWidth));
    slip.writeln();

    // Remaining Lessons
    if (remainingLessons != null) {
      slip.writeln(_center('REMAINING BALANCE', paperWidth));
      slip.writeln(_center('$remainingLessons lesson(s)', paperWidth));
      slip.writeln();
      slip.writeln(_divider(paperWidth));
      slip.writeln();
    }

    // Important Notes
    slip.writeln('IMPORTANT NOTES:');
    slip.writeln('* Please arrive 10 minutes early');
    slip.writeln('* Bring your Provisional ');
    slip.writeln('* Wear comfortable clothing');
    slip.writeln('* Call to reschedule if needed');
    slip.writeln();
    slip.writeln(_divider(paperWidth));
    slip.writeln();

    // Footer
    slip.writeln(_center('Thank you for choosing', paperWidth));
    slip.writeln(_center(settingsController.businessNameValue, paperWidth));
    slip.writeln(_center('Drive Safe!', paperWidth));
    slip.writeln();
    slip.writeln();
    slip.writeln();

    return slip.toString();
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

  static const platform = MethodChannel('com.codzlabzim.driving/printing');

  static Future<bool> requestBluetoothPermissions() async {
    try {
      print('📱 Requesting Bluetooth permissions from Flutter...');
      final bool result =
          await platform.invokeMethod('requestBluetoothPermissions');
      print('✅ Permission request result: $result');
      return result;
    } on PlatformException catch (e) {
      print('❌ Failed to request permissions: ${e.message}');
      return false;
    }
  }

  /// Check if Bluetooth permissions are already granted
  static Future<bool> checkBluetoothPermissions() async {
    try {
      final bool result =
          await platform.invokeMethod('checkBluetoothPermissions');
      return result;
    } on PlatformException catch (e) {
      print('❌ Failed to check permissions: ${e.message}');
      return false;
    }
  }

  /// Discover available printers by type
  /// Type can be: 'bluetooth', 'usb', 'network', or 'all'
  static Future<List<Map<String, dynamic>>> discoverPrinters({
    String type = 'all',
  }) async {
    try {
      print('🔍 Starting printer discovery for type: $type');

      // Check permissions first (on app side)
      final hasPermissions = await checkBluetoothPermissions();
      if (!hasPermissions && type.toLowerCase() == 'bluetooth') {
        print('⚠️ No Bluetooth permissions, requesting...');
        final granted = await requestBluetoothPermissions();
        if (!granted) {
          print('❌ Permissions denied by user');
          Get.snackbar(
            'Permission Required',
            'Bluetooth permission is needed to discover printers',
            snackPosition: SnackPosition.BOTTOM,
            duration: Duration(seconds: 3),
          );
          return [];
        }
      }

      // Now discover printers (native side will also check)
      final result = await platform.invokeMethod('discoverPrinters', {
        'type': type,
      });

      print('📱 Discovery result: $result');

      if (result == null) {
        print('⚠️ No printers found');
        return [];
      }

      // Convert to List<Map<String, dynamic>>
      final List<Map<String, dynamic>> printers = (result as List)
          .map((item) => Map<String, dynamic>.from(item as Map))
          .toList();

      print('✅ Found ${printers.length} printers');
      return printers;
    } on PlatformException catch (e) {
      print('❌ Error discovering printers: ${e.message}');

      if (e.code == 'PERMISSION_ERROR') {
        Get.snackbar(
          'Permission Required',
          'Please grant Bluetooth permissions to discover printers',
          snackPosition: SnackPosition.BOTTOM,
          duration: Duration(seconds: 4),
        );
      } else {
        Get.snackbar(
          'Discovery Error',
          'Failed to discover printers: ${e.message}',
          snackPosition: SnackPosition.BOTTOM,
          duration: Duration(seconds: 3),
        );
      }

      return [];
    } catch (e) {
      print('❌ Unexpected error: $e');
      return [];
    }
  }

  /// Verify if a specific printer is available
  static Future<bool> verifyPrinter(String printerName) async {
    try {
      print('🔍 Verifying printer: $printerName');

      final result = await platform.invokeMethod('verifyPrinter', {
        'printerName': printerName,
      });

      print('✅ Printer verification result: $result');
      return result as bool;
    } on PlatformException catch (e) {
      print('❌ Error verifying printer: ${e.message}');
      return false;
    }
  }

  /// Print a receipt
  static Future<bool> printReceipt({
    required String content,
    required String printerName,
    String paperSize = '80mm',
  }) async {
    try {
      print('🖨️ Printing receipt...');
      print('   Printer: $printerName');
      print('   Paper size: $paperSize');

      final result = await platform.invokeMethod('printReceipt', {
        'content': content,
        'printerName': printerName,
        'paperSize': paperSize,
      });

      print('✅ Print result: $result');
      return result as bool;
    } on PlatformException catch (e) {
      print('❌ Error printing receipt: ${e.message}');

      if (e.code == 'PERMISSION_ERROR') {
        Get.snackbar(
          'Permission Required',
          'Please grant Bluetooth permissions to print',
          snackPosition: SnackPosition.BOTTOM,
          duration: Duration(seconds: 4),
        );
      } else {
        Get.snackbar(
          'Print Error',
          e.message ?? 'Failed to print receipt',
          snackPosition: SnackPosition.BOTTOM,
          duration: Duration(seconds: 3),
        );
      }

      return false;
    }
  }

  /// Format a simple text receipt
  static String formatSimpleReceipt({
    required String schoolName,
    required String date,
    required String items,
    required String total,
  }) {
    return '''
[C]<b>${schoolName}</b>
[C]================================
[L]Date: $date
[L]
$items
[L]--------------------------------
[R]TOTAL: $total
[L]
[C]Thank you for your payment!
[C]
''';
  }
}
