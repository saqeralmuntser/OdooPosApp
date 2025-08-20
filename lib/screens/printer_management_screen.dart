import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../backend/providers/enhanced_pos_provider.dart';
import '../backend/models/network_printer.dart';
import '../theme/app_theme.dart';

class PrinterManagementScreen extends StatefulWidget {
  const PrinterManagementScreen({super.key});

  @override
  State<PrinterManagementScreen> createState() => _PrinterManagementScreenState();
}

class _PrinterManagementScreenState extends State<PrinterManagementScreen>
    with TickerProviderStateMixin {
  late TabController _tabController;
  bool _isDiscovering = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    
    // Start printer discovery when screen loads
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startDiscovery();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _startDiscovery() async {
    setState(() {
      _isDiscovering = true;
    });

    final posProvider = Provider.of<EnhancedPOSProvider>(context, listen: false);
    await posProvider.startPrinterDiscovery(continuous: false);

    setState(() {
      _isDiscovering = false;
    });
  }

  void _stopDiscovery() {
    final posProvider = Provider.of<EnhancedPOSProvider>(context, listen: false);
    posProvider.stopPrinterDiscovery();
    setState(() {
      _isDiscovering = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Printer Management'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.search), text: 'Discovery'),
            Tab(icon: Icon(Icons.settings), text: 'Configured'),
            Tab(icon: Icon(Icons.queue), text: 'Print Queue'),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(_isDiscovering ? Icons.stop : Icons.refresh),
            onPressed: _isDiscovering ? _stopDiscovery : _startDiscovery,
            tooltip: _isDiscovering ? 'Stop Discovery' : 'Start Discovery',
          ),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildDiscoveryTab(),
          _buildConfiguredTab(),
          _buildPrintQueueTab(),
        ],
      ),
    );
  }

  Widget _buildDiscoveryTab() {
    return Consumer<EnhancedPOSProvider>(
      builder: (context, posProvider, _) {
        final discoveredPrinters = posProvider.discoveredPrinters.cast<NetworkPrinter>();

        return Column(
          children: [
            // Status and controls
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              color: Colors.grey.shade100,
              child: Column(
                children: [
                  Row(
                    children: [
                      Icon(
                        _isDiscovering ? Icons.wifi_find : Icons.wifi,
                        color: _isDiscovering ? Colors.blue : Colors.grey,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _isDiscovering 
                            ? 'Discovering printers...'
                            : 'Found ${discoveredPrinters.length} printers',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const Spacer(),
                      if (_isDiscovering)
                        const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Scanning network for available printers...',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
            ),

            // Discovered printers list
            Expanded(
              child: discoveredPrinters.isEmpty
                  ? _buildEmptyState('No printers discovered', 
                      'Make sure printers are connected to the network and try again.')
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: discoveredPrinters.length,
                      itemBuilder: (context, index) {
                        final printer = discoveredPrinters[index];
                        return _buildPrinterCard(
                          printer: printer,
                          isConfigured: printer.isConfigured,
                          onConfigure: () => _configurePrinter(printer),
                          onTest: () => _testPrinter(printer),
                        );
                      },
                    ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildConfiguredTab() {
    return Consumer<EnhancedPOSProvider>(
      builder: (context, posProvider, _) {
        final configuredPrinters = posProvider.configuredPrinters.cast<NetworkPrinter>();

        return configuredPrinters.isEmpty
            ? _buildEmptyState('No configured printers',
                'Discover and configure printers from the Discovery tab.')
            : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: configuredPrinters.length,
                itemBuilder: (context, index) {
                  final printer = configuredPrinters[index];
                  return _buildPrinterCard(
                    printer: printer,
                    isConfigured: true,
                    onUnconfigure: () => _unconfigurePrinter(printer),
                    onTest: () => _testPrinter(printer),
                    showStatus: true,
                  );
                },
              );
      },
    );
  }

  Widget _buildPrintQueueTab() {
    return Consumer<EnhancedPOSProvider>(
      builder: (context, posProvider, _) {
        final printJobs = posProvider.printJobs.cast<PrintJob>();

        return Column(
          children: [
            // Queue summary
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              color: Colors.grey.shade100,
              child: Row(
                children: [
                  Icon(
                    Icons.queue,
                    color: posProvider.isPrinting ? Colors.blue : Colors.grey,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${posProvider.pendingJobsCount} pending jobs',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const Spacer(),
                  if (posProvider.isPrinting)
                    const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  const SizedBox(width: 16),
                  TextButton(
                    onPressed: () => posProvider.clearCompletedJobs(),
                    child: const Text('Clear Completed'),
                  ),
                ],
              ),
            ),

            // Print jobs list
            Expanded(
              child: printJobs.isEmpty
                  ? _buildEmptyState('No print jobs',
                      'Print jobs will appear here when you print receipts.')
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: printJobs.length,
                      itemBuilder: (context, index) {
                        final job = printJobs[index];
                        return _buildPrintJobCard(job);
                      },
                    ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildPrinterCard({
    required NetworkPrinter printer,
    required bool isConfigured,
    VoidCallback? onConfigure,
    VoidCallback? onUnconfigure,
    VoidCallback? onTest,
    bool showStatus = false,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.print,
                  color: printer.isOnline ? Colors.green : Colors.red,
                  size: 32,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        printer.displayName,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        '${printer.ipAddress}:${printer.port}',
                        style: const TextStyle(
                          color: Colors.grey,
                          fontSize: 14,
                        ),
                      ),
                      if (showStatus)
                        Text(
                          'Status: ${printer.status.toString().split('.').last}',
                          style: TextStyle(
                            color: printer.isOnline ? Colors.green : Colors.red,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                    ],
                  ),
                ),
                if (isConfigured)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.green.shade100,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.green.shade300),
                    ),
                    child: const Text(
                      'Configured',
                      style: TextStyle(
                        color: Colors.green,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            
            // Printer capabilities
            Wrap(
              spacing: 8,
              children: [
                if (printer.capabilities.supportsCutting)
                  _buildCapabilityChip('Auto Cut', Icons.content_cut),
                if (printer.capabilities.supportsCashDrawer)
                  _buildCapabilityChip('Cash Drawer', Icons.money),
                if (printer.capabilities.supportsQrCodes)
                  _buildCapabilityChip('QR Codes', Icons.qr_code),
                _buildCapabilityChip('${printer.capabilities.maxTextWidth} chars', Icons.text_fields),
              ],
            ),
            
            const SizedBox(height: 12),
            
            // Actions
            Row(
              children: [
                if (onTest != null)
                  OutlinedButton.icon(
                    onPressed: onTest,
                    icon: const Icon(Icons.print_outlined, size: 16),
                    label: const Text('Test'),
                  ),
                const SizedBox(width: 8),
                if (onConfigure != null)
                  ElevatedButton.icon(
                    onPressed: onConfigure,
                    icon: const Icon(Icons.settings, size: 16),
                    label: const Text('Configure'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                      foregroundColor: Colors.white,
                    ),
                  ),
                if (onUnconfigure != null)
                  OutlinedButton.icon(
                    onPressed: onUnconfigure,
                    icon: const Icon(Icons.remove_circle_outline, size: 16),
                    label: const Text('Remove'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPrintJobCard(PrintJob job) {
    Color statusColor;
    IconData statusIcon;
    
    switch (job.status) {
      case PrintJobStatus.pending:
        statusColor = Colors.orange;
        statusIcon = Icons.schedule;
        break;
      case PrintJobStatus.processing:
        statusColor = Colors.blue;
        statusIcon = Icons.print;
        break;
      case PrintJobStatus.completed:
        statusColor = Colors.green;
        statusIcon = Icons.check_circle;
        break;
      case PrintJobStatus.failed:
        statusColor = Colors.red;
        statusIcon = Icons.error;
        break;
      case PrintJobStatus.cancelled:
        statusColor = Colors.grey;
        statusIcon = Icons.cancel;
        break;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(statusIcon, color: statusColor),
        title: Text(job.jobName),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Type: ${job.type.toString().split('.').last}'),
            Text('Created: ${job.createdAt.toString().substring(11, 19)}'),
            if (job.error != null)
              Text(
                'Error: ${job.error}',
                style: const TextStyle(color: Colors.red),
              ),
          ],
        ),
        trailing: job.status == PrintJobStatus.pending
            ? IconButton(
                icon: const Icon(Icons.cancel),
                onPressed: () => _cancelPrintJob(job.id),
              )
            : job.status == PrintJobStatus.failed && job.canRetry
                ? IconButton(
                    icon: const Icon(Icons.refresh),
                    onPressed: () => _retryPrintJob(job.id),
                  )
                : null,
      ),
    );
  }

  Widget _buildCapabilityChip(String label, IconData icon) {
    return Chip(
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(fontSize: 12),
          ),
        ],
      ),
      backgroundColor: Colors.grey.shade100,
      side: BorderSide(color: Colors.grey.shade300),
    );
  }

  Widget _buildEmptyState(String title, String subtitle) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.print_disabled,
              size: 64,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade500,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  void _configurePrinter(NetworkPrinter printer) async {
    final posProvider = Provider.of<EnhancedPOSProvider>(context, listen: false);
    
    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Configure Printer'),
        content: Text(
          'Configure ${printer.displayName} for the current POS configuration?\n\n'
          'This printer will be used for receipts in this POS setup.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Configure'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final success = await posProvider.configurePrinter(printer);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              success 
                  ? 'Printer configured successfully'
                  : 'Failed to configure printer',
            ),
            backgroundColor: success ? Colors.green : Colors.red,
          ),
        );
      }
    }
  }

  void _unconfigurePrinter(NetworkPrinter printer) async {
    final posProvider = Provider.of<EnhancedPOSProvider>(context, listen: false);
    
    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Printer'),
        content: Text(
          'Remove ${printer.displayName} from the current POS configuration?\n\n'
          'This printer will no longer be used for printing.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final success = await posProvider.unconfigurePrinter(printer.id);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              success 
                  ? 'Printer removed successfully'
                  : 'Failed to remove printer',
            ),
            backgroundColor: success ? Colors.green : Colors.red,
          ),
        );
      }
    }
  }

  void _testPrinter(NetworkPrinter printer) async {
    final posProvider = Provider.of<EnhancedPOSProvider>(context, listen: false);
    
    // Show loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(),
      ),
    );

    final success = await posProvider.testPrinter(printer);
    
    if (mounted) {
      Navigator.of(context).pop(); // Hide loading
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            success 
                ? 'Test print sent successfully'
                : 'Test print failed',
          ),
          backgroundColor: success ? Colors.green : Colors.red,
        ),
      );
    }
  }

  void _cancelPrintJob(String jobId) async {
    final posProvider = Provider.of<EnhancedPOSProvider>(context, listen: false);
    final success = await posProvider.cancelPrintJob(jobId);
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            success 
                ? 'Print job cancelled'
                : 'Failed to cancel print job',
          ),
          backgroundColor: success ? Colors.green : Colors.red,
        ),
      );
    }
  }

  void _retryPrintJob(String jobId) async {
    final posProvider = Provider.of<EnhancedPOSProvider>(context, listen: false);
    final success = await posProvider.retryPrintJob(jobId);
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            success 
                ? 'Print job retried'
                : 'Failed to retry print job',
          ),
          backgroundColor: success ? Colors.green : Colors.red,
        ),
      );
    }
  }
}
