class AppUser {
  final int? id;
  final String fullName;
  final String email;
  final String passwordHash;

  const AppUser({
    this.id,
    required this.fullName,
    required this.email,
    required this.passwordHash,
  });

  factory AppUser.fromMap(Map<String, Object?> map) => AppUser(
    id: map['id'] as int?,
    fullName: map['full_name'] as String,
    email: map['email'] as String,
    passwordHash: map['password_hash'] as String,
  );

  Map<String, Object?> toMap() => {
    if (id != null) 'id': id,
    'full_name': fullName,
    'email': email,
    'password_hash': passwordHash,
  };
}

class Product {
  final int? id;
  final String name;
  final String description;
  final double price;

  /// Either an http(s) URL or an absolute path to a local image file.
  final String? image;

  const Product({
    this.id,
    required this.name,
    required this.description,
    required this.price,
    this.image,
  });

  factory Product.fromMap(Map<String, Object?> map) => Product(
    id: map['id'] as int?,
    name: map['name'] as String,
    description: map['description'] as String,
    price: (map['price'] as num).toDouble(),
    image: map['image'] as String?,
  );

  Map<String, Object?> toMap() => {
    if (id != null) 'id': id,
    'name': name,
    'description': description,
    'price': price,
    'image': image,
  };

  Product copyWith({
    int? id,
    String? name,
    String? description,
    double? price,
    String? image,
  }) => Product(
    id: id ?? this.id,
    name: name ?? this.name,
    description: description ?? this.description,
    price: price ?? this.price,
    image: image ?? this.image,
  );
}

class CartItem {
  final Product product;
  final int quantity;

  const CartItem({required this.product, required this.quantity});

  double get subtotal => product.price * quantity;
}

class OrderRecord {
  final int id;
  final double total;
  final DateTime createdAt;
  final int itemCount;

  const OrderRecord({
    required this.id,
    required this.total,
    required this.createdAt,
    required this.itemCount,
  });

  factory OrderRecord.fromMap(Map<String, Object?> map) => OrderRecord(
    id: map['id'] as int,
    total: (map['total'] as num).toDouble(),
    createdAt: DateTime.parse(map['created_at'] as String),
    itemCount: (map['item_count'] as num?)?.toInt() ?? 0,
  );
}
