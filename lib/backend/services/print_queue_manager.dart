import 'dart:async';
import 'dart:collection';
import 'package:uuid/uuid.dart';
import '../models/network_printer.dart';
import '../models/pos_order.dart';
import '../models/pos_order_line.dart';
import '../models/res_partner.dart';
import '../models/res_company.dart';
import '../storage/local_storage.dart';
import 'escpos_service.dart';

/// Print Queue Manager
/// Manages print jobs and queues for multiple printers
class PrintQueueManager {
  static final PrintQueueManager _instance = PrintQueueManager._internal();
  factory PrintQueueManager() => _instance;
  PrintQueueManager._internal();

  final LocalStorage _localStorage = LocalStorage();
  final ESCPOSService _escposService = ESCPOSService();
  
  final Map<String, Queue<PrintJob>> _printerQueues = {};
  final Map<String, bool> _printerProcessing = {};
  final List<PrintJob> _allJobs = [];
  
  Timer? _queueProcessor;
  bool _isProcessing = false;

  // Streams for real-time updates
  final StreamController<List<PrintJob>> _jobsController = 
      StreamController<List<PrintJob>>.broadcast();
  final StreamController<String> _statusController = 
      StreamController<String>.broadcast();

  /// Stream of all print jobs
  Stream<List<PrintJob>> get jobsStream => _jobsController.stream;
  
  /// Stream of status updates
  Stream<String> get statusStream => _statusController.stream;
  
  /// Get all jobs
  List<PrintJob> get allJobs => List.unmodifiable(_allJobs);
  
  /// Check if any printer is processing
  bool get isProcessing => _isProcessing;

  /// Initialize the queue manager
  Future<void> initialize() async {
    try {
      await _loadPendingJobs();
      _startQueueProcessor();
      _updateStatus('Print queue manager initialized');
    } catch (e) {
      print('Error initializing print queue manager: $e');
      _updateStatus('Failed to initialize print queue manager');
    }
  }

  /// Add print job to queue
  Future<String> addPrintJob({
    required String printerId,
    required String jobName,
    required PrintJobType type,
    required Map<String, dynamic> data,
    int priority = 5,
  }) async {
    try {
      final jobId = const Uuid().v4();
      final job = PrintJob(
        id: jobId,
        printerId: printerId,
        jobName: jobName,
        type: type,
        data: data,
        status: PrintJobStatus.pending,
        createdAt: DateTime.now(),
        priority: priority,
      );

      // Add to local queue
      _addJobToQueue(job);
      
      // Save to storage
      await _localStorage.savePrintJob(job);
      
      _updateStatus('Print job added: $jobName');
      _notifyJobsUpdate();
      
      return jobId;
    } catch (e) {
      print('Error adding print job: $e');
      _updateStatus('Failed to add print job: $e');
      rethrow;
    }
  }

  /// Add receipt print job
  Future<String> addReceiptPrintJob({
    required String printerId,
    POSOrder? order,
    required List<POSOrderLine> orderLines,
    required Map<String, double> payments,
    ResPartner? customer,
    ResCompany? company,
    int priority = 5,
  }) async {
    final jobName = 'Receipt ${order?.name ?? DateTime.now().millisecondsSinceEpoch}';
    
    return await addPrintJob(
      printerId: printerId,
      jobName: jobName,
      type: PrintJobType.receipt,
      data: {
        'order': order?.toJson(),
        'orderLines': orderLines.map((line) => line.toJson()).toList(),
        'payments': payments,
        'customer': customer?.toJson(),
        'company': company?.toJson(),
      },
      priority: priority,
    );
  }

  /// Add test print job
  Future<String> addTestPrintJob(String printerId) async {
    return await addPrintJob(
      printerId: printerId,
      jobName: 'Test Print ${DateTime.now()}',
      type: PrintJobType.test,
      data: {},
      priority: 1, // High priority for tests
    );
  }

  /// Cancel print job
  Future<bool> cancelPrintJob(String jobId) async {
    try {
      final jobIndex = _allJobs.indexWhere((job) => job.id == jobId);
      if (jobIndex >= 0) {
        final job = _allJobs[jobIndex];
        
        if (job.status == PrintJobStatus.pending) {
          // Update job status
          _allJobs[jobIndex] = job.copyWith(
            status: PrintJobStatus.cancelled,
            processedAt: DateTime.now(),
          );
          
          // Remove from printer queue
          final printerQueue = _printerQueues[job.printerId];
          printerQueue?.removeWhere((queueJob) => queueJob.id == jobId);
          
          // Update storage
          await _localStorage.updatePrintJobStatus(jobId, PrintJobStatus.cancelled);
          
          _updateStatus('Print job cancelled: ${job.jobName}');
          _notifyJobsUpdate();
          
          return true;
        } else {
          _updateStatus('Cannot cancel job in status: ${job.status}');
          return false;
        }
      }
      
      _updateStatus('Print job not found: $jobId');
      return false;
    } catch (e) {
      print('Error cancelling print job: $e');
      _updateStatus('Failed to cancel print job: $e');
      return false;
    }
  }

  /// Retry failed print job
  Future<bool> retryPrintJob(String jobId) async {
    try {
      final jobIndex = _allJobs.indexWhere((job) => job.id == jobId);
      if (jobIndex >= 0) {
        final job = _allJobs[jobIndex];
        
        if (job.canRetry) {
          // Update job status and retry count
          _allJobs[jobIndex] = job.copyWith(
            status: PrintJobStatus.pending,
            retryCount: job.retryCount + 1,
            error: null,
          );
          
          // Add back to queue
          _addJobToQueue(_allJobs[jobIndex]);
          
          // Update storage
          await _localStorage.updatePrintJobStatus(jobId, PrintJobStatus.pending);
          
          _updateStatus('Print job retried: ${job.jobName}');
          _notifyJobsUpdate();
          
          return true;
        } else {
          _updateStatus('Cannot retry job: max retries reached');
          return false;
        }
      }
      
      _updateStatus('Print job not found: $jobId');
      return false;
    } catch (e) {
      print('Error retrying print job: $e');
      _updateStatus('Failed to retry print job: $e');
      return false;
    }
  }

  /// Get jobs for specific printer
  List<PrintJob> getJobsForPrinter(String printerId) {
    return _allJobs.where((job) => job.printerId == printerId).toList();
  }

  /// Get pending jobs count
  int getPendingJobsCount() {
    return _allJobs.where((job) => 
      job.status == PrintJobStatus.pending || 
      job.status == PrintJobStatus.processing
    ).length;
  }

  /// Clear completed jobs
  Future<void> clearCompletedJobs() async {
    try {
      _allJobs.removeWhere((job) => job.isCompleted);
      await _localStorage.clearOldPrintJobs();
      _updateStatus('Completed jobs cleared');
      _notifyJobsUpdate();
    } catch (e) {
      print('Error clearing completed jobs: $e');
      _updateStatus('Failed to clear completed jobs: $e');
    }
  }

  /// Add job to appropriate printer queue
  void _addJobToQueue(PrintJob job) {
    // Ensure printer queue exists
    if (!_printerQueues.containsKey(job.printerId)) {
      _printerQueues[job.printerId] = Queue<PrintJob>();
      _printerProcessing[job.printerId] = false;
    }
    
    // Add to local jobs list
    final existingIndex = _allJobs.indexWhere((j) => j.id == job.id);
    if (existingIndex >= 0) {
      _allJobs[existingIndex] = job;
    } else {
      _allJobs.add(job);
    }
    
    // Add to printer queue (sorted by priority)
    final printerQueue = _printerQueues[job.printerId]!;
    
    // Insert job based on priority (higher priority = lower number = first)
    bool inserted = false;
    final tempList = printerQueue.toList();
    printerQueue.clear();
    
    for (final existingJob in tempList) {
      if (!inserted && job.priority < existingJob.priority) {
        printerQueue.add(job);
        inserted = true;
      }
      printerQueue.add(existingJob);
    }
    
    if (!inserted) {
      printerQueue.add(job);
    }
  }

  /// Start queue processor
  void _startQueueProcessor() {
    _queueProcessor?.cancel();
    _queueProcessor = Timer.periodic(const Duration(seconds: 2), (_) {
      _processQueues();
    });
  }

  /// Stop queue processor
  void _stopQueueProcessor() {
    _queueProcessor?.cancel();
    _queueProcessor = null;
  }

  /// Process all printer queues
  Future<void> _processQueues() async {
    if (_isProcessing) return;
    
    _isProcessing = true;
    
    try {
      for (final printerId in _printerQueues.keys) {
        await _processPrinterQueue(printerId);
      }
    } catch (e) {
      print('Error processing queues: $e');
    } finally {
      _isProcessing = false;
    }
  }

  /// Process queue for specific printer
  Future<void> _processPrinterQueue(String printerId) async {
    if (_printerProcessing[printerId] == true) return;
    
    final queue = _printerQueues[printerId];
    if (queue == null || queue.isEmpty) return;
    
    // Get printer info
    final configuredPrinters = await _localStorage.getConfiguredPrinters();
    final printer = configuredPrinters.firstWhere(
      (p) => p.id == printerId,
      orElse: () => throw Exception('Printer not found: $printerId'),
    );
    
    // Check if printer is online
    if (!printer.isOnline) {
      _updateStatus('Printer offline: ${printer.displayName}');
      return;
    }
    
    _printerProcessing[printerId] = true;
    
    try {
      final job = queue.removeFirst();
      
      // Update job status to processing
      final jobIndex = _allJobs.indexWhere((j) => j.id == job.id);
      if (jobIndex >= 0) {
        _allJobs[jobIndex] = job.copyWith(
          status: PrintJobStatus.processing,
          processedAt: DateTime.now(),
        );
        _notifyJobsUpdate();
      }
      
      // Process the job
      final success = await _processJob(printer, job);
      
      // Update job status
      final finalStatus = success ? PrintJobStatus.completed : PrintJobStatus.failed;
      final finalJob = job.copyWith(
        status: finalStatus,
        processedAt: DateTime.now(),
        error: success ? null : 'Printing failed',
      );
      
      if (jobIndex >= 0) {
        _allJobs[jobIndex] = finalJob;
      }
      
      // Update storage
      await _localStorage.updatePrintJobStatus(job.id, finalStatus, error: finalJob.error);
      
      _updateStatus(success 
          ? 'Print job completed: ${job.jobName}'
          : 'Print job failed: ${job.jobName}');
      
      _notifyJobsUpdate();
      
    } catch (e) {
      print('Error processing job for printer $printerId: $e');
      _updateStatus('Error processing job: $e');
    } finally {
      _printerProcessing[printerId] = false;
    }
  }

  /// Process individual print job
  Future<bool> _processJob(NetworkPrinter printer, PrintJob job) async {
    try {
      switch (job.type) {
        case PrintJobType.receipt:
          return await _processReceiptJob(printer, job);
        case PrintJobType.test:
          return await _processTestJob(printer, job);
        case PrintJobType.cashboxOpen:
          return await _processCashboxJob(printer, job);
        default:
          print('Unknown job type: ${job.type}');
          return false;
      }
    } catch (e) {
      print('Error processing job ${job.id}: $e');
      return false;
    }
  }

  /// Process receipt print job
  Future<bool> _processReceiptJob(NetworkPrinter printer, PrintJob job) async {
    try {
      final data = job.data;
      
      // Parse data
      POSOrder? order;
      if (data['order'] != null) {
        order = POSOrder.fromJson(data['order'] as Map<String, dynamic>);
      }
      
      final orderLines = (data['orderLines'] as List<dynamic>)
          .map((json) => POSOrderLine.fromJson(json as Map<String, dynamic>))
          .toList();
      
      final payments = Map<String, double>.from(data['payments'] as Map<dynamic, dynamic>);
      
      ResPartner? customer;
      if (data['customer'] != null) {
        customer = ResPartner.fromJson(data['customer'] as Map<String, dynamic>);
      }
      
      ResCompany? company;
      if (data['company'] != null) {
        company = ResCompany.fromJson(data['company'] as Map<String, dynamic>);
      }
      
      // Generate ESC-POS commands
      final commands = await _escposService.generateReceiptCommands(
        order: order,
        orderLines: orderLines,
        payments: payments,
        customer: customer,
        company: company,
        paperWidth: printer.capabilities.maxTextWidth,
      );
      
      // Send to printer
      return await _escposService.sendToPrinter(printer, commands);
      
    } catch (e) {
      print('Error processing receipt job: $e');
      return false;
    }
  }

  /// Process test print job
  Future<bool> _processTestJob(NetworkPrinter printer, PrintJob job) async {
    return await _escposService.testPrinter(printer);
  }

  /// Process cashbox open job
  Future<bool> _processCashboxJob(NetworkPrinter printer, PrintJob job) async {
    try {
      // ESC-POS command to open cash drawer
      final commands = [0x1B, 0x70, 0x00, 0x19, 0xFA]; // ESC p 0 25 250
      return await _escposService.sendToPrinter(printer, commands);
    } catch (e) {
      print('Error opening cashbox: $e');
      return false;
    }
  }

  /// Load pending jobs from storage
  Future<void> _loadPendingJobs() async {
    try {
      final pendingJobs = await _localStorage.getPendingPrintJobs();
      
      _allJobs.clear();
      _printerQueues.clear();
      _printerProcessing.clear();
      
      for (final job in pendingJobs) {
        _addJobToQueue(job);
      }
      
      print('Loaded ${pendingJobs.length} pending print jobs');
      _notifyJobsUpdate();
    } catch (e) {
      print('Error loading pending jobs: $e');
    }
  }

  /// Update status and notify listeners
  void _updateStatus(String status) {
    print('PrintQueueManager: $status');
    _statusController.add(status);
  }

  /// Notify jobs update
  void _notifyJobsUpdate() {
    _jobsController.add(_allJobs);
  }

  /// Dispose resources
  void dispose() {
    _stopQueueProcessor();
    _jobsController.close();
    _statusController.close();
  }
}
