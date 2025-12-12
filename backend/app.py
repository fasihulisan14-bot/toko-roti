from flask import Flask, jsonify, request
from flask_cors import CORS
import mysql.connector
from datetime import datetime, timedelta 
import bcrypt  
import jwt     
import traceback  
from functools import wraps  
app = Flask(__name__)
CORS(app)

# Secret key untuk JWT - ganti dengan random string di production
app.config['SECRET_KEY'] = 'bakery-system-secret-key-2024'

# Database configuration - SESUAIKAN DENGAN XAMPP ANDA
def get_db_config():
    return {
        'host': 'localhost',
        'user': 'root',
        'password': '',  # Password MySQL Anda (kosong jika tidak ada)
        'database': 'bakery_system',
        'port': 3306
    }

def get_db_connection():
    try:
        conn = mysql.connector.connect(**get_db_config())
        return conn
    except Exception as e:
        print(f"❌ Database error: {e}")
        return None

# Helper function untuk format tanggal yang konsisten
def format_date(date_obj):
    if date_obj is None:
        return None
    if isinstance(date_obj, datetime):
        return date_obj.isoformat() + 'Z'  # Format ISO dengan timezone
    return str(date_obj)

# 🔐 AUTH MIDDLEWARE & HELPERS

def generate_token(user_data):
    """Generate JWT token"""
    try:
        payload = {
            'user': user_data,
            'exp': datetime.utcnow() + timedelta(days=7)
        }
        return jwt.encode(payload, app.config['SECRET_KEY'], algorithm='HS256')
    except Exception as e:
        print(f"Token generation error: {e}")
        # Fallback - return simple token
        return f"simple-token-{user_data['id']}-{datetime.utcnow().timestamp()}"
  

def hash_password(password):
    """Hash password menggunakan bcrypt"""
    try:
        salt = bcrypt.gensalt()
        hashed = bcrypt.hashpw(password.encode('utf-8'), salt)
        return hashed.decode('utf-8')
    except Exception as e:
        print(f"Hash error: {e}")
        # Fallback ke hashlib jika bcrypt error
        import hashlib
        return hashlib.sha256(password.encode()).hexdigest()

def check_password(password, hashed):
    """Check password dengan hash"""
    try:
        return bcrypt.checkpw(password.encode('utf-8'), hashed.encode('utf-8'))
    except:
        # Fallback
        import hashlib
        return hashlib.sha256(password.encode()).hexdigest() == hashed

# 🔐 AUTH ROUTES

@app.route('/api/auth/register', methods=['POST'])
def register():
    """Register user baru"""
    conn = get_db_connection()
    if not conn:
        return jsonify({'success': False, 'error': 'Database connection failed'}), 500
    
    try:
        data = request.get_json()
        name = data.get('name', '').strip()
        email = data.get('email', '').strip().lower()
        password = data.get('password', '')
        role = data.get('role', 'kasir')  # Default role: kasir

        # Validasi input
        if not name or not email or not password:
            return jsonify({'success': False, 'message': 'Nama, email, dan password harus diisi!'}), 400
        
        if len(password) < 6:
            return jsonify({'success': False, 'message': 'Password minimal 6 karakter!'}), 400

        cursor = conn.cursor(dictionary=True)
        
        # Cek apakah email sudah terdaftar
        cursor.execute("SELECT id FROM users WHERE email = %s", (email,))
        if cursor.fetchone():
            cursor.close()
            conn.close()
            return jsonify({'success': False, 'message': 'Email sudah terdaftar!'}), 400

        # Hash password
        hashed_password = hash_password(password)

        # Insert user baru
        insert_query = """
            INSERT INTO users (name, email, password, role) 
            VALUES (%s, %s, %s, %s)
        """
        cursor.execute(insert_query, (name, email, hashed_password, role))
        conn.commit()
        user_id = cursor.lastrowid

        # Get user data untuk response
        cursor.execute("SELECT id, name, email, role, created_at FROM users WHERE id = %s", (user_id,))
        user = cursor.fetchone()
        
        # Format tanggal
        user['created_at'] = format_date(user['created_at'])

        cursor.close()
        conn.close()

        # Generate token
        token = generate_token({
            'id': user['id'],
            'name': user['name'],
            'email': user['email'],
            'role': user['role']
        })

        return jsonify({
            'success': True,
            'message': 'Registrasi berhasil!',
            'data': {
                'user': user,
                'token': token
            }
        })

    except Exception as e:
        return jsonify({'success': False, 'error': str(e)}), 500

@app.route('/api/auth/login', methods=['POST'])
def login():
    """Login user"""
    conn = get_db_connection()
    if not conn:
        return jsonify({'success': False, 'error': 'Database connection failed'}), 500
    
    try:
        data = request.get_json()
        email = data.get('email', '').strip().lower()
        password = data.get('password', '')

        # Validasi input
        if not email or not password:
            return jsonify({'success': False, 'message': 'Email dan password harus diisi!'}), 400

        cursor = conn.cursor(dictionary=True)
        
        # Cari user by email
        cursor.execute("SELECT * FROM users WHERE email = %s", (email,))
        user = cursor.fetchone()
        
        if not user:
            cursor.close()
            conn.close()
            return jsonify({'success': False, 'message': 'Email atau password salah!'}), 401

        # Check password
        if not check_password(password, user['password']):
            cursor.close()
            conn.close()
            return jsonify({'success': False, 'message': 'Email atau password salah!'}), 401

        # Remove password dari response
        user_data = {
            'id': user['id'],
            'name': user['name'],
            'email': user['email'],
            'role': user['role'],
            'created_at': format_date(user['created_at'])
        }

        # Generate token
        token = generate_token(user_data)

        cursor.close()
        conn.close()

        return jsonify({
            'success': True,
            'message': 'Login berhasil!',
            'data': {
                'user': user_data,
                'token': token
            }
        })

    except Exception as e:
        return jsonify({'success': False, 'error': str(e)}), 500

@app.route('/api/auth/me', methods=['GET'])
def token_required(f):
    @wraps(f)
    def decorated(*args, **kwargs):
        token = request.headers.get('Authorization')
        
        if not token:
            return jsonify({'success': False, 'message': 'Token is missing!'}), 401
        
        try:
            # Remove 'Bearer ' prefix
            if token.startswith('Bearer '):
                token = token[7:]
            
            data = jwt.decode(token, app.config['SECRET_KEY'], algorithms=['HS256'])
            current_user = data['user']
        except jwt.ExpiredSignatureError:
            return jsonify({'success': False, 'message': 'Token has expired!'}), 401
        except jwt.InvalidTokenError:
            return jsonify({'success': False, 'message': 'Token is invalid!'}), 401
        except Exception as e:
            return jsonify({'success': False, 'message': f'Token error: {str(e)}'}), 401
        
        return f(current_user, *args, **kwargs)
    
    return decorated

# Kemudian route untuk /api/auth/me
@app.route('/api/auth/me', methods=['GET'])
@token_required
def get_current_user(current_user):
    """Get data user yang sedang login"""
    return jsonify({
        'success': True,
        'data': current_user
    })


@app.route('/api/protected-dashboard')
@token_required
def protected_dashboard(current_user):
    """Contoh protected route"""
    # Anda bisa akses current_user disini
    print(f"User {current_user['name']} mengakses dashboard")
    
    # Panggil fungsi dashboard biasa
    return get_dashboard()

# ✅ EXISTING ROUTES (tetap sama seperti sebelumnya)

@app.route('/')
def home():
    return jsonify({'message': 'Bakery System API - MySQL Connected'})

@app.route('/api/health')
def health_check():
    conn = get_db_connection()
    if conn:
        conn.close()
        return jsonify({'status': 'healthy', 'database': 'connected'})
    else:
        return jsonify({'status': 'unhealthy', 'database': 'disconnected'}), 500

@app.route('/api/dashboard')
def get_dashboard():
    conn = get_db_connection()
    if not conn:
        return jsonify({'success': False, 'error': 'Database connection failed'}), 500
    
    try:
        cursor = conn.cursor(dictionary=True)
        
        # Total penjualan hari ini
        cursor.execute("""
            SELECT COUNT(*) as today_sales, COALESCE(SUM(total_amount), 0) as revenue 
            FROM sales 
            WHERE DATE(sale_date) = CURDATE()
        """)
        today_stats = cursor.fetchone()
        
        # Produk stok menipis
        cursor.execute("SELECT COUNT(*) as low_stock FROM products WHERE stock < 10")
        low_stock = cursor.fetchone()
        
        # Total produk
        cursor.execute("SELECT COUNT(*) as total_products FROM products")
        total_products = cursor.fetchone()
        
        # Total pelanggan
        cursor.execute("SELECT COUNT(*) as total_customers FROM customers")
        total_customers = cursor.fetchone()
        
        cursor.close()
        conn.close()
        
        return jsonify({
            'success': True,
            'data': {
                'today_sales': today_stats['today_sales'],
                'today_revenue': float(today_stats['revenue']),
                'low_stock': low_stock['low_stock'],
                'total_products': total_products['total_products'],
                'total_customers': total_customers['total_customers']
            }
        })
    except Exception as e:
        return jsonify({'success': False, 'error': str(e)}), 500
    
@app.route('/api/dashboard/stats')
def get_dashboard_stats():
    """Get quick stats untuk dashboard laporan"""
    conn = get_db_connection()
    if not conn:
        return jsonify({'success': False, 'error': 'Database connection failed'}), 500
    
    try:
        cursor = conn.cursor(dictionary=True)
        
        # Total penjualan hari ini
        cursor.execute("""
            SELECT 
                COUNT(*) as today_sales, 
                COALESCE(SUM(total_amount), 0) as today_revenue 
            FROM sales 
            WHERE DATE(sale_date) = CURDATE()
        """)
        today_stats = cursor.fetchone() or {'today_sales': 0, 'today_revenue': 0}
        
        # Total produk
        cursor.execute("SELECT COUNT(*) as total_products FROM products")
        total_products = cursor.fetchone() or {'total_products': 0}
        
        # Total pelanggan
        cursor.execute("SELECT COUNT(*) as total_customers FROM customers")
        total_customers = cursor.fetchone() or {'total_customers': 0}
        
        # Produk hampir habis (stok < 10)
        cursor.execute("SELECT COUNT(*) as low_stock FROM products WHERE stock < 10")
        low_stock = cursor.fetchone() or {'low_stock': 0}
        
        cursor.close()
        conn.close()
        
        return jsonify({
            'success': True,
            'data': {
                'today_sales': today_stats['today_sales'],
                'today_revenue': float(today_stats['today_revenue']),
                'total_products': total_products['total_products'],
                'total_customers': total_customers['total_customers'],
                'low_stock_items': low_stock['low_stock']
            }
        })
    except Exception as e:
        return jsonify({'success': False, 'error': str(e)}), 500
        
@app.route('/api/products', methods=['GET'])
def get_all_products():
    conn = get_db_connection()
    if not conn:
        return jsonify({'success': False, 'error': 'Database connection failed'}), 500

    try:
        cursor = conn.cursor(dictionary=True)
        cursor.execute("SELECT * FROM products ORDER BY id DESC")
        products = cursor.fetchall()

        for p in products:
            p['price'] = float(p['price'])
            p['stock'] = int(p['stock'])
            p['description'] = p['description'] or ""
            p['category'] = p['category'] or ""
            p['image_url'] = p['image_url'] or ""
            p['created_at'] = format_date(p['created_at'])
            p['updated_at'] = format_date(p['updated_at'])

        cursor.close()
        conn.close()

        return jsonify({'success': True, 'data': products})

    except Exception as e:
        return jsonify({'success': False, 'error': str(e)}), 500

@app.route('/api/products/update-stock', methods=['POST'])
def update_stock():
    conn = None
    try:
        data = request.get_json()
        
        # Validasi input
        if not data or 'product_id' not in data or 'stock_change' not in data:
            return jsonify({'success': False, 'error': 'Missing product_id or stock_change'}), 400
        
        try:
            product_id = int(data['product_id'])
            stock_change = int(data['stock_change'])
        except ValueError:
            return jsonify({'success': False, 'error': 'Invalid product_id or stock_change format'}), 400
        
        conn = get_db_connection()
        if not conn:
            return jsonify({'success': False, 'error': 'Database connection failed'}), 500
        
        cursor = conn.cursor(dictionary=True)
        
        # Mulai transaksi
        conn.start_transaction()
        
        # SELECT ... FOR UPDATE untuk locking row
        cursor.execute(
            "SELECT stock FROM products WHERE id = %s FOR UPDATE",
            (product_id,)
        )
        product = cursor.fetchone()
        
        if not product:
            conn.rollback()
            return jsonify({'success': False, 'error': 'Product not found'}), 404
        
        new_stock = product['stock'] + stock_change
        if new_stock < 0:
            new_stock = 0
        
        # Update stok
        cursor.execute(
            "UPDATE products SET stock = %s, updated_at = NOW() WHERE id = %s",
            (new_stock, product_id)
        )
        
        # Commit transaksi
        conn.commit()
        
        return jsonify({
            'success': True,
            'message': 'Stock updated successfully',
            'new_stock': new_stock,
            'product_id': product_id
        })
        
    except Exception as e:
        if conn:
            conn.rollback()
        return jsonify({'success': False, 'error': str(e)}), 500
    finally:
        if conn:
            conn.close()

@app.route('/api/products/low-stock')
def get_low_stock():
    """Get products with stock below threshold"""
    conn = get_db_connection()
    if not conn:
        return jsonify({'success': False, 'error': 'Database connection failed'}), 500
    
    try:
        threshold = request.args.get('threshold', 10, type=int)
        cursor = conn.cursor(dictionary=True)
        cursor.execute(
            "SELECT * FROM products WHERE stock < %s ORDER BY stock ASC",
            (threshold,)
        )
        products = cursor.fetchall()
        
        for p in products:
            p['price'] = float(p['price'])
            p['stock'] = int(p['stock'])
        
        cursor.close()
        conn.close()
        
        return jsonify({
            'success': True, 
            'data': products,
            'threshold': threshold
        })
        
    except Exception as e:
        return jsonify({'success': False, 'error': str(e)}), 500
    
@app.route('/api/customers', methods=['GET'])
def get_customers():
    conn = get_db_connection()
    if not conn:
        return jsonify({'success': False, 'error': 'Database connection failed'}), 500
    
    try:
        cursor = conn.cursor(dictionary=True)
        cursor.execute("SELECT * FROM customers ORDER BY name")
        customers = cursor.fetchall()
        
        # Format tanggal untuk konsistensi
        for customer in customers:
            customer['created_at'] = format_date(customer['created_at'])
        
        cursor.close()
        conn.close()
        
        return jsonify({
            'success': True,
            'data': customers,
            'count': len(customers)
        })
    except Exception as e:
        return jsonify({'success': False, 'error': str(e)}), 500

@app.route('/api/products/<int:product_id>', methods=['GET'])
def get_product_by_id(product_id):
    """Get produk berdasarkan ID"""
    conn = get_db_connection()
    if not conn:
        return jsonify({'success': False, 'error': 'Database connection failed'}), 500
    
    try:
        cursor = conn.cursor(dictionary=True)
        cursor.execute("SELECT * FROM products WHERE id = %s", (product_id,))
        product = cursor.fetchone()
        
        if not product:
            return jsonify({'success': False, 'error': 'Product not found'}), 404
        
        # Format data
        product['price'] = float(product['price'])
        product['stock'] = int(product['stock'])
        product['description'] = product['description'] or ""
        product['category'] = product['category'] or ""
        product['image_url'] = product['image_url'] or ""
        product['created_at'] = format_date(product['created_at'])
        product['updated_at'] = format_date(product['updated_at'])
        
        cursor.close()
        conn.close()
        
        return jsonify({'success': True, 'data': product})
        
    except Exception as e:
        return jsonify({'success': False, 'error': str(e)}), 500

@app.route('/api/products/<int:product_id>', methods=['PUT'])
def update_product(product_id):
    """Update data produk"""
    conn = get_db_connection()
    if not conn:
        return jsonify({'success': False, 'error': 'Database connection failed'}), 500
    
    try:
        data = request.get_json()
        
        if not data:
            return jsonify({'success': False, 'error': 'No data provided'}), 400
        
        cursor = conn.cursor(dictionary=True)
        
        # Cek produk exists
        cursor.execute("SELECT id FROM products WHERE id = %s", (product_id,))
        if not cursor.fetchone():
            return jsonify({'success': False, 'error': 'Product not found'}), 404
        
        # Build update query
        update_fields = []
        update_values = []
        
        if 'name' in data:
            update_fields.append("name = %s")
            update_values.append(data['name'].strip())
        if 'description' in data:
            update_fields.append("description = %s")
            update_values.append(data.get('description', '').strip())
        if 'price' in data:
            update_fields.append("price = %s")
            update_values.append(float(data['price']))
        if 'stock' in data:
            update_fields.append("stock = %s")
            update_values.append(int(data['stock']))
        if 'category' in data:
            update_fields.append("category = %s")
            update_values.append(data.get('category', '').strip())
        
        # Tambahkan updated_at
        update_fields.append("updated_at = NOW()")
        
        # Eksekusi update
        update_values.append(product_id)
        query = f"UPDATE products SET {', '.join(update_fields)} WHERE id = %s"
        
        cursor.execute(query, update_values)
        conn.commit()
        
        cursor.close()
        conn.close()
        
        return jsonify({
            'success': True,
            'message': 'Product updated successfully'
        })
        
    except Exception as e:
        return jsonify({'success': False, 'error': str(e)}), 500
    
@app.route('/api/products', methods=['POST'])
def create_product():
    """Create produk baru"""
    conn = get_db_connection()
    if not conn:
        return jsonify({'success': False, 'error': 'Database connection failed'}), 500
    
    try:
        data = request.get_json()
        
        # Validasi input wajib
        required_fields = ['name', 'price', 'stock']
        for field in required_fields:
            if field not in data:
                return jsonify({
                    'success': False, 
                    'error': f'Field "{field}" harus diisi'
                }), 400
        
        cursor = conn.cursor(dictionary=True)
        
        # Insert produk baru
        insert_query = """
            INSERT INTO products 
            (name, description, price, stock, category, image_url) 
            VALUES (%s, %s, %s, %s, %s, %s)
        """
        
        cursor.execute(insert_query, (
            data['name'].strip(),
            data.get('description', '').strip(),
            float(data['price']),
            int(data['stock']),
            data.get('category', '').strip(),
            data.get('image_url', '')
        ))
        
        conn.commit()
        new_id = cursor.lastrowid
        
        # Ambil data produk yang baru dibuat
        cursor.execute("SELECT * FROM products WHERE id = %s", (new_id,))
        new_product = cursor.fetchone()
        
        # Format data untuk response
        new_product['price'] = float(new_product['price'])
        new_product['stock'] = int(new_product['stock'])
        new_product['description'] = new_product['description'] or ""
        new_product['category'] = new_product['category'] or ""
        new_product['image_url'] = new_product['image_url'] or ""
        new_product['created_at'] = format_date(new_product['created_at'])
        new_product['updated_at'] = format_date(new_product['updated_at'])
        
        cursor.close()
        conn.close()
        
        return jsonify({
            'success': True,
            'message': 'Produk berhasil ditambahkan',
            'data': new_product
        })
        
    except Exception as e:
        return jsonify({'success': False, 'error': str(e)}), 500

@app.route('/api/customers', methods=['POST'])
def add_customer():
    conn = get_db_connection()
    if not conn:
        return jsonify({'success': False, 'error': 'Database connection failed'}), 500
    
    try:
        data = request.get_json()
        cursor = conn.cursor()
        
        query = """
            INSERT INTO customers (name, email, phone, address) 
            VALUES (%s, %s, %s, %s)
        """
        values = (
            data.get('name', '').strip(),
            data.get('email', '').strip(),
            data.get('phone', '').strip(),
            data.get('address', '').strip()
        )
        
        cursor.execute(query, values)
        conn.commit()
        customer_id = cursor.lastrowid
        
        cursor.close()
        conn.close()
        
        return jsonify({
            'success': True,
            'message': 'Pelanggan berhasil ditambahkan ke database',
            'data': {'id': customer_id}
        })
    except Exception as e:
        return jsonify({'success': False, 'error': str(e)}), 500

@app.route('/api/customers/report', methods=['GET'])
def customer_report():
    """Laporan pelanggan: total pelanggan, pelanggan terbaru, transaksi terbanyak"""
    conn = get_db_connection()
    if not conn:
        return jsonify({'success': False, 'error': 'Database connection failed'}), 500

    try:
        cursor = conn.cursor(dictionary=True)

        # Total pelanggan
        cursor.execute("SELECT COUNT(*) AS total_customers FROM customers")
        total_customers = cursor.fetchone()['total_customers']

        # Daftar pelanggan terbaru
        cursor.execute("""
            SELECT id, name, phone, created_at 
            FROM customers
            ORDER BY created_at DESC
            LIMIT 20
        """)
        latest_customers = cursor.fetchall()

        for c in latest_customers:
            c['created_at'] = format_date(c['created_at'])

        cursor.close()
        conn.close()

        return jsonify({
            'success': True,
            'data': {
                'total_customers': total_customers,
                'latest_customers': latest_customers
            }
        })

    except Exception as e:
        return jsonify({'success': False, 'error': str(e)}), 500


@app.route('/api/sales', methods=['GET'])
def get_sales():
    conn = get_db_connection()
    if not conn:
        return jsonify({'success': False, 'error': 'Database connection failed'}), 500
    
    try:
        cursor = conn.cursor(dictionary=True)
        
        # Get sales dengan customer name
        cursor.execute("""
            SELECT s.*, c.name as customer_name 
            FROM sales s 
            LEFT JOIN customers c ON s.customer_id = c.id 
            ORDER BY s.sale_date DESC
        """)
        sales = cursor.fetchall()
        
        # Convert data untuk JSON
        for sale in sales:
            sale['total_amount'] = float(sale['total_amount'])
            sale['sale_date'] = format_date(sale['sale_date'])
        
        # Get sale items untuk setiap sale
        for sale in sales:
            cursor.execute("""
                SELECT si.*, p.name as product_name 
                FROM sale_items si 
                JOIN products p ON si.product_id = p.id 
                WHERE si.sale_id = %s
            """, (sale['id'],))
            items = cursor.fetchall()
            
            # Convert decimal to float untuk items
            for item in items:
                item['unit_price'] = float(item['unit_price'])
                item['subtotal'] = float(item['subtotal'])
            
            sale['items'] = items
        
        cursor.close()
        conn.close()
        
        return jsonify({
            'success': True,
            'data': sales,
            'count': len(sales)
        })
    except Exception as e:
        return jsonify({'success': False, 'error': str(e)}), 500

@app.route('/api/sales', methods=['POST'])
def create_sale():
    conn = get_db_connection()
    if not conn:
        return jsonify({'success': False, 'error': 'Database connection failed'}), 500
    
    try:
        data = request.get_json()
        cursor = conn.cursor()
        
        # Start transaction
        conn.start_transaction()
        
        # Insert sale
        sale_query = """
            INSERT INTO sales (customer_id, total_amount, payment_method) 
            VALUES (%s, %s, %s)
        """
        
        customer_id = data.get('customer_id')
        if customer_id == '' or customer_id is None:
            customer_id = None
            
        sale_values = (
            customer_id,
            float(data.get('total_amount', 0)),
            data.get('payment_method', 'cash')
        )
        
        cursor.execute(sale_query, sale_values)
        sale_id = cursor.lastrowid
        
        # Insert sale items
        for item in data.get('items', []):
            item_query = """
                INSERT INTO sale_items (sale_id, product_id, quantity, unit_price, subtotal) 
                VALUES (%s, %s, %s, %s, %s)
            """
            item_values = (
                sale_id,
                item['product_id'],
                int(item['quantity']),
                float(item['unit_price']),
                float(item['subtotal'])
            )
            cursor.execute(item_query, item_values)
            
            # Update stock di database
            update_query = "UPDATE products SET stock = stock - %s WHERE id = %s"
            cursor.execute(update_query, (int(item['quantity']), item['product_id']))
        
        # Commit transaction
        conn.commit()
        cursor.close()
        conn.close()
        
        return jsonify({
            'success': True,
            'message': 'Transaksi penjualan berhasil disimpan di database',
            'data': {'sale_id': sale_id}
        })
    except Exception as e:
        conn.rollback()
        return jsonify({'success': False, 'error': str(e)}), 500

# Error handlers untuk handle 404
@app.errorhandler(404)
def not_found(error):
    return jsonify({'success': False, 'error': 'Endpoint not found'}), 404

@app.errorhandler(500)
def internal_error(error):
    return jsonify({'success': False, 'error': 'Internal server error'}), 500

if __name__ == '__main__':
    print("🚀 Bakery System - MySQL Connected")
    print("📊 Database: bakery_system")
    print("🌐 API: http://localhost:5000")
    print("🔐 AUTH Endpoints:")
    print("   POST /api/auth/register")
    print("   POST /api/auth/login") 
    print("   GET  /api/auth/me")
    print("   GET  /api/auth/check")
    print("✅ All endpoints ready:")
    print("   GET  /api/health")
    print("   GET  /api/dashboard")
    print("   GET  /api/products")
    print("   POST /api/products")
    print("   GET  /api/customers")
    print("   POST /api/customers")
    print("   GET  /api/sales")
    print("   POST /api/sales")
    app.run(host='0.0.0.0', port=5000, debug=True)