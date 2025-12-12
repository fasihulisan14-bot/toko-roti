import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/api_service.dart';

// Helper functions
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

int safeInt(dynamic value) {
  if (value == null) return 0;
  return value is String ? int.tryParse(value) ?? 0 : value.toInt();
}

String safeString(dynamic value, {String defaultValue = ''}) {
  if (value == null) return defaultValue;
  return value.toString();
}

class StockReportPage extends StatefulWidget {
  @override
  _StockReportPageState createState() => _StockReportPageState();
}

class _StockReportPageState extends State<StockReportPage> {
  List<dynamic> _products = [];
  List<dynamic> _filteredProducts = [];
  bool _isLoading = true;
  bool _hasError = false;
  String _filterType = 'all';
  String _sortBy = 'name';
  bool _isDisposed = false;

  @override
  void initState() {
    super.initState();
    _loadStockData();
  }

  @override
  void dispose() {
    _isDisposed = true;
    super.dispose();
  }

  void _safeSetState(VoidCallback fn) {
    if (!_isDisposed && mounted) {
      setState(fn);
    }
  }

  Future<void> _loadStockData() async {
    try {
      _safeSetState(() {
        _isLoading = true;
        _hasError = false;
      });

      final apiService = Provider.of<ApiService>(context, listen: false);
      final response = await apiService.get('products');

      if (response['success'] != false) {
        _safeSetState(() {
          _products = response['data'] ?? [];
          _applyFilters();
          _isLoading = false;
        });
      } else {
        throw Exception('Failed to load stock data');
      }
    } catch (e) {
      _safeSetState(() {
        _isLoading = false;
        _hasError = true;
      });
      print('Error loading stock: $e');
    }
  }

  void _applyFilters() {
    List<dynamic> filtered = List.from(_products);

    switch (_filterType) {
      case 'low_stock':
        filtered = filtered
            .where((product) => safeInt(product['stock']) < 10)
            .toList();
        break;
      case 'out_of_stock':
        filtered = filtered
            .where((product) => safeInt(product['stock']) == 0)
            .toList();
        break;
      case 'all':
      default:
        break;
    }

    filtered.sort((a, b) {
      switch (_sortBy) {
        case 'stock':
          return safeInt(a['stock']).compareTo(safeInt(b['stock']));
        case 'category':
          return safeString(a['category']).compareTo(safeString(b['category']));
        case 'name':
        default:
          return safeString(a['name']).compareTo(safeString(b['name']));
      }
    });

    _safeSetState(() {
      _filteredProducts = filtered;
    });
  }

  // === FUNGSI UPDATE STOK ===
 void _showUpdateStockDialog(dynamic product) {
  final currentStock = safeInt(product['stock']);
  final productName = safeString(product['name']);
  final controller = TextEditingController(text: currentStock.toString());

  showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text('Update Stok $productName'),
      content: TextField(
        controller: controller,
        keyboardType: TextInputType.number,
        decoration: InputDecoration(labelText: 'Stok Baru'),
      ),
      actions: [
        TextButton(
          child: Text('BATAL'),
          onPressed: () => Navigator.of(ctx).pop(),
        ),
        TextButton(
          child: Text('UPDATE'),
          onPressed: () {
            final newStock = int.tryParse(controller.text) ?? currentStock;
            _updateStock(product['id'], newStock, productName);
            Navigator.of(ctx).pop();
          },
        ),
      ],
    ),
  );
}

Future<void> _updateStock(int productId, int newStock, String productName) async {
  try {
    final apiService = Provider.of<ApiService>(context, listen: false);
    final response = await apiService.updateProductStock(productId, newStock);

    if (response['success'] == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ Stok diupdate: $newStock'),
          backgroundColor: Colors.green,
        ),
      );
      _loadStockData(); // Refresh
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Gagal update'),
          backgroundColor: Colors.red,
        ),
      );
    }
  } catch (e) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('❌ Error: $e'),
        backgroundColor: Colors.red,
      ),
    );
  }
}

  Widget _buildStatisticsCard() {
    final totalProducts = _products.length;
    final lowStockCount = _products
        .where((p) => safeInt(p['stock']) < 10 && safeInt(p['stock']) > 0)
        .length;
    final outOfStockCount =
        _products.where((p) => safeInt(p['stock']) == 0).length;
    final inStockCount =
        _products.where((p) => safeInt(p['stock']) >= 10).length;

    return Card(
      elevation: 4,
      margin: EdgeInsets.all(16),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          children: [
            Text(
              'STATISTIK STOK',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.grey[700],
              ),
            ),
            SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatItem('Total Produk', totalProducts.toString(),
                    Colors.blue, Icons.inventory),
                _buildStatItem('Stok Aman', inStockCount.toString(),
                    Colors.green, Icons.check_circle),
                _buildStatItem('Stok Menipis', lowStockCount.toString(),
                    Colors.orange, Icons.warning),
                _buildStatItem('Habis', outOfStockCount.toString(), Colors.red,
                    Icons.error),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(
      String title, String value, Color color, IconData icon) {
    return Column(
      children: [
        Container(
          padding: EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        SizedBox(height: 4),
        Text(
          title,
          style: TextStyle(
            fontSize: 10,
            color: Colors.grey[600],
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildFilterSection() {
    return Card(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Filter & Urutkan',
                style: TextStyle(fontWeight: FontWeight.bold)),
            SizedBox(height: 12),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildFilterChip('Semua Stok', 'all'),
                  SizedBox(width: 8),
                  _buildFilterChip('Stok Menipis (<10)', 'low_stock'),
                  SizedBox(width: 8),
                  _buildFilterChip('Stok Habis', 'out_of_stock'),
                ],
              ),
            ),
            SizedBox(height: 12),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildSortChip('Nama Produk', 'name'),
                  SizedBox(width: 8),
                  _buildSortChip('Jumlah Stok', 'stock'),
                  SizedBox(width: 8),
                  _buildSortChip('Kategori', 'category'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip(String label, String value) {
    return FilterChip(
      label: Text(label),
      selected: _filterType == value,
      onSelected: (selected) {
        if (selected) {
          _safeSetState(() {
            _filterType = value;
            _applyFilters();
          });
        }
      },
      backgroundColor: Colors.grey[200],
      selectedColor: Colors.blue.withOpacity(0.2),
      checkmarkColor: Colors.blue,
      labelStyle: TextStyle(
        color: _filterType == value ? Colors.blue : Colors.grey[700],
        fontSize: 12,
      ),
    );
  }

  Widget _buildSortChip(String label, String value) {
    return ChoiceChip(
      label: Text(label),
      selected: _sortBy == value,
      onSelected: (selected) {
        if (selected) {
          _safeSetState(() {
            _sortBy = value;
            _applyFilters();
          });
        }
      },
      backgroundColor: Colors.grey[200],
      selectedColor: Colors.green.withOpacity(0.2),
      labelStyle: TextStyle(
        color: _sortBy == value ? Colors.green : Colors.grey[700],
        fontSize: 12,
      ),
    );
  }

  Widget _buildProductCard(dynamic product) {
    final stock = safeInt(product['stock']);
    final price = product['price']?.toDouble() ?? 0.0;

    Color getStockColor() {
      if (stock == 0) return Colors.red;
      if (stock < 10) return Colors.orange;
      return Colors.green;
    }

    String getStockStatus() {
      if (stock == 0) return 'HABIS';
      if (stock < 10) return 'MENIPIS';
      return 'AMAN';
    }

    IconData getStockIcon() {
      if (stock == 0) return Icons.error_outline;
      if (stock < 10) return Icons.warning;
      return Icons.check_circle;
    }

    return Card(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      elevation: 2,
      child: ListTile(
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: getStockColor().withOpacity(0.2),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(getStockIcon(), color: getStockColor(), size: 20),
        ),
        title: Text(
          safeString(product['name']),
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
                'Kategori: ${safeString(product['category'], defaultValue: 'Umum')}',
                style: TextStyle(fontSize: 12)),
            Text('Harga: ${formatCurrency(price)}',
                style: TextStyle(fontSize: 11)),
          ],
        ),
        trailing: Container(
          width: 120,
          child: Row(
            children: [
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('$stock pcs',
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: getStockColor(),
                          fontSize: 14)),
                  SizedBox(height: 4),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                        color: getStockColor(),
                        borderRadius: BorderRadius.circular(8)),
                    child: Text(getStockStatus(),
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
              IconButton(
                icon: Icon(Icons.edit, size: 18),
                onPressed: () => _showUpdateStockDialog(product),
                tooltip: 'Update Stok',
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStockList() {
    if (_hasError) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.red),
            SizedBox(height: 16),
            Text('Gagal Memuat Data',
                style: TextStyle(fontSize: 16, color: Colors.red)),
            SizedBox(height: 8),
            ElevatedButton(onPressed: _loadStockData, child: Text('Coba Lagi')),
          ],
        ),
      );
    }

    if (_filteredProducts.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inventory_2, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text('Tidak Ada Data Stok',
                style: TextStyle(fontSize: 16, color: Colors.grey)),
            SizedBox(height: 8),
            Text(
                _filterType == 'all'
                    ? 'Belum ada produk yang terdaftar'
                    : 'Tidak ada produk dengan filter yang dipilih',
                style: TextStyle(color: Colors.grey),
                textAlign: TextAlign.center),
          ],
        ),
      );
    }

    return ListView.builder(
      physics: AlwaysScrollableScrollPhysics(),
      itemCount: _filteredProducts.length,
      itemBuilder: (ctx, index) {
        final product = _filteredProducts[index];
        return _buildProductCard(product);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Laporan Stok'),
        backgroundColor: Colors.purple,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
              icon: Icon(Icons.refresh),
              onPressed: _loadStockData,
              tooltip: 'Refresh Data'),
        ],
      ),
      body: _isLoading
          ? Center(
              child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Memuat data stok...')
                ]))
          : Column(
              children: [
                _buildStatisticsCard(),
                _buildFilterSection(),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Daftar Stok Produk',
                          style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 16)),
                      Text('${_filteredProducts.length} Produk',
                          style: TextStyle(color: Colors.grey, fontSize: 12)),
                    ],
                  ),
                ),
                Expanded(
                    child: RefreshIndicator(
                        onRefresh: _loadStockData, child: _buildStockList())),
              ],
            ),
    );
  }
}
