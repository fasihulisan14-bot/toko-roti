import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/api_service.dart';
import '../models/product.dart';

class ProductsPage extends StatefulWidget {
  @override
  _ProductsPageState createState() => _ProductsPageState();
}

class _ProductsPageState extends State<ProductsPage> {
  List<Product> _products = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadProducts();
  }

  Future<void> _loadProducts() async {
    try {
      final apiService = Provider.of<ApiService>(context, listen: false);
      final data = await apiService.get('products');
      setState(() {
        _products = (data['data'] as List)
            .map((json) => Product.fromJson(json))
            .toList();
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      _showErrorDialog('Gagal memuat produk: $e');
    }
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Error'),
        content: Text(message),
        actions: [
          TextButton(
            child: Text('OK'),
            onPressed: () => Navigator.of(ctx).pop(),
          ),
        ],
      ),
    );
  }

  void _showAddProductDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AddProductDialog(onProductAdded: _loadProducts),
    );
  }

  void _showEditProductDialog(Product product) {
    showDialog(
      context: context,
      builder: (ctx) => AddProductDialog(
        onProductAdded: _loadProducts,
        product: product,
        isEdit: true,
      ),
    );
  }

  // TAMBAHKAN METHOD UNTUK QUICK UPDATE STOCK
  void _quickUpdateStock(Product product, int stockChange) async {
    try {
      final apiService = Provider.of<ApiService>(context, listen: false);
      final response =
          await apiService.updateProductStock(product.id, stockChange);

      if (response['success'] == true) {
        _loadProducts(); // Refresh data
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Stock ${product.name} berhasil diupdate'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal update stock: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showProductDetails(Product product) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(product.name),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Deskripsi: ${product.description}'),
              SizedBox(height: 8),
              Text('Harga: Rp ${product.price.toStringAsFixed(0)}'),
              SizedBox(height: 8),
              Text('Stok: ${product.stock}'),
              SizedBox(height: 8),
              Text('Kategori: ${product.category}'),
              SizedBox(height: 16),
              // TAMBAHKAN TOMBOL QUICK STOCK UPDATE
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  ElevatedButton.icon(
                    icon: Icon(Icons.add),
                    label: Text('+10'),
                    onPressed: () {
                      Navigator.of(ctx).pop();
                      _quickUpdateStock(product, 10);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                    ),
                  ),
                  ElevatedButton.icon(
                    icon: Icon(Icons.remove),
                    label: Text('-10'),
                    onPressed: () {
                      Navigator.of(ctx).pop();
                      _quickUpdateStock(product, -10);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            child: Text('TUTUP'),
            onPressed: () => Navigator.of(ctx).pop(),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Manajemen Produk'),
        actions: [
          IconButton(
            icon: Icon(Icons.add),
            onPressed: _showAddProductDialog,
          ),
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: _loadProducts,
          ),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : _products.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.cake, size: 64, color: Colors.grey),
                      SizedBox(height: 16),
                      Text(
                        'Belum Ada Produk',
                        style: TextStyle(fontSize: 18, color: Colors.grey),
                      ),
                      SizedBox(height: 8),
                      ElevatedButton(
                        onPressed: _showAddProductDialog,
                        child: Text('Tambah Produk Pertama'),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadProducts,
                  child: ListView.builder(
                    itemCount: _products.length,
                    itemBuilder: (ctx, index) {
                      final product = _products[index];
                      return _buildProductCard(product);
                    },
                  ),
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddProductDialog,
        child: Icon(Icons.add),
        backgroundColor: Colors.brown,
      ),
    );
  }

  Widget _buildProductCard(Product product) {
    // Color based on stock level
    Color getStockColor() {
      if (product.stock == 0) return Colors.red;
      if (product.stock < 10) return Colors.orange;
      return Colors.green;
    }

    return Card(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 2,
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: getStockColor().withOpacity(0.2),
          child: Icon(Icons.cake, color: getStockColor()),
        ),
        title: Text(
          product.name,
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Rp ${product.price.toStringAsFixed(0)}'),
            Text('Stok: ${product.stock} • ${product.category}'),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // TAMBAHKAN TOMBOL QUICK STOCK
            IconButton(
              icon: Icon(Icons.add, size: 18, color: Colors.green),
              onPressed: () => _quickUpdateStock(product, 5),
              tooltip: 'Tambah 5 stok',
            ),
            IconButton(
              icon: Icon(Icons.remove, size: 18, color: Colors.orange),
              onPressed: () => _quickUpdateStock(product, -5),
              tooltip: 'Kurangi 5 stok',
            ),
            IconButton(
              icon: Icon(Icons.edit, color: Colors.blue),
              onPressed: () => _showEditProductDialog(product),
            ),
            IconButton(
              icon: Icon(Icons.info, color: Colors.green),
              onPressed: () => _showProductDetails(product),
            ),
          ],
        ),
        onTap: () => _showProductDetails(product),
      ),
    );
  }
}

class AddProductDialog extends StatefulWidget {
  final VoidCallback onProductAdded;
  final Product? product;
  final bool isEdit;

  const AddProductDialog({
    required this.onProductAdded,
    this.product,
    this.isEdit = false,
  });

  @override
  _AddProductDialogState createState() => _AddProductDialogState();
}

class _AddProductDialogState extends State<AddProductDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _priceController = TextEditingController();
  final _stockController = TextEditingController();
  final _categoryController = TextEditingController();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.isEdit && widget.product != null) {
      _nameController.text = widget.product!.name;
      _descriptionController.text = widget.product!.description;
      _priceController.text = widget.product!.price.toStringAsFixed(0);
      _stockController.text = widget.product!.stock.toString();
      _categoryController.text = widget.product!.category;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    _stockController.dispose();
    _categoryController.dispose();
    super.dispose();
  }

  Future<void> _saveProduct() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
      });

      try {
        final apiService = Provider.of<ApiService>(context, listen: false);

        final productData = {
          'name': _nameController.text.trim(),
          'description': _descriptionController.text.trim(),
          'price': double.parse(_priceController.text),
          'stock': int.parse(_stockController.text),
          'category': _categoryController.text.trim(),
        };

        final response = await apiService.post('products', productData);

        Navigator.of(context).pop();
        widget.onProductAdded();

        // TAMPILKAN PESAN BERDASARKAN ACTION (created/updated)
        final action = response['data']['action'] ?? 'disimpan';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Produk berhasil di$action!'),
            backgroundColor: Colors.green,
          ),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal menyimpan produk: $e'),
            backgroundColor: Colors.red,
          ),
        );
      } finally {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.isEdit ? 'Edit Produk' : 'Tambah Produk Baru'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: 'Nama Produk *',
                  border: OutlineInputBorder(),
                  hintText: 'Contoh: Roti Sobek Coklat',
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Nama produk harus diisi';
                  }
                  return null;
                },
              ),
              SizedBox(height: 16),
              TextFormField(
                controller: _descriptionController,
                decoration: InputDecoration(
                  labelText: 'Deskripsi',
                  border: OutlineInputBorder(),
                  hintText: 'Deskripsi produk...',
                ),
                maxLines: 2,
              ),
              SizedBox(height: 16),
              TextFormField(
                controller: _priceController,
                decoration: InputDecoration(
                  labelText: 'Harga *',
                  border: OutlineInputBorder(),
                  prefixText: 'Rp ',
                  hintText: '15000',
                ),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Harga harus diisi';
                  }
                  if (double.tryParse(value) == null) {
                    return 'Harga harus angka';
                  }
                  return null;
                },
              ),
              SizedBox(height: 16),
              TextFormField(
                controller: _stockController,
                decoration: InputDecoration(
                  labelText: 'Stok *',
                  border: OutlineInputBorder(),
                  hintText: '50',
                ),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Stok harus diisi';
                  }
                  if (int.tryParse(value) == null) {
                    return 'Stok harus angka';
                  }
                  return null;
                },
              ),
              SizedBox(height: 16),
              TextFormField(
                controller: _categoryController,
                decoration: InputDecoration(
                  labelText: 'Kategori',
                  border: OutlineInputBorder(),
                  hintText: 'Contoh: Roti Manis, Pastry, Donat',
                ),
              ),
              SizedBox(height: 8),
              if (!widget.isEdit)
                Text(
                  '💡 Tips: Jika nama produk sudah ada, stock akan ditambahkan ke produk yang sudah ada',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.blue,
                    fontStyle: FontStyle.italic,
                  ),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          child: Text('BATAL'),
          onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
        ),
        ElevatedButton(
          child: _isLoading
              ? SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(widget.isEdit ? 'UPDATE' : 'SIMPAN'),
          onPressed: _isLoading ? null : _saveProduct,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.brown,
            foregroundColor: Colors.white,
          ),
        ),
      ],
    );
  }
}
