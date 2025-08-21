# نظام الكومبو - التنفيذ والتشغيل

## 🎯 نظرة عامة

تم تحديث نظام الكومبو ليعمل مع البيانات الحقيقية من Odoo بدون الحاجة لحقول إضافية غير موجودة في قاعدة البيانات.

## 🏗️ البنية الأساسية

### 1. نموذج البيانات (Models)

#### `ProductCombo` - تعريف الكومبو
```dart
class ProductCombo {
  final int id;
  final String name;
  final double basePrice;
  final int sequence;
  final List<int> comboItemIds; // معرفات عناصر الكومبو
}
```

#### `ProductComboItem` - عنصر الكومبو
```dart
class ProductComboItem {
  final int id;
  final int comboId;        // معرف الكومبو
  final int productId;      // معرف المنتج
  final double extraPrice;  // السعر الإضافي
}
```

### 2. العلاقات في Odoo

```
product.product (المنتج الرئيسي)
├── type = 'combo'                    // نوع المنتج
└── combo_ids → product.combo         // معرفات الكومبوهات

product.combo (تعريف الكومبو)
├── combo_item_ids → product.combo.item  // عناصر الكومبو

product.combo.item (عناصر الكومبو)
├── combo_id → product.combo            // معرف الكومبو
└── product_id → product.product        // معرف المنتج
```

## 🔄 سير العمل

### 1. التحقق من أن المنتج كومبو
```dart
bool isComboProduct(ProductProduct product) {
  return product.type == 'combo';
}
```

### 2. جلب عناصر الكومبو
```dart
// البحث في جدول product.combo.item
final comboItemsData = await _apiClient.searchRead(
  'product.combo.item',
  domain: [['combo_id', 'in', comboIds]],
  fields: ['id', 'combo_id', 'product_id', 'extra_price'],
);
```

### 3. التجميع الذكي للأقسام
```dart
String determineGroupName(ProductComboItem item, ProductProduct product) {
  // الاستراتيجية 1: حسب السعر الإضافي
  if (item.extraPrice > 0) {
    return 'Drinks choice';
  }
  
  // الاستراتيجية 2: حسب اسم المنتج
  final productName = product.displayName.toLowerCase();
  if (productName.contains('burger') || productName.contains('sandwich')) {
    return 'Burgers Choice';
  }
  if (productName.contains('drink') || productName.contains('beverage')) {
    return 'Drinks choice';
  }
  if (productName.contains('fries') || productName.contains('chips')) {
    return 'Side Items';
  }
  
  // الاستراتيجية 3: حسب نوع المنتج
  if (product.type != null && product.type!.isNotEmpty) {
    return product.type!;
  }
  
  // الاستراتيجية 4: افتراضي
  return 'Main Items';
}
```

## 📊 إنشاء أقسام الكومبو

### 1. تجميع العناصر حسب المجموعة
```dart
Map<String, List<ComboSectionItem>> sections = {};

for (final item in comboItems) {
  final groupName = determineGroupName(item, itemProduct);
  
  if (!sections.containsKey(groupName)) {
    sections[groupName] = [];
  }
  sections[groupName]!.add(sectionItem);
}
```

### 2. إنشاء أقسام الكومبو
```dart
final comboSections = sections.entries.map((entry) {
  return ComboSection(
    groupName: entry.key,
    selectionType: 'single',  // افتراضي
    required: true,           // افتراضي
    items: entry.value,
  );
}).toList();
```

## 🎨 واجهة المستخدم

### 1. نافذة اختيار الكومبو
- عرض الأقسام المختلفة (Burgers Choice, Drinks choice, Side Items)
- إمكانية اختيار عنصر واحد من كل قسم
- عرض السعر الإضافي لكل عنصر
- زر تأكيد الاختيار

### 2. عرض الكومبو في الطلب
- عرض العناصر المختارة
- حساب السعر الإجمالي (السعر الأساسي + الأسعار الإضافية)
- إمكانية تعديل الاختيارات

## 🔧 الإعداد في Odoo

### 1. إنشاء منتج كومبو
```
1. إنشاء منتج جديد
2. تعيين النوع: combo
3. إضافة معرفات الكومبو في حقل combo_ids
```

### 2. إنشاء عناصر الكومبو
```
1. الذهاب لجدول product.combo.item
2. إضافة سجل جديد
3. تحديد combo_id (معرف الكومبو)
4. تحديد product_id (معرف المنتج)
5. تحديد extra_price (السعر الإضافي)
```

## ✅ المميزات

1. **عمل مع البيانات الحقيقية**: لا يحتاج لحقول إضافية
2. **تجميع ذكي**: تجميع تلقائي حسب نوع المنتج والسعر
3. **مرونة**: دعم أنواع مختلفة من الكومبوهات
4. **أداء**: استخدام البيانات المخزنة محلياً
5. **سهولة الصيانة**: كود واضح ومنظم

## 🚀 الاستخدام

### 1. في الشاشة الرئيسية
```dart
if (posProvider.backendService.isComboProduct(product)) {
  // عرض نافذة اختيار الكومبو
  showComboSelectionDialog(context, product);
}
```

### 2. في إدارة الطلبات
```dart
final comboInfo = await posProvider.backendService.getComboDetails(product);
if (comboInfo != null) {
  // إضافة الكومبو للطلب
  order.addComboProduct(product, comboInfo);
}
```

## 🔍 استكشاف الأخطاء

### 1. مشاكل شائعة
- **جدول فارغ**: تأكد من وجود بيانات في `product.combo.item`
- **منتجات مفقودة**: تأكد من وجود المنتجات في `product.product`
- **علاقات خاطئة**: تأكد من صحة `combo_id` و `product_id`

### 2. رسائل التشخيص
```
🔍 التحقق من أن المنتج "اسم المنتج" هو كومبو...
   نوع المنتج من Odoo: "combo"
   معرفات الكومبو للمنتج من Odoo: [1, 2, 3]
✅ المنتج IS كومبو
```

## 📈 التطوير المستقبلي

1. **دعم المجموعات المخصصة**: إضافة حقل `group_name` في Odoo
2. **أنواع اختيار متقدمة**: single, multiple, required
3. **أسعار ديناميكية**: أسعار مختلفة حسب الوقت أو الكمية
4. **تخصيص الواجهة**: ألوان وأيقونات مخصصة لكل مجموعة

---

**ملاحظة**: هذا النظام يعمل مع البيانات الأساسية الموجودة في Odoo ولا يحتاج لتعديلات إضافية في قاعدة البيانات.
