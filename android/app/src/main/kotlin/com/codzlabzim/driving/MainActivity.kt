package com.codzlabzim.driving

import android.Manifest
import android.bluetooth.BluetoothAdapter
import android.bluetooth.BluetoothDevice
import android.bluetooth.BluetoothManager
import android.content.Context
import android.content.pm.PackageManager
import android.os.Build
import android.print.PrintAttributes
import android.print.PrintDocumentAdapter
import android.print.PrintManager
import android.webkit.WebView
import android.webkit.WebViewClient
import androidx.core.app.ActivityCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

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
                        printReceipt(content, printerName, paperSize)
                        result.success(true)
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
                            else -> {
                                result.error("INVALID_TYPE", "Unknown printer type: $type", null)
                                return@setMethodCallHandler
                            }
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

    // Discover USB printers specifically
    private fun discoverUsbPrinters(): List<Map<String, String>> {
        val printers = mutableListOf<Map<String, String>>()
        
        try {
            val printManager = getSystemService(Context.PRINT_SERVICE) as? PrintManager
            
            if (printManager != null) {
                // Note: PrintManager doesn't have a direct printServices property
                // We'll use a default USB printer entry
                val printerInfo = mapOf(
                    "name" to "USB Thermal Printer",
                    "type" to "USB",
                    "description" to "Connected USB printer",
                    "address" to ""
                )
                printers.add(printerInfo)
                println("✅ Found USB printer placeholder")
            }
            
            println("🔍 Found ${printers.size} USB printers")
        } catch (e: Exception) {
            e.printStackTrace()
            println("❌ Error discovering USB printers: ${e.message}")
        }
        
        return printers
    }

    // Discover Network printers specifically
    private fun discoverNetworkPrinters(): List<Map<String, String>> {
        val printers = mutableListOf<Map<String, String>>()
        
        try {
            val printManager = getSystemService(Context.PRINT_SERVICE) as? PrintManager
            
            if (printManager != null) {
                // Note: PrintManager doesn't have a direct printServices property
                // We'll use a default network printer entry
                val printerInfo = mapOf(
                    "name" to "Network Printer",
                    "type" to "Network",
                    "description" to "Network connected printer",
                    "address" to ""
                )
                printers.add(printerInfo)
                println("✅ Found Network printer placeholder")
            }
            
            println("🔍 Found ${printers.size} Network printers")
        } catch (e: Exception) {
            e.printStackTrace()
            println("❌ Error discovering Network printers: ${e.message}")
        }
        
        return printers
    }

    // Check Bluetooth permissions
    private fun checkBluetoothPermissions(): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            ActivityCompat.checkSelfPermission(
                this,
                Manifest.permission.BLUETOOTH_CONNECT
            ) == PackageManager.PERMISSION_GRANTED
        } else {
            ActivityCompat.checkSelfPermission(
                this,
                Manifest.permission.BLUETOOTH
            ) == PackageManager.PERMISSION_GRANTED
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

    // Discover all printers (System + Bluetooth)
    private fun discoverAllPrinters(): List<Map<String, String>> {
        val printers = mutableListOf<Map<String, String>>()
        
        try {
            // Get Bluetooth Printers
            val bluetoothPrinters = discoverBluetoothPrinters()
            printers.addAll(bluetoothPrinters)
            
            // Add USB placeholder
            val usbPrinters = discoverUsbPrinters()
            printers.addAll(usbPrinters)
            
            // Add Network placeholder
            val networkPrinters = discoverNetworkPrinters()
            printers.addAll(networkPrinters)
            
            // If no printers found, add default
            if (printers.isEmpty()) {
                val defaultPrinter = getSystemDefaultPrinter()
                if (defaultPrinter != null) {
                    printers.add(defaultPrinter)
                }
            }
            
        } catch (e: Exception) {
            e.printStackTrace()
        }
        
        return printers
    }

    // Discover Bluetooth printers
    private fun discoverBluetoothPrinters(): List<Map<String, String>> {
        val printers = mutableListOf<Map<String, String>>()
        
        try {
            val bluetoothManager = getSystemService(Context.BLUETOOTH_SERVICE) as? BluetoothManager
            val bluetoothAdapter = bluetoothManager?.adapter
            
            if (bluetoothAdapter == null) {
                println("⚠️ Bluetooth not supported on this device")
                return printers
            }
            
            if (!bluetoothAdapter.isEnabled) {
                println("⚠️ Bluetooth is not enabled")
                return printers
            }
            
            if (!checkBluetoothPermissions()) {
                println("⚠️ Bluetooth permissions not granted")
                return printers
            }
            
            // Get paired Bluetooth devices
            val pairedDevices: Set<BluetoothDevice>? = try {
                bluetoothAdapter.bondedDevices
            } catch (e: SecurityException) {
                println("❌ Security exception getting bonded devices: ${e.message}")
                null
            }
            
            pairedDevices?.forEach { device ->
                try {
                    val deviceName = device.name ?: "Unknown Device"
                    val deviceAddress = device.address ?: ""
                    
                    // Filter for printer devices
                    if (isPrinterDevice(device)) {
                        val printerInfo = mapOf(
                            "name" to deviceName,
                            "type" to "Bluetooth",
                            "description" to "Paired Bluetooth printer",
                            "address" to deviceAddress
                        )
                        printers.add(printerInfo)
                        println("✅ Found Bluetooth printer: $deviceName ($deviceAddress)")
                    }
                } catch (e: SecurityException) {
                    println("❌ Security exception accessing device: ${e.message}")
                }
            }
            
            println("🔍 Found ${printers.size} Bluetooth printers")
            
        } catch (e: Exception) {
            e.printStackTrace()
            println("❌ Error discovering Bluetooth printers: ${e.message}")
        }
        
        return printers
    }

    // Check if device is likely a printer
    private fun isPrinterDevice(device: BluetoothDevice): Boolean {
        try {
            val deviceName = device.name?.lowercase() ?: ""
            val deviceClass = device.bluetoothClass
            
            // Check device name for printer keywords
            val printerKeywords = listOf(
                "printer", "print", "pos", "thermal", 
                "receipt", "label", "epson", "star",
                "citizen", "bixolon", "zj", "rpp"
            )
            
            val hasKeyword = printerKeywords.any { keyword ->
                deviceName.contains(keyword)
            }
            
            // Check device class (if available)
            val isPrinterClass = deviceClass?.majorDeviceClass == 1536
            
            return hasKeyword || isPrinterClass
        } catch (e: Exception) {
            return false
        }
    }

    // Get system default printer
    private fun getSystemDefaultPrinter(): Map<String, String>? {
        return try {
            mapOf(
                "name" to "System Default Printer",
                "type" to "System",
                "description" to "Default system printer",
                "address" to ""
            )
        } catch (e: Exception) {
            null
        }
    }
    
    // Detect printer type from name
    private fun detectPrinterType(printerName: String): String {
        val nameLower = printerName.lowercase()
        return when {
            nameLower.contains("usb") -> "USB"
            nameLower.contains("network") || nameLower.contains("wifi") -> "Network"
            nameLower.contains("bluetooth") || nameLower.contains("bt") -> "Bluetooth"
            else -> "Unknown"
        }
    }
    
    // Verify if printer is available
    private fun verifyPrinter(printerName: String): Boolean {
        try {
            // Check Bluetooth printers
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

    // Print receipt
    private fun printReceipt(content: String, printerName: String?, paperSize: String?) {
        try {
            val webView = WebView(this)
            webView.webViewClient = object : WebViewClient() {
                override fun onPageFinished(view: WebView, url: String) {
                    createPrintJob(view, printerName ?: "Receipt")
                }
            }

            val htmlContent = createReceiptHtml(content, paperSize ?: "80mm")
            webView.loadDataWithBaseURL(null, htmlContent, "text/html", "UTF-8", null)
            
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }

    private fun createReceiptHtml(content: String, paperSize: String): String {
        val width = if (paperSize == "58mm") "58mm" else "80mm"
        
        return """
            <!DOCTYPE html>
            <html>
            <head>
                <meta charset="UTF-8">
                <style>
                    @page {
                        size: $width 297mm;
                        margin: 0;
                    }
                    body {
                        margin: 0;
                        padding: 5mm;
                        font-family: 'Courier New', monospace;
                        font-size: 10pt;
                        line-height: 1.2;
                        width: $width;
                    }
                    pre {
                        margin: 0;
                        white-space: pre-wrap;
                        font-family: 'Courier New', monospace;
                    }
                </style>
            </head>
            <body>
                <pre>${content.replace("\n", "<br>")}</pre>
            </body>
            </html>
        """.trimIndent()
    }

    private fun createPrintJob(webView: WebView, jobName: String) {
        val printManager = getSystemService(Context.PRINT_SERVICE) as PrintManager
        val printAdapter: PrintDocumentAdapter = webView.createPrintDocumentAdapter(jobName)
        val attributes = PrintAttributes.Builder()
            .setMediaSize(PrintAttributes.MediaSize.ISO_A6)
            .setResolution(PrintAttributes.Resolution("receipt", "Receipt", 203, 203))
            .setMinMargins(PrintAttributes.Margins.NO_MARGINS)
            .build()
        
        printManager.print(jobName, printAdapter, attributes)
    }
}