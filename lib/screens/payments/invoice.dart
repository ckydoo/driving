import 'package:driving/models/invoice.dart';

class InvoiceNumberHelper {
  // Simple sequential invoice numbering
  static String generateSimpleInvoiceNumber(int invoiceId,
      {String prefix = 'INV'}) {
    return '$prefix-${invoiceId.toString().padLeft(6, '0')}';
    // Example: INV-000001, INV-000002, etc.
  }

  // Date-based invoice numbering
  static String generateDateBasedInvoiceNumber(
      int invoiceId, DateTime? createdDate) {
    final date = createdDate ?? DateTime.now();
    final year = date.year.toString().substring(2); // Last 2 digits
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    final id = invoiceId.toString().padLeft(4, '0');

    return 'INV-$year$month$day-$id';
    // Example: INV-250129-0001
  }

  // Year and sequential numbering
  static String generateYearlyInvoiceNumber(
      int invoiceId, DateTime? createdDate) {
    final date = createdDate ?? DateTime.now();
    final year = date.year;
    final id = invoiceId.toString().padLeft(4, '0');

    return 'INV-$year-$id';
    // Example: INV-2025-0001
  }

  // Receipt numbering
  static String generateReceiptNumber(int paymentId, DateTime? paymentDate) {
    final date = paymentDate ?? DateTime.now();
    final year = date.year.toString().substring(2);
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    final id = paymentId.toString().padLeft(4, '0');

    return 'RCP-$year$month$day-$id';
    // Example: RCP-250129-0001
  }

  // Student-based numbering (if you want to include student info)
  static String generateStudentInvoiceNumber(
      int invoiceId, int studentId, DateTime? createdDate) {
    final date = createdDate ?? DateTime.now();
    final year = date.year.toString().substring(2);
    final month = date.month.toString().padLeft(2, '0');
    final studentCode = studentId.toString().padLeft(3, '0');
    final invoiceSeq = invoiceId.toString().padLeft(3, '0');

    return 'INV-$year$month-$studentCode-$invoiceSeq';
    // Example: INV-2501-001-123
  }

  // Format display number with better readability
  static String formatInvoiceNumberForDisplay(String invoiceNumber) {
    // Add spaces or dashes for better readability
    return invoiceNumber.replaceAllMapped(
      RegExp(r'([A-Z]+)-(\d+)-?(\d+)?'),
      (match) {
        if (match.group(3) != null) {
          return '${match.group(1)} - ${match.group(2)} - ${match.group(3)}';
        }
        return '${match.group(1)} - ${match.group(2)}';
      },
    );
  }
}

// Extension to add invoice number generation to Invoice model
extension InvoiceNumberExtension on Invoice {
  String get invoiceNumber {
    // Use the simple format as default
    return InvoiceNumberHelper.generateSimpleInvoiceNumber(id ?? 0);
  }

  String get formattedInvoiceNumber {
    return InvoiceNumberHelper.formatInvoiceNumberForDisplay(invoiceNumber);
  }

  String get dateBasedInvoiceNumber {
    return InvoiceNumberHelper.generateDateBasedInvoiceNumber(
        id ?? 0, createdDate);
  }

  String get yearlyInvoiceNumber {
    return InvoiceNumberHelper.generateYearlyInvoiceNumber(
        id ?? 0, createdDate);
  }
}
