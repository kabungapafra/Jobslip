class LineItem {
  final String id;
  String description;
  double quantity;
  double unitPrice;

  LineItem({
    required this.id,
    required this.description,
    required this.quantity,
    required this.unitPrice,
  });

  double get amount => quantity * unitPrice;

  Map<String, dynamic> toJson() => {
        'id': id,
        'description': description,
        'quantity': quantity,
        'unitPrice': unitPrice,
      };

  factory LineItem.fromJson(Map<String, dynamic> json) => LineItem(
        id: json['id'] as String,
        description: json['description'] as String,
        quantity: (json['quantity'] as num).toDouble(),
        unitPrice: (json['unitPrice'] as num).toDouble(),
      );
}
