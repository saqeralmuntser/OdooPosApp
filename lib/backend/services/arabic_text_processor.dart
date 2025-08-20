/// معالج النص العربي للطباعة
/// يحل مشاكل ترتيب الأحرف وربطها في PDF
class ArabicTextProcessor {
  static final ArabicTextProcessor _instance = ArabicTextProcessor._internal();
  factory ArabicTextProcessor() => _instance;
  ArabicTextProcessor._internal();

  /// خريطة الأحرف العربية مع أشكالها المختلفة (Unicode Presentation Forms)
  static const Map<String, Map<String, String>> _arabicShapes = {
    // الألف
    'ا': {'isolated': '\u0627', 'initial': '\u0627', 'medial': '\u0627', 'final': '\uFE8E'},
    // الباء
    'ب': {'isolated': '\u0628', 'initial': '\uFE91', 'medial': '\uFE92', 'final': '\uFE90'},
    // التاء
    'ت': {'isolated': '\u062A', 'initial': '\uFE95', 'medial': '\uFE96', 'final': '\uFE94'},
    // الثاء
    'ث': {'isolated': '\u062B', 'initial': '\uFE99', 'medial': '\uFE9A', 'final': '\uFE98'},
    // الجيم
    'ج': {'isolated': '\u062C', 'initial': '\uFE9D', 'medial': '\uFE9E', 'final': '\uFE9C'},
    // الحاء
    'ح': {'isolated': '\u062D', 'initial': '\uFEA1', 'medial': '\uFEA2', 'final': '\uFEA0'},
    // الخاء
    'خ': {'isolated': '\u062E', 'initial': '\uFEA5', 'medial': '\uFEA6', 'final': '\uFEA4'},
    // الدال
    'د': {'isolated': '\u062F', 'initial': '\u062F', 'medial': '\u062F', 'final': '\uFEAA'},
    // الذال
    'ذ': {'isolated': '\u0630', 'initial': '\u0630', 'medial': '\u0630', 'final': '\uFEAC'},
    // الراء
    'ر': {'isolated': '\u0631', 'initial': '\u0631', 'medial': '\u0631', 'final': '\uFEAE'},
    // الزاي
    'ز': {'isolated': '\u0632', 'initial': '\u0632', 'medial': '\u0632', 'final': '\uFEB0'},
    // السين
    'س': {'isolated': '\u0633', 'initial': '\uFEB1', 'medial': '\uFEB2', 'final': '\uFEB4'},
    // الشين
    'ش': {'isolated': '\u0634', 'initial': '\uFEB5', 'medial': '\uFEB6', 'final': '\uFEB8'},
    // الصاد
    'ص': {'isolated': '\u0635', 'initial': '\uFEB9', 'medial': '\uFEBA', 'final': '\uFEBC'},
    // الضاد
    'ض': {'isolated': '\u0636', 'initial': '\uFEBD', 'medial': '\uFEBE', 'final': '\uFEC0'},
    // الطاء
    'ط': {'isolated': '\u0637', 'initial': '\uFEC1', 'medial': '\uFEC2', 'final': '\uFEC4'},
    // الظاء
    'ظ': {'isolated': '\u0638', 'initial': '\uFEC5', 'medial': '\uFEC6', 'final': '\uFEC8'},
    // العين
    'ع': {'isolated': '\u0639', 'initial': '\uFEC9', 'medial': '\uFECA', 'final': '\uFECC'},
    // الغين
    'غ': {'isolated': '\u063A', 'initial': '\uFECD', 'medial': '\uFECE', 'final': '\uFED0'},
    // الفاء
    'ف': {'isolated': '\u0641', 'initial': '\uFED1', 'medial': '\uFED2', 'final': '\uFED4'},
    // القاف
    'ق': {'isolated': '\u0642', 'initial': '\uFED5', 'medial': '\uFED6', 'final': '\uFED8'},
    // الكاف
    'ك': {'isolated': '\u0643', 'initial': '\uFED9', 'medial': '\uFEDA', 'final': '\uFEDC'},
    // اللام
    'ل': {'isolated': '\u0644', 'initial': '\uFEDD', 'medial': '\uFEDE', 'final': '\uFEE0'},
    // الميم
    'م': {'isolated': '\u0645', 'initial': '\uFEE1', 'medial': '\uFEE2', 'final': '\uFEE4'},
    // النون
    'ن': {'isolated': '\u0646', 'initial': '\uFEE5', 'medial': '\uFEE6', 'final': '\uFEE8'},
    // الهاء
    'ه': {'isolated': '\u0647', 'initial': '\uFEE9', 'medial': '\uFEEA', 'final': '\uFEEC'},
    // الواو
    'و': {'isolated': '\u0648', 'initial': '\u0648', 'medial': '\u0648', 'final': '\uFEEE'},
    // الياء
    'ي': {'isolated': '\u064A', 'initial': '\uFEF1', 'medial': '\uFEF2', 'final': '\uFEF4'},
    // التاء المربوطة
    'ة': {'isolated': '\u0629', 'initial': '\u0629', 'medial': '\u0629', 'final': '\uFE94'},
    // الألف المقصورة
    'ى': {'isolated': '\u0649', 'initial': '\u0649', 'medial': '\u0649', 'final': '\uFEF0'},
    // الهمزة
    'ء': {'isolated': '\u0621', 'initial': '\u0621', 'medial': '\u0621', 'final': '\u0621'},
    // الألف الممدودة
    'آ': {'isolated': '\u0622', 'initial': '\u0622', 'medial': '\u0622', 'final': '\uFE82'},
    // الألف مع همزة فوق
    'أ': {'isolated': '\u0623', 'initial': '\u0623', 'medial': '\u0623', 'final': '\uFE84'},
    // الألف مع همزة تحت
    'إ': {'isolated': '\u0625', 'initial': '\u0625', 'medial': '\u0625', 'final': '\uFE88'},
    // الواو مع همزة
    'ؤ': {'isolated': '\u0624', 'initial': '\u0624', 'medial': '\u0624', 'final': '\uFE86'},
    // الياء مع همزة
    'ئ': {'isolated': '\u0626', 'initial': '\uFE89', 'medial': '\uFE8A', 'final': '\uFE8C'},
  };

  /// الأحرف التي لا تتصل بما بعدها
  static const Set<String> _nonConnectingChars = {
    'ا', 'د', 'ذ', 'ر', 'ز', 'و', 'ء', 'آ', 'أ', 'إ', 'ؤ'
  };

  /// فحص إذا كان النص يحتوي على أحرف عربية
  bool containsArabic(String text) {
    final arabicRegex = RegExp(r'[\u0600-\u06FF\u0750-\u077F\u08A0-\u08FF\uFB50-\uFDFF\uFE70-\uFEFF]');
    return arabicRegex.hasMatch(text);
  }

  /// فحص إذا كان الحرف عربي
  bool isArabicChar(String char) {
    final arabicRegex = RegExp(r'[\u0600-\u06FF\u0750-\u077F\u08A0-\u08FF\uFB50-\uFDFF\uFE70-\uFEFF]');
    return arabicRegex.hasMatch(char);
  }

  /// فحص إذا كان الحرف رقم
  bool isDigit(String char) {
    return RegExp(r'[0-9٠-٩]').hasMatch(char);
  }

  /// فحص إذا كان الحرف إنجليزي
  bool isEnglish(String char) {
    return RegExp(r'[a-zA-Z]').hasMatch(char);
  }

  /// تطبيق ربط الأحرف العربية (Arabic Text Shaping)
  String applyArabicShaping(String word) {
    if (word.isEmpty || !containsArabic(word)) {
      return word;
    }

    try {
      final chars = word.split('');
      final shapedChars = <String>[];

      for (int i = 0; i < chars.length; i++) {
        final char = chars[i];
        
        // تحقق إذا كان الحرف موجود في خريطة الأشكال
        if (_arabicShapes.containsKey(char)) {
          // تحديد شكل الحرف بناءً على موقعه
          String shape;
          
          if (i == 0) {
            // بداية الكلمة
            if (chars.length == 1) {
              // حرف منفرد
              shape = _arabicShapes[char]!['isolated']!;
            } else {
              // بداية الكلمة
              shape = _arabicShapes[char]!['initial']!;
            }
          } else if (i == chars.length - 1) {
            // نهاية الكلمة
            final prevChar = chars[i - 1];
            if (_nonConnectingChars.contains(prevChar)) {
              // الحرف السابق لا يتصل
              shape = _arabicShapes[char]!['isolated']!;
            } else {
              // متصل مع السابق
              shape = _arabicShapes[char]!['final']!;
            }
          } else {
            // وسط الكلمة
            final prevChar = chars[i - 1];
            if (_nonConnectingChars.contains(prevChar)) {
              // الحرف السابق لا يتصل
              shape = _arabicShapes[char]!['initial']!;
            } else {
              // متصل من الجانبين
              shape = _arabicShapes[char]!['medial']!;
            }
          }
          
          shapedChars.add(shape);
        } else {
          // حرف غير عربي أو غير مدعوم
          shapedChars.add(char);
        }
      }

      return shapedChars.join('');
    } catch (e) {
      print('Error applying Arabic shaping: $e');
      return word; // إرجاع الكلمة الأصلية في حالة الخطأ
    }
  }

  /// معالجة النص العربي المحسنة - مع ربط الأحرف
  String processArabicText(String text) {
    if (!containsArabic(text)) {
      return text; // إذا لم يكن هناك عربي، ارجع النص كما هو
    }

    try {
      // تقسيم النص إلى كلمات مع الحفاظ على المسافات
      final parts = <String>[];
      final currentWord = StringBuffer();
      bool isCurrentWordArabic = false;

      for (int i = 0; i < text.length; i++) {
        final char = text[i];
        
        if (char == ' ' || char == '\t' || char == '\n') {
          // إنهاء الكلمة الحالية
          if (currentWord.isNotEmpty) {
            if (isCurrentWordArabic) {
              // تطبيق ربط الأحرف وعكس الكلمة العربية
              String word = currentWord.toString();
              word = applyArabicShaping(word);
              word = _reverseString(word);
              parts.add(word);
            } else {
              // الكلمة الإنجليزية/الأرقام كما هي
              parts.add(currentWord.toString());
            }
            currentWord.clear();
          }
          parts.add(char); // إضافة المسافة
          isCurrentWordArabic = false;
        } else {
          // إضافة الحرف للكلمة الحالية
          if (currentWord.isEmpty) {
            // تحديد نوع الكلمة بناءً على أول حرف
            isCurrentWordArabic = isArabicChar(char);
          }
          currentWord.write(char);
        }
      }

      // إضافة آخر كلمة
      if (currentWord.isNotEmpty) {
        if (isCurrentWordArabic) {
          String word = currentWord.toString();
          word = applyArabicShaping(word);
          word = _reverseString(word);
          parts.add(word);
        } else {
          parts.add(currentWord.toString());
        }
      }

      // دمج الأجزاء
      final result = parts.join('');
      
      // عكس ترتيب الكلمات العربية في الجملة
      return _reverseArabicWordsOrder(result);
      
    } catch (e) {
      print('Error processing Arabic text: $e');
      return text; // إرجاع النص الأصلي في حالة الخطأ
    }
  }

  /// عكس ترتيب الكلمات العربية في الجملة
  String _reverseArabicWordsOrder(String text) {
    // تقسيم النص إلى كلمات
    final words = text.split(' ');
    final reversedWords = <String>[];
    
    // عكس ترتيب الكلمات العربية فقط
    for (int i = words.length - 1; i >= 0; i--) {
      if (words[i].isNotEmpty && containsArabic(words[i])) {
        reversedWords.add(words[i]);
      }
    }
    
    // إضافة الكلمات الإنجليزية في مواضعها الأصلية
    final result = <String>[];
    int arabicIndex = 0;
    
    for (final word in words) {
      if (word.isNotEmpty && containsArabic(word)) {
        if (arabicIndex < reversedWords.length) {
          result.add(reversedWords[arabicIndex]);
          arabicIndex++;
        } else {
          result.add(word);
        }
      } else {
        result.add(word);
      }
    }
    
    return result.join(' ');
  }

  /// عكس السلسلة النصية
  String _reverseString(String input) {
    return input.split('').reversed.join('');
  }

  /// معالجة متقدمة للنص المختلط (عربي + إنجليزي + أرقام)
  String processMixedText(String text) {
    if (!containsArabic(text)) {
      return text;
    }

    try {
      // معالجة أساسية للنص العربي
      String processed = processArabicText(text);
      
      // معالجة إضافية للأرقام والعلامات
      processed = _fixNumbersAndPunctuation(processed);
      
      return processed;
    } catch (e) {
      print('Error processing mixed text: $e');
      return text;
    }
  }

  /// إصلاح ترتيب الأرقام والعلامات
  String _fixNumbersAndPunctuation(String text) {
    // هذه دالة بسيطة لمعالجة الأرقام
    // يمكن تطويرها أكثر حسب الحاجة
    
    // عكس ترتيب الأرقام العربية إذا كانت في سياق عربي
    return text.replaceAllMapped(
      RegExp(r'[٠-٩]+'),
      (match) => _reverseString(match.group(0)!),
    );
  }

  /// معالجة بسيطة جداً للطباعة - بدون أي تعقيد!
  String processForPrinting(String text) {
    if (text.isEmpty) return text;
    
    try {
      print('🔄 SIMPLE processing for: "$text"');
      
      // فقط تنظيف بسيط - بدون أي معالجة معقدة
      String result = text.trim();
      
      print('✅ SIMPLE result: "$result"');
      return result;
      
    } catch (e) {
      print('❌ Error in simple processing: $e');
      return text;
    }
  }



  /// اختبار المعالج البسيط
  void runTests() {
    final tests = [
      'مرحبا بكم',
      'العميل: أحمد محمد',
      'فاتورة ضريبية مبسطة',
      'شركة زاد بن لادن التجارية',
    ];

    print('🧪 Testing SIMPLE Arabic Text Processor:');
    for (final test in tests) {
      final processed = processForPrinting(test);
      print('Original: $test');
      print('Simple Result: $processed');
      print('Has Arabic: ${containsArabic(test)}');
      print('---');
    }
  }
}
