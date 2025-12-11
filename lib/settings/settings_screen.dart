import 'package:driving/controllers/sync_controller.dart';
import 'package:driving/services/print_service.dart';
import 'package:driving/settings/subscription_settings_screen.dart';
import 'package:driving/widgets/sync_status_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import '../controllers/settings_controller.dart';
import '../controllers/auth_controller.dart';
import '../widgets/lesson_duration_setting_tile.dart';
import 'package:url_launcher/url_launcher.dart';

class SettingsScreen extends StatefulWidget {
  @override
  _SettingsScreenState createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final SettingsController settingsController = Get.find<SettingsController>();
  final AuthController authController = Get.find<AuthController>();
  late ThemeData _theme;
  late ColorScheme _colorScheme;
  late TextTheme _textTheme;
  bool get _isDarkMode => _colorScheme.brightness == Brightness.dark;

  // Add getter to calculate tab count dynamically
  int get _tabCount => _availableTabs.length;

  // Add getter for tab indices
  List<String> get _availableTabs {
    List<String> tabs = [];
    if (authController.hasAnyRole(['admin', 'instructor'])) {
      tabs.addAll([
        'Business',
        'Scheduling',
        'Billing',
        'Instructor',
        'Notifications',
        'Printer'
      ]);
    }
    if (tabs.isEmpty) {
      tabs.add('Overview');
    }

    return tabs;
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabCount, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _theme = Theme.of(context);
    _colorScheme = _theme.colorScheme;
    _textTheme = _theme.textTheme;

    return Scaffold(
      body: Column(
        children: [
          // Settings Header with Tabs
          Container(
            decoration: BoxDecoration(
              color: _theme.cardColor,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(_isDarkMode ? 0.4 : 0.08),
                  spreadRadius: 1,
                  blurRadius: 5,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              children: [
                Padding(
                  padding: EdgeInsets.all(16),
                  child: Column(
                    children: [
                      // Main header row
                      Row(
                        children: [
                          Icon(Icons.settings,
                              size: 28, color: _colorScheme.primary),
                          SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Application Settings',
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: _textTheme.titleLarge?.color,
                              ),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            ),
                          ),
                        ],
                      ),
                      // Quick actions row (responsive)
                      SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Expanded(
                            child: SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  _buildQuickActions(),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                TabBar(
                  controller: _tabController,
                  isScrollable: true,
                  indicatorColor: _colorScheme.primary,
                  labelColor: _colorScheme.primary,
                  unselectedLabelColor: _colorScheme.onSurfaceVariant,
                  tabs: _availableTabs
                      .map((tabName) => Tab(text: tabName))
                      .toList(),
                ),
              ],
            ),
          ),
          // Settings Content
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: _buildTabViews(),
            ),
          ),
        ],
      ),
    );
  }

  // Add method to build tab views dynamically
  List<Widget> _buildTabViews() {
    return _availableTabs.map((tabName) {
      switch (tabName) {
        case 'Business':
          return _buildBusinessSettings();
        case 'Scheduling':
          return _buildSchedulingSettings();
        case 'Billing':
          return _buildBillingSettings();
        case 'Instructor':
          return _buildInstructorSettings();
        case 'Notifications':
          return _buildNotificationSettings();
        case 'Printer':
          return _buildPrinterSettings();
        default:
          return _buildOverviewPlaceholder();
      }
    }).toList();
  }

  final syncController = Get.find<SyncController>();

  Widget _buildQuickActions() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        if (authController.hasAnyRole(['admin', 'instructor']))
          _buildQuickActionButton(
            icon: Icons.bug_report,
            label: 'Sync Data',
            onTap: () {
              Get.to(() => SyncStatusWidget());
            },
            accentColor: _colorScheme.primary,
          ),
        if (authController.hasAnyRole(['admin', 'instructor']))
          _buildQuickActionButton(
            icon: Icons.subscriptions,
            label: 'Subscription',
            onTap: () {
              Get.to(() => SubscriptionScreen());
            },
            accentColor: _colorScheme.secondary,
          ),
        if (authController.hasAnyRole(['admin', 'instructor']))
          _buildQuickActionButton(
            icon: Icons.download,
            label: 'Export',
            onTap: _showExportDialog,
            accentColor: _colorScheme.primary,
          ),
        if (authController.hasAnyRole(['admin', 'instructor']))
          _buildQuickActionButton(
            icon: Icons.upload,
            label: 'Import',
            onTap: _showImportDialog,
            accentColor: _colorScheme.primary,
          ),
        if (authController.hasAnyRole(['admin', 'instructor']))
          _buildQuickActionButton(
            icon: Icons.refresh,
            label: 'Reset',
            onTap: _showResetConfirmation,
            accentColor: _colorScheme.error,
          ),
      ],
    );
  }
  // Replace your _buildPrinterSettings() method in settings_screen.dart with this:

  Widget _buildPrinterSettings() {
    return SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader('Thermal Printer Configuration'),
          _buildSettingsCard([
            // REPLACED: Text field with printer selector
            _buildPrinterSelector(),

            _buildDropdownTile(
              'Paper Size',
              'Select paper width',
              settingsController.printerPaperSize,
              ['58mm', '80mm'],
              (value) {
                settingsController.printerPaperSize.value = value;
                settingsController.savePrinterSettings();
              },
              (value) => value,
            ),
            _buildSwitchTile(
              'Auto-Print on Payment',
              'Automatically print receipt after successful payment',
              settingsController.autoPrintReceipt,
              (value) {
                settingsController.autoPrintReceipt.value = value;
                settingsController.savePrinterSettings();
              },
            ),
            _buildTextFieldTile(
              'Number of Copies',
              'How many copies to print (1-3)',
              settingsController.receiptCopies,
              Icons.copy_all,
            ),
          ]),

          SizedBox(height: 20),

          _buildSectionHeader('Receipt Customization'),
          _buildSettingsCard([
            _buildTextFieldTile(
              'Receipt Header',
              'Top text on receipt (e.g., Thank you for your business)',
              settingsController.receiptHeader,
              Icons.text_fields,
            ),
            _buildTextFieldTile(
              'Receipt Footer',
              'Bottom text on receipt (e.g., Come again)',
              settingsController.receiptFooter,
              Icons.text_fields,
            ),
          ]),

          SizedBox(height: 20),

          // Test Print Button with status indicator
          Center(
            child: Column(
              children: [
                Obx(() => settingsController.printerName.value.isEmpty
                    ? Container(
                        padding: EdgeInsets.all(12),
                        margin: EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: Colors.orange[50],
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.orange[200]!),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.warning,
                                color: Colors.orange[700], size: 20),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'No printer selected. Search for printers above.',
                                style: TextStyle(
                                  color: Colors.orange[700],
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ],
                        ),
                      )
                    : SizedBox.shrink()),
                ElevatedButton.icon(
                  onPressed: settingsController.printerName.value.isEmpty
                      ? null
                      : () => _printTestReceipt(),
                  icon: Icon(Icons.print),
                  label: Text('Test Print Receipt'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue[700],
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                    disabledBackgroundColor: Colors.grey[300],
                    disabledForegroundColor: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

// Add the printer selector widget method
  // Replace _buildPrinterSelector() in settings_screen.dart

  Widget _buildPrinterSelector() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.print, size: 20, color: Colors.blue[700]),
              SizedBox(width: 8),
              Text(
                'Printer Selection',
                style: TextStyle(
                  fontWeight: FontWeight.w500,
                  fontSize: 16,
                ),
              ),
            ],
          ),
          SizedBox(height: 12),

          // Selected Printer Display
          Obx(() => Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey[300]!),
                ),
                child: Row(
                  children: [
                    Icon(
                      settingsController.printerName.value.isEmpty
                          ? Icons.print_disabled
                          : Icons.print,
                      color: settingsController.printerName.value.isEmpty
                          ? Colors.grey
                          : Colors.green,
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            settingsController.printerName.value.isEmpty
                                ? 'No printer selected'
                                : settingsController.printerName.value,
                            style: TextStyle(
                              fontWeight: FontWeight.w500,
                              color:
                                  settingsController.printerName.value.isEmpty
                                      ? Colors.grey[600]
                                      : Colors.black87,
                            ),
                          ),
                          if (settingsController.printerName.value.isEmpty)
                            Text(
                              'Choose printer type below and search',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey[600],
                              ),
                            ),
                        ],
                      ),
                    ),
                    if (settingsController.printerName.value.isNotEmpty)
                      IconButton(
                        icon: Icon(Icons.close, size: 20),
                        onPressed: () {
                          settingsController.printerName.value = '';
                          settingsController.savePrinterSettings();
                        },
                        tooltip: 'Clear selection',
                        color: Colors.grey[600],
                      ),
                  ],
                ),
              )),

          SizedBox(height: 16),

          // Printer Type Selection
          Text(
            'Choose Printer Type',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Colors.grey[700],
            ),
          ),
          SizedBox(height: 12),

          // Printer Type Cards
          Row(
            children: [
              Expanded(
                child: _buildPrinterTypeCard(
                  icon: Icons.bluetooth,
                  label: 'Bluetooth',
                  type: 'bluetooth',
                  color: Colors.blue,
                ),
              ),
              SizedBox(width: 8),
              Expanded(
                child: _buildPrinterTypeCard(
                  icon: Icons.usb,
                  label: 'USB',
                  type: 'usb',
                  color: Colors.orange,
                ),
              ),
              SizedBox(width: 8),
              Expanded(
                child: _buildPrinterTypeCard(
                  icon: Icons.wifi,
                  label: 'Network',
                  type: 'network',
                  color: Colors.green,
                ),
              ),
            ],
          ),

          SizedBox(height: 16),

          // Search Button - only enabled if type is selected
          Obx(() => ElevatedButton.icon(
                onPressed: _selectedPrinterType.value.isEmpty
                    ? null
                    : () =>
                        _searchForPrintersByType(_selectedPrinterType.value),
                icon: Icon(Icons.search),
                label: Text(
                  _selectedPrinterType.value.isEmpty
                      ? 'Select a printer type first'
                      : 'Search ${_selectedPrinterType.value.capitalize} Printers',
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue[600],
                  foregroundColor: Colors.white,
                  minimumSize: Size(double.infinity, 50),
                  disabledBackgroundColor: Colors.grey[300],
                  disabledForegroundColor: Colors.grey[600],
                ),
              )),
        ],
      ),
    );
  }

  final RxString _selectedPrinterType = ''.obs;

// Build printer type selection card
  Widget _buildPrinterTypeCard({
    required IconData icon,
    required String label,
    required String type,
    required Color color,
  }) {
    return Obx(() {
      final isSelected = _selectedPrinterType.value == type;

      return InkWell(
        onTap: () {
          _selectedPrinterType.value = type;
        },
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: EdgeInsets.symmetric(vertical: 16, horizontal: 8),
          decoration: BoxDecoration(
            color: isSelected ? color.withOpacity(0.1) : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? color : Colors.grey[300]!,
              width: isSelected ? 2 : 1,
            ),
          ),
          child: Column(
            children: [
              Icon(
                icon,
                color: isSelected ? color : Colors.grey[600],
                size: 32,
              ),
              SizedBox(height: 8),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  color: isSelected ? color : Colors.grey[700],
                ),
              ),
              if (isSelected)
                Padding(
                  padding: EdgeInsets.only(top: 4),
                  child: Icon(
                    Icons.check_circle,
                    color: color,
                    size: 16,
                  ),
                ),
            ],
          ),
        ),
      );
    });
  }

// Search for printers by specific type
  void _searchForPrintersByType(String type) async {
    try {
      // Show loading dialog
      Get.dialog(
        WillPopScope(
          onWillPop: () async => false,
          child: Center(
            child: Card(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text('Searching for ${type.capitalize} printers...'),
                    SizedBox(height: 8),
                    Text(
                      _getPrinterTypeDescription(type),
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        barrierDismissible: false,
      );

      // Call the printer discovery service with type filter
      List<PrinterInfo> printers = [];

      try {
        printers = await PrintService.discoverPrintersByType(type);
      } catch (e) {
        Get.back(); // Close loading

        // Handle permission errors
        if (e.toString().contains('PERMISSION_DENIED')) {
          _showPermissionDialog(type);
          return;
        }

        Get.snackbar(
          'Error',
          'Failed to search for printers: $e',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.red,
          colorText: Colors.white,
        );
        return;
      }

      Get.back(); // Close loading

      // Show results
      if (printers.isEmpty) {
        _showNoPrintersDialog(type);
      } else {
        _showPrinterSelectionDialog(printers, type);
      }
    } catch (e) {
      Get.back(); // Close loading if open
      Get.snackbar(
        'Error',
        'Failed to search for printers: $e',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
  }

// Get description for printer type
  String _getPrinterTypeDescription(String type) {
    switch (type) {
      case 'bluetooth':
        return 'Scanning paired Bluetooth devices...';
      case 'usb':
        return 'Checking USB connections...';
      case 'network':
        return 'Scanning network for printers...';
      default:
        return 'Searching...';
    }
  }

// Show permission dialog
  void _showPermissionDialog(String type) {
    Get.dialog(
      AlertDialog(
        title: Row(
          children: [
            Icon(Icons.bluetooth_disabled, color: Colors.orange),
            SizedBox(width: 8),
            Text('Permission Required'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'To discover ${type.capitalize} printers, we need your permission.',
              style: TextStyle(fontSize: 14),
            ),
            SizedBox(height: 16),
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'What to do:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 8),
                  Text('1. Allow permission when prompted'),
                  Text('2. Try searching again'),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: Text('Cancel'),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Get.back();
              Future.delayed(Duration(seconds: 1), () {
                _searchForPrintersByType(type);
              });
            },
            icon: Icon(Icons.refresh),
            label: Text('Try Again'),
          ),
        ],
      ),
    );
  }

// Show no printers dialog
  void _showNoPrintersDialog(String type) {
    Get.dialog(
      AlertDialog(
        title: Row(
          children: [
            Icon(Icons.print_disabled, color: Colors.orange),
            SizedBox(width: 8),
            Text('No ${type.capitalize} Printers Found'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Please check the following:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 12),
              ..._getChecklistForType(type),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: Text('Cancel'),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Get.back();
              _searchForPrintersByType(type);
            },
            icon: Icon(Icons.refresh),
            label: Text('Try Again'),
          ),
        ],
      ),
    );
  }

// Get checklist items based on printer type
  List<Widget> _getChecklistForType(String type) {
    List<String> items = [];

    switch (type) {
      case 'bluetooth':
        items = [
          'Bluetooth is enabled on your device',
          'Printer is powered on',
          'Printer is paired in Bluetooth settings',
          'Printer is within range (< 10 meters)',
        ];
        break;
      case 'usb':
        items = [
          'Printer is powered on',
          'USB cable is properly connected',
          'USB drivers are installed',
          'Printer is recognized by the system',
        ];
        break;
      case 'network':
        items = [
          'Printer is powered on',
          'Printer is connected to WiFi',
          'Device and printer are on same network',
          'Printer has a valid IP address',
        ];
        break;
    }

    return items.map((item) => _buildChecklistItem(item)).toList();
  }

// Update the printer selection dialog to show type
  void _showPrinterSelectionDialog(List<PrinterInfo> printers, String type) {
    Get.dialog(
      AlertDialog(
        title: Row(
          children: [
            Icon(_getPrinterTypeIcon(type), color: Colors.blue[700]),
            SizedBox(width: 8),
            Text('Select ${type.capitalize} Printer'),
          ],
        ),
        content: Container(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.green, size: 16),
                  SizedBox(width: 8),
                  Text(
                    'Found ${printers.length} ${type} printer${printers.length > 1 ? 's' : ''}',
                    style: TextStyle(color: Colors.grey[600], fontSize: 14),
                  ),
                ],
              ),
              SizedBox(height: 16),
              Container(
                constraints: BoxConstraints(maxHeight: 400),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: printers.length,
                  itemBuilder: (context, index) {
                    final printer = printers[index];
                    final isSelected =
                        settingsController.printerName.value == printer.name;

                    return Card(
                      color: isSelected ? Colors.blue[50] : Colors.white,
                      elevation: isSelected ? 3 : 1,
                      margin: EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: Container(
                          padding: EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? Colors.blue[100]
                                : Colors.grey[100],
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            _getPrinterIcon(printer.type),
                            color: isSelected
                                ? Colors.blue[700]
                                : Colors.grey[600],
                            size: 28,
                          ),
                        ),
                        title: Text(
                          printer.name,
                          style: TextStyle(
                            fontWeight:
                                isSelected ? FontWeight.bold : FontWeight.w500,
                          ),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SizedBox(height: 4),
                            Row(
                              children: [
                                Icon(Icons.info_outline,
                                    size: 12, color: Colors.grey[600]),
                                SizedBox(width: 4),
                                Text(
                                  printer.description,
                                  style: TextStyle(fontSize: 11),
                                ),
                              ],
                            ),
                            if (printer.address?.isNotEmpty ?? false)
                              Row(
                                children: [
                                  Icon(Icons.location_on,
                                      size: 12, color: Colors.grey[600]),
                                  SizedBox(width: 4),
                                  Text(
                                    printer.address!,
                                    style: TextStyle(fontSize: 10),
                                  ),
                                ],
                              ),
                          ],
                        ),
                        trailing: isSelected
                            ? Icon(Icons.check_circle,
                                color: Colors.green, size: 28)
                            : Icon(Icons.radio_button_unchecked,
                                color: Colors.grey, size: 28),
                        onTap: () {
                          settingsController.printerName.value = printer.name;
                          settingsController.savePrinterSettings();
                          Get.back();

                          // Reset printer type selection
                          _selectedPrinterType.value = '';

                          Get.snackbar(
                            'Printer Selected',
                            '${printer.name} is now your default printer',
                            snackPosition: SnackPosition.BOTTOM,
                            backgroundColor: Colors.green,
                            colorText: Colors.white,
                            icon: Icon(Icons.check_circle, color: Colors.white),
                          );
                        },
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: Text('Cancel'),
          ),
        ],
      ),
    );
  }

// Helper to get icon for printer type
  IconData _getPrinterTypeIcon(String type) {
    switch (type) {
      case 'bluetooth':
        return Icons.bluetooth;
      case 'usb':
        return Icons.usb;
      case 'network':
        return Icons.wifi;
      default:
        return Icons.print;
    }
  }

// Helper widget for checklist items
  Widget _buildChecklistItem(String text) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.check_circle_outline, size: 16, color: Colors.green),
          SizedBox(width: 8),
          Expanded(
            child: Text(text, style: TextStyle(fontSize: 13)),
          ),
        ],
      ),
    );
  }

// Helper to get printer icon based on type
  IconData _getPrinterIcon(String type) {
    final typeLower = type.toLowerCase();
    if (typeLower.contains('usb')) return Icons.usb;
    if (typeLower.contains('network') || typeLower.contains('wifi'))
      return Icons.wifi;
    if (typeLower.contains('bluetooth')) return Icons.bluetooth;
    return Icons.print;
  }

// 5. Add the test print method

  void _printTestReceipt() async {
    try {
      // ✅ ADD VALIDATION CHECK FIRST
      final settingsController = Get.find<SettingsController>();
      final printerName = settingsController.printerNameValue;

      // Validate printer before showing "sending" message
      Get.snackbar(
        'Validating Printer',
        'Checking printer connection...',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.blue,
        colorText: Colors.white,
        showProgressIndicator: true,
        duration: Duration(seconds: 2),
      );

      final isReady = await PrintService.validatePrinterReady(printerName);

      if (!isReady) {
        // Error already shown by validatePrinterReady
        return;
      }

      Get.snackbar(
        'Test Print',
        'Sending test receipt to printer...',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.blue,
        colorText: Colors.white,
      );

      await PrintService.printTestReceipt();

      Get.snackbar(
        'Success',
        'Test receipt printed successfully!',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.green,
        colorText: Colors.white,
        icon: Icon(Icons.check_circle, color: Colors.white),
      );
    } catch (e) {
      Get.snackbar(
        'Error',
        'Failed to print: $e',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red,
        colorText: Colors.white,
        duration: Duration(seconds: 4),
      );
    }
  }

  Widget _buildQuickActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    Color? accentColor,
  }) {
    final color = accentColor ?? _colorScheme.primary;
    final textColor = _isDarkMode ? colorSchemeDependentText(color) : color;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: color.withOpacity(_isDarkMode ? 0.08 : 0.05),
          border: Border.all(color: color.withOpacity(0.4)),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: textColor),
            SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                color: textColor,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color colorSchemeDependentText(Color baseColor) {
    if (!_isDarkMode) return baseColor;
    final luminance = baseColor.computeLuminance();
    return luminance > 0.4 ? Colors.black87 : Colors.white;
  }

  Widget _buildSchedulingSettings() {
    return SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader('Lesson Configuration'),
          LessonDurationSettingTile(settingsController: settingsController),
          // OR use the compact version:
          // CompactLessonDurationSetting(settingsController: settingsController),

          SizedBox(height: 16),
          _buildSectionHeader('Scheduling Policies'),
          _buildSettingsCard([
            _buildSwitchTile(
              'Enforce Billing Validation',
              'Check student billing status before scheduling',
              settingsController.enforceBillingValidation,
              settingsController.toggleBillingValidation,
            ),
            _buildSwitchTile(
              'Check Instructor Availability',
              'Verify instructor is available before scheduling',
              settingsController.checkInstructorAvailability,
              settingsController.toggleInstructorAvailabilityCheck,
            ),
            _buildSwitchTile(
              'Enforce Working Hours',
              'Only allow scheduling within working hours',
              settingsController.enforceWorkingHours,
              settingsController.toggleWorkingHours,
            ),
            _buildSwitchTile(
              'Auto-Assign Vehicles',
              'Automatically assign available vehicles to lessons',
              settingsController.autoAssignVehicles,
              settingsController.toggleAutoAssignVehicles,
            ),
          ]),
        ],
      ),
    );
  }

  Widget _buildOverviewPlaceholder() {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.lock_outline, size: 48, color: _colorScheme.primary),
            SizedBox(height: 16),
            Text(
              'No settings available',
              style: _textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Contact an administrator to manage application settings.',
              style: _textTheme.bodyMedium?.copyWith(
                color: _colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  // Helper widgets
  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: _textTheme.titleMedium?.color,
        ),
      ),
    );
  }

  Widget _buildSettingsCard(List<Widget> children) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Column(
        children: children
            .map((child) => children.indexOf(child) == children.length - 1
                ? child
                : Column(children: [
                    child,
                    Divider(height: 1, color: _colorScheme.outlineVariant)
                  ]))
            .toList(),
      ),
    );
  }

  Widget _buildSwitchTile(
    String title,
    String subtitle,
    RxBool value,
    Function(bool) onChanged,
  ) {
    return Obx(() => SwitchListTile(
          title: Text(title, style: TextStyle(fontWeight: FontWeight.w500)),
          subtitle: Text(subtitle, style: TextStyle(fontSize: 12)),
          value: value.value,
          onChanged: onChanged,
          activeColor: _colorScheme.primary,
        ));
  }

  Widget _buildSliderTile(
    String title,
    String subtitle,
    RxInt currentValue,
    RxInt tempValue,
    double min,
    double max,
    double divisions,
    Function(int) onTempChanged,
    Function() onCommit,
    String Function(int) formatter,
  ) {
    return Obx(() => Container(
          padding: EdgeInsets.symmetric(vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontWeight: FontWeight.w500,
                  fontSize: 16,
                ),
              ),
              SizedBox(height: 4),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 12,
                  color: _colorScheme.onSurfaceVariant,
                ),
              ),
              SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        activeTrackColor: _colorScheme.primary,
                        inactiveTrackColor:
                            _colorScheme.primary.withOpacity(0.2),
                        thumbColor: _colorScheme.primary,
                        overlayColor: _colorScheme.primary.withOpacity(0.2),
                        thumbShape:
                            RoundSliderThumbShape(enabledThumbRadius: 12),
                        overlayShape:
                            RoundSliderOverlayShape(overlayRadius: 20),
                        trackHeight: 4,
                        valueIndicatorShape: PaddleSliderValueIndicatorShape(),
                        valueIndicatorColor: _colorScheme.primary,
                        valueIndicatorTextStyle: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      child: Slider(
                        value: tempValue.value.toDouble(),
                        min: min,
                        max: max,
                        divisions: ((max - min) / divisions).round(),
                        label: formatter(tempValue.value),
                        onChanged: (value) => onTempChanged(value.toInt()),
                        onChangeEnd: (value) {
                          onCommit();
                          // Add haptic feedback
                          HapticFeedback.lightImpact();
                        },
                      ),
                    ),
                  ),
                  SizedBox(width: 16),
                  Container(
                    width: 80,
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: _colorScheme.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                          color: _colorScheme.primary.withOpacity(0.3)),
                    ),
                    child: Text(
                      formatter(tempValue.value),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: _colorScheme.primary,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),
              // Show if value has changed
              if (tempValue.value != currentValue.value) ...[
                SizedBox(height: 8),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: _colorScheme.tertiary.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                        color: _colorScheme.tertiary.withOpacity(0.4)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.info_outline,
                          size: 14, color: _colorScheme.tertiary),
                      SizedBox(width: 4),
                      Text(
                        'Changed from ${formatter(currentValue.value)}',
                        style: TextStyle(
                          fontSize: 11,
                          color: _colorScheme.tertiary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ));
  }

  Widget _buildDropdownTile<T>(
    String title,
    String subtitle,
    RxString value,
    List<T> items,
    Function(T) onChanged,
    String Function(T) formatter,
  ) {
    return Obx(() {
      // Find matching item or use first item as fallback
      T? selectedItem;
      try {
        selectedItem =
            items.firstWhere((item) => item.toString() == value.value);
      } catch (e) {
        // If no match found, use the first item and update the value
        selectedItem = items.isNotEmpty ? items.first : null;
        if (selectedItem != null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            value.value = selectedItem.toString();
          });
        }
      }

      return ListTile(
        title: Text(title, style: TextStyle(fontWeight: FontWeight.w500)),
        subtitle: Text(subtitle, style: TextStyle(fontSize: 12)),
        trailing: DropdownButton<T>(
          value: selectedItem,
          items: items.map((item) {
            return DropdownMenuItem<T>(
              value: item,
              child: Text(formatter(item)),
            );
          }).toList(),
          onChanged: (newValue) {
            if (newValue != null) {
              onChanged(newValue);
            }
          },
          underline: SizedBox.shrink(),
        ),
      );
    });
  }

  Widget _buildTimeTile(
    String title,
    RxString timeValue,
    bool? isStart, {
    String? subtitle,
  }) {
    return Obx(() => ListTile(
          title: Text(title, style: TextStyle(fontWeight: FontWeight.w500)),
          subtitle: subtitle != null
              ? Text(subtitle, style: TextStyle(fontSize: 12))
              : null,
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                timeValue.value,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: _colorScheme.primary,
                ),
              ),
              SizedBox(width: 8),
              Icon(Icons.access_time, color: _colorScheme.onSurfaceVariant),
            ],
          ),
          onTap: () => _selectTime(context, timeValue, isStart),
        ));
  }

  Future<void> _selectTime(
      BuildContext context, RxString timeValue, bool? isStart) async {
    final currentTime = timeValue.value;
    final timeParts = currentTime.split(':');
    final initialTime = TimeOfDay(
      hour: int.parse(timeParts[0]),
      minute: int.parse(timeParts[1]),
    );

    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: initialTime,
    );

    if (picked != null) {
      final timeString =
          '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';

      if (isStart == true) {
        settingsController.setWorkingHours(
            timeString, settingsController.workingHoursEnd.value);
      } else if (isStart == false) {
        settingsController.setWorkingHours(
            settingsController.workingHoursStart.value, timeString);
      } else {
        // For daily summary time
        settingsController.setDailySummaryTime(timeString);
      }
    }
  }

  void _showResetConfirmation() {
    Get.dialog(
      AlertDialog(
        title: Row(
          children: [
            Icon(Icons.warning, color: Colors.orange),
            SizedBox(width: 8),
            Text('Reset All Settings'),
          ],
        ),
        content: Text(
          'Are you sure you want to reset all settings to their default values? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Get.back();
              settingsController.resetToDefaults();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade600,
              foregroundColor: Colors.white,
            ),
            child: Text('Reset All'),
          ),
        ],
      ),
    );
  }

  void _showExportDialog() {
    final exportedSettings = settingsController.exportSettings();

    Get.dialog(
      AlertDialog(
        title: Row(
          children: [
            Icon(Icons.download, color: Colors.green),
            SizedBox(width: 8),
            Text('Export Settings'),
          ],
        ),
        content: Container(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Your settings have been exported. Copy the text below:'),
              SizedBox(height: 16),
              Container(
                height: 200,
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: SingleChildScrollView(
                  child: SelectableText(
                    exportedSettings,
                    style: TextStyle(fontSize: 12, fontFamily: 'monospace'),
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: Text('Close'),
          ),
          ElevatedButton(
            onPressed: () {
              // Here you would implement clipboard copy functionality
              Get.back();
              Get.snackbar(
                snackPosition: SnackPosition.BOTTOM,
                'Settings Exported',
                'Settings have been copied to clipboard',
                backgroundColor: Colors.green,
                colorText: Colors.white,
              );
            },
            child: Text('Copy to Clipboard'),
          ),
        ],
      ),
    );
  }

  void _showImportDialog() {
    final TextEditingController controller = TextEditingController();

    Get.dialog(
      AlertDialog(
        title: Row(
          children: [
            Icon(Icons.upload, color: Colors.blue),
            SizedBox(width: 8),
            Text('Import Settings'),
          ],
        ),
        content: Container(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Paste your exported settings JSON below:'),
              SizedBox(height: 16),
              TextField(
                controller: controller,
                maxLines: 10,
                decoration: InputDecoration(
                  border: OutlineInputBorder(),
                  hintText: 'Paste settings JSON here...',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              try {
                final jsonString = controller.text.trim();
                if (jsonString.isNotEmpty) {
                  settingsController.importSettings(jsonString);
                  Get.back();
                } else {
                  Get.snackbar(
                    snackPosition: SnackPosition.BOTTOM,
                    'Error',
                    'Please paste valid settings JSON',
                    backgroundColor: Colors.red,
                    colorText: Colors.white,
                  );
                }
              } catch (e) {
                Get.snackbar(
                  snackPosition: SnackPosition.BOTTOM,
                  'Import Error',
                  'Invalid JSON format',
                  backgroundColor: Colors.red,
                  colorText: Colors.white,
                );
              }
            },
            child: Text('Import'),
          ),
        ],
      ),
    );
  }

  Widget _buildInstructorSettings() {
    return SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader('Working Hours'),
          _buildSettingsCard([
            _buildTimeTile(
              'Start Time',
              settingsController.workingHoursStart,
              true,
            ),
            _buildTimeTile(
              'End Time',
              settingsController.workingHoursEnd,
              false,
            ),
          ]),
          SizedBox(height: 16),
          _buildSectionHeader('Lesson Scheduling'),
          _buildSettingsCard([
            _buildSwitchTile(
              'Allow Back-to-Back Lessons',
              'Allow consecutive lessons without breaks',
              settingsController.allowBackToBackLessons,
              settingsController.toggleBackToBackLessons,
            ),
          ]),
          SizedBox(height: 16),
          _buildSectionHeader('Break Settings'),
          _buildSettingsCard([
            _buildSliderTile(
              'Break Between Lessons',
              'Minimum break time in minutes',
              settingsController.breakBetweenLessons,
              settingsController.tempBreakBetweenLessons,
              0.0,
              60.0,
              5.0,
              settingsController.updateBreakBetweenLessonsTemp,
              settingsController.commitBreakBetweenLessons,
              (value) => '${value} min',
            ),
          ]),
        ],
      ),
    );
  }

  // Update notification settings with smooth sliders
  Widget _buildNotificationSettings() {
    return SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader('Automatic Notifications'),
          _buildSettingsCard([
            _buildSwitchTile(
              'Auto Attendance Notifications',
              'Send notifications for attendance updates',
              settingsController.autoAttendanceNotifications,
              settingsController.toggleAutoAttendanceNotifications,
            ),
            _buildSwitchTile(
              'Schedule Conflict Alerts',
              'Alert when scheduling conflicts occur',
              settingsController.scheduleConflictAlerts,
              settingsController.toggleScheduleConflictAlerts,
            ),
            _buildSwitchTile(
              'Billing Warnings',
              'Send billing-related notifications',
              settingsController.billingWarnings,
              settingsController.toggleBillingWarnings,
            ),
          ]),
          SizedBox(height: 16),
          _buildSectionHeader('Reminder Settings'),
          _buildSettingsCard([
            _buildSliderTile(
              'Lesson Start Reminder',
              'Minutes before lesson to send reminder',
              settingsController.lessonStartReminder,
              settingsController.tempLessonStartReminder,
              5.0,
              60.0,
              5.0,
              settingsController.updateLessonStartReminderTemp,
              settingsController.commitLessonStartReminder,
              (value) => '${value} min',
            ),
          ]),
          SizedBox(height: 16),
          _buildSectionHeader('Daily Summary'),
          _buildSettingsCard([
            _buildTimeTile(
              'Daily Summary Time',
              settingsController.dailySummaryTime,
              null,
              subtitle: 'Time to send daily summary notifications',
            ),
          ]),
        ],
      ),
    );
  }

  // Update billing settings with smooth sliders
  Widget _buildBillingSettings() {
    return SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader('Billing Warnings'),
          _buildSettingsCard([
            _buildSwitchTile(
              'Show Low Lesson Warning',
              'Alert when student has few lessons remaining',
              settingsController.showLowLessonWarning,
              settingsController.toggleLowLessonWarning,
            ),
            _buildSwitchTile(
              'Prevent Over-Scheduling',
              'Block scheduling when no lessons remain',
              settingsController.preventOverScheduling,
              settingsController.togglePreventOverScheduling,
            ),
          ]),
          SizedBox(height: 16),
          _buildSectionHeader('Billing Automation'),
          _buildSettingsCard([
            _buildSwitchTile(
              'Auto-Create Billing Records',
              'Automatically create billing entries for completed lessons',
              settingsController.autoCreateBillingRecords,
              settingsController.toggleAutoCreateBillingRecords,
            ),
            _buildSwitchTile(
              'Count Scheduled Lessons',
              'Include scheduled lessons in billing calculations',
              settingsController.countScheduledLessons,
              settingsController.toggleCountScheduledLessons,
            ),
          ]),
          SizedBox(height: 16),
          _buildSectionHeader('Thresholds'),
          _buildSettingsCard([
            _buildSliderTile(
              'Low Lesson Threshold',
              'Number of lessons to trigger warning',
              settingsController.lowLessonThreshold,
              settingsController.tempLowLessonThreshold,
              1.0,
              10.0,
              1.0,
              settingsController.updateLowLessonThresholdTemp,
              settingsController.commitLowLessonThreshold,
              (value) => '${value} lesson${value == 1 ? '' : 's'}',
            ),
          ]),
        ],
      ),
    );
  }

  Widget _buildTextFieldTile(
    String title,
    String hintText,
    RxString value,
    IconData icon,
  ) {
    final TextEditingController controller =
        TextEditingController(text: value.value);
    final RxBool hasChanges = false.obs;

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: _colorScheme.primary),
              SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  fontWeight: FontWeight.w500,
                  fontSize: 16,
                ),
              ),
              Spacer(),
              Obx(() => hasChanges.value
                  ? Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: Icon(Icons.close, size: 18),
                          onPressed: () {
                            controller.text = value.value;
                            hasChanges.value = false;
                          },
                          color: _colorScheme.onSurfaceVariant,
                          tooltip: 'Cancel changes',
                        ),
                        IconButton(
                          icon: Icon(Icons.check, size: 18),
                          onPressed: () {
                            // Update the reactive value immediately
                            value.value = controller.text;
                            hasChanges.value = false;

                            // Save individual setting
                            settingsController.saveBusinessSettings();

                            Get.snackbar(
                              snackPosition: SnackPosition.BOTTOM,
                              'Saved',
                              '$title updated successfully',
                              backgroundColor: _colorScheme.secondary,
                              colorText: Colors.white,
                              duration: Duration(seconds: 2),
                            );
                          },
                          color: _colorScheme.secondary,
                          tooltip: 'Save changes',
                        ),
                      ],
                    )
                  : SizedBox.shrink()),
            ],
          ),
          SizedBox(height: 8),
          TextField(
            controller: controller,
            decoration: InputDecoration(
              hintText: hintText,
            ),
            onChanged: (newValue) {
              hasChanges.value = newValue != value.value;
              // Update the reactive value in real-time for the "Save All" button
              value.value = newValue;
            },
          ),
        ],
      ),
    );
  }

  Widget _buildBusinessSettings() {
    return SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader('Business Information'),
          _buildSettingsCard([
            _buildTextFieldTile(
              'Business Name',
              'Enter your driving school name',
              settingsController.businessName,
              Icons.business,
            ),
            _buildTextFieldTile(
              'Address',
              'Street address',
              settingsController.businessAddress,
              Icons.location_on,
            ),
            _buildTextFieldTile(
              'City',
              'City name',
              settingsController.businessCity,
              Icons.location_city,
            ),
            _buildDropdownTile(
              'Country',
              'Select your country',
              settingsController.businessCountry,
              [
                'Zimbabwe',
              ],
              (value) {
                settingsController.businessCountry.value = value;
                settingsController.saveBusinessSettings();
              },
              (value) => value,
            ),
          ]),
          SizedBox(height: 16),
          _buildSectionHeader('Contact Information'),
          _buildSettingsCard([
            _buildTextFieldTile(
              'Phone Number',
              'Business phone number',
              settingsController.businessPhone,
              Icons.phone,
            ),
            _buildTextFieldTile(
              'Email',
              'Business email address',
              settingsController.businessEmail,
              Icons.email,
            ),
            _buildTextFieldTile(
              'Website',
              'Business website (optional)',
              settingsController.businessWebsite,
              Icons.language,
            ),
          ]),
          SizedBox(height: 16),
          _buildSectionHeader('Operating Days'),
          _buildSettingsCard([
            _buildDaysOfWeekSelector(),
          ]),
          SizedBox(height: 16),
          _buildSectionHeader('Business Hours'),
          _buildSettingsCard([
            _buildTimeTile(
              'Business Start Time',
              settingsController.businessStartTime,
              true,
              subtitle: 'When your business opens',
            ),
            _buildTimeTile(
              'Business End Time',
              settingsController.businessEndTime,
              false,
              subtitle: 'When your business closes',
            ),
          ]),
          SizedBox(height: 24),
          // Save All Button
          Center(
            child: ElevatedButton.icon(
              onPressed: () async {
                print('Save button pressed');

                try {
                  await Future.delayed(Duration(milliseconds: 100));

                  await settingsController.saveAllBusinessSettings();

                  // Then show success message
                  Get.snackbar(
                    snackPosition: SnackPosition.BOTTOM,
                    'Success',
                    'All business settings saved successfully',
                    backgroundColor: _colorScheme.secondary,
                    colorText: Colors.white,
                    icon: Icon(Icons.check_circle, color: Colors.white),
                    duration: Duration(seconds: 3),
                  );
                } catch (e) {
                  print('Save failed with error: $e');

                  // Then show error message
                  Get.snackbar(
                    snackPosition: SnackPosition.BOTTOM,
                    'Error',
                    'Failed to save settings: ${e.toString()}',
                    backgroundColor: _colorScheme.error,
                    colorText: Colors.white,
                    icon: Icon(Icons.error, color: Colors.white),
                    duration: Duration(seconds: 3),
                  );
                }
              },
              icon: Icon(Icons.save_alt),
              label: Text('Save All Settings'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
          SizedBox(height: 32),
          _buildSectionHeader('Developer Information'),
          _buildSettingsCard([
            _buildDeveloperInfo(),
          ]),
          SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildDeveloperInfo() {
    return Padding(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.code, size: 20, color: Colors.blue[700]),
              SizedBox(width: 8),
              Text(
                'Developed by CodzLabZim',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                  color: Colors.blue[700],
                ),
              ),
            ],
          ),
          SizedBox(height: 16),
          // Email
          InkWell(
            onTap: () async {
              final Uri emailUri = Uri(
                scheme: 'mailto',
                path: 'support@drivesyncpro.co.zw',
              );
              if (await canLaunchUrl(emailUri)) {
                await launchUrl(emailUri);
              } else {
                Get.snackbar(
                  'Error',
                  'Could not open email app',
                  snackPosition: SnackPosition.BOTTOM,
                  backgroundColor: Colors.red,
                  colorText: Colors.white,
                );
              }
            },
            child: Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: Row(
                children: [
                  Icon(Icons.email, color: Colors.blue[600], size: 20),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'support@drivesyncpro.co.zw',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.blue[700],
                      ),
                    ),
                  ),
                  Icon(Icons.open_in_new, size: 16, color: Colors.grey[600]),
                ],
              ),
            ),
          ),
          SizedBox(height: 12),
          // WhatsApp
          InkWell(
            onTap: () async {
              final Uri whatsappUri = Uri.parse('https://wa.me/2630784666891');
              if (await canLaunchUrl(whatsappUri)) {
                await launchUrl(whatsappUri,
                    mode: LaunchMode.externalApplication);
              } else {
                Get.snackbar(
                  'Error',
                  'Could not open WhatsApp',
                  snackPosition: SnackPosition.BOTTOM,
                  backgroundColor: Colors.red,
                  colorText: Colors.white,
                );
              }
            },
            child: Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.green[300]!),
              ),
              child: Row(
                children: [
                  Icon(Icons.chat, color: Colors.green[700], size: 20),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Contact on WhatsApp',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: Colors.green[700],
                          ),
                        ),
                        Text(
                          '+263 78 466 6891',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.green[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.open_in_new, size: 16, color: Colors.grey[600]),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDaysOfWeekSelector() {
    final List<String> daysOfWeek = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday'
    ];

    return Padding(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.calendar_today, size: 20, color: Colors.blue[700]),
              SizedBox(width: 8),
              Text(
                'Operating Days',
                style: TextStyle(
                  fontWeight: FontWeight.w500,
                  fontSize: 16,
                ),
              ),
              Spacer(),
              TextButton.icon(
                onPressed: () {
                  settingsController.saveBusinessSettings();
                  Get.snackbar(
                    snackPosition: SnackPosition.BOTTOM,
                    'Saved',
                    'Operating days updated',
                    backgroundColor: Colors.green,
                    colorText: Colors.white,
                  );
                },
                icon: Icon(Icons.save, size: 16),
                label: Text('Save'),
                style: TextButton.styleFrom(
                  foregroundColor: Colors.blue[700],
                ),
              ),
            ],
          ),
          SizedBox(height: 12),
          Text(
            'Select the days your business operates',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
            ),
          ),
          SizedBox(height: 16),
          Obx(() => Wrap(
                spacing: 8,
                runSpacing: 8,
                children: daysOfWeek.map((day) {
                  final isSelected =
                      settingsController.operatingDays.contains(day);
                  return FilterChip(
                    label: Text(
                      day.substring(0, 3),
                      style: TextStyle(
                        color: isSelected ? Colors.white : Colors.blue[700],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    selected: isSelected,
                    onSelected: (selected) {
                      if (selected) {
                        if (!settingsController.operatingDays.contains(day)) {
                          settingsController.operatingDays.add(day);
                        }
                      } else {
                        settingsController.operatingDays.remove(day);
                      }
                    },
                    selectedColor: Colors.blue[700],
                    checkmarkColor: Colors.white,
                    backgroundColor: Colors.blue[50],
                    side: BorderSide(color: Colors.blue[300]!),
                  );
                }).toList(),
              )),
          Obx(() => settingsController.operatingDays.isEmpty
              ? Container(
                  margin: EdgeInsets.only(top: 8),
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.orange[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.orange[200]!),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.warning, size: 16, color: Colors.orange[700]),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Please select at least one operating day',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.orange[700],
                          ),
                        ),
                      ),
                    ],
                  ),
                )
              : SizedBox.shrink()),
        ],
      ),
    );
  }
}
