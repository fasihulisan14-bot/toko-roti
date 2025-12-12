import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/api_service.dart';
import '../models/product.dart';
import '../models/customer.dart';

// Helper functions untuk handle null values
String formatCurrency(dynamic value) {
  if (value == null) return 'Rp 0';
  try {
    final numValue =
        value is String ? double.tryParse(value) ?? 0.0 : value.toDouble();
    return 'Rp ${numValue.toStringAsFixed(0)}';
  } catch (e) {
    return 'Rp 0';
  }
}

double safeDouble(dynamic value) {
  if (value == null) return 0.0;
  return value is String ? double.tryParse(value) ?? 0.0 : value.toDouble();
}

int safeInt(dynamic value) {
  if (value == null) return 0;
  return value is String ? int.tryParse(value) ?? 0 : value.toInt();
}

class SalesPage extends StatefulWidget {
  @override
  _SalesPageState createState() => _SalesPageState();
}

class _SalesPageState extends State<SalesPage> {
  List<dynamic> _sales = [];
  List<Product> _products = [];
  List<Customer> _customers = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    try {
      final apiService = Provider.of<ApiService>(context, listen: false);

      final [salesData, productsData, customersData] = await Future.wait([
        apiService.get('sales'),
        apiService.get('products'),
        apiService.get('customers'),
      ]);

      setState(() {
        _sales = salesData['data'] ?? [];
        _products = (productsData['data'] as List)
            .map((json) => Product.fromJson(json))
            .toList();
        _customers = (customersData['data'] as List)
            .map((json) => Customer.fromJson(json))
            .toList();
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      _showErrorDialog('Gagal memuat data: $e');
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

  void _showCreateSaleDialog() {
    showDialog(
      context: context,
      builder: (ctx) => CreateSaleDialog(
        products: _products,
        customers: _customers,
        onSaleCreated: _loadInitialData,
      ),
    );
  }

  void _showSaleDetails(dynamic sale) {
    showDialog(
      context: context,
      builder: (ctx) => SaleDetailsDialog(sale: sale),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Manajemen Penjualan'),
        actions: [
          IconButton(
            icon: Icon(Icons.add),
            onPressed: _showCreateSaleDialog,
            tooltip: 'Tambah Penjualan Baru',
          ),
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: _loadInitialData,
            tooltip: 'Refresh Data',
          ),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : _sales.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.receipt_long, size: 64, color: Colors.grey),
                      SizedBox(height: 16),
                      Text(
                        'Belum Ada Penjualan',
                        style: TextStyle(fontSize: 18, color: Colors.grey),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Tekan tombol + untuk membuat penjualan baru',
                        style: TextStyle(color: Colors.grey),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  itemCount: _sales.length,
                  itemBuilder: (ctx, index) {
                    final sale = _sales[index];
                    return _buildSaleCard(sale);
                  },
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showCreateSaleDialog,
        child: Icon(Icons.add),
        backgroundColor: Colors.green,
      ),
    );
  }

  Widget _buildSaleCard(dynamic sale) {
    // FIX: Handle date parsing error
    DateTime saleDate;
    try {
      saleDate =
          DateTime.parse(sale['sale_date'].toString().replaceAll(' GMT', ''));
    } catch (e) {
      saleDate = DateTime.now(); // Fallback ke tanggal sekarang
    }

    final formattedDate = '${saleDate.day}/${saleDate.month}/${saleDate.year}';
    final formattedTime =
        '${saleDate.hour}:${saleDate.minute.toString().padLeft(2, '0')}';

    // Fix: Handle null value untuk total_amount
    final totalAmount = sale['total_amount']?.toDouble() ?? 0.0;

    // Simple color based on payment method
    Color getPaymentColor(String? method) {
      switch (method) {
        case 'cash':
          return Colors.blue;
        case 'transfer':
          return Colors.green;
        case 'card':
          return Colors.orange;
        default:
          return Colors.grey;
      }
    }

    return Card(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 3,
      child: ListTile(
        leading: Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            color: Colors.green.withOpacity(0.2),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(Icons.receipt, color: Colors.green),
        ),
        title: Text(
          'Penjualan #${sale['id']}',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${sale['customer_name'] ?? 'Pelanggan Umum'}'),
            Text('$formattedDate $formattedTime'),
            Text(
              'Rp ${totalAmount.toStringAsFixed(0)}',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.green,
              ),
            ),
          ],
        ),
        trailing: Chip(
          label: Text(
            sale['payment_method']?.toString().toUpperCase() ?? 'CASH',
            style: TextStyle(color: Colors.white, fontSize: 12),
          ),
          backgroundColor: getPaymentColor(sale['payment_method']),
        ),
        onTap: () => _showSaleDetails(sale),
      ),
    );
  }
}

class CreateSaleDialog extends StatefulWidget {
  final List<Product> products;
  final List<Customer> customers;
  final VoidCallback onSaleCreated;

  const CreateSaleDialog({
    required this.products,
    required this.customers,
    required this.onSaleCreated,
  });

  @override
  _CreateSaleDialogState createState() => _CreateSaleDialogState();
}

class _CreateSaleDialogState extends State<CreateSaleDialog> {
  final List<SaleItem> _saleItems = [];
  int? _selectedCustomerId;
  String _paymentMethod = 'cash';
  double _totalAmount = 0.0;

  void _addItem(Product product) {
    setState(() {
      // Cek apakah produk sudah ada di cart
      final existingIndex =
          _saleItems.indexWhere((item) => item.product.id == product.id);

      if (existingIndex >= 0) {
        // Jika sudah ada, tambah quantity
        final existingItem = _saleItems[existingIndex];
        if (existingItem.quantity < product.stock) {
          _saleItems[existingIndex] = SaleItem(
            product: product,
            quantity: existingItem.quantity + 1,
            unitPrice: product.price,
          );
        } else {
          _showSnackBar('Stok tidak mencukupi');
        }
      } else {
        // Jika belum ada, tambah item baru
        if (product.stock > 0) {
          _saleItems.add(SaleItem(
            product: product,
            quantity: 1,
            unitPrice: product.price,
          ));
        } else {
          _showSnackBar('Stok habis');
        }
      }
      _calculateTotal();
    });
  }

  void _removeItem(int index) {
    setState(() {
      _saleItems.removeAt(index);
      _calculateTotal();
    });
  }

  void _updateQuantity(int index, int newQuantity) {
    if (newQuantity <= 0) {
      _removeItem(index);
      return;
    }

    if (newQuantity > _saleItems[index].product.stock) {
      _showSnackBar('Stok tidak mencukupi');
      return;
    }

    setState(() {
      _saleItems[index] = SaleItem(
        product: _saleItems[index].product,
        quantity: newQuantity,
        unitPrice: _saleItems[index].unitPrice,
      );
      _calculateTotal();
    });
  }

  void _calculateTotal() {
    _totalAmount = _saleItems.fold(0.0, (sum, item) => sum + item.subtotal);
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> _createSale() async {
    if (_saleItems.isEmpty) {
      _showSnackBar('Tambahkan minimal satu produk');
      return;
    }

    try {
      final apiService = Provider.of<ApiService>(context, listen: false);

      final saleData = {
        'customer_id': _selectedCustomerId,
        'total_amount': _totalAmount,
        'payment_method': _paymentMethod,
        'items': _saleItems
            .map((item) => {
                  'product_id': item.product.id,
                  'quantity': item.quantity,
                  'unit_price': item.unitPrice,
                  'subtotal': item.subtotal,
                })
            .toList(),
      };

      await apiService.post('sales', saleData);

      Navigator.of(context).pop();
      widget.onSaleCreated();

      _showSnackBar('Penjualan berhasil dibuat!');
    } catch (e) {
      _showSnackBar('Gagal membuat penjualan: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;

    return Dialog(
      insetPadding: EdgeInsets.all(16),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: screenHeight * 0.8, // Maksimal 80% dari tinggi layar
        ),
        child: SingleChildScrollView(
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Buat Penjualan Baru',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 16),

                // Pilih Pelanggan
                DropdownButtonFormField<int>(
                  value: _selectedCustomerId,
                  decoration: InputDecoration(
                    labelText: 'Pelanggan',
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    DropdownMenuItem(
                      value: null,
                      child: Text('Pelanggan Umum'),
                    ),
                    ...widget.customers.map((customer) {
                      return DropdownMenuItem(
                        value: customer.id,
                        child: Text(customer.name),
                      );
                    }).toList(),
                  ],
                  onChanged: (value) {
                    setState(() {
                      _selectedCustomerId = value;
                    });
                  },
                ),
                SizedBox(height: 16),

                // Daftar Produk
                Text(
                  'Pilih Produk:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 8),
                Container(
                  height: 120, // Diperkecil dari 150
                  child: GridView.builder(
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      childAspectRatio: 3,
                      crossAxisSpacing: 8,
                      mainAxisSpacing: 8,
                    ),
                    itemCount: widget.products.length,
                    itemBuilder: (ctx, index) {
                      final product = widget.products[index];
                      return _buildProductItem(product);
                    },
                  ),
                ),
                SizedBox(height: 16),

                // Items yang dipilih
                Text(
                  'Items dalam Keranjang:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 8),
                _saleItems.isEmpty
                    ? Padding(
                        padding: EdgeInsets.all(16),
                        child: Text(
                          'Belum ada item yang dipilih',
                          style: TextStyle(color: Colors.grey),
                        ),
                      )
                    : Container(
                        height: 120, // Diperkecil dari 150
                        child: ListView.builder(
                          itemCount: _saleItems.length,
                          itemBuilder: (ctx, index) {
                            return _buildSaleItem(_saleItems[index], index);
                          },
                        ),
                      ),

                SizedBox(height: 16),

                // Total dan Payment Method
                Card(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Total:',
                                style: TextStyle(fontWeight: FontWeight.bold)),
                            Text(
                              formatCurrency(_totalAmount),
                              style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.green),
                            ),
                          ],
                        ),
                        SizedBox(height: 12),
                        DropdownButtonFormField<String>(
                          value: _paymentMethod,
                          decoration: InputDecoration(
                            labelText: 'Metode Pembayaran',
                            border: OutlineInputBorder(),
                          ),
                          items: [
                            DropdownMenuItem(
                                value: 'cash', child: Text('Cash')),
                            DropdownMenuItem(
                                value: 'transfer', child: Text('Transfer')),
                            DropdownMenuItem(
                                value: 'card', child: Text('Card')),
                          ],
                          onChanged: (value) {
                            setState(() {
                              _paymentMethod = value!;
                            });
                          },
                        ),
                      ],
                    ),
                  ),
                ),

                SizedBox(height: 16),

                // Actions
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        child: Text('BATAL'),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ),
                    SizedBox(width: 16),
                    Expanded(
                      child: ElevatedButton(
                        child: Text('SIMPAN'),
                        onPressed: _createSale,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProductItem(Product product) {
    return Card(
      elevation: 2,
      child: ListTile(
        dense: true,
        leading: Icon(Icons.cake, color: Colors.brown, size: 20), // Diperkecil
        title: Text(
          product.name,
          style: TextStyle(fontSize: 11), // Font lebih kecil
          overflow: TextOverflow.ellipsis,
          maxLines: 1,
        ),
        subtitle: Text(
          formatCurrency(product.price),
          style: TextStyle(fontSize: 9), // Font lebih kecil
        ),
        trailing: Text(
          'Stok: ${product.stock}',
          style: TextStyle(fontSize: 9), // Font lebih kecil
        ),
        onTap: () => _addItem(product),
      ),
    );
  }

  Widget _buildSaleItem(SaleItem item, int index) {
    return Card(
      margin: EdgeInsets.symmetric(vertical: 2), // Margin diperkecil
      child: ListTile(
        dense: true,
        contentPadding:
            EdgeInsets.symmetric(horizontal: 8), // Padding diperkecil
        leading: IconButton(
          icon: Icon(Icons.remove, size: 18), // Icon diperkecil
          onPressed: () => _updateQuantity(index, item.quantity - 1),
        ),
        title: Text(
          item.product.name,
          style: TextStyle(fontSize: 12), // Font lebih kecil
        ),
        subtitle: Text(
          '${formatCurrency(item.unitPrice)} x ${item.quantity}',
          style: TextStyle(fontSize: 10), // Font lebih kecil
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              formatCurrency(item.subtotal),
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
            ),
            IconButton(
              icon: Icon(Icons.delete,
                  size: 16, color: Colors.red), // Icon diperkecil
              onPressed: () => _removeItem(index),
            ),
          ],
        ),
      ),
    );
  }
}

class SaleDetailsDialog extends StatelessWidget {
  final dynamic sale;

  const SaleDetailsDialog({required this.sale});

  @override
  Widget build(BuildContext context) {
    DateTime saleDate;
    try {
      saleDate =
          DateTime.parse(sale['sale_date'].toString().replaceAll(' GMT', ''));
    } catch (e) {
      saleDate = DateTime.now();
    }

    final items = List<dynamic>.from(sale['items'] ?? []);

    return Dialog(
      child: SingleChildScrollView(
        child: Container(
          padding: EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Detail Penjualan #${sale['id']}',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 16),

              // Info Penjualan
              _buildInfoRow('Tanggal',
                  '${saleDate.day}/${saleDate.month}/${saleDate.year} ${saleDate.hour}:${saleDate.minute.toString().padLeft(2, '0')}'),
              _buildInfoRow(
                  'Pelanggan', sale['customer_name'] ?? 'Pelanggan Umum'),
              _buildInfoRow('Metode Bayar',
                  sale['payment_method']?.toString().toUpperCase() ?? 'CASH'),

              Divider(),
              SizedBox(height: 8),

              // Items
              Text('Items:', style: TextStyle(fontWeight: FontWeight.bold)),
              SizedBox(height: 8),
              ...items.map((item) => _buildItemRow(item)).toList(),

              Divider(),
              SizedBox(height: 8),

              // Total
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('TOTAL:',
                      style:
                          TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  Text(
                    formatCurrency(sale['total_amount']),
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: Colors.green),
                  ),
                ],
              ),

              SizedBox(height: 16),
              Center(
                child: ElevatedButton(
                  child: Text('TUTUP'),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Text('$label: ', style: TextStyle(fontWeight: FontWeight.bold)),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  Widget _buildItemRow(dynamic item) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Text(
              item['product_name'] ?? '',
              style: TextStyle(fontSize: 12), // Font lebih kecil
            ),
          ),
          Expanded(
            child: Text(
              '${safeInt(item['quantity'])}x',
              style: TextStyle(fontSize: 12), // Font lebih kecil
            ),
          ),
          Expanded(
            child: Text(
              formatCurrency(item['unit_price']),
              style: TextStyle(fontSize: 12), // Font lebih kecil
            ),
          ),
          Expanded(
            child: Text(
              formatCurrency(item['subtotal']),
              style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 12), // Font lebih kecil
            ),
          ),
        ],
      ),
    );
  }
}

class SaleItem {
  final Product product;
  final int quantity;
  final double unitPrice;

  SaleItem({
    required this.product,
    required this.quantity,
    required this.unitPrice,
  });

  double get subtotal => quantity * safeDouble(unitPrice);
}
