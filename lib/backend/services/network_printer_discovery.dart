import 'dart:async';
import 'dart:io';
import 'dart:convert';
import '../models/network_printer.dart';
import '../storage/local_storage.dart';

/// Network Printer Discovery Service
/// Discovers and manages network printers
class NetworkPrinterDiscovery {
  static final NetworkPrinterDiscovery _instance = NetworkPrinterDiscovery._internal();
  factory NetworkPrinterDiscovery() => _instance;
  NetworkPrinterDiscovery._internal();

  final LocalStorage _localStorage = LocalStorage();
  final List<NetworkPrinter> _discoveredPrinters = [];
  final List<NetworkPrinter> _configuredPrinters = [];
  
  Timer? _discoveryTimer;
  bool _isDiscovering = false;
  
  // Common printer ports
  static const List<int> commonPrinterPorts = [
    9100, // RAW/ESC-POS
    515,  // LPR/LPD
    631,  // IPP
    9101, // Alternate ESC-POS
    9102, // Alternate ESC-POS
    9600, // Some thermal printers
  ];

  // Streams for real-time updates
  final StreamController<List<NetworkPrinter>> _printersController = 
      StreamController<List<NetworkPrinter>>.broadcast();
  final StreamController<String> _statusController = 
      StreamController<String>.broadcast();

  /// Stream of discovered printers
  Stream<List<NetworkPrinter>> get printersStream => _printersController.stream;
  
  /// Stream of discovery status updates
  Stream<String> get statusStream => _statusController.stream;

  /// Get all discovered printers
  List<NetworkPrinter> get discoveredPrinters => List.unmodifiable(_discoveredPrinters);
  
  /// Get configured printers
  List<NetworkPrinter> get configuredPrinters => List.unmodifiable(_configuredPrinters);
  
  /// Check if discovery is in progress
  bool get isDiscovering => _isDiscovering;

  /// Initialize the discovery service
  Future<void> initialize() async {
    try {
      await _loadConfiguredPrinters();
      await _validateConfiguredPrinters();
      _updateStatus('Printer discovery service initialized');
    } catch (e) {
      print('Error initializing printer discovery: $e');
      _updateStatus('Failed to initialize printer discovery');
    }
  }

  /// Start network discovery for printers
  Future<void> startDiscovery({bool continuous = false}) async {
    if (_isDiscovering) {
      print('Discovery already in progress');
      return;
    }

    _isDiscovering = true;
    _updateStatus('Starting printer discovery...');

    try {
      // Get local network interfaces
      final interfaces = await NetworkInterface.list();
      String? localIP;
      
      for (final interface in interfaces) {
        if (interface.addresses.isNotEmpty) {
          final address = interface.addresses.first;
          if (address.address.startsWith('192.168.') || 
              address.address.startsWith('10.') ||
              address.address.startsWith('172.')) {
            localIP = address.address;
            break;
          }
        }
      }

      if (localIP == null) {
        _updateStatus('No local network found');
        _isDiscovering = false;
        return;
      }

      _updateStatus('Scanning network: ${_getNetworkRange(localIP)}');
      
      // Discover devices on network
      final subnet = _getSubnet(localIP);
      await _scanNetworkForPrinters(subnet);

      if (continuous) {
        // Start periodic discovery
        _discoveryTimer = Timer.periodic(const Duration(minutes: 5), (_) {
          _scanNetworkForPrinters(subnet);
        });
      }

      _updateStatus('Discovery completed. Found ${_discoveredPrinters.length} printers');
    } catch (e) {
      print('Error during discovery: $e');
      _updateStatus('Discovery failed: $e');
    } finally {
      _isDiscovering = false;
    }
  }

  /// Stop discovery
  void stopDiscovery() {
    _discoveryTimer?.cancel();
    _discoveryTimer = null;
    _isDiscovering = false;
    _updateStatus('Discovery stopped');
  }

  /// Scan network subnet for printers
  Future<void> _scanNetworkForPrinters(String subnet) async {
    // Scan common IP range (192.168.x.1 - 192.168.x.254)
    final futures = <Future<void>>[];
    
    for (int i = 1; i <= 254; i++) {
      final ip = '$subnet.$i';
      futures.add(_checkDeviceForPrinterServices(ip));
      
      // Process in batches to avoid overwhelming the network
      if (futures.length >= 20) {
        await Future.wait(futures);
        futures.clear();
        // Small delay between batches
        await Future.delayed(const Duration(milliseconds: 100));
      }
    }
    
    // Process remaining futures
    if (futures.isNotEmpty) {
      await Future.wait(futures);
    }

    _printersController.add(_discoveredPrinters);
  }

  /// Check if a device has printer services
  Future<void> _checkDeviceForPrinterServices(String ipAddress) async {
    for (final port in commonPrinterPorts) {
      try {
        final socket = await Socket.connect(
          ipAddress, 
          port, 
          timeout: const Duration(seconds: 2),
        );

        // If connection successful, this might be a printer
        await socket.close();
        
        final printer = await _identifyPrinter(ipAddress, port);
        if (printer != null) {
          _addOrUpdatePrinter(printer);
          break; // Found printer on this IP, no need to check other ports
        }
      } catch (e) {
        // Port not open or not a printer, continue
        continue;
      }
    }
  }

  /// Try to identify printer type and capabilities
  Future<NetworkPrinter?> _identifyPrinter(String ipAddress, int port) async {
    try {
      final socket = await Socket.connect(ipAddress, port, timeout: const Duration(seconds: 3));
      
      // Send printer status query (ESC-POS command)
      socket.add([0x10, 0x04, 0x01]); // DLE EOT n (transmit printer status)
      
      // Wait for response (just to verify connection)
      await socket.timeout(const Duration(seconds: 2)).first;
      await socket.close();

      // Basic printer identification
      final printerId = '${ipAddress}_$port';
      final now = DateTime.now();

      // Try to get more info via SNMP-like queries (simplified)
      final printerInfo = await _getPrinterInfo(ipAddress);

      return NetworkPrinter(
        id: printerId,
        name: printerInfo['name'] ?? 'Thermal Printer',
        ipAddress: ipAddress,
        port: port,
        type: PrinterType.thermal, // Assume thermal for ESC-POS
        status: PrinterStatus.online,
        manufacturer: printerInfo['manufacturer'],
        model: printerInfo['model'],
        lastSeen: now,
        capabilities: const PrinterCapabilities(
          supportsCutting: true,
          supportsCashDrawer: true,
          supportsImages: true,
          supportsQrCodes: true,
          supportedPaperWidths: [80, 58],
          maxTextWidth: 48,
        ),
      );
    } catch (e) {
      print('Error identifying printer at $ipAddress:$port - $e');
      return null;
    }
  }

  /// Get printer information (simplified)
  Future<Map<String, String>> _getPrinterInfo(String ipAddress) async {
    final info = <String, String>{};
    
    try {
      // Try to get hostname
      final result = await InternetAddress.lookup(ipAddress).timeout(
        const Duration(seconds: 2)
      );
      
      if (result.isNotEmpty) {
        final hostname = result.first.host;
        info['name'] = hostname;
        
        // Try to extract manufacturer from hostname
        if (hostname.toLowerCase().contains('epson')) {
          info['manufacturer'] = 'Epson';
        } else if (hostname.toLowerCase().contains('brother')) {
          info['manufacturer'] = 'Brother';
        } else if (hostname.toLowerCase().contains('zebra')) {
          info['manufacturer'] = 'Zebra';
        } else if (hostname.toLowerCase().contains('star')) {
          info['manufacturer'] = 'Star';
        } else if (hostname.toLowerCase().contains('citizen')) {
          info['manufacturer'] = 'Citizen';
        }
      }
    } catch (e) {
      // Use IP as fallback name
      info['name'] = 'Printer $ipAddress';
    }
    
    return info;
  }

  /// Add or update printer in the discovered list
  void _addOrUpdatePrinter(NetworkPrinter printer) {
    final existingIndex = _discoveredPrinters.indexWhere(
      (p) => p.ipAddress == printer.ipAddress && p.port == printer.port
    );

    if (existingIndex >= 0) {
      // Update existing printer
      _discoveredPrinters[existingIndex] = printer.copyWith(
        lastSeen: DateTime.now(),
        status: PrinterStatus.online,
      );
    } else {
      // Add new printer
      _discoveredPrinters.add(printer);
    }

    print('Discovered printer: ${printer.displayName}');
  }

  /// Configure a discovered printer for use
  Future<bool> configurePrinter(NetworkPrinter printer, {int? posConfigId}) async {
    try {
      final configuredPrinter = printer.copyWith(
        isConfigured: true,
        posConfigId: posConfigId,
      );

      // Save to local storage
      await _saveConfiguredPrinter(configuredPrinter);
      
      // Add to configured list
      final existingIndex = _configuredPrinters.indexWhere((p) => p.id == printer.id);
      if (existingIndex >= 0) {
        _configuredPrinters[existingIndex] = configuredPrinter;
      } else {
        _configuredPrinters.add(configuredPrinter);
      }

      _updateStatus('Printer configured: ${printer.displayName}');
      return true;
    } catch (e) {
      print('Error configuring printer: $e');
      _updateStatus('Failed to configure printer: $e');
      return false;
    }
  }

  /// Remove printer configuration
  Future<bool> unconfigurePrinter(String printerId) async {
    try {
      await _removeConfiguredPrinter(printerId);
      _configuredPrinters.removeWhere((p) => p.id == printerId);
      _updateStatus('Printer configuration removed');
      return true;
    } catch (e) {
      print('Error removing printer configuration: $e');
      return false;
    }
  }

  /// Test printer connection and capabilities
  Future<bool> testPrinter(NetworkPrinter printer) async {
    try {
      _updateStatus('Testing printer: ${printer.displayName}');
      
      final socket = await Socket.connect(
        printer.ipAddress, 
        printer.port, 
        timeout: const Duration(seconds: 5)
      );

      // Send test print command
      final testReceipt = _generateTestReceipt();
      socket.add(testReceipt);
      
      await Future.delayed(const Duration(milliseconds: 500));
      await socket.close();

      _updateStatus('Printer test successful: ${printer.displayName}');
      return true;
    } catch (e) {
      print('Printer test failed: $e');
      _updateStatus('Printer test failed: ${printer.displayName}');
      return false;
    }
  }

  /// Generate test receipt in ESC-POS format
  List<int> _generateTestReceipt() {
    final commands = <int>[];
    
    // Initialize printer
    commands.addAll([0x1B, 0x40]); // ESC @
    
    // Center align
    commands.addAll([0x1B, 0x61, 0x01]); // ESC a 1
    
    // Bold text
    commands.addAll([0x1B, 0x45, 0x01]); // ESC E 1
    
    // Add test text
    commands.addAll(utf8.encode('PRINTER TEST\n'));
    commands.addAll(utf8.encode('Flutter POS System\n'));
    
    // Normal text
    commands.addAll([0x1B, 0x45, 0x00]); // ESC E 0
    
    // Left align
    commands.addAll([0x1B, 0x61, 0x00]); // ESC a 0
    
    commands.addAll(utf8.encode('Test Date: ${DateTime.now()}\n'));
    commands.addAll(utf8.encode('Status: Connected\n'));
    
    // Cut paper
    commands.addAll([0x1D, 0x56, 0x00]); // GS V 0
    
    return commands;
  }

  /// Get subnet from IP address
  String _getSubnet(String ip) {
    final parts = ip.split('.');
    return '${parts[0]}.${parts[1]}.${parts[2]}';
  }

  /// Get network range display string
  String _getNetworkRange(String ip) {
    final subnet = _getSubnet(ip);
    return '$subnet.1-254';
  }

  /// Load configured printers from storage
  Future<void> _loadConfiguredPrinters() async {
    try {
      final printersData = await _localStorage.getConfiguredPrinters();
      _configuredPrinters.clear();
      _configuredPrinters.addAll(printersData);
      print('Loaded ${_configuredPrinters.length} configured printers');
    } catch (e) {
      print('Error loading configured printers: $e');
    }
  }

  /// Save configured printer to storage
  Future<void> _saveConfiguredPrinter(NetworkPrinter printer) async {
    await _localStorage.saveConfiguredPrinter(printer);
  }

  /// Remove configured printer from storage
  Future<void> _removeConfiguredPrinter(String printerId) async {
    await _localStorage.removeConfiguredPrinter(printerId);
  }

  /// Validate configured printers (check if still accessible)
  Future<void> _validateConfiguredPrinters() async {
    for (int i = 0; i < _configuredPrinters.length; i++) {
      final printer = _configuredPrinters[i];
      try {
        final socket = await Socket.connect(
          printer.ipAddress, 
          printer.port, 
          timeout: const Duration(seconds: 2)
        );
        await socket.close();
        
        // Update status to online
        _configuredPrinters[i] = printer.copyWith(
          status: PrinterStatus.online,
          lastSeen: DateTime.now(),
        );
      } catch (e) {
        // Update status to offline
        _configuredPrinters[i] = printer.copyWith(
          status: PrinterStatus.offline,
        );
      }
    }
  }

  /// Update status and notify listeners
  void _updateStatus(String status) {
    print('PrinterDiscovery: $status');
    _statusController.add(status);
  }

  /// Get printers for specific POS config
  List<NetworkPrinter> getPrintersForConfig(int posConfigId) {
    return _configuredPrinters
        .where((printer) => printer.posConfigId == posConfigId)
        .toList();
  }

  /// Dispose resources
  void dispose() {
    stopDiscovery();
    _printersController.close();
    _statusController.close();
  }
}

// Network discovery completed using native Dart:io Socket operations
