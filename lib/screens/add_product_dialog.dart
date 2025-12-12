import 'package:bakery_system/services/api_service.dart';
import 'package:flutter/material.dart';

class AddProductDialog extends StatefulWidget {
  final Function()? onProductAdded;
  
  AddProductDialog({this.onProductAdded});
  
  @override
  _AddProductDialogState createState() => _AddProductDialogState();
}

class _AddProductDialogState extends State<AddProductDialog> {
  final _formKey = GlobalKey<FormState>();
  final ApiService _apiService = ApiService();
  
  // Controllers
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _priceController = TextEditingController();
  final TextEditingController _stockController = TextEditingController();
  // ignore: unused_field
  final TextEditingController _categoryController = TextEditingController();
  
  bool _isLoading = false;
  String _errorMessage = '';
  
  // Kategori pilihan
  final List<String> _categories = [
    'Roti Manis',
    'Roti Tawar',
    'Pastry',
    'Donat',
    'Roti Isi',
    'Kue Basah',
    'Kue Kering',
    'Lainnya'
  ];
  String _selectedCategory = 'Roti Manis';
  
  Future<void> _submitProduct() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });
    
    try {
      // Prepare data
      Map<String, dynamic> productData = {
        'name': _nameController.text.trim(),
        'description': _descriptionController.text.trim(),
        'price': double.parse(_priceController.text),
        'stock': int.parse(_stockController.text),
        'category': _selectedCategory,
      };
      
      // Call API
      var response = await _apiService.createProduct(productData);
      
      if (response['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ Produk berhasil ditambahkan'),
            backgroundColor: Colors.green,
          ),
        );
        
        Navigator.pop(context);
        
        // Trigger refresh
        if (widget.onProductAdded != null) {
          widget.onProductAdded!();
        }
      } else {
        setState(() {
          _errorMessage = response['error'] ?? 'Gagal menambah produk';
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.add_circle, color: Colors.green),
          SizedBox(width: 10),
          Text('Tambah Produk Baru'),
        ],
      ),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_errorMessage.isNotEmpty)
                Container(
                  padding: EdgeInsets.all(10),
                  margin: EdgeInsets.only(bottom: 10),
                  decoration: BoxDecoration(
                    color: Colors.red[50],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.error, color: Colors.red, size: 20),
                      SizedBox(width: 8),
                      Expanded(child: Text(_errorMessage)),
                    ],
                  ),
                ),
              
              TextFormField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: 'Nama Produk *',
                  border: OutlineInputBorder(),
                  hintText: 'Contoh: Roti Coklat',
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Nama produk harus diisi';
                  }
                  return null;
                },
              ),
              
              SizedBox(height: 12),
              
              TextFormField(
                controller: _descriptionController,
                decoration: InputDecoration(
                  labelText: 'Deskripsi',
                  border: OutlineInputBorder(),
                  hintText: 'Deskripsi produk (opsional)',
                ),
                maxLines: 2,
              ),
              
              SizedBox(height: 12),
              
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _priceController,
                      decoration: InputDecoration(
                        labelText: 'Harga *',
                        prefixText: 'Rp ',
                        border: OutlineInputBorder(),
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
                  ),
                  
                  SizedBox(width: 12),
                  
                  Expanded(
                    child: TextFormField(
                      controller: _stockController,
                      decoration: InputDecoration(
                        labelText: 'Stok Awal *',
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
                  ),
                ],
              ),
              
              SizedBox(height: 12),
              
              DropdownButtonFormField<String>(
                value: _selectedCategory,
                decoration: InputDecoration(
                  labelText: 'Kategori',
                  border: OutlineInputBorder(),
                ),
                items: _categories.map((category) {
                  return DropdownMenuItem(
                    value: category,
                    child: Text(category),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedCategory = value!;
                  });
                },
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.pop(context),
          child: Text('BATAL'),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _submitProduct,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green,
          ),
          child: _isLoading
              ? SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                )
              : Text('SIMPAN PRODUK'),
        ),
      ],
    );
  }
}