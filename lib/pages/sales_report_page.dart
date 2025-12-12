import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/api_service.dart';

// Helper functions untuk handle null values
String formatCurrency(dynamic value) {
  if (value == null) return 'Rp 0';
  try {
    final numValue =
        value is String ? double.tryParse(value) ?? 0.0 : value.toDouble();
    return 'Rp ${numValue.toStringAsFixed(0).replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (Match m) => '${m[1]}.',
        )}';
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

String safeString(dynamic value) {
  if (value == null) return '';
  return value.toString();
}

class SalesReportPage extends StatefulWidget {
  @override
  _SalesReportPageState createState() => _SalesReportPageState();
}

class _SalesReportPageState extends State<SalesReportPage> {
  List<dynamic> _sales = [];
  List<dynamic> _filteredSales = [];
  bool _isLoading = true;
  // ignore: unused_field
  bool _hasError = false;
  DateTime _selectedStartDate = DateTime.now().subtract(Duration(days: 30));
  DateTime _selectedEndDate = DateTime.now();
  String _selectedFilter = '30_hari';

  // Statistics
  double _totalRevenue = 0.0;
  int _totalTransactions = 0;
  double _averageTransaction = 0.0;

  @override
  void initState() {
    super.initState();
    _loadSalesData();
  }

  Future<void> _loadSalesData() async {
    try {
      setState(() {
        _isLoading = true;
        _hasError = false;
      });

      final apiService = Provider.of<ApiService>(context, listen: false);
      final response = await apiService.get('sales');

      if (response['success'] != false) {
        setState(() {
          _sales = response['data'] ?? [];
          _applyFilters();
          _isLoading = false;
        });
      } else {
        throw Exception('Failed to load sales data');
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _hasError = true;
      });
      _showErrorDialog('Gagal memuat data laporan: $e');
    }
  }

  void _applyFilters() {
    List<dynamic> filtered = List.from(_sales);

    // Filter berdasarkan tanggal
    filtered = filtered.where((sale) {
      try {
        final saleDateString = safeString(sale['sale_date'])
            .replaceAll(' GMT', '')
            .replaceAll(' UTC', '');
        final saleDate = DateTime.parse(saleDateString);
        return saleDate
                .isAfter(_selectedStartDate.subtract(Duration(seconds: 1))) &&
            saleDate.isBefore(_selectedEndDate.add(Duration(days: 1)));
      } catch (e) {
        print('Error parsing date: ${sale['sale_date']} - $e');
        return false;
      }
    }).toList();

    setState(() {
      _filteredSales = filtered;
      _calculateStatistics();
    });
  }

  void _calculateStatistics() {
    _totalRevenue = _filteredSales.fold(0.0, (sum, sale) {
      return sum + safeDouble(sale['total_amount']);
    });

    _totalTransactions = _filteredSales.length;

    _averageTransaction =
        _totalTransactions > 0 ? _totalRevenue / _totalTransactions : 0.0;
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Error', style: TextStyle(color: Colors.red)),
        content: Text(message),
        actions: [
          TextButton(
            child: const Text('OK'),
            onPressed: () => Navigator.of(ctx).pop(),
          ),
          TextButton(
            child: const Text('Coba Lagi'),
            onPressed: () {
              Navigator.of(ctx).pop();
              _loadSalesData();
            },
          ),
        ],
      ),
    );
  }

  Future<void> _selectDate(BuildContext context, bool isStartDate) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: isStartDate ? _selectedStartDate : _selectedEndDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(Duration(days: 365)),
    );

    if (picked != null) {
      setState(() {
        if (isStartDate) {
          _selectedStartDate = picked;
        } else {
          _selectedEndDate = picked;
        }
        _selectedFilter = 'custom';
        _applyFilters();
      });
    }
  }

  void _applyQuickFilter(String filter) {
    setState(() {
      _selectedFilter = filter;

      final now = DateTime.now();
      switch (filter) {
        case 'hari_ini':
          _selectedStartDate = DateTime(now.year, now.month, now.day);
          _selectedEndDate = now;
          break;
        case '7_hari':
          _selectedStartDate = now.subtract(Duration(days: 7));
          _selectedEndDate = now;
          break;
        case '30_hari':
          _selectedStartDate = now.subtract(Duration(days: 30));
          _selectedEndDate = now;
          break;
        case 'custom':
          break;
      }

      _applyFilters();
    });
  }

  void _showSaleDetails(dynamic sale) {
    showDialog(
      context: context,
      builder: (ctx) => SaleDetailsDialog(sale: sale),
    );
  }

  Widget _buildStatisticsCard() {
    return Card(
      elevation: 4,
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text(
              'STATISTIK PENJUALAN',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.grey[700],
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatItem(
                  'Total Pendapatan',
                  formatCurrency(_totalRevenue),
                  Colors.green,
                  Icons.attach_money,
                ),
                _buildStatItem(
                  'Total Transaksi',
                  _totalTransactions.toString(),
                  Colors.blue,
                  Icons.receipt,
                ),
                _buildStatItem(
                  'Rata-rata Transaksi',
                  formatCurrency(_averageTransaction),
                  Colors.orange,
                  Icons.trending_up,
                ),
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
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          title,
          style: const TextStyle(
            fontSize: 10,
            color: Colors.grey,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildFilterSection() {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Filter Periode',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),

            // Quick Filters
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildFilterChip('Hari Ini', 'hari_ini'),
                  const SizedBox(width: 8),
                  _buildFilterChip('7 Hari', '7_hari'),
                  const SizedBox(width: 8),
                  _buildFilterChip('30 Hari', '30_hari'),
                  const SizedBox(width: 8),
                  _buildFilterChip('Custom', 'custom'),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // Date Range
            if (_selectedFilter == 'custom') ...[
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Dari Tanggal',
                            style: TextStyle(fontSize: 12)),
                        const SizedBox(height: 4),
                        InkWell(
                          onTap: () => _selectDate(context, true),
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.calendar_today, size: 16),
                                const SizedBox(width: 8),
                                Text(
                                  '${_selectedStartDate.day}/${_selectedStartDate.month}/${_selectedStartDate.year}',
                                  style: const TextStyle(fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Sampai Tanggal',
                            style: TextStyle(fontSize: 12)),
                        const SizedBox(height: 4),
                        InkWell(
                          onTap: () => _selectDate(context, false),
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.calendar_today, size: 16),
                                const SizedBox(width: 8),
                                Text(
                                  '${_selectedEndDate.day}/${_selectedEndDate.month}/${_selectedEndDate.year}',
                                  style: const TextStyle(fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Periode: ${_selectedStartDate.day}/${_selectedStartDate.month}/${_selectedStartDate.year} - ${_selectedEndDate.day}/${_selectedEndDate.month}/${_selectedEndDate.year}',
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ] else ...[
              Text(
                'Periode: ${_getPeriodText()}',
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _getPeriodText() {
    switch (_selectedFilter) {
      case 'hari_ini':
        return 'Hari Ini';
      case '7_hari':
        return '7 Hari Terakhir';
      case '30_hari':
        return '30 Hari Terakhir';
      default:
        return 'Custom';
    }
  }

  Widget _buildFilterChip(String label, String value) {
    return FilterChip(
      label: Text(label),
      selected: _selectedFilter == value,
      onSelected: (selected) {
        if (selected) {
          _applyQuickFilter(value);
        }
      },
      backgroundColor: Colors.grey[200],
      selectedColor: Colors.blue.withOpacity(0.2),
      checkmarkColor: Colors.blue,
      labelStyle: TextStyle(
        color: _selectedFilter == value ? Colors.blue : Colors.grey[700],
        fontSize: 12,
      ),
    );
  }

  // ignore: unused_element
  Widget _buildSalesList() {
    if (_filteredSales.isEmpty) {
      return Container(
        height: 200,
        child: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.receipt_long, size: 64, color: Colors.grey),
              SizedBox(height: 16),
              Text('Tidak ada data penjualan'),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _filteredSales.length,
      itemBuilder: (BuildContext context, int index) {
        final sale = _filteredSales[index];
        return _buildSaleCard(sale);
      },
    );
  }

  Widget _buildSaleCard(dynamic sale) {
    DateTime saleDate;
    try {
      final saleDateString = safeString(sale['sale_date'])
          .replaceAll(' GMT', '')
          .replaceAll(' UTC', '');
      saleDate = DateTime.parse(saleDateString);
    } catch (e) {
      saleDate = DateTime.now();
    }

    final formattedDate = '${saleDate.day}/${saleDate.month}/${saleDate.year}';
    final totalAmount = safeDouble(sale['total_amount']);

    // Color based on payment method
    Color getPaymentColor(String? method) {
      switch (method?.toLowerCase()) {
        case 'cash':
          return Colors.green;
        case 'transfer':
          return Colors.blue;
        case 'card':
          return Colors.orange;
        case 'qris':
          return Colors.purple;
        default:
          return Colors.grey;
      }
    }

    String getPaymentMethodText(String? method) {
      switch (method?.toLowerCase()) {
        case 'cash':
          return 'CASH';
        case 'transfer':
          return 'TRANSFER';
        case 'card':
          return 'CARD';
        case 'qris':
          return 'QRIS';
        default:
          return method?.toUpperCase() ?? 'CASH';
      }
    }

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      elevation: 2,
      child: ListTile(
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: getPaymentColor(sale['payment_method']).withOpacity(0.2),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            Icons.receipt,
            color: getPaymentColor(sale['payment_method']),
            size: 20,
          ),
        ),
        title: Text(
          'Penjualan #${safeString(sale['id'])}',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(safeString(sale['customer_name']),
                style: const TextStyle(fontSize: 12)),
            Text(formattedDate, style: const TextStyle(fontSize: 11)),
          ],
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              formatCurrency(totalAmount),
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.green,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: getPaymentColor(sale['payment_method']),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                getPaymentMethodText(sale['payment_method']),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        onTap: () => _showSaleDetails(sale),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Laporan Penjualan'),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Statistics Card
                _buildStatisticsCard(),

                // Filter Section
                _buildFilterSection(),

                // Header
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Daftar Transaksi',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      Text(
                        '${_filteredSales.length} Transaksi',
                        style:
                            const TextStyle(color: Colors.grey, fontSize: 12),
                      ),
                    ],
                  ),
                ),

                // Sales List dengan Expanded - BISA SCROLL
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: _loadSalesData,
                    child: _filteredSales.isEmpty
                        ? const Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.receipt_long,
                                    size: 64, color: Colors.grey),
                                SizedBox(height: 16),
                                Text('Tidak ada data penjualan'),
                              ],
                            ),
                          )
                        : ListView.builder(
                            itemCount: _filteredSales.length,
                            itemBuilder: (BuildContext ctx, int index) {
                              return _buildSaleCard(_filteredSales[index]);
                            },
                          ),
                  ),
                ),
              ],
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
      final saleDateString = safeString(sale['sale_date'])
          .replaceAll(' GMT', '')
          .replaceAll(' UTC', '');
      saleDate = DateTime.parse(saleDateString);
    } catch (e) {
      saleDate = DateTime.now();
    }

    final items = List<dynamic>.from(sale['items'] ?? []);
    final formattedDate =
        '${saleDate.day}/${saleDate.month}/${saleDate.year} ${saleDate.hour}:${saleDate.minute.toString().padLeft(2, '0')}';

    return Dialog(
      insetPadding: const EdgeInsets.all(20),
      child: Container(
        constraints:
            BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.8),
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Detail Penjualan',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.of(context).pop(),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Info Penjualan
                _buildInfoRow('No. Transaksi', safeString(sale['id'])),
                _buildInfoRow('Tanggal', formattedDate),
                _buildInfoRow('Pelanggan', safeString(sale['customer_name'])),
                _buildInfoRow('Metode Bayar',
                    safeString(sale['payment_method']).toUpperCase()),

                const Divider(),
                const SizedBox(height: 8),

                // Items Header
                const Row(
                  children: [
                    Expanded(
                        flex: 3,
                        child: Text('Produk',
                            style: TextStyle(fontWeight: FontWeight.bold))),
                    Expanded(
                        child: Text('Qty',
                            style: TextStyle(fontWeight: FontWeight.bold))),
                    Expanded(
                        child: Text('Harga',
                            style: TextStyle(fontWeight: FontWeight.bold))),
                    Expanded(
                        child: Text('Subtotal',
                            style: TextStyle(fontWeight: FontWeight.bold))),
                  ],
                ),
                const Divider(),

                // Items
                ...items.map((item) => _buildItemRow(item)).toList(),

                const Divider(),
                const SizedBox(height: 8),

                // Total
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('TOTAL:',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 16)),
                    Text(
                      formatCurrency(sale['total_amount']),
                      style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: Colors.green),
                    ),
                  ],
                ),

                const SizedBox(height: 16),
                Center(
                  child: ElevatedButton(
                    child: const Text('TUTUP'),
                    onPressed: () => Navigator.of(context).pop(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  Widget _buildItemRow(dynamic item) {
    final quantity = safeInt(item['quantity']);
    final unitPrice = safeDouble(item['unit_price']);
    final subtotal = safeDouble(item['subtotal']);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(safeString(item['product_name']),
                    style: const TextStyle(fontSize: 12)),
                if (safeString(item['product_variant']).isNotEmpty)
                  Text(
                    'Varian: ${safeString(item['product_variant'])}',
                    style: const TextStyle(fontSize: 10, color: Colors.grey),
                  ),
              ],
            ),
          ),
          Expanded(
            child: Text('$quantity', style: const TextStyle(fontSize: 12)),
          ),
          Expanded(
            child: Text(formatCurrency(unitPrice),
                style: const TextStyle(fontSize: 12)),
          ),
          Expanded(
            child: Text(
              formatCurrency(subtotal),
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}
