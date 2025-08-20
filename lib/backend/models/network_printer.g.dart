// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'network_printer.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

NetworkPrinter _$NetworkPrinterFromJson(Map<String, dynamic> json) =>
    NetworkPrinter(
      id: json['id'] as String,
      name: json['name'] as String,
      ipAddress: json['ipAddress'] as String,
      port: (json['port'] as num?)?.toInt() ?? 9100,
      type:
          $enumDecodeNullable(_$PrinterTypeEnumMap, json['type']) ??
          PrinterType.thermal,
      status:
          $enumDecodeNullable(_$PrinterStatusEnumMap, json['status']) ??
          PrinterStatus.unknown,
      macAddress: json['macAddress'] as String?,
      manufacturer: json['manufacturer'] as String?,
      model: json['model'] as String?,
      lastSeen: json['lastSeen'] == null
          ? null
          : DateTime.parse(json['lastSeen'] as String),
      isConfigured: json['isConfigured'] as bool? ?? false,
      posConfigId: (json['posConfigId'] as num?)?.toInt(),
      capabilities: json['capabilities'] == null
          ? const PrinterCapabilities()
          : PrinterCapabilities.fromJson(
              json['capabilities'] as Map<String, dynamic>,
            ),
    );

Map<String, dynamic> _$NetworkPrinterToJson(NetworkPrinter instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'ipAddress': instance.ipAddress,
      'port': instance.port,
      'type': _$PrinterTypeEnumMap[instance.type]!,
      'status': _$PrinterStatusEnumMap[instance.status]!,
      'macAddress': instance.macAddress,
      'manufacturer': instance.manufacturer,
      'model': instance.model,
      'lastSeen': instance.lastSeen?.toIso8601String(),
      'isConfigured': instance.isConfigured,
      'posConfigId': instance.posConfigId,
      'capabilities': instance.capabilities,
    };

const _$PrinterTypeEnumMap = {
  PrinterType.thermal: 'thermal',
  PrinterType.inkjet: 'inkjet',
  PrinterType.laser: 'laser',
  PrinterType.label: 'label',
  PrinterType.receipt: 'receipt',
  PrinterType.unknown: 'unknown',
};

const _$PrinterStatusEnumMap = {
  PrinterStatus.unknown: 'unknown',
  PrinterStatus.online: 'online',
  PrinterStatus.offline: 'offline',
  PrinterStatus.ready: 'ready',
  PrinterStatus.busy: 'busy',
  PrinterStatus.error: 'error',
  PrinterStatus.paperEmpty: 'paper_empty',
  PrinterStatus.paperJam: 'paper_jam',
  PrinterStatus.doorOpen: 'door_open',
};

PrinterCapabilities _$PrinterCapabilitiesFromJson(Map<String, dynamic> json) =>
    PrinterCapabilities(
      supportsCutting: json['supportsCutting'] as bool? ?? true,
      supportsCashDrawer: json['supportsCashDrawer'] as bool? ?? true,
      supportsImages: json['supportsImages'] as bool? ?? true,
      supportsQrCodes: json['supportsQrCodes'] as bool? ?? true,
      supportsBarcodes: json['supportsBarcodes'] as bool? ?? true,
      supportedPaperWidths:
          (json['supportedPaperWidths'] as List<dynamic>?)
              ?.map((e) => (e as num).toInt())
              .toList() ??
          const [80, 58],
      maxTextWidth: (json['maxTextWidth'] as num?)?.toInt() ?? 48,
      supportsColor: json['supportsColor'] as bool? ?? false,
      supportedLanguages:
          (json['supportedLanguages'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const ['en', 'ar'],
    );

Map<String, dynamic> _$PrinterCapabilitiesToJson(
  PrinterCapabilities instance,
) => <String, dynamic>{
  'supportsCutting': instance.supportsCutting,
  'supportsCashDrawer': instance.supportsCashDrawer,
  'supportsImages': instance.supportsImages,
  'supportsQrCodes': instance.supportsQrCodes,
  'supportsBarcodes': instance.supportsBarcodes,
  'supportedPaperWidths': instance.supportedPaperWidths,
  'maxTextWidth': instance.maxTextWidth,
  'supportsColor': instance.supportsColor,
  'supportedLanguages': instance.supportedLanguages,
};

PrintJob _$PrintJobFromJson(Map<String, dynamic> json) => PrintJob(
  id: json['id'] as String,
  printerId: json['printerId'] as String,
  jobName: json['jobName'] as String,
  type: $enumDecode(_$PrintJobTypeEnumMap, json['type']),
  data: json['data'] as Map<String, dynamic>,
  status:
      $enumDecodeNullable(_$PrintJobStatusEnumMap, json['status']) ??
      PrintJobStatus.pending,
  createdAt: DateTime.parse(json['createdAt'] as String),
  processedAt: json['processedAt'] == null
      ? null
      : DateTime.parse(json['processedAt'] as String),
  error: json['error'] as String?,
  priority: (json['priority'] as num?)?.toInt() ?? 5,
  retryCount: (json['retryCount'] as num?)?.toInt() ?? 0,
  maxRetries: (json['maxRetries'] as num?)?.toInt() ?? 3,
);

Map<String, dynamic> _$PrintJobToJson(PrintJob instance) => <String, dynamic>{
  'id': instance.id,
  'printerId': instance.printerId,
  'jobName': instance.jobName,
  'type': _$PrintJobTypeEnumMap[instance.type]!,
  'data': instance.data,
  'status': _$PrintJobStatusEnumMap[instance.status]!,
  'createdAt': instance.createdAt.toIso8601String(),
  'processedAt': instance.processedAt?.toIso8601String(),
  'error': instance.error,
  'priority': instance.priority,
  'retryCount': instance.retryCount,
  'maxRetries': instance.maxRetries,
};

const _$PrintJobTypeEnumMap = {
  PrintJobType.receipt: 'receipt',
  PrintJobType.report: 'report',
  PrintJobType.label: 'label',
  PrintJobType.test: 'test',
  PrintJobType.cashboxOpen: 'cashbox_open',
};

const _$PrintJobStatusEnumMap = {
  PrintJobStatus.pending: 'pending',
  PrintJobStatus.processing: 'processing',
  PrintJobStatus.completed: 'completed',
  PrintJobStatus.failed: 'failed',
  PrintJobStatus.cancelled: 'cancelled',
};
