import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/api_service.dart';

class CustomerReportPage extends StatefulWidget {
  @override
  _CustomerReportPageState createState() => _CustomerReportPageState();
}

class _CustomerReportPageState extends State<CustomerReportPage> {
  late Future<Map<String, dynamic>> _customerData;

  @override
  void initState() {
    super.initState();
    _customerData = _loadCustomerData();
  }

  Future<Map<String, dynamic>> _loadCustomerData() async {
    try {
      final apiService = Provider.of<ApiService>(context, listen: false);
      final response = await apiService.get('customers/report');
      return response['data'] ?? {};
    } catch (e) {
      print('Error loading customer data: $e');
      return {};
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Laporan Pelanggan'),
        backgroundColor: Colors.orange,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: () {
              setState(() {
                _customerData = _loadCustomerData();
              });
            },
          ),
        ],
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _customerData,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline, color: Colors.red, size: 64),
                  SizedBox(height: 16),
                  Text(
                    'Gagal memuat data pelanggan',
                    style: TextStyle(fontSize: 16, color: Colors.red),
                  ),
                  SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {
                      setState(() {
                        _customerData = _loadCustomerData();
                      });
                    },
                    child: Text('Coba Lagi'),
                  ),
                ],
              ),
            );
          }

          final data = snapshot.data ?? {};
          final totalCustomers = data['total_customers'] ?? 0;
          final latestCustomers = List<dynamic>.from(data['latest_customers'] ?? []);

          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Summary Card
                Card(
                  elevation: 4,
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildSummaryItem(
                          totalCustomers.toString(),
                          'Total Pelanggan',
                          Icons.people,
                          Colors.orange,
                        ),
                        _buildSummaryItem(
                          latestCustomers.length.toString(),
                          'Pelanggan Terbaru',
                          Icons.new_releases,
                          Colors.green,
                        ),
                      ],
                    ),
                  ),
                ),
                SizedBox(height: 16),

                // Header
                Row(
                  children: [
                    Text(
                      'Daftar Pelanggan Terbaru',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[800],
                      ),
                    ),
                    Spacer(),
                    Text(
                      'Total: $totalCustomers',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 16),

                // Customer List
                Expanded(
                  child: latestCustomers.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.people_outline, size: 64, color: Colors.grey[400]),
                              SizedBox(height: 16),
                              Text(
                                'Belum ada data pelanggan',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          itemCount: latestCustomers.length,
                          itemBuilder: (context, index) {
                            final customer = latestCustomers[index];
                            return _buildCustomerCard(customer);
                          },
                        ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildSummaryItem(String value, String label, IconData icon, Color color) {
    return Column(
      children: [
        Container(
          padding: EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: color.withOpacity(0.2),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: 24),
        ),
        SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
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

  Widget _buildCustomerCard(Map<String, dynamic> customer) {
    return Card(
      margin: EdgeInsets.only(bottom: 12),
      elevation: 2,
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Row(
          children: [
            // Avatar
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.person,
                color: Colors.orange,
                size: 24,
              ),
            ),
            SizedBox(width: 16),

            // Customer Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    customer['name']?.toString() ?? 'Tidak ada nama',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 4),
                  if (customer['phone'] != null)
                    Text(
                      customer['phone'].toString(),
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                  SizedBox(height: 4),
                  if (customer['created_at'] != null)
                    Text(
                      'Bergabung: ${customer['created_at']}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[500],
                      ),
                    ),
                ],
              ),
            ),

            // Action Button
            IconButton(
              icon: Icon(Icons.visibility, color: Colors.orange),
              onPressed: () {
                _showCustomerDetail(customer);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showCustomerDetail(Map<String, dynamic> customer) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Detail Pelanggan'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildDetailItem('Nama', customer['name']?.toString() ?? '-'),
            _buildDetailItem('Telepon', customer['phone']?.toString() ?? '-'),
            _buildDetailItem('Bergabung', customer['created_at']?.toString() ?? '-'),
            _buildDetailItem('ID', customer['id']?.toString() ?? '-'),
          ],
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

  Widget _buildDetailItem(String label, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$label: ',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          Expanded(
            child: Text(value),
          ),
        ],
      ),
    );
  }
}