import 'package:flutter/services.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart';
import 'arabic_text_processor.dart';

/// خدمة إدارة الخطوط العربية للطباعة
/// تتولى تحميل واستخدام الخطوط العربية في PDF
class ArabicFontService {
  static final ArabicFontService _instance = ArabicFontService._internal();
  factory ArabicFontService() => _instance;
  ArabicFontService._internal();

  pw.Font? _arabicRegularFont;
  pw.Font? _arabicBoldFont;
  pw.Font? _englishRegularFont;
  pw.Font? _englishBoldFont;
  bool _fontsLoaded = false;
  
  final ArabicTextProcessor _textProcessor = ArabicTextProcessor();

  /// تحميل الخطوط العربية والإنجليزية
  Future<void> loadFonts() async {
    if (_fontsLoaded) return;

    try {
      // محاولة تحميل الخطوط العربية
      try {
        final arabicRegularData = await rootBundle.load('assets/fonts/NotoSansArabic-Regular.ttf');
        _arabicRegularFont = pw.Font.ttf(arabicRegularData);
        
        final arabicBoldData = await rootBundle.load('assets/fonts/NotoSansArabic-Bold.ttf');
        _arabicBoldFont = pw.Font.ttf(arabicBoldData);
        
        print('✅ Arabic fonts loaded successfully');
      } catch (e) {
        print('⚠️ Arabic fonts not found: $e');
        print('📋 Using fallback fonts for Arabic text');
      }

      // محاولة تحميل خطوط إنجليزية
      try {
        final englishRegularData = await rootBundle.load('assets/fonts/Roboto-Regular.ttf');
        _englishRegularFont = pw.Font.ttf(englishRegularData);
        
        final englishBoldData = await rootBundle.load('assets/fonts/Roboto-Bold.ttf');
        _englishBoldFont = pw.Font.ttf(englishBoldData);
        
        print('✅ English fonts loaded successfully');
      } catch (e) {
        print('⚠️ English fonts not found: $e');
        print('📋 Using system default fonts');
      }

      _fontsLoaded = true;
      print('✅ Font service initialized');
      
    } catch (e) {
      print('❌ Error loading fonts: $e');
      _fontsLoaded = true; // Mark as loaded to avoid repeated attempts
    }
  }

  /// إنشاء TextStyle للنص العربي
  pw.TextStyle createArabicTextStyle({
    double fontSize = 12,
    bool isBold = false,
    PdfColor color = PdfColors.black,
  }) {
    return pw.TextStyle(
      font: isBold ? _arabicBoldFont : _arabicRegularFont,
      fontSize: fontSize,
      fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
      color: color,
    );
  }

  /// إنشاء TextStyle للنص الإنجليزي
  pw.TextStyle createEnglishTextStyle({
    double fontSize = 12,
    bool isBold = false,
    PdfColor color = PdfColors.black,
  }) {
    return pw.TextStyle(
      font: isBold ? _englishBoldFont : _englishRegularFont,
      fontSize: fontSize,
      fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
      color: color,
    );
  }

  /// إنشاء TextStyle تلقائي بناءً على نوع النص
  pw.TextStyle createTextStyle({
    required String text,
    double fontSize = 12,
    bool isBold = false,
    PdfColor color = PdfColors.black,
  }) {
    // فحص إذا كان النص يحتوي على أحرف عربية
    if (containsArabic(text)) {
      return createArabicTextStyle(fontSize: fontSize, isBold: isBold, color: color);
    } else {
      return createEnglishTextStyle(fontSize: fontSize, isBold: isBold, color: color);
    }
  }

  /// فحص إذا كان النص يحتوي على أحرف عربية
  bool containsArabic(String text) {
    final arabicRegex = RegExp(r'[\u0600-\u06FF\u0750-\u077F\u08A0-\u08FF\uFB50-\uFDFF\uFE70-\uFEFF]');
    return arabicRegex.hasMatch(text);
  }

  /// إنشاء نص بسيط - بدون معالجة معقدة
  pw.Widget createText(
    String text, {
    double fontSize = 12,
    bool isBold = false,
    PdfColor color = PdfColors.black,
    pw.TextAlign textAlign = pw.TextAlign.left,
  }) {
    print('🔤 Creating SIMPLE text: "$text"');
    
    // استخدام النص كما هو - بدون معالجة معقدة
    return pw.Text(
      text,
      style: createTextStyle(
        text: text,
        fontSize: fontSize,
        isBold: isBold,
        color: color,
      ),
      textAlign: textAlign,
      textDirection: containsArabic(text) ? pw.TextDirection.rtl : pw.TextDirection.ltr,
    );
  }

  /// إنشاء نص مركز بسيط - بدون معالجة معقدة
  pw.Widget createCenteredText(
    String text, {
    double fontSize = 12,
    bool isBold = false,
    PdfColor color = PdfColors.black,
  }) {
    print('🔤 Creating SIMPLE centered text: "$text"');
    
    // استخدام النص كما هو - بدون معالجة معقدة
    return pw.Center(
      child: pw.Text(
        text,
        style: createTextStyle(
          text: text,
          fontSize: fontSize,
          isBold: isBold,
          color: color,
        ),
        textAlign: pw.TextAlign.center,
        textDirection: containsArabic(text) ? pw.TextDirection.rtl : pw.TextDirection.ltr,
      ),
    );
  }

  /// فحص إذا كانت الخطوط العربية متاحة
  bool get areArabicFontsAvailable => _arabicRegularFont != null;

  /// فحص إذا كانت الخطوط الإنجليزية متاحة
  bool get areEnglishFontsAvailable => _englishRegularFont != null;

  /// فحص إذا كانت أي خطوط مخصصة متاحة
  bool get areCustomFontsAvailable => areArabicFontsAvailable || areEnglishFontsAvailable;

  /// رسالة حالة الخطوط
  String get fontStatus {
    if (areArabicFontsAvailable && areEnglishFontsAvailable) {
      return 'جميع الخطوط متاحة (All fonts available)';
    } else if (areArabicFontsAvailable) {
      return 'الخطوط العربية فقط متاحة (Arabic fonts only)';
    } else if (areEnglishFontsAvailable) {
      return 'الخطوط الإنجليزية فقط متاحة (English fonts only)';
    } else {
      return 'استخدام الخطوط الافتراضية (Using default fonts)';
    }
  }

  /// إعادة تعيين حالة الخطوط (مفيد للاختبار)
  void reset() {
    _arabicRegularFont = null;
    _arabicBoldFont = null;
    _englishRegularFont = null;
    _englishBoldFont = null;
    _fontsLoaded = false;
  }

  /// معالجة نص عربي للطباعة (دالة مساعدة)
  String processArabicForPrinting(String text) {
    return _textProcessor.processForPrinting(text);
  }

  /// فحص اكتشاف النص العربي
  bool detectsArabic(String text) {
    return _textProcessor.containsArabic(text);
  }

  /// تشغيل اختبارات بسيطة
  void runArabicProcessorTests() {
    print('🔤 Running SIMPLE Arabic Tests...');
    print('🔤 Font Status: $fontStatus');
    print('🔤 Arabic fonts available: $areArabicFontsAvailable');
    print('🔤 English fonts available: $areEnglishFontsAvailable');
    _textProcessor.runTests();
  }
}
