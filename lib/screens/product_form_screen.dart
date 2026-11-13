import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../providers/product_provider.dart';
import '../theme/app_theme.dart';
import '../utils/validators.dart';
import '../widgets/decor.dart';
import '../widgets/product_image.dart';

/// Add a new product, or edit the one with [productId].
class ProductFormScreen extends StatefulWidget {
  const ProductFormScreen({super.key, this.productId});

  final int? productId;

  @override
  State<ProductFormScreen> createState() => _ProductFormScreenState();
}

class _ProductFormScreenState extends State<ProductFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _description = TextEditingController();
  final _price = TextEditingController();
  final _imageUrl = TextEditingController();
  Product? _editing;
  bool _busy = false;

  bool get _isEdit => widget.productId != null;

  @override
  void initState() {
    super.initState();
    if (_isEdit) {
      _editing = context.read<ProductProvider>().findById(widget.productId!);
      final p = _editing;
      if (p != null) {
        _name.text = p.name;
        _description.text = p.description;
        _price.text = p.price.toStringAsFixed(0);
        _imageUrl.text = p.image ?? '';
      }
    }
    _imageUrl.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    for (final c in [_name, _description, _price, _imageUrl]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _pickImage() async {
    final file = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 1200,
    );
    if (file != null) _imageUrl.text = file.path;
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _busy = true);
    final image = _imageUrl.text.trim();
    final product = Product(
      id: _editing?.id,
      name: _name.text.trim(),
      description: _description.text.trim(),
      price: double.parse(_price.text.trim()),
      image: image.isEmpty ? null : image,
    );
    final provider = context.read<ProductProvider>();
    final messenger = ScaffoldMessenger.of(context);
    if (_isEdit) {
      await provider.update(product);
    } else {
      await provider.add(product);
    }
    messenger.showSnackBar(
      SnackBar(content: Text(_isEdit ? 'Product updated' : 'Product added')),
    );
    if (mounted) context.pop();
  }

  @override
  Widget build(BuildContext context) {
    if (_isEdit && _editing == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: Text('Product not found')),
      );
    }

    final text = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: Text(_isEdit ? 'Edit product' : 'Add product')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Stack(
                  children: [
                    ProductImage(
                      source: _imageUrl.text,
                      height: 200,
                      radius: 28,
                    ),
                    Positioned(
                      right: 12,
                      bottom: 12,
                      child: FilledButton.tonalIcon(
                        style: FilledButton.styleFrom(
                          minimumSize: const Size(0, 42),
                          backgroundColor: Colors.white,
                          foregroundColor: AppColors.ink,
                        ),
                        onPressed: _pickImage,
                        icon: const Icon(
                          Icons.photo_library_outlined,
                          size: 18,
                        ),
                        label: const Text('Gallery'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 22),
                Text(
                  'Details',
                  style: text.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  autovalidateMode: AutovalidateMode.onUserInteraction,
                  controller: _name,
                  decoration: const InputDecoration(
                    labelText: 'Product name',
                    prefixIcon: Icon(Icons.sell_outlined),
                  ),
                  validator: (v) => validateRequired(v, 'Product name'),
                ),
                const SizedBox(height: 14),
                TextFormField(
                  autovalidateMode: AutovalidateMode.onUserInteraction,
                  controller: _description,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Description',
                    alignLabelWithHint: true,
                  ),
                  validator: (v) => validateRequired(v, 'Description'),
                ),
                const SizedBox(height: 14),
                TextFormField(
                  autovalidateMode: AutovalidateMode.onUserInteraction,
                  controller: _price,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Price (₫)',
                    prefixIcon: Icon(Icons.payments_outlined),
                  ),
                  validator: validatePrice,
                ),
                const SizedBox(height: 14),
                TextFormField(
                  autovalidateMode: AutovalidateMode.onUserInteraction,
                  controller: _imageUrl,
                  decoration: InputDecoration(
                    labelText: 'Image URL or local file',
                    prefixIcon: const Icon(Icons.link_rounded),
                    suffixIcon: IconButton(
                      tooltip: 'Pick from gallery',
                      icon: const Icon(Icons.photo_library_outlined),
                      onPressed: _pickImage,
                    ),
                  ),
                ),
                const SizedBox(height: 28),
                GradientButton(
                  label: _isEdit ? 'Save changes' : 'Add product',
                  icon: Icons.check_rounded,
                  busy: _busy,
                  onPressed: _save,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
