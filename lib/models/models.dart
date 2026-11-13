/// What a signed-in account may see and do on the marketplace.
enum UserRole {
  /// Runs the platform: every product, every order, every account.
  admin,

  /// Owns a shop: manages its own products and sees its own sales.
  seller,

  /// Shops: browses all products, keeps a cart and places orders.
  customer;

  static UserRole fromName(String? name) => UserRole.values.firstWhere(
    (r) => r.name == name,
    orElse: () => UserRole.customer,
  );

  String get label => switch (this) {
    UserRole.admin => 'Admin',
    UserRole.seller => 'Seller',
    UserRole.customer => 'Customer',
  };
}

class AppUser {
  final int? id;
  final String fullName;
  final String email;
  final String passwordHash;
  final UserRole role;

  /// Shop name, set for sellers.
  final String? shopName;

  const AppUser({
    this.id,
    required this.fullName,
    required this.email,
    required this.passwordHash,
    this.role = UserRole.customer,
    this.shopName,
  });

  bool get isAdmin => role == UserRole.admin;
  bool get isSeller => role == UserRole.seller;
  bool get isCustomer => role == UserRole.customer;

  /// Admins manage every product; sellers only the ones of their shop.
  bool canManage(Product product) =>
      isAdmin || (isSeller && product.sellerId == id);

  factory AppUser.fromMap(Map<String, Object?> map) => AppUser(
    id: map['id'] as int?,
    fullName: map['full_name'] as String,
    email: map['email'] as String,
    passwordHash: map['password_hash'] as String,
    role: UserRole.fromName(map['role'] as String?),
    shopName: map['shop_name'] as String?,
  );

  Map<String, Object?> toMap() => {
    if (id != null) 'id': id,
    'full_name': fullName,
    'email': email,
    'password_hash': passwordHash,
    'role': role.name,
    'shop_name': shopName,
  };
}

class Product {
  final int? id;
  final String name;
  final String description;
  final double price;

  /// Either an http(s) URL or an absolute path to a local image file.
  final String? image;

  /// The seller account that owns this product.
  final int? sellerId;

  /// The owning shop's name, read from the seller; never stored on the product.
  final String? shopName;

  const Product({
    this.id,
    required this.name,
    required this.description,
    required this.price,
    this.image,
    this.sellerId,
    this.shopName,
  });

  factory Product.fromMap(Map<String, Object?> map) => Product(
    id: map['id'] as int?,
    name: map['name'] as String,
    description: map['description'] as String,
    price: (map['price'] as num).toDouble(),
    image: map['image'] as String?,
    sellerId: map['seller_id'] as int?,
    shopName: map['shop_name'] as String?,
  );

  Map<String, Object?> toMap() => {
    if (id != null) 'id': id,
    'name': name,
    'description': description,
    'price': price,
    'image': image,
    'seller_id': sellerId,
  };

  Product copyWith({
    int? id,
    String? name,
    String? description,
    double? price,
    String? image,
    int? sellerId,
  }) => Product(
    id: id ?? this.id,
    name: name ?? this.name,
    description: description ?? this.description,
    price: price ?? this.price,
    image: image ?? this.image,
    sellerId: sellerId ?? this.sellerId,
    shopName: shopName,
  );
}

class CartItem {
  final Product product;
  final int quantity;

  const CartItem({required this.product, required this.quantity});

  double get subtotal => product.price * quantity;
}

/// An order, or the part of an order sold by one shop.
class OrderRecord {
  final int id;
  final double total;
  final DateTime createdAt;
  final int itemCount;

  /// Who placed the order; filled in seller and admin views.
  final String? customerName;

  /// Which shop sold this part; filled in the admin per-shop view.
  final String? shopName;

  const OrderRecord({
    required this.id,
    required this.total,
    required this.createdAt,
    required this.itemCount,
    this.customerName,
    this.shopName,
  });

  factory OrderRecord.fromMap(Map<String, Object?> map) => OrderRecord(
    id: map['id'] as int,
    total: (map['total'] as num).toDouble(),
    createdAt: DateTime.parse(map['created_at'] as String),
    itemCount: (map['item_count'] as num?)?.toInt() ?? 0,
    customerName: map['customer_name'] as String?,
    shopName: map['shop_name'] as String?,
  );
}
