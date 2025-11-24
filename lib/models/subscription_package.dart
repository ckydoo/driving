class SubscriptionPackage {
  final int id;
  final String name;
  final String slug;
  final double monthlyPrice;
  final double? yearlyPrice;
  final String? description;
  final List<String> features;
  final Map<String, dynamic> limits;
  final int trialDays;
  final bool isPopular;
  final int yearlyDiscount;

  SubscriptionPackage({
    required this.id,
    required this.name,
    required this.slug,
    required this.monthlyPrice,
    this.yearlyPrice,
    this.description,
    required this.features,
    required this.limits,
    required this.trialDays,
    required this.isPopular,
    required this.yearlyDiscount,
  });

  factory SubscriptionPackage.fromJson(Map<String, dynamic> json) {
    return SubscriptionPackage(
      id: json['id'],
      name: json['name'],
      slug: json['slug'],
      monthlyPrice: double.parse(json['monthly_price'].toString()),
      yearlyPrice: json['yearly_price'] != null
          ? double.parse(json['yearly_price'].toString())
          : null,
      description: json['description'],
      features: List<String>.from(json['features'] ?? []),
      limits: Map<String, dynamic>.from(json['limits'] ?? {}),
      trialDays: json['trial_days'] ?? 30,
      isPopular: json['is_popular'] ?? false,
      yearlyDiscount: json['yearly_discount'] ?? 0,
    );
  }

  bool get hasYearlyPricing => yearlyPrice != null && yearlyPrice! > 0;

  int getLimit(String limitType) {
    return limits[limitType] ?? 0;
  }

  bool isUnlimited(String limitType) {
    return getLimit(limitType) == -1;
  }

  double getPrice(String billingPeriod) {
    return billingPeriod == 'yearly'
        ? (yearlyPrice ?? monthlyPrice)
        : monthlyPrice;
  }
}
