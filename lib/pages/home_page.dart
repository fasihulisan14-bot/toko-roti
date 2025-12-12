import 'package:bakery_system/pages/login_page.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/api_service.dart';
import '../providers/auth_provider.dart';
import '../widgets/dashboard_card.dart';
import 'products_page.dart';
import 'sales_page.dart';
import 'customers_page.dart';
import 'laporan_page.dart';

class HomePage extends StatefulWidget {
  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  Map<String, dynamic> _dashboardData = {
    'today_sales': 0,
    'today_revenue': 0.0,
    'low_stock': 0,
    'total_products': 0,
    'total_customers': 0
  };
  bool _isLoading = true;
  String? _error;
  bool _isRefreshing = false;
  bool _isDisposed = false; // ← TAMBAHKAN INI

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
  }

  // TAMBAHKAN dispose method
  @override
  void dispose() {
    _isDisposed = true;
    super.dispose();
  }

  // HELPER METHOD untuk safe setState
  void _safeSetState(VoidCallback fn) {
    if (!_isDisposed && mounted) {
      setState(fn);
    }
  }

  Future<void> _loadDashboardData() async {
    if (_isRefreshing) return;

    _safeSetState(() {
      _isRefreshing = true;
      if (!_isLoading) _error = null;
    });

    try {
      final apiService = Provider.of<ApiService>(context, listen: false);
      final response = await apiService.get('dashboard');

      // CHECK JIKA MASIH MOUNTED SEBELUM SETSTATE
      if (!_isDisposed && mounted) {
        _safeSetState(() {
          _dashboardData = response['data'] ??
              {
                'today_sales': 0,
                'today_revenue': 0.0,
                'low_stock': 0,
                'total_products': 0,
                'total_customers': 0
              };
          _isLoading = false;
          _error = null;
        });
      }
    } catch (e) {
      if (!_isDisposed && mounted) {
        _safeSetState(() {
          _isLoading = false;
          _error = e.toString();
        });
      }
      print('Error loading dashboard: $e');
    } finally {
      if (!_isDisposed && mounted) {
        _safeSetState(() {
          _isRefreshing = false;
        });
      }
    }
  }

  Widget _buildErrorWidget() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 64, color: Colors.red),
          SizedBox(height: 16),
          Text(
            'Koneksi Gagal',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 8),
          Text(
            'Pastikan backend berjalan di http://localhost:5000',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey),
          ),
          SizedBox(height: 16),
          ElevatedButton(
            onPressed: _isRefreshing ? null : _loadDashboardData,
            child: _isRefreshing
                ? SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : Text('Coba Lagi'),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingWidget() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 16),
          Text('Memuat data dashboard...'),
        ],
      ),
    );
  }

  Widget _buildDashboard() {
    return RefreshIndicator(
      onRefresh: _loadDashboardData,
      child: SingleChildScrollView(
        physics: AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Dashboard Bakery',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                IconButton(
                  icon: Icon(
                      _isRefreshing ? Icons.refresh : Icons.refresh_outlined),
                  onPressed: _isRefreshing ? null : _loadDashboardData,
                  tooltip: 'Refresh',
                ),
              ],
            ),
            SizedBox(height: 20),
            GridView.count(
              shrinkWrap: true,
              physics: NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              children: [
                DashboardCard(
                  title: 'Penjualan Hari Ini',
                  value: _dashboardData['today_sales'].toString(),
                  icon: Icons.shopping_cart,
                  color: Colors.green,
                ),
                DashboardCard(
                  title: 'Pendapatan Hari Ini',
                  value:
                      'Rp ${_dashboardData['today_revenue'].toStringAsFixed(0)}',
                  icon: Icons.attach_money,
                  color: Colors.blue,
                ),
                DashboardCard(
                  title: 'Stok Menipis',
                  value: _dashboardData['low_stock'].toString(),
                  icon: Icons.warning,
                  color: Colors.orange,
                ),
                DashboardCard(
                  title: 'Total Produk',
                  value: _dashboardData['total_products'].toString(),
                  icon: Icons.inventory,
                  color: Colors.purple,
                ),
              ],
            ),
            SizedBox(height: 30),
            Text(
              'Menu Utama',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 16),
            GridView.count(
              shrinkWrap: true,
              physics: NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              children: [
                _buildMenuCard(
                  'Produk',
                  Icons.cake,
                  Colors.brown,
                  () => _navigateToPage(ProductsPage()),
                ),
                _buildMenuCard(
                  'Penjualan',
                  Icons.point_of_sale,
                  Colors.green,
                  () => _navigateToPage(SalesPage()),
                ),
                _buildMenuCard(
                  'Pelanggan',
                  Icons.people,
                  Colors.blue,
                  () => _navigateToPage(CustomersPage()),
                ),
                _buildMenuCard(
                  'Laporan',
                  Icons.analytics,
                  Colors.purple,
                  () => _navigateToPage(LaporanPage()),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _navigateToPage(Widget page) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => page),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Bakery System'),
        backgroundColor: Colors.brown,
        elevation: 0,
        actions: [
          Consumer<AuthProvider>(
            builder: (context, authProvider, child) {
              return PopupMenuButton<String>(
                icon: Icon(Icons.account_circle),
                onSelected: (value) async {
                  // ← TAMBAH async
                  if (value == 'logout') {
                    // ========== TAMBAH KODE INI ==========
                    // Konfirmasi logout
                    bool confirm = await showDialog(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: Text('Logout'),
                        content: Text('Yakin ingin logout?'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context, false),
                            child: Text('BATAL'),
                          ),
                          TextButton(
                            onPressed: () => Navigator.pop(context, true),
                            child: Text('LOGOUT'),
                          ),
                        ],
                      ),
                    );

                    if (confirm == true) {
                      // 1. Logout dari provider
                      await authProvider.logout();

                      // 2. Navigasi ke LoginPage
                      Navigator.of(context).pushAndRemoveUntil(
                        MaterialPageRoute(builder: (context) => LoginPage()),
                        (route) => false,
                      );
                    }
                    // ========== SAMPAI SINI ==========
                  }
                },
                itemBuilder: (context) => [
                  PopupMenuItem<String>(
                    value: 'profile',
                    child: Text(
                        'Profile: ${authProvider.user?['name'] ?? 'User'}'),
                  ),
                  PopupMenuItem<String>(
                    value: 'role',
                    child: Text(
                        'Role: ${authProvider.user?['role']?.toUpperCase() ?? '-'}'),
                  ),
                  PopupMenuDivider(),
                  PopupMenuItem<String>(
                    value: 'logout',
                    child: Text('Logout'),
                  ),
                ],
              );
            },
          ),
          IconButton(
            icon: Icon(_isRefreshing ? Icons.refresh : Icons.refresh_outlined),
            onPressed: _isRefreshing ? null : _loadDashboardData,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _isLoading
          ? _buildLoadingWidget()
          : _error != null
              ? _buildErrorWidget()
              : _buildDashboard(),
    );
  }

  Widget _buildMenuCard(
      String title, IconData icon, Color color, VoidCallback onTap) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 32, color: color),
              ),
              SizedBox(height: 12),
              Text(
                title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[800],
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
