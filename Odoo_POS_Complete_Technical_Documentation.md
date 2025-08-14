# التوثيق التقني الشامل والدقيق - نظام نقطة المبيعات Odoo 18

## 📋 نظرة عامة شاملة

هذا الدليل يوضح **جميع** البيانات والعمليات في نظام نقطة المبيعات Odoo 18 بتفصيل دقيق، مع التركيز على:
- **البيانات الكاملة للأصناف وخصائصها**
- **دورة حياة الجلسات بالتفصيل**
- **تسلسل العمليات الدقيق**
- **جميع النماذج والعلاقات**

---

## 🏗️ هيكل البيانات الكامل

### 1. النماذج الأساسية الرئيسية

#### 1.1 pos.config - إعدادات نقطة البيع
```sql
-- الحقول الأساسية
id: INTEGER PRIMARY KEY
name: VARCHAR NOT NULL -- اسم نقطة البيع
active: BOOLEAN DEFAULT TRUE -- حالة التفعيل
company_id: INTEGER REFERENCES res_company(id) -- الشركة
currency_id: INTEGER REFERENCES res_currency(id) -- العملة
pricelist_id: INTEGER REFERENCES product_pricelist(id) -- قائمة الأسعار الافتراضية
journal_id: INTEGER REFERENCES account_journal(id) -- دفتر اليومية
invoice_journal_id: INTEGER REFERENCES account_journal(id) -- دفتر الفواتير
picking_type_id: INTEGER REFERENCES stock_picking_type(id) -- نوع التسليم
warehouse_id: INTEGER REFERENCES stock_warehouse(id) -- المستودع

-- إعدادات الواجهة
iface_cashdrawer: BOOLEAN DEFAULT FALSE -- درج النقود
iface_electronic_scale: BOOLEAN DEFAULT FALSE -- الميزان الإلكتروني
iface_customer_facing_display: VARCHAR -- شاشة العميل
iface_print_auto: BOOLEAN DEFAULT FALSE -- طباعة تلقائية
iface_print_skip_screen: BOOLEAN DEFAULT FALSE -- تخطي شاشة الطباعة
iface_scan_via_proxy: BOOLEAN DEFAULT FALSE -- المسح عبر البروكسي
iface_big_scrollbars: BOOLEAN DEFAULT FALSE -- أشرطة التمرير الكبيرة
iface_print_via_proxy: BOOLEAN DEFAULT FALSE -- الطباعة عبر البروكسي

-- إعدادات الوظائف
module_pos_restaurant: BOOLEAN DEFAULT FALSE -- وضع المطعم
module_pos_discount: BOOLEAN DEFAULT FALSE -- الخصومات
module_pos_loyalty: BOOLEAN DEFAULT FALSE -- برنامج الولاء
module_pos_mercury: BOOLEAN DEFAULT FALSE -- دفع Mercury
use_pricelist: BOOLEAN DEFAULT FALSE -- استخدام قوائم الأسعار
group_by: BOOLEAN DEFAULT FALSE -- تجميع المنتجات
limit_categories: BOOLEAN DEFAULT FALSE -- تحديد الفئات
restrict_price_control: BOOLEAN DEFAULT FALSE -- تقييد التحكم في الأسعار
cash_control: BOOLEAN DEFAULT FALSE -- التحكم في النقد
receipt_header: TEXT -- رأس الفاتورة
receipt_footer: TEXT -- تذييل الفاتورة
proxy_ip: VARCHAR -- عنوان IP للبروكسي
other_devices: TEXT -- الأجهزة الأخرى

-- العلاقات
payment_method_ids: Many2many('pos.payment.method') -- طرق الدفع
available_pricelist_ids: Many2many('product.pricelist') -- قوائم الأسعار المتاحة
printer_ids: Many2many('pos.printer') -- الطابعات
iface_available_categ_ids: Many2many('pos.category') -- الفئات المتاحة
```

#### 1.2 pos.session - جلسة نقطة البيع
```sql
-- الحقول الأساسية
id: INTEGER PRIMARY KEY
name: VARCHAR UNIQUE NOT NULL -- اسم الجلسة (تلقائي)
config_id: INTEGER REFERENCES pos_config(id) NOT NULL -- ربط بالإعدادات
user_id: INTEGER REFERENCES res_users(id) NOT NULL -- المستخدم المسؤول
company_id: INTEGER REFERENCES res_company(id) -- الشركة
currency_id: INTEGER REFERENCES res_currency(id) -- العملة

-- حالة الجلسة وتوقيتاتها
state: VARCHAR DEFAULT 'opening_control' -- ('opening_control', 'opened', 'closing_control', 'closed')
start_at: TIMESTAMP -- تاريخ ووقت البداية
stop_at: TIMESTAMP -- تاريخ ووقت النهاية
sequence_number: INTEGER DEFAULT 1 -- رقم تسلسل الطلبات
login_number: INTEGER DEFAULT 0 -- رقم تسلسل تسجيل الدخول

-- إدارة النقد
cash_control: BOOLEAN -- التحكم في النقد
cash_journal_id: INTEGER REFERENCES account_journal(id) -- دفتر النقد
cash_register_balance_start: NUMERIC(16,2) -- رصيد النقد في البداية
cash_register_balance_end_real: NUMERIC(16,2) -- الرصيد الفعلي في النهاية
cash_register_balance_end: NUMERIC(16,2) -- الرصيد النظري في النهاية
cash_register_difference: NUMERIC(16,2) -- الفرق في النقد
cash_real_transaction: NUMERIC(16,2) -- المعاملات النقدية الفعلية

-- الملاحظات والتحكم
opening_notes: TEXT -- ملاحظات الافتتاح
closing_notes: TEXT -- ملاحظات الإغلاق
rescue: BOOLEAN DEFAULT FALSE -- جلسة إنقاذ
update_stock_at_closing: BOOLEAN -- تحديث المخزون عند الإغلاق

-- العلاقات
order_ids: One2many('pos.order', 'session_id') -- الطلبات
statement_line_ids: One2many('account.bank.statement.line', 'pos_session_id') -- بنود النقد
picking_ids: One2many('stock.picking', 'pos_session_id') -- التسليمات
payment_method_ids: Many2many('pos.payment.method') -- طرق الدفع
move_id: Many2one('account.move') -- القيد المحاسبي
bank_payment_ids: One2many('account.payment', 'pos_session_id') -- المدفوعات البنكية
```

### 2. نماذج المنتجات والأصناف (التفصيل الكامل)

#### 2.1 product.template - قالب المنتج
```sql
-- الحقول الأساسية
id: INTEGER PRIMARY KEY
name: VARCHAR NOT NULL -- اسم المنتج
default_code: VARCHAR -- الكود المرجعي
barcode: VARCHAR -- الباركود
sequence: INTEGER -- الترتيب
description: TEXT -- الوصف
description_sale: TEXT -- وصف البيع
public_description: HTML -- الوصف العام

-- إعدادات نقطة البيع
available_in_pos: BOOLEAN DEFAULT FALSE -- متاح في نقطة البيع
to_weight: BOOLEAN DEFAULT FALSE -- يحتاج وزن
color: INTEGER -- لون الفئة

-- الأسعار والتكاليف
list_price: NUMERIC(16,2) -- سعر القائمة
standard_price: NUMERIC(16,2) -- التكلفة المعيارية
currency_id: INTEGER REFERENCES res_currency(id) -- العملة

-- إعدادات المنتج
sale_ok: BOOLEAN DEFAULT TRUE -- قابل للبيع
purchase_ok: BOOLEAN DEFAULT TRUE -- قابل للشراء
active: BOOLEAN DEFAULT TRUE -- نشط
can_be_expensed: BOOLEAN DEFAULT FALSE -- قابل للمصروفات

-- الوحدات والقياسات
uom_id: INTEGER REFERENCES uom_uom(id) -- وحدة القياس
uom_po_id: INTEGER REFERENCES uom_uom(id) -- وحدة الشراء
weight: FLOAT -- الوزن
volume: FLOAT -- الحجم

-- العلاقات
categ_id: Many2one('product.category') -- فئة المنتج
pos_categ_ids: Many2many('pos.category') -- فئات نقطة البيع
taxes_id: Many2many('account.tax') -- الضرائب
supplier_taxes_id: Many2many('account.tax') -- ضرائب الموردين
product_variant_ids: One2many('product.product', 'product_tmpl_id') -- المتغيرات
attribute_line_ids: One2many('product.template.attribute.line', 'product_tmpl_id') -- خطوط الخصائص
product_tag_ids: Many2many('product.tag') -- علامات المنتج
route_ids: Many2many('stock.route') -- طرق المخزون
```

#### 2.2 product.product - متغير المنتج
```sql
-- الحقول الأساسية
id: INTEGER PRIMARY KEY
product_tmpl_id: INTEGER REFERENCES product_template(id) NOT NULL -- القالب الأساسي
default_code: VARCHAR -- كود المتغير
barcode: VARCHAR -- باركود المتغير
active: BOOLEAN DEFAULT TRUE -- نشط

-- الأسعار المحسوبة
lst_price: NUMERIC(16,2) -- سعر البيع (محسوب من القالب)
standard_price: NUMERIC(16,2) -- التكلفة (محسوب من القالب)
price_extra: NUMERIC(16,2) -- السعر الإضافي للمتغير

-- معلومات المخزون
qty_available: FLOAT -- الكمية المتاحة
virtual_available: FLOAT -- الكمية المتوقعة
incoming_qty: FLOAT -- الكمية الواردة
outgoing_qty: FLOAT -- الكمية الصادرة
free_qty: FLOAT -- الكمية المجانية

-- العلاقات
product_template_variant_value_ids: Many2many('product.template.attribute.value') -- قيم خصائص المتغير
combo_ids: Many2many('product.combo') -- الكومبوهات المرتبطة
packaging_ids: One2many('product.packaging', 'product_id') -- التعبئة والتغليف
seller_ids: One2many('product.supplierinfo', 'product_id') -- معلومات الموردين
```

#### 2.3 product.attribute - خصائص المنتج
```sql
-- الحقول الأساسية
id: INTEGER PRIMARY KEY
name: VARCHAR NOT NULL -- اسم الخاصية
display_type: VARCHAR -- نوع العرض ('radio', 'select', 'color', 'pills')
create_variant: VARCHAR -- إنشاء المتغيرات ('always', 'dynamic', 'no_variant')
sequence: INTEGER -- الترتيب

-- العلاقات
value_ids: One2many('product.attribute.value', 'attribute_id') -- القيم المتاحة
attribute_line_ids: One2many('product.template.attribute.line', 'attribute_id') -- خطوط الخصائص
```

#### 2.4 product.attribute.value - قيم الخصائص
```sql
-- الحقول الأساسية
id: INTEGER PRIMARY KEY
name: VARCHAR NOT NULL -- اسم القيمة
attribute_id: INTEGER REFERENCES product_attribute(id) NOT NULL -- الخاصية
sequence: INTEGER -- الترتيب
color: INTEGER -- لون القيمة
is_custom: BOOLEAN DEFAULT FALSE -- قيمة مخصصة
html_color: VARCHAR -- لون HTML
image: BINARY -- صورة القيمة
```

#### 2.5 product.template.attribute.line - خط خصائص القالب
```sql
-- الحقول الأساسية
id: INTEGER PRIMARY KEY
product_tmpl_id: INTEGER REFERENCES product_template(id) NOT NULL -- القالب
attribute_id: INTEGER REFERENCES product_attribute(id) NOT NULL -- الخاصية
required: BOOLEAN DEFAULT FALSE -- مطلوب

-- العلاقات
value_ids: Many2many('product.attribute.value') -- القيم المتاحة
product_template_value_ids: One2many('product.template.attribute.value', 'attribute_line_id') -- قيم القالب
```

#### 2.6 product.template.attribute.value - قيمة خاصية القالب
```sql
-- الحقول الأساسية
id: INTEGER PRIMARY KEY
product_tmpl_id: INTEGER REFERENCES product_template(id) -- القالب
attribute_line_id: INTEGER REFERENCES product_template_attribute_line(id) -- خط الخاصية
product_attribute_value_id: INTEGER REFERENCES product_attribute_value(id) -- قيمة الخاصية
price_extra: NUMERIC(16,2) -- السعر الإضافي
exclude_for: TEXT -- استبعاد للخصائص الأخرى
```

#### 2.7 product.combo - الكومبوهات
```sql
-- الحقول الأساسية
id: INTEGER PRIMARY KEY
name: VARCHAR NOT NULL -- اسم الكومبو
base_price: NUMERIC(16,2) -- السعر الأساسي
sequence: INTEGER -- الترتيب

-- العلاقات
combo_item_ids: One2many('product.combo.item', 'combo_id') -- عناصر الكومبو
```

#### 2.8 product.combo.item - عنصر الكومبو
```sql
-- الحقول الأساسية
id: INTEGER PRIMARY KEY
combo_id: INTEGER REFERENCES product_combo(id) NOT NULL -- الكومبو
product_id: INTEGER REFERENCES product_product(id) NOT NULL -- المنتج
extra_price: NUMERIC(16,2) -- السعر الإضافي
```

#### 2.9 pos.category - فئات نقطة البيع
```sql
-- الحقول الأساسية
id: INTEGER PRIMARY KEY
name: VARCHAR NOT NULL -- اسم الفئة
parent_id: INTEGER REFERENCES pos_category(id) -- الفئة الأب
sequence: INTEGER -- الترتيب
color: INTEGER -- اللون
image_128: BINARY -- الصورة
has_image: BOOLEAN -- يحتوي على صورة

-- العلاقات
child_ids: One2many('pos.category', 'parent_id') -- الفئات الفرعية
```

### 3. نماذج الضرائب والأسعار

#### 3.1 account.tax - الضرائب
```sql
-- الحقول الأساسية
id: INTEGER PRIMARY KEY
name: VARCHAR NOT NULL -- اسم الضريبة
amount_type: VARCHAR -- نوع المبلغ ('fixed', 'percent', 'division', 'group')
amount: NUMERIC(16,4) -- مبلغ الضريبة
type_tax_use: VARCHAR -- نوع الاستخدام ('sale', 'purchase', 'none')
price_include: BOOLEAN DEFAULT FALSE -- السعر شامل الضريبة
include_base_amount: BOOLEAN DEFAULT FALSE -- تضمين المبلغ الأساسي
is_base_affected: BOOLEAN DEFAULT FALSE -- يؤثر على الأساس
sequence: INTEGER -- الترتيب
company_id: INTEGER REFERENCES res_company(id) -- الشركة

-- العلاقات
tax_group_id: Many2one('account.tax.group') -- مجموعة الضريبة
children_tax_ids: Many2many('account.tax') -- الضرائب الفرعية
invoice_repartition_line_ids: One2many('account.tax.repartition.line') -- خطوط توزيع الفاتورة
refund_repartition_line_ids: One2many('account.tax.repartition.line') -- خطوط توزيع الاسترداد
```

#### 3.2 product.pricelist - قائمة الأسعار
```sql
-- الحقول الأساسية
id: INTEGER PRIMARY KEY
name: VARCHAR NOT NULL -- اسم قائمة الأسعار
active: BOOLEAN DEFAULT TRUE -- نشطة
currency_id: INTEGER REFERENCES res_currency(id) -- العملة
company_id: INTEGER REFERENCES res_company(id) -- الشركة
sequence: INTEGER -- الترتيب

-- العلاقات
item_ids: One2many('product.pricelist.item', 'pricelist_id') -- عناصر القائمة
country_group_ids: Many2many('res.country.group') -- مجموعات البلدان
```

#### 3.3 product.pricelist.item - عنصر قائمة الأسعار
```sql
-- الحقول الأساسية
id: INTEGER PRIMARY KEY
pricelist_id: INTEGER REFERENCES product_pricelist(id) NOT NULL -- قائمة الأسعار
product_tmpl_id: INTEGER REFERENCES product_template(id) -- قالب المنتج
product_id: INTEGER REFERENCES product_product(id) -- المنتج المحدد
categ_id: INTEGER REFERENCES product_category(id) -- فئة المنتج
min_quantity: FLOAT DEFAULT 0 -- الحد الأدنى للكمية
applied_on: VARCHAR -- المطبق على ('3_global', '2_product_category', '1_product', '0_product_variant')
compute_price: VARCHAR -- حساب السعر ('fixed', 'percentage', 'formula')
fixed_price: NUMERIC(16,2) -- السعر الثابت
percent_price: FLOAT -- نسبة السعر
price_discount: FLOAT -- خصم السعر
price_round: FLOAT -- تقريب السعر
price_surcharge: FLOAT -- رسوم إضافية
price_min_margin: FLOAT -- الحد الأدنى للهامش
price_max_margin: FLOAT -- الحد الأقصى للهامش
base: VARCHAR -- الأساس ('list_price', 'standard_price', 'pricelist')
base_pricelist_id: INTEGER REFERENCES product_pricelist(id) -- قائمة الأسعار الأساسية
date_start: DATE -- تاريخ البداية
date_end: DATE -- تاريخ النهاية
```

### 4. نماذج الطلبات والمدفوعات

#### 4.1 pos.order - طلب نقطة البيع
```sql
-- الحقول الأساسية
id: INTEGER PRIMARY KEY
name: VARCHAR -- اسم الطلب (تلقائي)
pos_reference: VARCHAR -- المرجع الخارجي
uuid: VARCHAR UNIQUE -- معرف فريد
session_id: INTEGER REFERENCES pos_session(id) NOT NULL -- الجلسة
config_id: INTEGER REFERENCES pos_config(id) -- الإعدادات
company_id: INTEGER REFERENCES res_company(id) -- الشركة
partner_id: INTEGER REFERENCES res_partner(id) -- العميل
user_id: INTEGER REFERENCES res_users(id) -- المستخدم
salesman_id: INTEGER REFERENCES res_users(id) -- البائع

-- التوقيتات
date_order: TIMESTAMP DEFAULT NOW() -- تاريخ الطلب
create_date: TIMESTAMP DEFAULT NOW() -- تاريخ الإنشاء
write_date: TIMESTAMP -- تاريخ التحديث

-- المبالغ والحسابات
amount_total: NUMERIC(16,2) -- المبلغ الإجمالي
amount_tax: NUMERIC(16,2) -- مبلغ الضريبة
amount_paid: NUMERIC(16,2) -- المبلغ المدفوع
amount_return: NUMERIC(16,2) -- مبلغ الاسترداد
currency_id: INTEGER REFERENCES res_currency(id) -- العملة
currency_rate: FLOAT DEFAULT 1.0 -- سعر الصرف

-- حالة الطلب
state: VARCHAR DEFAULT 'draft' -- ('draft', 'cancel', 'paid', 'done', 'invoiced')
to_invoice: BOOLEAN DEFAULT FALSE -- للفوترة
is_invoiced: BOOLEAN DEFAULT FALSE -- تم فوترته
is_tipped: BOOLEAN DEFAULT FALSE -- يحتوي على إكرامية
tip_amount: NUMERIC(16,2) -- مبلغ الإكرامية

-- إعدادات إضافية
sequence_number: INTEGER -- رقم التسلسل
tracking_number: VARCHAR -- رقم التتبع
fiscal_position_id: INTEGER REFERENCES account_fiscal_position(id) -- المركز الضريبي
pricelist_id: INTEGER REFERENCES product_pricelist(id) -- قائمة الأسعار
note: TEXT -- ملاحظات
nb_print: INTEGER DEFAULT 0 -- عدد مرات الطباعة
pos_session_id: INTEGER REFERENCES pos_session(id) -- الجلسة (مكرر للفهرسة)
ticket_code: VARCHAR -- كود التذكرة
access_token: VARCHAR -- رمز الوصول

-- العلاقات
lines: One2many('pos.order.line', 'order_id') -- بنود الطلب
payment_ids: One2many('pos.payment', 'pos_order_id') -- المدفوعات
statement_ids: Many2many('account.bank.statement.line') -- بنود النقد
picking_ids: One2many('stock.picking', 'pos_order_id') -- التسليمات
invoice_ids: Many2many('account.move') -- الفواتير
account_move: Many2one('account.move') -- القيد المحاسبي
```

#### 4.2 pos.order.line - بند طلب نقطة البيع
```sql
-- الحقول الأساسية
id: INTEGER PRIMARY KEY
order_id: INTEGER REFERENCES pos_order(id) NOT NULL -- الطلب
product_id: INTEGER REFERENCES product_product(id) NOT NULL -- المنتج
uuid: VARCHAR UNIQUE -- معرف فريد
full_product_name: VARCHAR -- الاسم الكامل للمنتج
company_id: INTEGER REFERENCES res_company(id) -- الشركة

-- الكميات والأسعار
qty: NUMERIC(16,3) -- الكمية
price_unit: NUMERIC(16,2) -- سعر الوحدة
price_subtotal: NUMERIC(16,2) -- المجموع الفرعي (بدون ضريبة)
price_subtotal_incl: NUMERIC(16,2) -- المجموع الفرعي (شامل الضريبة)
discount: NUMERIC(5,2) DEFAULT 0 -- نسبة الخصم
margin: NUMERIC(16,2) -- الهامش
margin_percent: FLOAT -- نسبة الهامش

-- معلومات إضافية
customer_note: TEXT -- ملاحظة العميل
refunded_orderline_id: INTEGER REFERENCES pos_order_line(id) -- البند المسترد
refunded_qty: NUMERIC(16,3) -- الكمية المستردة
total_cost: NUMERIC(16,2) -- التكلفة الإجمالية
is_total_cost_computed: BOOLEAN DEFAULT FALSE -- تم حساب التكلفة

-- العلاقات
tax_ids: Many2many('account.tax') -- الضرائب
tax_ids_after_fiscal_position: Many2many('account.tax') -- الضرائب بعد المركز الضريبي
pack_lot_ids: One2many('pos.pack.operation.lot', 'pos_order_line_id') -- أرقام اللوت
custom_attribute_value_ids: One2many('product.attribute.custom.value', 'pos_order_line_id') -- القيم المخصصة
```

#### 4.3 pos.payment - دفعة نقطة البيع
```sql
-- الحقول الأساسية
id: INTEGER PRIMARY KEY
name: VARCHAR -- تسمية الدفعة
pos_order_id: INTEGER REFERENCES pos_order(id) NOT NULL -- الطلب
payment_method_id: INTEGER REFERENCES pos_payment_method(id) NOT NULL -- طريقة الدفع
uuid: VARCHAR UNIQUE -- معرف فريد
amount: NUMERIC(16,2) -- المبلغ
currency_id: INTEGER REFERENCES res_currency(id) -- العملة
currency_rate: FLOAT -- سعر الصرف
payment_date: TIMESTAMP DEFAULT NOW() -- تاريخ الدفع
is_change: BOOLEAN DEFAULT FALSE -- هل هو فكة

-- معلومات البطاقة
card_type: VARCHAR -- نوع البطاقة
card_brand: VARCHAR -- علامة البطاقة
card_no: VARCHAR -- آخر 4 أرقام
cardholder_name: VARCHAR -- اسم حامل البطاقة

-- معلومات المعاملة
payment_ref_no: VARCHAR -- رقم مرجع الدفع
payment_method_authcode: VARCHAR -- كود التفويض
payment_method_issuer_bank: VARCHAR -- البنك المصدر
payment_method_payment_mode: VARCHAR -- وضع الدفع
transaction_id: VARCHAR -- معرف المعاملة
payment_status: VARCHAR -- حالة الدفع
ticket: VARCHAR -- معلومات الإيصال

-- العلاقات
session_id: Many2one('pos.session') -- الجلسة
partner_id: Many2one('res.partner') -- العميل
user_id: Many2one('res.users') -- المستخدم
company_id: Many2one('res.company') -- الشركة
account_move_id: Many2one('account.move') -- القيد المحاسبي
```

#### 4.4 pos.payment.method - طريقة الدفع
```sql
-- الحقول الأساسية
id: INTEGER PRIMARY KEY
name: VARCHAR NOT NULL -- اسم طريقة الدفع
sequence: INTEGER -- الترتيب
active: BOOLEAN DEFAULT TRUE -- نشطة
company_id: INTEGER REFERENCES res_company(id) -- الشركة

-- إعدادات الحسابات
outstanding_account_id: INTEGER REFERENCES account_account(id) -- الحساب المعلق
receivable_account_id: INTEGER REFERENCES account_account(id) -- الحساب المدين
journal_id: INTEGER REFERENCES account_journal(id) -- دفتر اليومية

-- إعدادات السلوك
is_cash_count: BOOLEAN -- عد النقد
split_transactions: BOOLEAN DEFAULT FALSE -- تقسيم المعاملات
open_session_ids: Many2many('pos.session') -- الجلسات المفتوحة
use_payment_terminal: VARCHAR -- استخدام طرفية الدفع

-- العلاقات
config_ids: Many2many('pos.config') -- إعدادات نقطة البيع
```

---

## 🔄 دورة حياة الجلسات (التفصيل الكامل)

### 1. مراحل حالة الجلسة

#### 1.1 opening_control - التحكم في الافتتاح
```python
# الحالة الافتراضية عند إنشاء جلسة جديدة
state = 'opening_control'

# العمليات المطلوبة:
1. تحديد رصيد النقد الابتدائي (إذا كان cash_control مفعل)
2. إدخال ملاحظات الافتتاح
3. التحقق من صحة البيانات
4. الانتقال إلى حالة 'opened'

# الطرق المستخدمة:
- set_opening_control(cashbox_value, notes)
- action_pos_session_open()
```

#### 1.2 opened - الجلسة مفتوحة
```python
# الحالة النشطة للبيع
state = 'opened'

# العمليات المتاحة:
1. إنشاء طلبات جديدة
2. معالجة المدفوعات
3. طباعة الفواتير
4. إدارة المخزون
5. تسجيل المعاملات النقدية

# معايير الانتقال:
- يجب أن تكون جميع الطلبات في حالة غير 'draft'
- لا توجد فواتير غير مرحلة
```

#### 1.3 closing_control - التحكم في الإغلاق
```python
# حالة ما قبل الإغلاق النهائي
state = 'closing_control'

# العمليات المطلوبة:
1. التحقق من رصيد النقد النهائي
2. مطابقة الأرصدة النظرية مع الفعلية
3. معالجة الفروقات
4. إدخال ملاحظات الإغلاق
5. التحقق من المعاملات المعلقة

# الطرق المستخدمة:
- action_pos_session_closing_control()
- _validate_session()
```

#### 1.4 closed - الجلسة مغلقة
```python
# الحالة النهائية
state = 'closed'

# العمليات المكتملة:
1. ترحيل جميع القيود المحاسبية
2. إنشاء التسليمات النهائية
3. تحديث المخزون
4. إغلاق جميع المعاملات
5. أرشفة البيانات
```

### 2. خوارزمية فتح/إغلاق الجلسات

#### 2.1 فتح جلسة جديدة
```python
def create_new_session(config_id, user_id):
    """
    خوارزمية فتح جلسة جديدة
    """
    # 1. التحقق من وجود جلسة مفتوحة
    existing_session = search_open_session(config_id, user_id)
    
    if existing_session:
        # استكمال الجلسة الموجودة
        return continue_existing_session(existing_session)
    
    # 2. إنشاء جلسة جديدة
    session_data = {
        'config_id': config_id,
        'user_id': user_id,
        'state': 'opening_control',
        'sequence_number': 1,
        'login_number': 0
    }
    
    # 3. تحديد اسم الجلسة التلقائي
    config_name = get_config_name(config_id)
    session_counter = get_next_session_counter(config_name)
    session_data['name'] = f"{config_name}/{session_counter:05d}"
    
    # 4. إعداد التحكم في النقد
    if config.cash_control:
        last_session = get_last_session(config_id)
        session_data['cash_register_balance_start'] = last_session.cash_register_balance_end_real or 0
    
    # 5. إنشاء الجلسة
    session = create_session(session_data)
    
    # 6. تفعيل الجلسة
    session.action_pos_session_open()
    
    return session

def search_open_session(config_id, user_id):
    """
    البحث عن جلسة مفتوحة
    """
    domain = [
        ('state', 'in', ['opening_control', 'opened']),
        ('user_id', '=', user_id),
        ('rescue', '=', False)
    ]
    
    if config_id:
        domain.append(('config_id', '=', config_id))
    
    return search_session(domain, limit=1)

def continue_existing_session(session):
    """
    استكمال جلسة موجودة
    """
    # تحديث رقم تسجيل الدخول
    session.login_number += 1
    
    # تحميل البيانات المطلوبة
    load_session_data(session)
    
    return session
```

#### 2.2 إغلاق الجلسة
```python
def close_session(session_id, closing_data):
    """
    خوارزمية إغلاق الجلسة
    """
    session = get_session(session_id)
    
    # 1. التحقق من حالة الجلسة
    if session.state == 'closed':
        raise UserError('الجلسة مغلقة بالفعل')
    
    # 2. التحقق من الطلبات المعلقة
    draft_orders = get_draft_orders(session)
    if draft_orders:
        raise UserError('يوجد طلبات لم تكتمل بعد')
    
    # 3. التحقق من الفواتير غير المرحلة
    unposted_invoices = get_unposted_invoices(session)
    if unposted_invoices:
        raise UserError('يوجد فواتير لم ترحل بعد')
    
    # 4. الانتقال إلى حالة closing_control
    session.state = 'closing_control'
    session.stop_at = datetime.now()
    
    # 5. معالجة التحكم في النقد
    if session.config_id.cash_control:
        process_cash_control(session, closing_data)
    
    # 6. إنشاء التسليمات النهائية
    if session.update_stock_at_closing:
        create_final_pickings(session)
    
    # 7. إنشاء القيود المحاسبية
    create_accounting_entries(session, closing_data)
    
    # 8. الإغلاق النهائي
    session.state = 'closed'
    
    # 9. تحديث حالة الطلبات
    update_orders_state(session)
    
    return True

def process_cash_control(session, closing_data):
    """
    معالجة التحكم في النقد
    """
    # حساب الرصيد النظري
    theoretical_balance = calculate_theoretical_balance(session)
    
    # الرصيد الفعلي المدخل
    actual_balance = closing_data.get('cash_register_balance_end_real', 0)
    
    # حساب الفرق
    difference = actual_balance - theoretical_balance
    
    # تسجيل الفرق
    if difference != 0:
        record_cash_difference(session, difference)
    
    # تحديث الأرصدة
    session.cash_register_balance_end_real = actual_balance
    session.cash_register_balance_end = theoretical_balance
    session.cash_register_difference = difference

def create_accounting_entries(session, closing_data):
    """
    إنشاء القيود المحاسبية
    """
    # جمع بيانات المدفوعات
    payment_data = collect_payment_data(session)
    
    # إنشاء القيد الرئيسي
    account_move = create_main_journal_entry(session, payment_data)
    
    # معالجة المدفوعات البنكية
    process_bank_payments(session, payment_data)
    
    # ترحيل القيد
    account_move.post()
    
    # ربط القيد بالجلسة
    session.move_id = account_move.id
```

### 3. تسلسل العمليات الدقيق

#### 3.1 تسلسل بدء الجلسة
```
1. إنشاء الجلسة (state='opening_control')
   ↓
2. تحديد اسم الجلسة التلقائي
   ↓
3. ربط الإعدادات والمستخدم
   ↓
4. تحديد رصيد النقد الابتدائي (إن وجد)
   ↓
5. تحميل طرق الدفع المتاحة
   ↓
6. تحميل بيانات المنتجات والفئات
   ↓
7. تحميل قوائم الأسعار والضرائب
   ↓
8. تحميل بيانات العملاء
   ↓
9. إعداد التسلسلات والعدادات
   ↓
10. تفعيل الجلسة (state='opened')
```

#### 3.2 تسلسل معالجة الطلب
```
1. إنشاء طلب جديد (state='draft')
   ↓
2. إضافة بنود الطلب
   ↓
3. حساب الأسعار والضرائب
   ↓
4. تطبيق الخصومات والعروض
   ↓
5. حساب الإجماليات
   ↓
6. إضافة المدفوعات
   ↓
7. التحقق من اكتمال الدفع
   ↓
8. تحديث حالة الطلب (state='paid')
   ↓
9. إنشاء التسليم (إن أمكن)
   ↓
10. طباعة الفاتورة
   ↓
11. تحديث المخزون (حسب الإعدادات)
   ↓
12. إنشاء القيود المحاسبية (إن أمكن)
```

#### 3.3 تسلسل إغلاق الجلسة
```
1. التحقق من اكتمال جميع الطلبات
   ↓
2. التحقق من ترحيل جميع الفواتير
   ↓
3. الانتقال إلى حالة closing_control
   ↓
4. جمع بيانات المدفوعات
   ↓
5. حساب أرصدة النقد
   ↓
6. معالجة الفروقات النقدية
   ↓
7. إنشاء التسليمات النهائية
   ↓
8. تحديث المخزون النهائي
   ↓
9. إنشاء القيود المحاسبية
   ↓
10. ترحيل جميع القيود
   ↓
11. إغلاق الجلسة (state='closed')
   ↓
12. أرشفة البيانات
```

---

## 🔗 العلاقات والروابط بين النماذج

### 1. مخطط العلاقات الأساسي
```
pos.config (1) ←→ (∞) pos.session
    ↓
pos.session (1) ←→ (∞) pos.order
    ↓
pos.order (1) ←→ (∞) pos.order.line
    ↓
pos.order (1) ←→ (∞) pos.payment

product.template (1) ←→ (∞) product.product
    ↓
product.product (∞) ←→ (∞) pos.category
    ↓
product.template (1) ←→ (∞) product.template.attribute.line
    ↓
product.template.attribute.line (1) ←→ (∞) product.template.attribute.value
```

### 2. علاقات الأصناف والخصائص
```
product.template
    ├── product.product (متغيرات المنتج)
    ├── product.template.attribute.line (خطوط الخصائص)
    │   ├── product.attribute (الخاصية)
    │   │   └── product.attribute.value (قيم الخاصية)
    │   └── product.template.attribute.value (قيم خاصية القالب)
    ├── pos.category (فئات نقطة البيع)
    ├── product.category (فئة المنتج الأساسية)
    ├── account.tax (الضرائب)
    └── product.combo (الكومبوهات)
        └── product.combo.item (عناصر الكومبو)
```

---

## 📊 APIs وطرق الوصول للبيانات

### 1. تحميل بيانات نقطة البيع الكاملة
```python
# الطريقة الرئيسية لتحميل جميع البيانات
def load_pos_data(session_id, models_to_load=None):
    """
    تحميل جميع البيانات المطلوبة لنقطة البيع
    """
    if not models_to_load:
        models_to_load = [
            'pos.config',
            'pos.session', 
            'product.product',
            'product.template',
            'product.attribute',
            'product.attribute.value',
            'product.template.attribute.line',
            'product.template.attribute.value',
            'product.combo',
            'product.combo.item',
            'pos.category',
            'product.category',
            'account.tax',
            'account.tax.group',
            'product.pricelist',
            'product.pricelist.item',
            'pos.payment.method',
            'res.partner',
            'res.currency',
            'res.country',
            'res.country.state',
            'account.fiscal.position',
            'pos.order',
            'pos.order.line',
            'pos.payment'
        ]
    
    session = get_session(session_id)
    config = session.config_id
    
    result = {}
    
    for model in models_to_load:
        model_obj = env[model]
        
        # تحديد النطاق (domain) لكل نموذج
        domain = model_obj._load_pos_data_domain({'pos.config': {'data': [config.read()[0]]}})
        
        # تحديد الحقول المطلوبة
        fields = model_obj._load_pos_data_fields(config.id)
        
        # تحميل البيانات
        data = model_obj.search_read(domain, fields)
        
        # معالجة البيانات الخاصة (إن وجدت)
        if hasattr(model_obj, '_load_pos_data'):
            processed_data = model_obj._load_pos_data({'pos.config': {'data': [config.read()[0]]}})
            if processed_data:
                data = processed_data.get('data', data)
        
        result[model] = {
            'data': data,
            'fields': fields
        }
    
    return result
```

### 2. APIs محددة للأصناف والخصائص
```python
# الحصول على تفاصيل المنتج الكاملة
def get_product_complete_info(product_id, config_id):
    """
    الحصول على جميع تفاصيل المنتج
    """
    product = env['product.product'].browse(product_id)
    config = env['pos.config'].browse(config_id)
    
    return {
        # البيانات الأساسية
        'basic_info': {
            'id': product.id,
            'name': product.display_name,
            'default_code': product.default_code,
            'barcode': product.barcode,
            'active': product.active,
            'available_in_pos': product.available_in_pos,
            'to_weight': product.to_weight,
            'type': product.type,
            'tracking': product.tracking
        },
        
        # الأسعار والتكاليف
        'pricing_info': {
            'lst_price': product.lst_price,
            'standard_price': product.standard_price,
            'currency_id': product.currency_id.id,
            'price_extra': product.price_extra
        },
        
        # الخصائص والمتغيرات
        'attributes_info': {
            'attribute_line_ids': product.attribute_line_ids.ids,
            'product_template_variant_value_ids': product.product_template_variant_value_ids.ids,
            'variant_info': get_product_variants(product)
        },
        
        # الفئات والتصنيفات
        'category_info': {
            'categ_id': product.categ_id.id,
            'pos_categ_ids': product.pos_categ_ids.ids,
            'product_tag_ids': product.product_tag_ids.ids
        },
        
        # الضرائب
        'tax_info': {
            'taxes_id': product.taxes_id.ids,
            'supplier_taxes_id': product.supplier_taxes_id.ids,
            'tax_calculation': calculate_product_taxes(product, config)
        },
        
        # المخزون
        'stock_info': {
            'qty_available': product.qty_available,
            'virtual_available': product.virtual_available,
            'incoming_qty': product.incoming_qty,
            'outgoing_qty': product.outgoing_qty
        },
        
        # قوائم الأسعار
        'pricelist_info': get_product_pricelists(product, config),
        
        # الكومبوهات
        'combo_info': {
            'combo_ids': product.combo_ids.ids,
            'combo_details': get_product_combos(product)
        },
        
        # معلومات الموردين
        'supplier_info': get_product_suppliers(product),
        
        # التعبئة والتغليف
        'packaging_info': {
            'packaging_ids': product.packaging_ids.ids,
            'packaging_details': get_product_packaging(product)
        }
    }

def get_product_variants(product):
    """
    الحصول على تفاصيل متغيرات المنتج
    """
    template = product.product_tmpl_id
    variants = []
    
    for variant in template.product_variant_ids:
        variant_data = {
            'id': variant.id,
            'name': variant.display_name,
            'default_code': variant.default_code,
            'barcode': variant.barcode,
            'lst_price': variant.lst_price,
            'standard_price': variant.standard_price,
            'active': variant.active,
            'attributes': []
        }
        
        # إضافة تفاصيل الخصائص
        for ptav in variant.product_template_variant_value_ids:
            variant_data['attributes'].append({
                'attribute_id': ptav.attribute_id.id,
                'attribute_name': ptav.attribute_id.name,
                'value_id': ptav.product_attribute_value_id.id,
                'value_name': ptav.product_attribute_value_id.name,
                'price_extra': ptav.price_extra,
                'html_color': ptav.html_color,
                'image': bool(ptav.image)
            })
        
        variants.append(variant_data)
    
    return variants

def calculate_product_taxes(product, config):
    """
    حساب الضرائب للمنتج
    """
    taxes = product.taxes_id.filtered(lambda t: t.company_id == config.company_id)
    
    tax_details = []
    for tax in taxes:
        tax_details.append({
            'id': tax.id,
            'name': tax.name,
            'amount': tax.amount,
            'amount_type': tax.amount_type,
            'price_include': tax.price_include,
            'include_base_amount': tax.include_base_amount,
            'sequence': tax.sequence
        })
    
    return tax_details
```

### 3. إدارة الجلسات المتقدمة
```python
def get_session_status(config_id, user_id):
    """
    الحصول على حالة الجلسة الحالية
    """
    # البحث عن جلسة مفتوحة
    open_session = env['pos.session'].search([
        ('config_id', '=', config_id),
        ('state', 'in', ['opening_control', 'opened']),
        ('rescue', '=', False)
    ], limit=1)
    
    if open_session:
        return {
            'has_active_session': True,
            'session_id': open_session.id,
            'session_name': open_session.name,
            'state': open_session.state,
            'user_id': open_session.user_id.id,
            'user_name': open_session.user_id.name,
            'start_at': open_session.start_at,
            'can_continue': open_session.user_id.id == user_id or user_has_manager_rights(user_id),
            'cash_control': open_session.cash_control,
            'cash_register_balance_start': open_session.cash_register_balance_start,
            'order_count': len(open_session.order_ids),
            'total_sales': sum(open_session.order_ids.mapped('amount_total'))
        }
    else:
        return {
            'has_active_session': False,
            'can_create_session': user_can_create_session(user_id, config_id),
            'last_session_info': get_last_session_info(config_id)
        }

def open_or_continue_session(config_id, user_id, opening_data=None):
    """
    فتح جلسة جديدة أو استكمال الموجودة
    """
    session_status = get_session_status(config_id, user_id)
    
    if session_status['has_active_session']:
        # استكمال الجلسة الموجودة
        session = env['pos.session'].browse(session_status['session_id'])
        
        if session.state == 'opening_control' and opening_data:
            # إكمال عملية الافتتاح
            session.set_opening_control(
                opening_data.get('cashbox_value', 0),
                opening_data.get('notes', '')
            )
        
        # تحديث رقم تسجيل الدخول
        login_number = session.login()
        
        return {
            'session_id': session.id,
            'login_number': login_number,
            'action': 'continued'
        }
    
    else:
        # إنشاء جلسة جديدة
        session = env['pos.session'].create({
            'config_id': config_id,
            'user_id': user_id
        })
        
        if opening_data and session.cash_control:
            session.set_opening_control(
                opening_data.get('cashbox_value', 0),
                opening_data.get('notes', '')
            )
        
        return {
            'session_id': session.id,
            'login_number': 1,
            'action': 'created'
        }

def close_session_with_validation(session_id, closing_data):
    """
    إغلاق الجلسة مع التحقق الكامل
    """
    session = env['pos.session'].browse(session_id)
    
    # التحقق من الصلاحيات
    if not user_can_close_session(session):
        raise AccessError('ليس لديك صلاحية إغلاق هذه الجلسة')
    
    # التحقق من الطلبات المعلقة
    validation_result = validate_session_for_closing(session)
    if not validation_result['can_close']:
        return {
            'success': False,
            'errors': validation_result['errors'],
            'warnings': validation_result['warnings']
        }
    
    # معالجة بيانات الإغلاق
    try:
        # التحكم في النقد
        if session.cash_control and closing_data.get('cash_register_balance_end_real') is not None:
            session.cash_register_balance_end_real = closing_data['cash_register_balance_end_real']
        
        # ملاحظات الإغلاق
        if closing_data.get('closing_notes'):
            session.closing_notes = closing_data['closing_notes']
        
        # معالجة فروقات طرق الدفع البنكية
        bank_payment_method_diffs = closing_data.get('bank_payment_method_diffs', {})
        
        # إغلاق الجلسة
        session.action_pos_session_closing_control(
            bank_payment_method_diffs=bank_payment_method_diffs
        )
        
        return {
            'success': True,
            'session_id': session.id,
            'final_state': session.state,
            'cash_difference': session.cash_register_difference,
            'total_sales': sum(session.order_ids.mapped('amount_total'))
        }
        
    except Exception as e:
        return {
            'success': False,
            'error': str(e)
        }
```

---

## 🎯 نقاط مهمة للتطبيق

### 1. متطلبات الاتصال الأساسية
```python
# معلومات الاتصال المطلوبة
connection_info = {
    'server_url': 'http://your-odoo-server.com',
    'database': 'your_database_name',
    'username': 'pos_user',
    'password': 'user_password',
    'api_key': 'optional_api_key'  # للإصدارات الحديثة
}

# الحقول الأساسية المطلوبة لكل نموذج
required_fields_per_model = {
    'pos.config': ['id', 'name', 'currency_id', 'pricelist_id', 'payment_method_ids', 'cash_control'],
    'pos.session': ['id', 'name', 'config_id', 'user_id', 'state', 'start_at', 'cash_register_balance_start'],
    'product.product': ['id', 'display_name', 'lst_price', 'standard_price', 'barcode', 'available_in_pos', 'taxes_id'],
    'pos.order': ['id', 'pos_reference', 'session_id', 'partner_id', 'amount_total', 'state', 'date_order'],
    'pos.order.line': ['id', 'order_id', 'product_id', 'qty', 'price_unit', 'price_subtotal', 'discount'],
    'pos.payment': ['id', 'pos_order_id', 'payment_method_id', 'amount', 'payment_date']
}
```

### 2. تسلسل العمليات الموصى به
```
1. تسجيل الدخول والمصادقة
2. الحصول على إعدادات نقطة البيع المتاحة
3. فتح أو استكمال جلسة
4. تحميل البيانات الأساسية (منتجات، فئات، ضرائب، إلخ)
5. بدء معالجة الطلبات
6. حفظ الطلبات محلياً ومزامنتها مع الخادم
7. إغلاق الجلسة عند الانتهاء
```

### 3. اعتبارات الأداء والمزامنة
```python
# استراتيجية تحميل البيانات
data_loading_strategy = {
    'initial_load': [
        'pos.config', 'pos.session', 'pos.payment.method',
        'product.product', 'pos.category', 'account.tax'
    ],
    'on_demand_load': [
        'res.partner', 'product.pricelist', 'product.combo'
    ],
    'background_sync': [
        'pos.order', 'pos.payment', 'stock.quant'
    ]
}

# إعدادات المزامنة
sync_settings = {
    'auto_sync_interval': 300,  # 5 دقائق
    'batch_size': 100,  # عدد السجلات في الدفعة الواحدة
    'retry_attempts': 3,  # عدد محاولات الإعادة
    'offline_mode': True,  # دعم العمل دون اتصال
    'conflict_resolution': 'server_wins'  # حل التعارضات
}
```

هذا التوثيق يوفر **جميع** البيانات والتفاصيل المطلوبة لبناء تطبيق Flutter متكامل مع نظام نقطة المبيعات في Odoo 18. كل جدول وعلاقة وعملية موثقة بدقة مع التسلسل الصحيح للعمليات.
