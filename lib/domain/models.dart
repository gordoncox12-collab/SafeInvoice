enum InvoiceStatus { draft, sent, paid, overdue, cancelled }

enum FolderType { invoices, receipts, excel, images, notes }

enum TransactionType { payment, refund, expense, receipt }

enum ThemeModeOption { light, dark, system }

enum AccentPalette {
  forest,
  navy,
  emerald,
  amber,
  rose,
  slate,
  indigo,
  teal,
  coral,
  magenta,
  violet,
  azure,
  tangerine,
  fuchsia,
  sunshine,
  electric,
  crimson,
  mint,
}

enum TemplateLayout { classic, modern, compact, letterhead, minimal }

enum LogoAlignment { left, center, right }

enum MarginPreset { tight, normal, wide }

enum PicturePlacement { header, afterItems, footer }

enum PaymentOption { cash, eft, consignmentStock, swappedStock }

enum SignatureKind { authorised, pod }

extension EnumWire on Enum {
  String get wire => name.toUpperCase();
}

InvoiceStatus invoiceStatusFrom(String raw) {
  return InvoiceStatus.values.firstWhere(
    (e) => e.name.toUpperCase() == raw.toUpperCase(),
    orElse: () => InvoiceStatus.draft,
  );
}

String paymentOptionLabel(PaymentOption option) => switch (option) {
      PaymentOption.cash => 'Cash',
      PaymentOption.eft => 'EFT',
      PaymentOption.consignmentStock => 'Consignment stock',
      PaymentOption.swappedStock => 'Swapped stock',
    };

String paymentOptionWire(PaymentOption option) => switch (option) {
      PaymentOption.cash => 'CASH',
      PaymentOption.eft => 'EFT',
      PaymentOption.consignmentStock => 'CONSIGNMENT_STOCK',
      PaymentOption.swappedStock => 'SWAPPED_STOCK',
    };

PaymentOption? paymentOptionFrom(String? raw) {
  if (raw == null || raw.trim().isEmpty) return null;
  final key = raw.trim().toUpperCase().replaceAll(' ', '_');
  return switch (key) {
    'CASH' => PaymentOption.cash,
    'EFT' => PaymentOption.eft,
    'CONSIGNMENT_STOCK' || 'CONSIGNMENTSTOCK' => PaymentOption.consignmentStock,
    'SWAPPED_STOCK' || 'SWAPPEDSTOCK' => PaymentOption.swappedStock,
    _ => null,
  };
}

FolderType folderTypeFrom(String raw) {
  return FolderType.values.firstWhere(
    (e) => e.name.toUpperCase() == raw.toUpperCase() || e.name == raw.toLowerCase(),
    orElse: () => FolderType.invoices,
  );
}

class Business {
  const Business({
    required this.id,
    required this.name,
    this.tradingName,
    this.registrationNumber,
    this.vatNumber,
    this.email = '',
    this.phone = '',
    this.addressLine1 = '',
    this.addressLine2,
    this.city = '',
    this.province = '',
    this.postalCode = '',
    this.country = 'South Africa',
    this.bankName,
    this.bankAccountName,
    this.bankAccountNumber,
    this.bankBranchCode,
    this.logoPath,
    this.defaultCurrency = 'ZAR',
    this.defaultVatPercent = 15,
    this.invoicePrefix = 'INV',
    this.nextInvoiceNumber = 1,
    required this.createdAt,
    required this.updatedAt,
    this.isActive = true,
  });

  final String id;
  final String name;
  final String? tradingName;
  final String? registrationNumber;
  final String? vatNumber;
  final String email;
  final String phone;
  final String addressLine1;
  final String? addressLine2;
  final String city;
  final String province;
  final String postalCode;
  final String country;
  final String? bankName;
  final String? bankAccountName;
  final String? bankAccountNumber;
  final String? bankBranchCode;
  final String? logoPath;
  final String defaultCurrency;
  final double defaultVatPercent;
  final String invoicePrefix;
  final int nextInvoiceNumber;
  final int createdAt;
  final int updatedAt;
  final bool isActive;

  Business copyWith({
    String? name,
    String? tradingName,
    String? registrationNumber,
    String? vatNumber,
    String? email,
    String? phone,
    String? addressLine1,
    String? addressLine2,
    String? city,
    String? province,
    String? postalCode,
    String? country,
    String? bankName,
    String? bankAccountName,
    String? bankAccountNumber,
    String? bankBranchCode,
    String? logoPath,
    String? defaultCurrency,
    double? defaultVatPercent,
    String? invoicePrefix,
    int? nextInvoiceNumber,
    int? updatedAt,
    bool? isActive,
    bool clearLogo = false,
  }) {
    return Business(
      id: id,
      name: name ?? this.name,
      tradingName: tradingName ?? this.tradingName,
      registrationNumber: registrationNumber ?? this.registrationNumber,
      vatNumber: vatNumber ?? this.vatNumber,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      addressLine1: addressLine1 ?? this.addressLine1,
      addressLine2: addressLine2 ?? this.addressLine2,
      city: city ?? this.city,
      province: province ?? this.province,
      postalCode: postalCode ?? this.postalCode,
      country: country ?? this.country,
      bankName: bankName ?? this.bankName,
      bankAccountName: bankAccountName ?? this.bankAccountName,
      bankAccountNumber: bankAccountNumber ?? this.bankAccountNumber,
      bankBranchCode: bankBranchCode ?? this.bankBranchCode,
      logoPath: clearLogo ? null : (logoPath ?? this.logoPath),
      defaultCurrency: defaultCurrency ?? this.defaultCurrency,
      defaultVatPercent: defaultVatPercent ?? this.defaultVatPercent,
      invoicePrefix: invoicePrefix ?? this.invoicePrefix,
      nextInvoiceNumber: nextInvoiceNumber ?? this.nextInvoiceNumber,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isActive: isActive ?? this.isActive,
    );
  }

  Map<String, Object?> toMap() => {
        'id': id,
        'name': name,
        'tradingName': tradingName,
        'registrationNumber': registrationNumber,
        'vatNumber': vatNumber,
        'email': email,
        'phone': phone,
        'addressLine1': addressLine1,
        'addressLine2': addressLine2,
        'city': city,
        'province': province,
        'postalCode': postalCode,
        'country': country,
        'bankName': bankName,
        'bankAccountName': bankAccountName,
        'bankAccountNumber': bankAccountNumber,
        'bankBranchCode': bankBranchCode,
        'logoPath': logoPath,
        'defaultCurrency': defaultCurrency,
        'defaultVatPercent': defaultVatPercent,
        'invoicePrefix': invoicePrefix,
        'nextInvoiceNumber': nextInvoiceNumber,
        'createdAt': createdAt,
        'updatedAt': updatedAt,
        'isActive': isActive ? 1 : 0,
      };

  factory Business.fromMap(Map<String, Object?> m) => Business(
        id: m['id']! as String,
        name: m['name']! as String,
        tradingName: m['tradingName'] as String?,
        registrationNumber: m['registrationNumber'] as String?,
        vatNumber: m['vatNumber'] as String?,
        email: (m['email'] as String?) ?? '',
        phone: (m['phone'] as String?) ?? '',
        addressLine1: (m['addressLine1'] as String?) ?? '',
        addressLine2: m['addressLine2'] as String?,
        city: (m['city'] as String?) ?? '',
        province: (m['province'] as String?) ?? '',
        postalCode: (m['postalCode'] as String?) ?? '',
        country: (m['country'] as String?) ?? 'South Africa',
        bankName: m['bankName'] as String?,
        bankAccountName: m['bankAccountName'] as String?,
        bankAccountNumber: m['bankAccountNumber'] as String?,
        bankBranchCode: m['bankBranchCode'] as String?,
        logoPath: m['logoPath'] as String?,
        defaultCurrency: (m['defaultCurrency'] as String?) ?? 'ZAR',
        defaultVatPercent: (m['defaultVatPercent'] as num?)?.toDouble() ?? 15,
        invoicePrefix: (m['invoicePrefix'] as String?) ?? 'INV',
        nextInvoiceNumber: (m['nextInvoiceNumber'] as int?) ?? 1,
        createdAt: m['createdAt']! as int,
        updatedAt: m['updatedAt']! as int,
        isActive: (m['isActive'] as int? ?? 1) == 1,
      );
}

class Customer {
  const Customer({
    required this.id,
    required this.businessId,
    required this.name,
    this.contactName,
    this.email,
    this.phone,
    this.addressLine1,
    this.city,
    this.province,
    this.postalCode,
    this.vatNumber,
    this.notes,
    this.whatsapp,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String businessId;
  final String name;
  final String? contactName;
  final String? email;
  final String? phone;
  final String? addressLine1;
  final String? city;
  final String? province;
  final String? postalCode;
  final String? vatNumber;
  final String? notes;
  final String? whatsapp;
  final int createdAt;
  final int updatedAt;

  Customer copyWith({
    String? name,
    String? contactName,
    String? email,
    String? phone,
    String? addressLine1,
    String? city,
    String? province,
    String? postalCode,
    String? vatNumber,
    String? notes,
    String? whatsapp,
    int? updatedAt,
    bool clearWhatsapp = false,
  }) {
    return Customer(
      id: id,
      businessId: businessId,
      name: name ?? this.name,
      contactName: contactName ?? this.contactName,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      addressLine1: addressLine1 ?? this.addressLine1,
      city: city ?? this.city,
      province: province ?? this.province,
      postalCode: postalCode ?? this.postalCode,
      vatNumber: vatNumber ?? this.vatNumber,
      notes: notes ?? this.notes,
      whatsapp: clearWhatsapp ? null : (whatsapp ?? this.whatsapp),
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, Object?> toMap() => {
        'id': id,
        'businessId': businessId,
        'name': name,
        'contactName': contactName,
        'email': email,
        'phone': phone,
        'addressLine1': addressLine1,
        'city': city,
        'province': province,
        'postalCode': postalCode,
        'vatNumber': vatNumber,
        'notes': notes,
        'whatsapp': whatsapp,
        'createdAt': createdAt,
        'updatedAt': updatedAt,
      };

  factory Customer.fromMap(Map<String, Object?> m) => Customer(
        id: m['id']! as String,
        businessId: m['businessId']! as String,
        name: m['name']! as String,
        contactName: m['contactName'] as String?,
        email: m['email'] as String?,
        phone: m['phone'] as String?,
        addressLine1: m['addressLine1'] as String?,
        city: m['city'] as String?,
        province: m['province'] as String?,
        postalCode: m['postalCode'] as String?,
        vatNumber: m['vatNumber'] as String?,
        notes: m['notes'] as String?,
        whatsapp: m['whatsapp'] as String?,
        createdAt: m['createdAt']! as int,
        updatedAt: m['updatedAt']! as int,
      );
}

class Product {
  const Product({
    required this.id,
    required this.businessId,
    required this.name,
    this.description,
    this.unitPrice = 0,
    this.taxable = true,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String businessId;
  final String name;
  final String? description;
  final double unitPrice;
  final bool taxable;
  final int createdAt;
  final int updatedAt;

  Product copyWith({
    String? name,
    String? description,
    double? unitPrice,
    bool? taxable,
    int? updatedAt,
  }) {
    return Product(
      id: id,
      businessId: businessId,
      name: name ?? this.name,
      description: description ?? this.description,
      unitPrice: unitPrice ?? this.unitPrice,
      taxable: taxable ?? this.taxable,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, Object?> toMap() => {
        'id': id,
        'businessId': businessId,
        'name': name,
        'description': description,
        'unitPrice': unitPrice,
        'taxable': taxable ? 1 : 0,
        'createdAt': createdAt,
        'updatedAt': updatedAt,
      };

  factory Product.fromMap(Map<String, Object?> m) => Product(
        id: m['id']! as String,
        businessId: m['businessId']! as String,
        name: m['name']! as String,
        description: m['description'] as String?,
        unitPrice: (m['unitPrice'] as num?)?.toDouble() ?? 0,
        taxable: (m['taxable'] as int? ?? 1) == 1,
        createdAt: m['createdAt']! as int,
        updatedAt: m['updatedAt']! as int,
      );
}

class InvoiceLineItem {
  const InvoiceLineItem({
    required this.id,
    required this.invoiceId,
    required this.position,
    required this.description,
    this.quantity = 1,
    this.unitPrice = 0,
    this.taxable = true,
    this.productId,
  });

  final String id;
  final String invoiceId;
  final int position;
  final String description;
  final double quantity;
  final double unitPrice;
  final bool taxable;
  final String? productId;

  InvoiceLineItem applyProduct(Product product) {
    final desc = product.description == null || product.description!.trim().isEmpty
        ? product.name
        : '${product.name} — ${product.description}';
    return copyWith(
      productId: product.id,
      description: desc,
      unitPrice: product.unitPrice,
      taxable: product.taxable,
    );
  }

  InvoiceLineItem copyWith({
    int? position,
    String? description,
    double? quantity,
    double? unitPrice,
    bool? taxable,
    String? productId,
    bool clearProduct = false,
  }) {
    return InvoiceLineItem(
      id: id,
      invoiceId: invoiceId,
      position: position ?? this.position,
      description: description ?? this.description,
      quantity: quantity ?? this.quantity,
      unitPrice: unitPrice ?? this.unitPrice,
      taxable: taxable ?? this.taxable,
      productId: clearProduct ? null : (productId ?? this.productId),
    );
  }

  Map<String, Object?> toMap() => {
        'id': id,
        'invoiceId': invoiceId,
        'position': position,
        'description': description,
        'quantity': quantity,
        'unitPrice': unitPrice,
        'taxable': taxable ? 1 : 0,
        'productId': productId,
      };

  factory InvoiceLineItem.fromMap(Map<String, Object?> m) => InvoiceLineItem(
        id: m['id']! as String,
        invoiceId: m['invoiceId']! as String,
        position: m['position']! as int,
        description: m['description']! as String,
        quantity: (m['quantity'] as num?)?.toDouble() ?? 1,
        unitPrice: (m['unitPrice'] as num?)?.toDouble() ?? 0,
        taxable: (m['taxable'] as int? ?? 1) == 1,
        productId: m['productId'] as String?,
      );
}

class InvoiceImage {
  const InvoiceImage({
    required this.id,
    required this.invoiceId,
    required this.path,
    required this.sortOrder,
  });

  final String id;
  final String invoiceId;
  final String path;
  final int sortOrder;

  Map<String, Object?> toMap() => {
        'id': id,
        'invoiceId': invoiceId,
        'path': path,
        'sortOrder': sortOrder,
      };

  factory InvoiceImage.fromMap(Map<String, Object?> m) => InvoiceImage(
        id: m['id']! as String,
        invoiceId: m['invoiceId']! as String,
        path: m['path']! as String,
        sortOrder: m['sortOrder']! as int,
      );
}

class Invoice {
  const Invoice({
    required this.id,
    required this.businessId,
    required this.customerId,
    required this.number,
    required this.status,
    required this.issueDate,
    required this.dueDate,
    this.currency = 'ZAR',
    this.vatPercent = 15,
    this.discountAmount = 0,
    this.discountPercent = 0,
    this.notes,
    this.terms,
    this.signaturePath,
    this.pdfPath,
    this.templateId,
    this.subtotal = 0,
    this.vatAmount = 0,
    this.total = 0,
    this.paymentMethod,
    this.paymentNote,
    this.podSignaturePath,
    this.issuedAt,
    this.generatedAt,
    this.savedToStoragePath,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String businessId;
  final String customerId;
  final String number;
  final InvoiceStatus status;
  final int issueDate;
  final int dueDate;
  final String currency;
  final double vatPercent;
  final double discountAmount;
  final double discountPercent;
  final String? notes;
  final String? terms;
  final String? signaturePath;
  final String? pdfPath;
  final String? templateId;
  final double subtotal;
  final double vatAmount;
  final double total;
  final PaymentOption? paymentMethod;
  final String? paymentNote;
  final String? podSignaturePath;
  final int? issuedAt;
  final int? generatedAt;
  final String? savedToStoragePath;
  final int createdAt;
  final int updatedAt;

  bool get savedForLater => status == InvoiceStatus.draft;

  int get displayIssuedAt => issuedAt ?? issueDate;

  Invoice copyWith({
    String? customerId,
    String? number,
    InvoiceStatus? status,
    int? issueDate,
    int? dueDate,
    String? currency,
    double? vatPercent,
    double? discountAmount,
    double? discountPercent,
    String? notes,
    String? terms,
    String? signaturePath,
    String? pdfPath,
    String? templateId,
    double? subtotal,
    double? vatAmount,
    double? total,
    PaymentOption? paymentMethod,
    String? paymentNote,
    String? podSignaturePath,
    int? issuedAt,
    int? generatedAt,
    String? savedToStoragePath,
    int? updatedAt,
    bool clearSignature = false,
    bool clearPdf = false,
    bool clearPayment = false,
    bool clearPod = false,
    bool clearStorage = false,
  }) {
    return Invoice(
      id: id,
      businessId: businessId,
      customerId: customerId ?? this.customerId,
      number: number ?? this.number,
      status: status ?? this.status,
      issueDate: issueDate ?? this.issueDate,
      dueDate: dueDate ?? this.dueDate,
      currency: currency ?? this.currency,
      vatPercent: vatPercent ?? this.vatPercent,
      discountAmount: discountAmount ?? this.discountAmount,
      discountPercent: discountPercent ?? this.discountPercent,
      notes: notes ?? this.notes,
      terms: terms ?? this.terms,
      signaturePath: clearSignature ? null : (signaturePath ?? this.signaturePath),
      pdfPath: clearPdf ? null : (pdfPath ?? this.pdfPath),
      templateId: templateId ?? this.templateId,
      subtotal: subtotal ?? this.subtotal,
      vatAmount: vatAmount ?? this.vatAmount,
      total: total ?? this.total,
      paymentMethod: clearPayment ? null : (paymentMethod ?? this.paymentMethod),
      paymentNote: clearPayment ? null : (paymentNote ?? this.paymentNote),
      podSignaturePath: clearPod ? null : (podSignaturePath ?? this.podSignaturePath),
      issuedAt: issuedAt ?? this.issuedAt,
      generatedAt: generatedAt ?? this.generatedAt,
      savedToStoragePath: clearStorage ? null : (savedToStoragePath ?? this.savedToStoragePath),
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, Object?> toMap() => {
        'id': id,
        'businessId': businessId,
        'customerId': customerId,
        'number': number,
        'status': status.wire,
        'issueDate': issueDate,
        'dueDate': dueDate,
        'currency': currency,
        'vatPercent': vatPercent,
        'discountAmount': discountAmount,
        'discountPercent': discountPercent,
        'notes': notes,
        'terms': terms,
        'signaturePath': signaturePath,
        'pdfPath': pdfPath,
        'templateId': templateId,
        'subtotal': subtotal,
        'vatAmount': vatAmount,
        'total': total,
        'paymentMethod': paymentMethod == null ? null : paymentOptionWire(paymentMethod!),
        'paymentNote': paymentNote,
        'podSignaturePath': podSignaturePath,
        'issuedAt': issuedAt,
        'generatedAt': generatedAt,
        'savedToStoragePath': savedToStoragePath,
        'createdAt': createdAt,
        'updatedAt': updatedAt,
      };

  factory Invoice.fromMap(Map<String, Object?> m) => Invoice(
        id: m['id']! as String,
        businessId: m['businessId']! as String,
        customerId: m['customerId']! as String,
        number: m['number']! as String,
        status: invoiceStatusFrom(m['status']! as String),
        issueDate: m['issueDate']! as int,
        dueDate: m['dueDate']! as int,
        currency: (m['currency'] as String?) ?? 'ZAR',
        vatPercent: (m['vatPercent'] as num?)?.toDouble() ?? 15,
        discountAmount: (m['discountAmount'] as num?)?.toDouble() ?? 0,
        discountPercent: (m['discountPercent'] as num?)?.toDouble() ?? 0,
        notes: m['notes'] as String?,
        terms: m['terms'] as String?,
        signaturePath: m['signaturePath'] as String?,
        pdfPath: m['pdfPath'] as String?,
        templateId: m['templateId'] as String?,
        subtotal: (m['subtotal'] as num?)?.toDouble() ?? 0,
        vatAmount: (m['vatAmount'] as num?)?.toDouble() ?? 0,
        total: (m['total'] as num?)?.toDouble() ?? 0,
        paymentMethod: paymentOptionFrom(m['paymentMethod'] as String?),
        paymentNote: m['paymentNote'] as String?,
        podSignaturePath: m['podSignaturePath'] as String?,
        issuedAt: m['issuedAt'] as int?,
        generatedAt: m['generatedAt'] as int?,
        savedToStoragePath: m['savedToStoragePath'] as String?,
        createdAt: m['createdAt']! as int,
        updatedAt: m['updatedAt']! as int,
      );
}

class InvoiceDetails {
  const InvoiceDetails({
    required this.invoice,
    required this.items,
    required this.images,
  });

  final Invoice invoice;
  final List<InvoiceLineItem> items;
  final List<InvoiceImage> images;
}

class Txn {
  const Txn({
    required this.id,
    required this.businessId,
    this.customerId,
    this.invoiceId,
    required this.type,
    required this.amount,
    this.currency = 'ZAR',
    required this.occurredAt,
    this.method,
    this.reference,
    this.notes,
    this.receiptPath,
    required this.createdAt,
  });

  final String id;
  final String businessId;
  final String? customerId;
  final String? invoiceId;
  final TransactionType type;
  final double amount;
  final String currency;
  final int occurredAt;
  final String? method;
  final String? reference;
  final String? notes;
  final String? receiptPath;
  final int createdAt;

  Map<String, Object?> toMap() => {
        'id': id,
        'businessId': businessId,
        'customerId': customerId,
        'invoiceId': invoiceId,
        'type': type.wire,
        'amount': amount,
        'currency': currency,
        'occurredAt': occurredAt,
        'method': method,
        'reference': reference,
        'notes': notes,
        'receiptPath': receiptPath,
        'createdAt': createdAt,
      };

  factory Txn.fromMap(Map<String, Object?> m) => Txn(
        id: m['id']! as String,
        businessId: m['businessId']! as String,
        customerId: m['customerId'] as String?,
        invoiceId: m['invoiceId'] as String?,
        type: TransactionType.values.firstWhere(
          (e) => e.name.toUpperCase() == (m['type'] as String).toUpperCase(),
          orElse: () => TransactionType.payment,
        ),
        amount: (m['amount'] as num).toDouble(),
        currency: (m['currency'] as String?) ?? 'ZAR',
        occurredAt: m['occurredAt']! as int,
        method: m['method'] as String?,
        reference: m['reference'] as String?,
        notes: m['notes'] as String?,
        receiptPath: m['receiptPath'] as String?,
        createdAt: m['createdAt']! as int,
      );
}

class Note {
  const Note({
    required this.id,
    required this.businessId,
    required this.customerId,
    required this.title,
    required this.body,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String businessId;
  final String customerId;
  final String title;
  final String body;
  final int createdAt;
  final int updatedAt;

  Map<String, Object?> toMap() => {
        'id': id,
        'businessId': businessId,
        'customerId': customerId,
        'title': title,
        'body': body,
        'createdAt': createdAt,
        'updatedAt': updatedAt,
      };

  factory Note.fromMap(Map<String, Object?> m) => Note(
        id: m['id']! as String,
        businessId: m['businessId']! as String,
        customerId: m['customerId']! as String,
        title: m['title']! as String,
        body: m['body']! as String,
        createdAt: m['createdAt']! as int,
        updatedAt: m['updatedAt']! as int,
      );
}

class FolderFile {
  const FolderFile({
    required this.id,
    required this.businessId,
    required this.customerId,
    required this.folderType,
    required this.displayName,
    required this.mimeType,
    required this.relativePath,
    required this.sizeBytes,
    required this.createdAt,
  });

  final String id;
  final String businessId;
  final String customerId;
  final FolderType folderType;
  final String displayName;
  final String mimeType;
  final String relativePath;
  final int sizeBytes;
  final int createdAt;

  Map<String, Object?> toMap() => {
        'id': id,
        'businessId': businessId,
        'customerId': customerId,
        'folderType': folderType.wire,
        'displayName': displayName,
        'mimeType': mimeType,
        'relativePath': relativePath,
        'sizeBytes': sizeBytes,
        'createdAt': createdAt,
      };

  factory FolderFile.fromMap(Map<String, Object?> m) => FolderFile(
        id: m['id']! as String,
        businessId: m['businessId']! as String,
        customerId: m['customerId']! as String,
        folderType: folderTypeFrom(m['folderType']! as String),
        displayName: m['displayName']! as String,
        mimeType: m['mimeType']! as String,
        relativePath: m['relativePath']! as String,
        sizeBytes: m['sizeBytes']! as int,
        createdAt: m['createdAt']! as int,
      );
}

class InvoiceTemplate {
  const InvoiceTemplate({
    required this.id,
    required this.businessId,
    required this.name,
    this.isDefault = false,
    this.primaryColor = 0xFF0F766E,
    this.accentColor = 0xFFD4A017,
    this.logoPath,
    this.layout = TemplateLayout.classic,
    this.showBankDetails = true,
    this.footerText,
    this.headerImagePath,
    this.extraImagePath,
    this.logoAlignment = LogoAlignment.left,
    this.marginPreset = MarginPreset.normal,
    this.picturePlacement = PicturePlacement.afterItems,
    this.showSignatureLine = true,
    this.headerBanner = true,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String businessId;
  final String name;
  final bool isDefault;
  final int primaryColor;
  final int accentColor;
  final String? logoPath;
  final TemplateLayout layout;
  final bool showBankDetails;
  final String? footerText;
  final String? headerImagePath;
  final String? extraImagePath;
  final LogoAlignment logoAlignment;
  final MarginPreset marginPreset;
  final PicturePlacement picturePlacement;
  final bool showSignatureLine;
  final bool headerBanner;
  final int createdAt;
  final int updatedAt;

  InvoiceTemplate copyWith({
    String? name,
    bool? isDefault,
    int? primaryColor,
    int? accentColor,
    String? logoPath,
    TemplateLayout? layout,
    bool? showBankDetails,
    String? footerText,
    String? headerImagePath,
    String? extraImagePath,
    LogoAlignment? logoAlignment,
    MarginPreset? marginPreset,
    PicturePlacement? picturePlacement,
    bool? showSignatureLine,
    bool? headerBanner,
    int? updatedAt,
    bool clearLogo = false,
    bool clearHeader = false,
    bool clearExtra = false,
  }) {
    return InvoiceTemplate(
      id: id,
      businessId: businessId,
      name: name ?? this.name,
      isDefault: isDefault ?? this.isDefault,
      primaryColor: primaryColor ?? this.primaryColor,
      accentColor: accentColor ?? this.accentColor,
      logoPath: clearLogo ? null : (logoPath ?? this.logoPath),
      layout: layout ?? this.layout,
      showBankDetails: showBankDetails ?? this.showBankDetails,
      footerText: footerText ?? this.footerText,
      headerImagePath: clearHeader ? null : (headerImagePath ?? this.headerImagePath),
      extraImagePath: clearExtra ? null : (extraImagePath ?? this.extraImagePath),
      logoAlignment: logoAlignment ?? this.logoAlignment,
      marginPreset: marginPreset ?? this.marginPreset,
      picturePlacement: picturePlacement ?? this.picturePlacement,
      showSignatureLine: showSignatureLine ?? this.showSignatureLine,
      headerBanner: headerBanner ?? this.headerBanner,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, Object?> toMap() => {
        'id': id,
        'businessId': businessId,
        'name': name,
        'isDefault': isDefault ? 1 : 0,
        'primaryColor': primaryColor,
        'accentColor': accentColor,
        'logoPath': logoPath,
        'layout': layout.wire,
        'showBankDetails': showBankDetails ? 1 : 0,
        'footerText': footerText,
        'headerImagePath': headerImagePath,
        'extraImagePath': extraImagePath,
        'logoAlignment': logoAlignment.wire,
        'marginPreset': marginPreset.wire,
        'picturePlacement': picturePlacement == PicturePlacement.afterItems
            ? 'AFTER_ITEMS'
            : picturePlacement.wire,
        'showSignatureLine': showSignatureLine ? 1 : 0,
        'headerBanner': headerBanner ? 1 : 0,
        'createdAt': createdAt,
        'updatedAt': updatedAt,
      };

  factory InvoiceTemplate.fromMap(Map<String, Object?> m) => InvoiceTemplate(
        id: m['id']! as String,
        businessId: m['businessId']! as String,
        name: m['name']! as String,
        isDefault: (m['isDefault'] as int? ?? 0) == 1,
        primaryColor: m['primaryColor'] as int? ?? 0xFF0F766E,
        accentColor: m['accentColor'] as int? ?? 0xFFD4A017,
        logoPath: m['logoPath'] as String?,
        layout: TemplateLayout.values.firstWhere(
          (e) => e.name.toUpperCase() == (m['layout'] as String? ?? 'CLASSIC').toUpperCase(),
          orElse: () => TemplateLayout.classic,
        ),
        showBankDetails: (m['showBankDetails'] as int? ?? 1) == 1,
        footerText: m['footerText'] as String?,
        headerImagePath: m['headerImagePath'] as String?,
        extraImagePath: m['extraImagePath'] as String?,
        logoAlignment: LogoAlignment.values.firstWhere(
          (e) => e.name.toUpperCase() == (m['logoAlignment'] as String? ?? 'LEFT').toUpperCase(),
          orElse: () => LogoAlignment.left,
        ),
        marginPreset: MarginPreset.values.firstWhere(
          (e) => e.name.toUpperCase() == (m['marginPreset'] as String? ?? 'NORMAL').toUpperCase(),
          orElse: () => MarginPreset.normal,
        ),
        picturePlacement: () {
          final raw = (m['picturePlacement'] as String? ?? 'AFTER_ITEMS').toUpperCase();
          if (raw == 'AFTER_ITEMS' || raw == 'AFTERITEMS') {
            return PicturePlacement.afterItems;
          }
          return PicturePlacement.values.firstWhere(
            (e) => e.name.toUpperCase() == raw,
            orElse: () => PicturePlacement.afterItems,
          );
        }(),
        showSignatureLine: (m['showSignatureLine'] as int? ?? 1) == 1,
        headerBanner: (m['headerBanner'] as int? ?? 1) == 1,
        createdAt: m['createdAt']! as int,
        updatedAt: m['updatedAt']! as int,
      );
}

class AppSettings {
  const AppSettings({
    this.themeMode = ThemeModeOption.system,
    this.accentPalette = AccentPalette.forest,
    this.activeBusinessId,
  });

  final ThemeModeOption themeMode;
  final AccentPalette accentPalette;
  final String? activeBusinessId;

  AppSettings copyWith({
    ThemeModeOption? themeMode,
    AccentPalette? accentPalette,
    String? activeBusinessId,
    bool clearBusiness = false,
  }) {
    return AppSettings(
      themeMode: themeMode ?? this.themeMode,
      accentPalette: accentPalette ?? this.accentPalette,
      activeBusinessId: clearBusiness ? null : (activeBusinessId ?? this.activeBusinessId),
    );
  }

  Map<String, Object?> toMap() => {
        'id': 1,
        'themeMode': themeMode.wire,
        'accentPalette': accentPalette.wire,
        'activeBusinessId': activeBusinessId,
      };

  factory AppSettings.fromMap(Map<String, Object?> m) => AppSettings(
        themeMode: ThemeModeOption.values.firstWhere(
          (e) => e.name.toUpperCase() == (m['themeMode'] as String? ?? 'SYSTEM').toUpperCase(),
          orElse: () => ThemeModeOption.system,
        ),
        accentPalette: AccentPalette.values.firstWhere(
          (e) => e.name.toUpperCase() == (m['accentPalette'] as String? ?? 'FOREST').toUpperCase(),
          orElse: () => AccentPalette.forest,
        ),
        activeBusinessId: m['activeBusinessId'] as String?,
      );
}

const customerImportFields = <(String, String)>[
  ('name', 'Customer name'),
  ('contactName', 'Contact'),
  ('email', 'Email'),
  ('phone', 'Phone'),
  ('addressLine1', 'Address'),
  ('city', 'City'),
  ('province', 'Province'),
  ('postalCode', 'Postal code'),
  ('vatNumber', 'VAT number'),
  ('notes', 'Notes'),
];

const invoiceImportFields = <(String, String)>[
  ('customerName', 'Customer name'),
  ('number', 'Invoice number'),
  ('status', 'Status'),
  ('issueDate', 'Issue date'),
  ('dueDate', 'Due date'),
  ('description', 'Line description'),
  ('quantity', 'Quantity'),
  ('unitPrice', 'Unit price'),
  ('total', 'Total'),
  ('notes', 'Notes'),
];
