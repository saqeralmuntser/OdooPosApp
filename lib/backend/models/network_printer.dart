import 'package:json_annotation/json_annotation.dart';

part 'network_printer.g.dart';

/// Network Printer Model
/// Represents a discovered or configured network printer
@JsonSerializable()
class NetworkPrinter {
  final String id;
  final String name;
  final String ipAddress;
  final int port;
  final PrinterType type;
  final PrinterStatus status;
  final String? macAddress;
  final String? manufacturer;
  final String? model;
  final DateTime? lastSeen;
  final bool isConfigured;
  final int? posConfigId; // Link to POS Config
  final PrinterCapabilities capabilities;

  const NetworkPrinter({
    required this.id,
    required this.name,
    required this.ipAddress,
    this.port = 9100, // Default ESC/POS port
    this.type = PrinterType.thermal,
    this.status = PrinterStatus.unknown,
    this.macAddress,
    this.manufacturer,
    this.model,
    this.lastSeen,
    this.isConfigured = false,
    this.posConfigId,
    this.capabilities = const PrinterCapabilities(),
  });

  factory NetworkPrinter.fromJson(Map<String, dynamic> json) =>
      _$NetworkPrinterFromJson(json);

  Map<String, dynamic> toJson() => _$NetworkPrinterToJson(this);

  NetworkPrinter copyWith({
    String? id,
    String? name,
    String? ipAddress,
    int? port,
    PrinterType? type,
    PrinterStatus? status,
    String? macAddress,
    String? manufacturer,
    String? model,
    DateTime? lastSeen,
    bool? isConfigured,
    int? posConfigId,
    PrinterCapabilities? capabilities,
  }) {
    return NetworkPrinter(
      id: id ?? this.id,
      name: name ?? this.name,
      ipAddress: ipAddress ?? this.ipAddress,
      port: port ?? this.port,
      type: type ?? this.type,
      status: status ?? this.status,
      macAddress: macAddress ?? this.macAddress,
      manufacturer: manufacturer ?? this.manufacturer,
      model: model ?? this.model,
      lastSeen: lastSeen ?? this.lastSeen,
      isConfigured: isConfigured ?? this.isConfigured,
      posConfigId: posConfigId ?? this.posConfigId,
      capabilities: capabilities ?? this.capabilities,
    );
  }

  /// Get printer connection string
  String get connectionString => '$ipAddress:$port';

  /// Check if printer is online
  bool get isOnline =>
      status == PrinterStatus.online || status == PrinterStatus.ready;

  /// Check if printer is linked to a POS config
  bool get isLinkedToPosConfig => posConfigId != null;

  /// Get display name for UI
  String get displayName {
    if (manufacturer != null && model != null) {
      return '$manufacturer $model ($ipAddress)';
    }
    return '$name ($ipAddress)';
  }

  @override
  String toString() {
    return 'NetworkPrinter(id: $id, name: $name, ipAddress: $ipAddress, status: $status)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is NetworkPrinter &&
        other.id == id &&
        other.ipAddress == ipAddress &&
        other.port == port;
  }

  @override
  int get hashCode => Object.hash(id, ipAddress, port);
}

/// Printer Types
enum PrinterType {
  @JsonValue('thermal')
  thermal,
  @JsonValue('inkjet')
  inkjet,
  @JsonValue('laser')
  laser,
  @JsonValue('label')
  label,
  @JsonValue('receipt')
  receipt,
  @JsonValue('unknown')
  unknown,
}

/// Printer Status
enum PrinterStatus {
  @JsonValue('unknown')
  unknown,
  @JsonValue('online')
  online,
  @JsonValue('offline')
  offline,
  @JsonValue('ready')
  ready,
  @JsonValue('busy')
  busy,
  @JsonValue('error')
  error,
  @JsonValue('paper_empty')
  paperEmpty,
  @JsonValue('paper_jam')
  paperJam,
  @JsonValue('door_open')
  doorOpen,
}

/// Printer Capabilities
@JsonSerializable()
class PrinterCapabilities {
  final bool supportsCutting;
  final bool supportsCashDrawer;
  final bool supportsImages;
  final bool supportsQrCodes;
  final bool supportsBarcodes;
  final List<int> supportedPaperWidths; // in mm
  final int maxTextWidth; // characters per line
  final bool supportsColor;
  final List<String> supportedLanguages;

  const PrinterCapabilities({
    this.supportsCutting = true,
    this.supportsCashDrawer = true,
    this.supportsImages = true,
    this.supportsQrCodes = true,
    this.supportsBarcodes = true,
    this.supportedPaperWidths = const [80, 58], // 80mm and 58mm
    this.maxTextWidth = 48, // for 80mm paper
    this.supportsColor = false,
    this.supportedLanguages = const ['en', 'ar'],
  });

  factory PrinterCapabilities.fromJson(Map<String, dynamic> json) =>
      _$PrinterCapabilitiesFromJson(json);

  Map<String, dynamic> toJson() => _$PrinterCapabilitiesToJson(this);
}

/// Print Job Model
@JsonSerializable()
class PrintJob {
  final String id;
  final String printerId;
  final String jobName;
  final PrintJobType type;
  final Map<String, dynamic> data;
  final PrintJobStatus status;
  final DateTime createdAt;
  final DateTime? processedAt;
  final String? error;
  final int priority;
  final int retryCount;
  final int maxRetries;

  const PrintJob({
    required this.id,
    required this.printerId,
    required this.jobName,
    required this.type,
    required this.data,
    this.status = PrintJobStatus.pending,
    required this.createdAt,
    this.processedAt,
    this.error,
    this.priority = 5,
    this.retryCount = 0,
    this.maxRetries = 3,
  });

  factory PrintJob.fromJson(Map<String, dynamic> json) =>
      _$PrintJobFromJson(json);

  Map<String, dynamic> toJson() => _$PrintJobToJson(this);

  PrintJob copyWith({
    String? id,
    String? printerId,
    String? jobName,
    PrintJobType? type,
    Map<String, dynamic>? data,
    PrintJobStatus? status,
    DateTime? createdAt,
    DateTime? processedAt,
    String? error,
    int? priority,
    int? retryCount,
    int? maxRetries,
  }) {
    return PrintJob(
      id: id ?? this.id,
      printerId: printerId ?? this.printerId,
      jobName: jobName ?? this.jobName,
      type: type ?? this.type,
      data: data ?? this.data,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      processedAt: processedAt ?? this.processedAt,
      error: error ?? this.error,
      priority: priority ?? this.priority,
      retryCount: retryCount ?? this.retryCount,
      maxRetries: maxRetries ?? this.maxRetries,
    );
  }

  /// Check if job can be retried
  bool get canRetry => retryCount < maxRetries && status == PrintJobStatus.failed;

  /// Check if job is completed (success or failed with no retries)
  bool get isCompleted =>
      status == PrintJobStatus.completed || 
      (status == PrintJobStatus.failed && !canRetry);

  @override
  String toString() {
    return 'PrintJob(id: $id, jobName: $jobName, status: $status)';
  }
}

/// Print Job Types
enum PrintJobType {
  @JsonValue('receipt')
  receipt,
  @JsonValue('report')
  report,
  @JsonValue('label')
  label,
  @JsonValue('test')
  test,
  @JsonValue('cashbox_open')
  cashboxOpen,
}

/// Print Job Status
enum PrintJobStatus {
  @JsonValue('pending')
  pending,
  @JsonValue('processing')
  processing,
  @JsonValue('completed')
  completed,
  @JsonValue('failed')
  failed,
  @JsonValue('cancelled')
  cancelled,
}
