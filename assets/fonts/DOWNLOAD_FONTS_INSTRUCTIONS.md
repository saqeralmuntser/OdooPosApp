# تعليمات تحميل الخطوط العربية - Arabic Fonts Download Instructions

## ✅ تم إعداد النظام لدعم الخط العربي!

تم إعداد نظام الطباعة لدعم النص العربي في PDF. تحتاج الآن لتحميل ملفات الخطوط التالية:

## 📥 الخطوط المطلوبة - Required Fonts

### 1. 🇸🇦 الخط العربي - Arabic Font (Noto Sans Arabic)
**تحميل من Google Fonts:**
- اذهب إلى: https://fonts.google.com/noto/specimen/Noto+Sans+Arabic
- اضغط على "Download family"
- استخرج الملفات واختر:
  - `NotoSansArabic-Regular.ttf`
  - `NotoSansArabic-Bold.ttf`

### 2. 🇬🇧 الخط الإنجليزي - English Font (Roboto)
**تحميل من Google Fonts:**
- اذهب إلى: https://fonts.google.com/specimen/Roboto
- اضغط على "Download family"
- استخرج الملفات واختر:
  - `Roboto-Regular.ttf`
  - `Roboto-Bold.ttf`

## 📂 خطوات التثبيت - Installation Steps

1. **تحميل الخطوط:**
   - حمل الخطوط من الروابط أعلاه
   - استخرج ملفات `.ttf` المطلوبة

2. **وضع الملفات:**
   - ضع الملفات الـ 4 في مجلد `assets/fonts/`
   - تأكد من الأسماء الصحيحة:
     ```
     assets/fonts/NotoSansArabic-Regular.ttf
     assets/fonts/NotoSansArabic-Bold.ttf
     assets/fonts/Roboto-Regular.ttf
     assets/fonts/Roboto-Bold.ttf
     ```

3. **إعادة تشغيل التطبيق:**
   ```bash
   flutter pub get
   flutter run
   ```

## 🔄 بدائل أخرى - Alternative Fonts

### خطوط عربية أخرى:
- **Cairo:** https://fonts.google.com/specimen/Cairo
- **Tajawal:** https://fonts.google.com/specimen/Tajawal
- **Amiri:** https://fonts.google.com/specimen/Amiri

### للاستخدام مع خطوط أخرى:
1. عدل `pubspec.yaml` وغير اسم العائلة
2. عدل `ArabicFontService` لاستخدام الاسم الجديد

## ✅ فحص حالة الخطوط - Font Status Check

بعد إضافة الخطوط، ستظهر رسالة في الكونسول:
- ✅ `جميع الخطوط متاحة (All fonts available)` - مثالي!
- ⚠️ `الخطوط العربية فقط متاحة` - يعمل للعربي فقط
- ⚠️ `الخطوط الإنجليزية فقط متاحة` - يعمل للإنجليزي فقط  
- ❌ `استخدام الخطوط الافتراضية` - قد تظهر رموز غريبة

## 🔧 حل المشاكل - Troubleshooting

### مشكلة: "رموز غريبة في PDF"
**الحل:**
1. تأكد من وضع ملفات الخطوط في المكان الصحيح
2. تأكد من أسماء الملفات الصحيحة
3. شغل `flutter pub get`
4. أعد تشغيل التطبيق

### مشكلة: "فايل الخط غير موجود"
**الحل:**
1. تأكد من تحميل الخطوط من الروابط الصحيحة
2. تأكد من استخراج ملفات `.ttf` وليس `.zip`
3. تأكد من وجود الملفات في `assets/fonts/`

## 📱 بعد إضافة الخطوط

عندما تطبع إيصال من نظام POS، ستحصل على:
- ✅ نص عربي واضح ومقروء
- ✅ نص إنجليزي مع خط Roboto الأنيق
- ✅ دعم كامل للـ QR Code
- ✅ تصميم مطابق لشاشة الإيصال

## 🎯 ملاحظات مهمة

- الخطوط تُحمل تلقائياً عند تشغيل التطبيق
- النظام يختار الخط المناسب تلقائياً (عربي/إنجليزي)
- يمكن استخدام خطوط أخرى بتعديل الكود
- الخطوط تعمل فقط في PDF، وليس في واجهة التطبيق

---

**🚀 جاهز للطباعة مع دعم عربي كامل!**
