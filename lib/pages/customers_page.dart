import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/api_service.dart';
import '../models/customer.dart';

class CustomersPage extends StatefulWidget {
  @override
  _CustomersPageState createState() => _CustomersPageState();
}

class _CustomersPageState extends State<CustomersPage> {
  List<Customer> _customers = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadCustomers();
  }

  Future<void> _loadCustomers() async {
    try {
      final apiService = Provider.of<ApiService>(context, listen: false);
      final response = await apiService.get('customers');

      print('📦 Customers API Response: $response');

      // FIX: Handle response format
      if (response['success'] == true) {
        final data = response['data'];
        if (data is List) {
          setState(() {
            _customers = data.map((json) => Customer.fromJson(json)).toList();
            _isLoading = false;
            _error = null;
          });
        } else {
          throw Exception('Data format invalid');
        }
      } else {
        throw Exception('API error: ${response['error']}');
      }
    } catch (e) {
      print('❌ Error loading customers: $e');
      setState(() {
        _isLoading = false;
        _error = e.toString();
        _customers = [];
      });
    }
  }

  void _showAddCustomerDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AddCustomerDialog(onCustomerAdded: _loadCustomers),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Manajemen Pelanggan'),
        actions: [
          IconButton(
            icon: Icon(Icons.add),
            onPressed: _showAddCustomerDialog,
          ),
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: _loadCustomers,
          ),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.error, size: 64, color: Colors.red),
                      SizedBox(height: 16),
                      Text('Error: $_error'),
                      SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _loadCustomers,
                        child: Text('Coba Lagi'),
                      ),
                    ],
                  ),
                )
              : _customers.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.people_outline,
                              size: 64, color: Colors.grey),
                          SizedBox(height: 16),
                          Text(
                            'Belum Ada Pelanggan',
                            style: TextStyle(fontSize: 18, color: Colors.grey),
                          ),
                          SizedBox(height: 8),
                          ElevatedButton(
                            onPressed: _showAddCustomerDialog,
                            child: Text('Tambah Pelanggan Pertama'),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      itemCount: _customers.length,
                      itemBuilder: (ctx, index) {
                        final customer = _customers[index];
                        return _buildCustomerCard(customer);
                      },
                    ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddCustomerDialog,
        child: Icon(Icons.person_add),
        backgroundColor: Colors.blue,
      ),
    );
  }

  Widget _buildCustomerCard(Customer customer) {
    return Card(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 2,
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Colors.blue.withOpacity(0.2),
          child: Icon(Icons.person, color: Colors.blue),
        ),
        title: Text(
          customer.name,
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (customer.phone.isNotEmpty) Text('Telp: ${customer.phone}'),
            if (customer.email.isNotEmpty) Text('Email: ${customer.email}'),
            if (customer.address.isNotEmpty)
              Text(
                'Alamat: ${customer.address}',
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
          ],
        ),
        trailing: Icon(Icons.arrow_forward_ios, size: 16),
        onTap: () {
          _showCustomerDetails(customer);
        },
      ),
    );
  }

  void _showCustomerDetails(Customer customer) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(customer.name),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (customer.email.isNotEmpty)
                Padding(
                  padding: EdgeInsets.only(bottom: 8),
                  child: Text('Email: ${customer.email}'),
                ),
              if (customer.phone.isNotEmpty)
                Padding(
                  padding: EdgeInsets.only(bottom: 8),
                  child: Text('Telepon: ${customer.phone}'),
                ),
              if (customer.address.isNotEmpty)
                Padding(
                  padding: EdgeInsets.only(bottom: 8),
                  child: Text('Alamat: ${customer.address}'),
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
}

class AddCustomerDialog extends StatefulWidget {
  final VoidCallback onCustomerAdded;

  const AddCustomerDialog({required this.onCustomerAdded});

  @override
  _AddCustomerDialogState createState() => _AddCustomerDialogState();
}

class _AddCustomerDialogState extends State<AddCustomerDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  bool _isLoading = false;

  Future<void> _saveCustomer() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
      });

      try {
        final apiService = Provider.of<ApiService>(context, listen: false);

        final customerData = {
          'name': _nameController.text.trim(),
          'email': _emailController.text.trim(),
          'phone': _phoneController.text.trim(),
          'address': _addressController.text.trim(),
        };

        await apiService.post('customers', customerData);

        Navigator.of(context).pop();
        widget.onCustomerAdded();

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Pelanggan berhasil ditambahkan!'),
            backgroundColor: Colors.green,
          ),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal menambah pelanggan: $e'),
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
      title: Text('Tambah Pelanggan Baru'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: 'Nama Pelanggan *',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Nama pelanggan harus diisi';
                  }
                  return null;
                },
              ),
              SizedBox(height: 16),
              TextFormField(
                controller: _emailController,
                decoration: InputDecoration(
                  labelText: 'Email',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.emailAddress,
              ),
              SizedBox(height: 16),
              TextFormField(
                controller: _phoneController,
                decoration: InputDecoration(
                  labelText: 'Nomor Telepon',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.phone,
              ),
              SizedBox(height: 16),
              TextFormField(
                controller: _addressController,
                decoration: InputDecoration(
                  labelText: 'Alamat',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
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
              : Text('SIMPAN'),
          onPressed: _isLoading ? null : _saveCustomer,
        ),
      ],
    );
  }
}
