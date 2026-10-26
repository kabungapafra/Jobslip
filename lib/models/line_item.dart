class LineItem {
  final String id;
  String description;
  double quantity;
  double unitPrice;

  /// What the quantity is counted in - "pcs", "roll(s)", "hrs", "m".
  /// Printed as its own column on an invoice; blank simply prints nothing.
  String unit;

  /// Groups lines on a quotation under a heading ("Roof", "Gutters").
  /// Consecutive lines sharing a category print it once, as in the template.
  String category;

  LineItem({
    required this.id,
    required this.description,
    required this.quantity,
    required this.unitPrice,
    this.unit = '',
    this.category = '',
  });

  double get amount => quantity * unitPrice;

  Map<String, dynamic> toJson() => {
    'id': id,
    'description': description,
    'quantity': quantity,
    'unitPrice': unitPrice,
    'unit': unit,
    'category': category,
  };

  /// `unit` and `category` arrived after the first release, so a line
  /// written by an older version must still load - blank, not missing.
  factory LineItem.fromJson(Map<String, dynamic> json) => LineItem(
    id: json['id'] as String,
    description: json['description'] as String,
    quantity: (json['quantity'] as num).toDouble(),
    unitPrice: (json['unitPrice'] as num).toDouble(),
    unit: (json['unit'] as String?) ?? '',
    category: (json['category'] as String?) ?? '',
  );
}
