import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/api_service.dart';
import 'sales_report_page.dart';
import 'stock_report_page.dart';
import 'customer_report_page.dart'; // IMPORT BARU

class LaporanPage extends StatelessWidget {
  Future<Map<String, dynamic>> _loadQuickStats(BuildContext context) async {
    try {
      final apiService = Provider.of<ApiService>(context, listen: false);
      final response = await apiService.get('dashboard');
      return response['data'] ?? {};
    } catch (e) {
      print('Error loading quick stats: $e');
      return {};
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Laporan'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Menu Laporan',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.grey[800],
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Pilih jenis laporan yang ingin dilihat',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
              ),
            ),
            SizedBox(height: 24),

            // Grid Menu Laporan - HANYA 3 MENU
            Expanded(
              child: GridView(
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  childAspectRatio: 1.2,
                ),
                children: [
                  _buildReportCard(
                    context,
                    'Laporan Penjualan',
                    Icons.receipt_long,
                    Colors.green,
                    'Lihat detail penjualan dan statistik',
                    () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => SalesReportPage(),
                        ),
                      );
                    },
                  ),
                  _buildReportCard(
                    context,
                    'Laporan Stok',
                    Icons.warehouse,
                    Colors.purple,
                    'Monitoring stok barang',
                    () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => StockReportPage(),
                        ),
                      );
                    },
                  ),
                  _buildReportCard(
                    context,
                    'Laporan Pelanggan',
                    Icons.people,
                    Colors.orange,
                    'Data dan riwayat pelanggan',
                    () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => CustomerReportPage(), // DIUBAH
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),

            // Quick Stats
            _buildQuickStats(context),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickStats(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: _loadQuickStats(context),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildStatItem(
                      'Loading...', 'Penjualan Hari Ini', Colors.grey),
                  _buildStatItem('Loading...', 'Total Produk', Colors.grey),
                  _buildStatItem('Loading...', 'Pelanggan', Colors.grey),
                ],
              ),
            ),
          );
        }

        if (snapshot.hasError) {
          return Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Center(
                child: Text(
                  'Gagal memuat statistik',
                  style: TextStyle(color: Colors.red),
                ),
              ),
            ),
          );
        }

        final stats = snapshot.data ?? {};
        return Card(
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatItem(
                  _formatCurrency(stats['today_revenue'] ?? 0), // today_revenue
                  'Pendapatan Hari Ini',
                  Colors.green,
                ),
                _buildStatItem(
                  '${stats['total_products'] ?? 0}',
                  'Total Produk',
                  Colors.blue,
                ),
                _buildStatItem(
                  '${stats['total_customers'] ?? 0}',
                  'Pelanggan',
                  Colors.orange,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildReportCard(
    BuildContext context,
    String title,
    IconData icon,
    Color color,
    String description,
    VoidCallback onTap,
  ) {
    return Card(
      elevation: 4,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [color.withOpacity(0.1), color.withOpacity(0.05)],
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 30),
              ),
              SizedBox(height: 12),
              Text(
                title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 8),
              Text(
                description,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatItem(String value, String label, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  String _formatCurrency(dynamic value) {
    if (value == null) return 'Rp 0';
    try {
      final numValue =
          value is String ? double.tryParse(value) ?? 0.0 : value.toDouble();
      return 'Rp ${numValue.toStringAsFixed(0)}';
    } catch (e) {
      return 'Rp 0';
    }
  }
}
