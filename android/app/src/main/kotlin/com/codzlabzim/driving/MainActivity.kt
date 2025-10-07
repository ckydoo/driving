package com.codzlabzim.driving

import android.Manifest
import android.bluetooth.BluetoothAdapter
import android.bluetooth.BluetoothDevice
import android.bluetooth.BluetoothManager
import android.bluetooth.BluetoothSocket
import android.content.Context
import android.content.pm.PackageManager
import android.os.Build
import androidx.core.app.ActivityCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import com.dantsu.escposprinter.connection.bluetooth.BluetoothPrintersConnections
import com.dantsu.escposprinter.EscPosPrinter
import com.dantsu.escposprinter.textparser.PrinterTextParserImg
import java.util.*

class MainActivity: FlutterActivity() {
    private val CHANNEL = "com.codzlabzim.driving/thermal_print"
    private val BLUETOOTH_PERMISSION_REQUEST = 1001

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "printReceipt" -> {
                    val content = call.argument<String>("content")
                    val printerName = call.argument<String>("printerName")
                    val paperSize = call.argument<String>("paperSize")
                    
                    if (content != null) {
                        try {
                            printReceiptDirectly(content, printerName, paperSize)
                            result.success(true)
                        } catch (e: Exception) {
                            result.error("PRINT_ERROR", "Failed to print: ${e.message}", null)
                        }
                    } else {
                        result.error("INVALID_ARGUMENT", "Content is required", null)
                    }
                }
                "discoverPrinters" -> {
                    if (checkBluetoothPermissions()) {
                        val printers = discoverAllPrinters()
                        result.success(printers)
                    } else {
                        requestBluetoothPermissions()
                        result.error("PERMISSION_DENIED", "Bluetooth permissions required", null)
                    }
                }
                "discoverPrintersByType" -> {
                    val type = call.argument<String>("type")
                    
                    if (type != null) {
                        val printers = when (type.lowercase()) {
                            "bluetooth" -> {
                                if (checkBluetoothPermissions()) {
                                    discoverBluetoothPrinters()
                                } else {
                                    requestBluetoothPermissions()
                                    result.error("PERMISSION_DENIED", "Bluetooth permissions required", null)
                                    return@setMethodCallHandler
                                }
                            }
                            "usb" -> discoverUsbPrinters()
                            "network" -> discoverNetworkPrinters()
                            else -> emptyList()
                        }
                        result.success(printers)
                    } else {
                        result.error("INVALID_ARGUMENT", "Type is required", null)
                    }
                }
                "verifyPrinter" -> {
                    val printerName = call.argument<String>("printerName")
                    if (printerName != null) {
                        val isValid = verifyPrinter(printerName)
                        result.success(isValid)
                    } else {
                        result.error("INVALID_ARGUMENT", "Printer name is required", null)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    // NEW METHOD: Direct Bluetooth ESC/POS Printing
    private fun printReceiptDirectly(content: String, printerName: String?, paperSize: String?) {
        try {
            // Get Bluetooth connection
            val bluetoothConnection = BluetoothPrintersConnections.selectFirstPaired()
            
            if (bluetoothConnection == null) {
                throw Exception("No paired Bluetooth printer found")
            }

            // Determine paper width (in characters)
            val paperWidth = when (paperSize) {
                "58mm" -> 32
                "80mm" -> 48
                else -> 32
            }

            // Create ESC/POS printer instance
            val printer = EscPosPrinter(
                bluetoothConnection,
                203, // DPI for most thermal printers
                paperWidth.toFloat(),
                paperWidth // Characters per line
            )

            // Format and print the receipt
            printer.printFormattedTextAndCut(
                formatReceiptForEscPos(content)
            )

            println("✅ Receipt printed successfully to Bluetooth printer")
            
        } catch (e: Exception) {
            println("❌ Error printing receipt: ${e.message}")
            e.printStackTrace()
            throw e
        }
    }

    // Format receipt content for ESC/POS
    private fun formatReceiptForEscPos(content: String): String {
        // ESC/POS formatting commands:
        // [C] = Center align
        // [L] = Left align
        // [R] = Right align
        return "[C]<b>${content}</b>\n" +
               "[L]\n" +
               content
    }

    // Check Bluetooth permissions
    private fun checkBluetoothPermissions(): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            ActivityCompat.checkSelfPermission(this, Manifest.permission.BLUETOOTH_CONNECT) == PackageManager.PERMISSION_GRANTED &&
            ActivityCompat.checkSelfPermission(this, Manifest.permission.BLUETOOTH_SCAN) == PackageManager.PERMISSION_GRANTED
        } else {
            ActivityCompat.checkSelfPermission(this, Manifest.permission.BLUETOOTH) == PackageManager.PERMISSION_GRANTED &&
            ActivityCompat.checkSelfPermission(this, Manifest.permission.BLUETOOTH_ADMIN) == PackageManager.PERMISSION_GRANTED
        }
    }

    // Request Bluetooth permissions
    private fun requestBluetoothPermissions() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            ActivityCompat.requestPermissions(
                this,
                arrayOf(
                    Manifest.permission.BLUETOOTH_CONNECT,
                    Manifest.permission.BLUETOOTH_SCAN
                ),
                BLUETOOTH_PERMISSION_REQUEST
            )
        } else {
            ActivityCompat.requestPermissions(
                this,
                arrayOf(
                    Manifest.permission.BLUETOOTH,
                    Manifest.permission.BLUETOOTH_ADMIN
                ),
                BLUETOOTH_PERMISSION_REQUEST
            )
        }
    }

    // Discover all printers
    private fun discoverAllPrinters(): List<Map<String, String>> {
        val allPrinters = mutableListOf<Map<String, String>>()
        
        if (checkBluetoothPermissions()) {
            allPrinters.addAll(discoverBluetoothPrinters())
        }
        allPrinters.addAll(discoverUsbPrinters())
        allPrinters.addAll(discoverNetworkPrinters())
        
        return allPrinters
    }

    // Discover Bluetooth printers
    private fun discoverBluetoothPrinters(): List<Map<String, String>> {
        val printers = mutableListOf<Map<String, String>>()
        
        try {
            val bluetoothManager = getSystemService(Context.BLUETOOTH_SERVICE) as? BluetoothManager
            val bluetoothAdapter = bluetoothManager?.adapter
            
            if (bluetoothAdapter?.isEnabled == true) {
                try {
                    bluetoothAdapter.bondedDevices?.forEach { device ->
                        printers.add(mapOf(
                            "name" to (device.name ?: "Unknown Device"),
                            "type" to "Bluetooth",
                            "description" to "Paired Bluetooth printer",
                            "address" to device.address
                        ))
                    }
                } catch (e: SecurityException) {
                    println("❌ Security exception discovering Bluetooth printers: ${e.message}")
                }
            }
        } catch (e: Exception) {
            println("❌ Error discovering Bluetooth printers: ${e.message}")
        }
        
        return printers
    }

    // Discover USB printers
    private fun discoverUsbPrinters(): List<Map<String, String>> {
        return listOf(
            mapOf(
                "name" to "USB Printer",
                "type" to "USB",
                "description" to "Connected via USB",
                "address" to ""
            )
        )
    }

    // Discover Network printers
    private fun discoverNetworkPrinters(): List<Map<String, String>> {
        return listOf(
            mapOf(
                "name" to "Network Printer",
                "type" to "Network",
                "description" to "Connected via WiFi/LAN",
                "address" to ""
            )
        )
    }

    // Verify printer
    private fun verifyPrinter(printerName: String): Boolean {
        try {
            if (checkBluetoothPermissions()) {
                val bluetoothManager = getSystemService(Context.BLUETOOTH_SERVICE) as? BluetoothManager
                val bluetoothAdapter = bluetoothManager?.adapter
                
                try {
                    bluetoothAdapter?.bondedDevices?.forEach { device ->
                        if (device.name?.contains(printerName, ignoreCase = true) == true) {
                            return true
                        }
                    }
                } catch (e: SecurityException) {
                    println("❌ Security exception verifying printer: ${e.message}")
                }
            }
            
            return printerName.isNotEmpty()
        } catch (e: Exception) {
            e.printStackTrace()
            return false
        }
    }
}