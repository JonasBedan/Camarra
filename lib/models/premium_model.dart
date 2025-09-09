import 'package:cloud_firestore/cloud_firestore.dart';

enum SubscriptionStatus { active, cancelled, expired, pending, trial }

enum SubscriptionPlan { monthly, yearly, lifetime }

class PremiumSubscriptionModel {
  final String id;
  final String userId;
  final SubscriptionPlan plan;
  final SubscriptionStatus status;
  final DateTime startDate;
  final DateTime endDate;
  final DateTime? cancelledAt;
  final double price;
  final String currency;
  final String? paymentMethodId;
  final bool isTrial;
  final DateTime? trialEndDate;
  final Map<String, dynamic> metadata;

  const PremiumSubscriptionModel({
    required this.id,
    required this.userId,
    required this.plan,
    required this.status,
    required this.startDate,
    required this.endDate,
    this.cancelledAt,
    required this.price,
    required this.currency,
    this.paymentMethodId,
    this.isTrial = false,
    this.trialEndDate,
    this.metadata = const {},
  });

  factory PremiumSubscriptionModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return PremiumSubscriptionModel(
      id: doc.id,
      userId: data['userId'] ?? '',
      plan: SubscriptionPlan.values.firstWhere(
        (e) => e.toString().split('.').last == data['plan'],
        orElse: () => SubscriptionPlan.monthly,
      ),
      status: SubscriptionStatus.values.firstWhere(
        (e) => e.toString().split('.').last == data['status'],
        orElse: () => SubscriptionStatus.pending,
      ),
      startDate: (data['startDate'] as Timestamp).toDate(),
      endDate: (data['endDate'] as Timestamp).toDate(),
      cancelledAt: data['cancelledAt'] != null
          ? (data['cancelledAt'] as Timestamp).toDate()
          : null,
      price: (data['price'] ?? 0.0).toDouble(),
      currency: data['currency'] ?? 'USD',
      paymentMethodId: data['paymentMethodId'],
      isTrial: data['isTrial'] ?? false,
      trialEndDate: data['trialEndDate'] != null
          ? (data['trialEndDate'] as Timestamp).toDate()
          : null,
      metadata: Map<String, dynamic>.from(data['metadata'] ?? {}),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'plan': plan.toString().split('.').last,
      'status': status.toString().split('.').last,
      'startDate': Timestamp.fromDate(startDate),
      'endDate': Timestamp.fromDate(endDate),
      'cancelledAt': cancelledAt != null
          ? Timestamp.fromDate(cancelledAt!)
          : null,
      'price': price,
      'currency': currency,
      'paymentMethodId': paymentMethodId,
      'isTrial': isTrial,
      'trialEndDate': trialEndDate != null
          ? Timestamp.fromDate(trialEndDate!)
          : null,
      'metadata': metadata,
    };
  }

  bool get isActive => status == SubscriptionStatus.active;
  bool get isExpired => DateTime.now().isAfter(endDate);
  bool get isInTrial =>
      isTrial && trialEndDate != null && DateTime.now().isBefore(trialEndDate!);
  int get daysRemaining => endDate.difference(DateTime.now()).inDays;

  PremiumSubscriptionModel copyWith({
    String? id,
    String? userId,
    SubscriptionPlan? plan,
    SubscriptionStatus? status,
    DateTime? startDate,
    DateTime? endDate,
    DateTime? cancelledAt,
    double? price,
    String? currency,
    String? paymentMethodId,
    bool? isTrial,
    DateTime? trialEndDate,
    Map<String, dynamic>? metadata,
  }) {
    return PremiumSubscriptionModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      plan: plan ?? this.plan,
      status: status ?? this.status,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      cancelledAt: cancelledAt ?? this.cancelledAt,
      price: price ?? this.price,
      currency: currency ?? this.currency,
      paymentMethodId: paymentMethodId ?? this.paymentMethodId,
      isTrial: isTrial ?? this.isTrial,
      trialEndDate: trialEndDate ?? this.trialEndDate,
      metadata: metadata ?? this.metadata,
    );
  }
}

class PremiumFeatureModel {
  final String id;
  final String name;
  final String description;
  final String icon;
  final bool isAvailable;
  final String category;
  final Map<String, dynamic> metadata;

  const PremiumFeatureModel({
    required this.id,
    required this.name,
    required this.description,
    required this.icon,
    required this.isAvailable,
    required this.category,
    this.metadata = const {},
  });

  factory PremiumFeatureModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return PremiumFeatureModel(
      id: doc.id,
      name: data['name'] ?? '',
      description: data['description'] ?? '',
      icon: data['icon'] ?? '',
      isAvailable: data['isAvailable'] ?? false,
      category: data['category'] ?? '',
      metadata: Map<String, dynamic>.from(data['metadata'] ?? {}),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'description': description,
      'icon': icon,
      'isAvailable': isAvailable,
      'category': category,
      'metadata': metadata,
    };
  }
}

class PremiumPlanModel {
  final String id;
  final String name;
  final String description;
  final double price;
  final String currency;
  final SubscriptionPlan plan;
  final int durationDays;
  final List<String> features;
  final bool isPopular;
  final bool isLifetime;
  final double? originalPrice;
  final String? discountText;

  const PremiumPlanModel({
    required this.id,
    required this.name,
    required this.description,
    required this.price,
    required this.currency,
    required this.plan,
    required this.durationDays,
    required this.features,
    this.isPopular = false,
    this.isLifetime = false,
    this.originalPrice,
    this.discountText,
  });

  factory PremiumPlanModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return PremiumPlanModel(
      id: doc.id,
      name: data['name'] ?? '',
      description: data['description'] ?? '',
      price: (data['price'] ?? 0.0).toDouble(),
      currency: data['currency'] ?? 'USD',
      plan: SubscriptionPlan.values.firstWhere(
        (e) => e.toString().split('.').last == data['plan'],
        orElse: () => SubscriptionPlan.monthly,
      ),
      durationDays: data['durationDays'] ?? 30,
      features: List<String>.from(data['features'] ?? []),
      isPopular: data['isPopular'] ?? false,
      isLifetime: data['isLifetime'] ?? false,
      originalPrice: data['originalPrice'] != null
          ? (data['originalPrice'] as num).toDouble()
          : null,
      discountText: data['discountText'],
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'description': description,
      'price': price,
      'currency': currency,
      'plan': plan.toString().split('.').last,
      'durationDays': durationDays,
      'features': features,
      'isPopular': isPopular,
      'isLifetime': isLifetime,
      'originalPrice': originalPrice,
      'discountText': discountText,
    };
  }

  bool get hasDiscount => originalPrice != null && originalPrice! > price;
  double get discountPercentage => hasDiscount
      ? ((originalPrice! - price) / originalPrice! * 100).roundToDouble()
      : 0.0;
}
