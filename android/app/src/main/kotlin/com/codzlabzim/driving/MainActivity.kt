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
    private val BLUETOOTH_PERMISSION_REQUEST_CODE = 1001
    private var pendingResult: MethodChannel.Result? = null
    private var pendingDiscoverType: String? = null
    
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "requestBluetoothPermissions" -> {
                    if (checkBluetoothPermissions()) {
                        result.success(true)
                    } else {
                        pendingResult = result
                        requestBluetoothPermissions()
                    }
                }
                
                "checkBluetoothPermissions" -> {
                    result.success(checkBluetoothPermissions())
                }
                
                "printReceipt" -> {
                    CoroutineScope(Dispatchers.Main).launch {
                        try {
                            val content = call.argument<String>("content") ?: ""
                            val printerName = call.argument<String>("printerName") ?: ""
                            val paperSize = call.argument<String>("paperSize") ?: "80mm"
                            
                            if (!checkBluetoothPermissions()) {
                                result.error("PERMISSION_ERROR", "Bluetooth permissions not granted", null)
                                return@launch
                            }
                            
                            withContext(Dispatchers.IO) {
                                printReceipt(content, printerName, paperSize)
                            }
                            
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
                            
                            if (!checkBluetoothPermissions()) {
                                pendingResult = result
                                pendingDiscoverType = type
                                requestBluetoothPermissions()
                                return@launch
                            }
                            
                            val printers = withContext(Dispatchers.IO) {
                                discoverPrinters(type)
                            }
                            
                            result.success(printers)
                        } catch (e: Exception) {
                            result.error("DISCOVER_ERROR", e.message, null)
                        }
                    }
                }
                
                "getAllBluetoothDevices" -> {
                    CoroutineScope(Dispatchers.Main).launch {
                        try {
                            if (!checkBluetoothPermissions()) {
                                pendingResult = result
                                requestBluetoothPermissions()
                                return@launch
                            }
                            
                            val devices = withContext(Dispatchers.IO) {
                                getAllBluetoothDevices()
                            }
                            
                            result.success(devices)
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

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        
        if (requestCode == BLUETOOTH_PERMISSION_REQUEST_CODE) {
            val allGranted = grantResults.isNotEmpty() && 
                           grantResults.all { it == PackageManager.PERMISSION_GRANTED }
            
            println("🔐 Permission result: ${if (allGranted) "GRANTED" else "DENIED"}")
            
            if (pendingResult != null) {
                if (pendingDiscoverType != null && allGranted) {
                    CoroutineScope(Dispatchers.Main).launch {
                        try {
                            val printers = withContext(Dispatchers.IO) {
                                discoverPrinters(pendingDiscoverType!!)
                            }
                            pendingResult?.success(printers)
                        } catch (e: Exception) {
                            pendingResult?.error("DISCOVER_ERROR", e.message, null)
                        } finally {
                            pendingResult = null
                            pendingDiscoverType = null
                        }
                    }
                } else {
                    pendingResult?.success(allGranted)
                    pendingResult = null
                }
            }
        }
    }



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
                }
                "network" -> {
                    // Network printer discovery would go here
                }
                else -> {
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

    private fun getAllBluetoothDevices(): List<Map<String, String>> {
        val devices = mutableListOf<Map<String, String>>()
        
        try {
            println("🔍 Getting ALL Bluetooth devices...")
            
            if (!checkBluetoothPermissions()) {
                println("❌ Bluetooth permissions NOT granted")
                return devices
            }

            val bluetoothManager = getSystemService(BLUETOOTH_SERVICE) as BluetoothManager
            val bluetoothAdapter = bluetoothManager.adapter
            
            if (bluetoothAdapter == null || !bluetoothAdapter.isEnabled) {
                println("❌ Bluetooth not available")
                return devices
            }

            val pairedDevices: Set<BluetoothDevice> = try {
                bluetoothAdapter.bondedDevices
            } catch (e: SecurityException) {
                println("❌ SecurityException: ${e.message}")
                return devices
            }
            
            println("📱 Found ${pairedDevices.size} paired devices")
            
            for (device in pairedDevices) {
                try {
                    val deviceName = device.name ?: "Unknown Device"
                    val deviceAddress = device.address ?: "No Address"
                    val deviceClass = device.bluetoothClass?.deviceClass ?: 0
                    
                    println("📱 Device: $deviceName ($deviceAddress)")
                    
                    val isProbablyPrinter = isPrinterDevice(deviceName) || isPrinterByClass(deviceClass)
                    
                    devices.add(mapOf(
                        "name" to deviceName,
                        "type" to "Bluetooth",
                        "description" to deviceAddress,
                        "isPrinter" to isProbablyPrinter.toString(),
                        "deviceClass" to deviceClass.toString()
                    ))
                } catch (e: SecurityException) {
                    println("❌ SecurityException: ${e.message}")
                }
            }
            
            println("✅ Total devices found: ${devices.size}")
            
        } catch (e: Exception) {
            println("❌ Error: ${e.message}")
            e.printStackTrace()
        }
        
        return devices
    }

    private fun getBluetoothPrinters(): List<Map<String, String>> {
        val printers = mutableListOf<Map<String, String>>()
        
        try {
            println("🔍 Starting Bluetooth printer search...")
            
            if (!checkBluetoothPermissions()) {
                println("❌ Bluetooth permissions NOT granted")
                return printers
            }

            val bluetoothManager = getSystemService(BLUETOOTH_SERVICE) as BluetoothManager
            val bluetoothAdapter = bluetoothManager.adapter
            
            if (bluetoothAdapter == null) {
                println("❌ Bluetooth adapter is NULL")
                return printers
            }
            
            if (!bluetoothAdapter.isEnabled) {
                println("❌ Bluetooth is NOT enabled")
                return printers
            }

            val pairedDevices: Set<BluetoothDevice> = try {
                bluetoothAdapter.bondedDevices
            } catch (e: SecurityException) {
                println("❌ SecurityException: ${e.message}")
                return printers
            }
            
            println("📱 Found ${pairedDevices.size} paired Bluetooth devices")
            
            if (pairedDevices.isEmpty()) {
                println("⚠️ No paired Bluetooth devices found")
                return printers
            }
            
            for (device in pairedDevices) {
                try {
                    val deviceName = device.name ?: "Unknown Device"
                    val deviceAddress = device.address ?: "No Address"
                    val deviceClass = device.bluetoothClass?.deviceClass ?: 0
                    
                    println("📱 Device: $deviceName")
                    println("   Address: $deviceAddress")
                    println("   Class: $deviceClass")
                    println("   Type: ${device.type}")
                    println("   Bond State: ${device.bondState}")
                    
                    // Check for specific printer model (CY-BX58D)
                    if (deviceName.contains("CY-BX", ignoreCase = true) || 
                        deviceName.contains("58D", ignoreCase = true) ||
                        deviceName.contains("CY", ignoreCase = true)) {
                        println("   ✅ Matched CY-BX58D printer model")
                        printers.add(mapOf(
                            "name" to deviceName,
                            "type" to "Bluetooth",
                            "description" to deviceAddress
                        ))
                        continue
                    }
                    
                    // Check general printer detection
                    val isPrinterByName = isPrinterDevice(deviceName)
                    val isPrinterByDeviceClass = isPrinterByClass(deviceClass)
                    val isPrinter = isPrinterByName || isPrinterByDeviceClass
                    
                    if (isPrinter) {
                        println("   ✅ Adding device (detected as printer)")
                        printers.add(mapOf(
                            "name" to deviceName,
                            "type" to "Bluetooth",
                            "description" to deviceAddress
                        ))
                    } else {
                        println("   ⏭️ Skipping (not identified as printer)")
                    }
                } catch (e: SecurityException) {
                    println("❌ SecurityException: ${e.message}")
                }
            }
            
            println("✅ Total printers found: ${printers.size}")
            
        } catch (e: Exception) {
            println("❌ Error: ${e.message}")
            e.printStackTrace()
        }
        
        return printers
    }

    private fun isPrinterDevice(deviceName: String): Boolean {
        val printerKeywords = listOf(
            // Common printer terms
            "printer", "print", "pos", "receipt", 
            "thermal", "escpos", "esc/pos",
            
            // Printer brands and models
            "zjiang", "goojprt", "xprinter", "epson",
            "star", "bixolon", "citizen", "custom",
            "sam4s", "snbc", "sewoo", "posbank",
            "hp", "canon", "brother",
            
            // Model prefixes
            "rpp", "mpt", "bt", "tmp", "tsp",
            "ct", "crp", "mrp", "lk", "zj",
            "cy", "bx",
            
            // Descriptor terms
            "mobile", "portable", "wireless",
            "58mm", "80mm", "label", "58d" 
        )
        
        val lowerName = deviceName.lowercase()
        val matches = printerKeywords.filter { lowerName.contains(it) }
        
        if (matches.isNotEmpty()) {
            println("   🎯 Matched keywords: $matches")
            return true
        }
        
        return false
    }

    private fun isPrinterByClass(deviceClass: Int): Boolean {
        val majorClass = (deviceClass and 0x1F00) shr 8
        
        if (majorClass == 0x06) {
            println("   🎯 Device class indicates imaging device (likely printer)")
            return true
        }
        
        return false
    }

private fun verifyPrinter(printerName: String): Boolean {
    var connection: BluetoothConnection? = null
    return try {
        if (!checkBluetoothPermissions()) {
            println("❌ Bluetooth permissions not granted")
            false
        } else {
            println("🔍 Verifying printer: $printerName")
            
            // Find the specific device by name
            val device = findBluetoothDeviceByName(printerName)
            
            if (device == null) {
                println("❌ Printer not found: $printerName")
                false
            } else {
                println("📱 Found printer device: ${device.name} (${device.address})")
                
                // Create connection to specific device
                connection = BluetoothConnection(device)
                
                println("🔗 Attempting connection...")
                connection.connect()
                val isConnected = connection.isConnected
                
                if (isConnected) {
                    println("✅ Printer verified and connected")
                } else {
                    println("❌ Printer found but couldn't connect")
                }
                
                connection.disconnect()
                isConnected
            }
        }
    } catch (e: Exception) {
        println("❌ Error verifying printer: ${e.message}")
        e.printStackTrace()
        false
    } finally {
        try {
            connection?.disconnect()
        } catch (e: Exception) {
            // Ignore disconnect errors
        }
    }
}

private fun printReceipt(content: String, printerName: String, paperSize: String) {
    var bluetoothConnection: BluetoothConnection? = null
    
    try {
        println("🖨️ Starting print operation...")
        println("   Content length: ${content.length}")
        println("   Printer: $printerName")
        println("   Paper: $paperSize")
        
        if (!checkBluetoothPermissions()) {
            println("⚠️ Bluetooth permissions not granted")
            throw Exception("Bluetooth permissions required. Please grant permissions in settings.")
        }
        println("✅ Bluetooth permissions OK")

        val device = findBluetoothDeviceByName(printerName)
        
        if (device == null) {
            println("❌ Printer not found: $printerName")
            throw Exception("Printer '$printerName' not found. Please check Bluetooth settings.")
        }
        
        println("📱 Found printer: ${device.name} (${device.address})")
        
        bluetoothConnection = BluetoothConnection(device)
        
        println("🔗 Connecting to printer...")
        bluetoothConnection.connect()
        
        if (!bluetoothConnection.isConnected) {
            println("❌ Failed to establish connection")
            throw Exception("Printer not ready. Please ensure:\n• Printer is ON\n• Printer has paper\n• Bluetooth is enabled")
        }
        println("✅ Connected successfully")

        val paperWidth = when (paperSize) {
            "58mm" -> 32
            "80mm" -> 48
            else -> 32
        }
        println("📄 Paper size: $paperSize ($paperWidth chars)")

        val printer = EscPosPrinter(
            bluetoothConnection,
            203,
            paperWidth.toFloat(),
            paperWidth
        )
        println("🖨️ Printer instance created")

        println("📝 Formatting receipt...")
        val formattedContent = formatReceiptForEscPos(content)
        
        // ⭐ Simple: Just print with feed lines, no cut
        println("🖨️ Sending to printer...")
        printer.printFormattedText(formattedContent + "\n\n\n\n\n")
        
        // Short delay to ensure data is sent
        Thread.sleep(200)

        println("✅ Receipt printed successfully!")
        
    } catch (e: Exception) {
        println("❌ Error printing receipt: ${e.message}")
        e.printStackTrace()
        throw Exception(e.message ?: "Print failed")
        
    } finally {
        try {
            bluetoothConnection?.disconnect()
            println("🔌 Disconnected from printer")
        } catch (e: Exception) {
            println("⚠️ Error disconnecting: ${e.message}")
        }
    }
}

private fun findBluetoothDeviceByName(deviceName: String): BluetoothDevice? {
    return try {
        if (!checkBluetoothPermissions()) {
            println("❌ No Bluetooth permissions")
            return null
        }

        val bluetoothManager = getSystemService(BLUETOOTH_SERVICE) as BluetoothManager
        val bluetoothAdapter = bluetoothManager.adapter
        
        if (bluetoothAdapter == null || !bluetoothAdapter.isEnabled) {
            println("❌ Bluetooth not available")
            return null
        }

        val pairedDevices = bluetoothAdapter.bondedDevices
        
        // Find exact match first
        var device = pairedDevices.find { it.name == deviceName }
        
        // If no exact match, try partial match
        if (device == null) {
            device = pairedDevices.find { 
                it.name?.contains(deviceName, ignoreCase = true) == true 
            }
        }
        
        if (device != null) {
            println("✅ Found device: ${device.name} (${device.address})")
        } else {
            println("❌ Device not found: $deviceName")
            println("   Available devices: ${pairedDevices.map { it.name }.joinToString()}")
        }
        
        device
        
    } catch (e: Exception) {
        println("❌ Error finding device: ${e.message}")
        null
    }
}
    private fun formatReceiptForEscPos(content: String): String {
        return "[L]$content"
    }

    private fun checkBluetoothPermissions(): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            ActivityCompat.checkSelfPermission(this, Manifest.permission.BLUETOOTH_CONNECT) == PackageManager.PERMISSION_GRANTED &&
            ActivityCompat.checkSelfPermission(this, Manifest.permission.BLUETOOTH_SCAN) == PackageManager.PERMISSION_GRANTED
        } else {
            ActivityCompat.checkSelfPermission(this, Manifest.permission.BLUETOOTH) == PackageManager.PERMISSION_GRANTED &&
            ActivityCompat.checkSelfPermission(this, Manifest.permission.BLUETOOTH_ADMIN) == PackageManager.PERMISSION_GRANTED
        }
    }

    private fun requestBluetoothPermissions() {
        println("🔐 Requesting Bluetooth permissions...")
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            ActivityCompat.requestPermissions(
                this,
                arrayOf(
                    Manifest.permission.BLUETOOTH_CONNECT,
                    Manifest.permission.BLUETOOTH_SCAN
                ),
                BLUETOOTH_PERMISSION_REQUEST_CODE
            )
        } else {
            ActivityCompat.requestPermissions(
                this,
                arrayOf(
                    Manifest.permission.BLUETOOTH,
                    Manifest.permission.BLUETOOTH_ADMIN
                ),
                BLUETOOTH_PERMISSION_REQUEST_CODE
            )
        }
    }
}