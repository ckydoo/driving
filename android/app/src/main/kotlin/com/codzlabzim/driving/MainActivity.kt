package com.codzlabzim.driving

import android.Manifest
import android.bluetooth.BluetoothAdapter
import android.bluetooth.BluetoothDevice
import android.bluetooth.BluetoothManager
import android.content.pm.PackageManager
import android.os.Build
import android.os.Bundle
import androidx.core.app.ActivityCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import com.dantsu.escposprinter.connection.bluetooth.BluetoothConnection
import com.dantsu.escposprinter.connection.bluetooth.BluetoothPrintersConnections
import com.dantsu.escposprinter.EscPosPrinter
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext

class MainActivity: FlutterActivity() {
    private val CHANNEL = "com.codzlabzim.driving/printing"
    
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "printReceipt" -> {
                    // Run printing in background thread to avoid UI freeze
                    CoroutineScope(Dispatchers.Main).launch {
                        try {
                            val content = call.argument<String>("content") ?: ""
                            val printerName = call.argument<String>("printerName") ?: ""
                            val paperSize = call.argument<String>("paperSize") ?: "80mm"
                            
                            // Execute print operation on IO thread
                            withContext(Dispatchers.IO) {
                                printReceipt(content, printerName, paperSize)
                            }
                            
                            // Return success on main thread
                            result.success(true)
                        } catch (e: Exception) {
                            result.error("PRINT_ERROR", e.message, null)
                        }
                    }
                }
                
                "discoverPrinters" -> {
                    CoroutineScope(Dispatchers.Main).launch {
                        try {
                            val type = call.argument<String>("type") ?: "all"
                            
                            val printers = withContext(Dispatchers.IO) {
                                discoverPrinters(type)
                            }
                            
                            result.success(printers)
                        } catch (e: Exception) {
                            result.error("DISCOVER_ERROR", e.message, null)
                        }
                    }
                }
                
                "verifyPrinter" -> {
                    CoroutineScope(Dispatchers.Main).launch {
                        try {
                            val printerName = call.argument<String>("printerName") ?: ""
                            
                            val isValid = withContext(Dispatchers.IO) {
                                verifyPrinter(printerName)
                            }
                            
                            result.success(isValid)
                        } catch (e: Exception) {
                            result.error("VERIFY_ERROR", e.message, null)
                        }
                    }
                }
                
                else -> result.notImplemented()
            }
        }
    }

    // Print receipt (runs on background thread)
    private fun printReceipt(content: String, printerName: String, paperSize: String) {
        try {
            println("🖨️ Starting print operation...")
            
            // Check Bluetooth permissions
            if (!checkBluetoothPermissions()) {
                println("⚠️ Bluetooth permissions not granted")
                throw Exception("Bluetooth permissions required. Please grant permissions in settings.")
            }

            // Get Bluetooth connection
            val bluetoothConnection = BluetoothPrintersConnections.selectFirstPaired()
            
            if (bluetoothConnection == null) {
                throw Exception("No paired Bluetooth printer found. Please pair your printer in Bluetooth settings.")
            }

            println("📱 Found Bluetooth printer")

            // Determine paper width (in characters)
            val paperWidth = when (paperSize) {
                "58mm" -> 32
                "80mm" -> 48
                else -> 32
            }

            println("📄 Paper size: $paperSize ($paperWidth chars)")

            // Create ESC/POS printer instance
            val printer = EscPosPrinter(
                bluetoothConnection,
                203, // DPI for most thermal printers
                paperWidth.toFloat(),
                paperWidth // Characters per line
            )

            // Format and print the receipt
            println("📝 Formatting receipt...")
            val formattedContent = formatReceiptForEscPos(content)
            
            println("🖨️ Sending to printer...")
            printer.printFormattedTextAndCut(formattedContent)

            println("✅ Receipt printed successfully!")
            
        } catch (e: Exception) {
            println("❌ Error printing receipt: ${e.message}")
            e.printStackTrace()
            throw e
        }
    }

    // Discover printers by type (runs on background thread)
    private fun discoverPrinters(type: String): List<Map<String, String>> {
        val printers = mutableListOf<Map<String, String>>()
        
        try {
            when (type.lowercase()) {
                "bluetooth" -> {
                    if (checkBluetoothPermissions()) {
                        printers.addAll(getBluetoothPrinters())
                    }
                }
                "usb" -> {
                    // USB printer discovery would go here
                    // For now, return empty list
                }
                "network" -> {
                    // Network printer discovery would go here
                    // For now, return empty list
                }
                else -> {
                    // Discover all types
                    if (checkBluetoothPermissions()) {
                        printers.addAll(getBluetoothPrinters())
                    }
                }
            }
        } catch (e: Exception) {
            println("❌ Error discovering printers: ${e.message}")
        }
        
        return printers
    }

    // Get Bluetooth printers
    private fun getBluetoothPrinters(): List<Map<String, String>> {
        val printers = mutableListOf<Map<String, String>>()
        
        try {
            println("🔍 Starting Bluetooth printer search...")
            
            // Check permissions again
            if (!checkBluetoothPermissions()) {
                println("❌ Bluetooth permissions NOT granted")
                println("   Please grant Bluetooth permissions in app settings")
                return printers
            }
            println("✅ Bluetooth permissions granted")

            // Get Bluetooth adapter
            val bluetoothManager = getSystemService(BLUETOOTH_SERVICE) as BluetoothManager
            val bluetoothAdapter = bluetoothManager.adapter
            
            if (bluetoothAdapter == null) {
                println("❌ Bluetooth adapter is NULL - device may not support Bluetooth")
                return printers
            }
            println("✅ Bluetooth adapter obtained")
            
            if (!bluetoothAdapter.isEnabled) {
                println("❌ Bluetooth is NOT enabled - please turn on Bluetooth")
                return printers
            }
            println("✅ Bluetooth is enabled")

            // Get paired devices - THIS REQUIRES BLUETOOTH_CONNECT PERMISSION
            val pairedDevices: Set<BluetoothDevice> = try {
                bluetoothAdapter.bondedDevices
            } catch (e: SecurityException) {
                println("❌ SecurityException getting bonded devices: ${e.message}")
                println("   This usually means BLUETOOTH_CONNECT permission is not granted")
                return printers
            }
            
            println("📱 Found ${pairedDevices.size} paired Bluetooth devices total")
            
            if (pairedDevices.isEmpty()) {
                println("⚠️ No paired Bluetooth devices found")
                println("   Please pair your printer in device Bluetooth settings first")
                return printers
            }
            
            // List all paired devices
            for (device in pairedDevices) {
                try {
                    val deviceName = device.name ?: "Unknown Device"
                    val deviceAddress = device.address ?: "No Address"
                    
                    println("📱 Device: $deviceName")
                    println("   Address: $deviceAddress")
                    println("   Type: ${device.type}")
                    println("   Bond State: ${device.bondState}")
                    
                    // Check if it's a printer
                    if (isPrinterDevice(deviceName)) {
                        println("   ✅ Adding as printer")
                        printers.add(mapOf(
                            "name" to deviceName,
                            "type" to "Bluetooth",
                            "description" to deviceAddress
                        ))
                    } else {
                        println("   ⏭️ Skipping (not identified as printer)")
                    }
                } catch (e: SecurityException) {
                    println("❌ SecurityException accessing device: ${e.message}")
                }
            }
            
            println("✅ Total printers found: ${printers.size}")
            
        } catch (e: SecurityException) {
            println("❌ Security exception getting Bluetooth devices: ${e.message}")
            println("   Stack trace:")
            e.printStackTrace()
        } catch (e: Exception) {
            println("❌ Error getting Bluetooth printers: ${e.message}")
            println("   Stack trace:")
            e.printStackTrace()
        }
        
        return printers
    }

    // Check if device name suggests it's a printer
    private fun isPrinterDevice(deviceName: String): Boolean {
    val printerKeywords = listOf(
        "printer", "print", "pos", "receipt", 
        "thermal", "bluetooth", "rpp", "mpt",
        "escpos", "zjiang", "goojprt", "xprinter",
        "bt", "wireless"
    )
    
    val lowerName = deviceName.lowercase()
    return printerKeywords.any { lowerName.contains(it) }
}

    // Verify printer connection (runs on background thread)
    private fun verifyPrinter(printerName: String): Boolean {
        return try {
            if (!checkBluetoothPermissions()) {
                false
            } else {
                val connection = BluetoothPrintersConnections.selectFirstPaired()
                connection != null
            }
        } catch (e: Exception) {
            println("❌ Error verifying printer: ${e.message}")
            false
        }
    }

    // Format receipt content for ESC/POS
    private fun formatReceiptForEscPos(content: String): String {
        // ESC/POS formatting commands:
        // [C] = Center align
        // [L] = Left align
        // [R] = Right align
        return "[L]$content"
    }

    // Check Bluetooth permissions
    private fun checkBluetoothPermissions(): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            // Android 12+
            ActivityCompat.checkSelfPermission(this, Manifest.permission.BLUETOOTH_CONNECT) == PackageManager.PERMISSION_GRANTED &&
            ActivityCompat.checkSelfPermission(this, Manifest.permission.BLUETOOTH_SCAN) == PackageManager.PERMISSION_GRANTED
        } else {
            // Android 11 and below
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
                1
            )
        } else {
            ActivityCompat.requestPermissions(
                this,
                arrayOf(
                    Manifest.permission.BLUETOOTH,
                    Manifest.permission.BLUETOOTH_ADMIN
                ),
                1
            )
        }
    }
}