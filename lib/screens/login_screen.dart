
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'dashboard_screen.dart';
import 'forgot_password_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();

  final SupabaseClient supabase = Supabase.instance.client;

  List<String> _employees = [];
  String? _selectedUsername;

  bool _obscurePassword = true;
  bool _isLoading = false;
  bool _isLoadingEmployees = true;

  @override
  void initState() {
    super.initState();
    _loadEmployees();
  }

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  // โหลดรายชื่อพนักงานจาก Supabase
  Future<void> _loadEmployees() async {
    if (!mounted) return;

    setState(() {
      _isLoadingEmployees = true;
    });

    try {
      debugPrint('กำลังโหลดรายชื่อพนักงานจาก profiles...');

      final response = await supabase
          .from('profiles')
          .select('full_name')
          .eq('is_active', true)
          .order('full_name');

      final names = response
          .map((item) => item['full_name']?.toString() ?? '')
          .where((name) => name.trim().isNotEmpty)
          .toSet()
          .toList();

      if (!mounted) return;

      setState(() {
        _employees = names;
        _isLoadingEmployees = false;
      });

      debugPrint('โหลดรายชื่อสำเร็จ จำนวน ${names.length} รายชื่อ');

      if (names.isEmpty) {
        _showMessage('ยังไม่พบรายชื่อพนักงานที่เปิดใช้งาน');
      }
    } catch (e, stackTrace) {
      debugPrint('LOAD EMPLOYEES ERROR: $e');
      debugPrint('STACK TRACE: $stackTrace');

      if (!mounted) return;

      setState(() {
        _employees = [];
        _isLoadingEmployees = false;
      });

      // แสดง Error จริงจาก Supabase
      _showMessage('โหลดรายชื่อไม่สำเร็จ: $e');
    }
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final response = await supabase.functions.invoke(
        'login-with-username',
        body: {
          'full_name': _selectedUsername,
          'password': _passwordController.text.trim(),
        },
      );

      final data = response.data;

      if (data is! Map || data['success'] != true) {
        throw Exception(
          data is Map
              ? data['message']?.toString() ??
                  'ชื่อผู้ใช้หรือรหัสผ่านไม่ถูกต้อง'
              : 'ไม่สามารถเข้าสู่ระบบได้',
        );
      }

      final tokenHash = data['token_hash'];

      if (tokenHash == null || tokenHash.toString().isEmpty) {
        throw Exception('ไม่พบ Token สำหรับเข้าสู่ระบบ');
      }

      await supabase.auth.verifyOTP(
        tokenHash: tokenHash.toString(),
        type: OtpType.magiclink,
      );

      final user = supabase.auth.currentUser;

      if (user == null) {
        throw Exception('ไม่สามารถตรวจสอบบัญชีผู้ใช้ได้');
      }

      final profile = await supabase
          .from('profiles')
          .select('full_name, role, is_active')
          .eq('id', user.id)
          .maybeSingle();

      if (profile == null) {
        await supabase.auth.signOut();
        throw Exception('ไม่พบข้อมูลพนักงานในระบบ');
      }

      if (profile['is_active'] != true) {
        await supabase.auth.signOut();
        throw Exception(
          'บัญชีนี้ถูกระงับการใช้งาน กรุณาติดต่อผู้ดูแลระบบ',
        );
      }

      if (!mounted) return;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => DashboardScreen(
            fullName: profile['full_name']?.toString() ?? '',
          ),
        ),
      );
    } on FunctionException catch (e) {
      if (!mounted) return;

      final details = e.details;
      String message = 'ชื่อผู้ใช้หรือรหัสผ่านไม่ถูกต้อง';

      if (details is Map && details['message'] != null) {
        message = details['message'].toString();
      }

      _showMessage(message);
    } catch (e) {
      if (!mounted) return;

      String message = e.toString().replaceFirst('Exception: ', '');

      _showMessage(message);
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red.shade700,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 6),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FA),
      body: Stack(
        children: [
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 430),
                child: Card(
                  elevation: 5,
                  shadowColor: Colors.black12,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(30),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Icon(
                            Icons.event_note_rounded,
                            size: 65,
                            color: Color(0xFF2563EB),
                          ),
                          const SizedBox(height: 16),

                          const Text(
                            'เข้าสู่ระบบ',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1E293B),
                            ),
                          ),
                          const SizedBox(height: 8),

                          const Text(
                            'ระบบบริหารจัดการการลางาน',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 15,
                              color: Colors.grey,
                            ),
                          ),
                          const SizedBox(height: 32),

                          const Text(
                            'ชื่อผู้ใช้',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 15,
                            ),
                          ),
                          const SizedBox(height: 8),

                          DropdownButtonFormField<String>(
                            value: _selectedUsername,
                            isExpanded: true,
                            decoration: InputDecoration(
                              hintText: _isLoadingEmployees
                                  ? 'กำลังโหลดรายชื่อ...'
                                  : 'กดเพื่อเลือกชื่อพนักงาน',
                              prefixIcon: const Icon(
                                Icons.person_outline,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              filled: true,
                              fillColor: const Color(0xFFF8FAFC),
                            ),
                            items: _employees.map((name) {
                              return DropdownMenuItem<String>(
                                value: name,
                                child: Text(
                                  name,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              );
                            }).toList(),
                            onChanged: _isLoadingEmployees ||
                                    _employees.isEmpty
                                ? null
                                : (value) {
                                    setState(() {
                                      _selectedUsername = value;
                                    });
                                  },
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'กรุณาเลือกชื่อผู้ใช้';
                              }
                              return null;
                            },
                          ),

                          if (!_isLoadingEmployees &&
                              _employees.isEmpty)
                            Align(
                              alignment: Alignment.centerRight,
                              child: TextButton.icon(
                                onPressed: _loadEmployees,
                                icon: const Icon(Icons.refresh),
                                label: const Text('โหลดรายชื่ออีกครั้ง'),
                              ),
                            ),

                          const SizedBox(height: 20),

                          const Text(
                            'รหัสผ่าน',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 15,
                            ),
                          ),
                          const SizedBox(height: 8),

                          TextFormField(
                            controller: _passwordController,
                            obscureText: _obscurePassword,
                            decoration: InputDecoration(
                              hintText: 'กรอกรหัสพนักงาน',
                              prefixIcon: const Icon(
                                Icons.lock_outline,
                              ),
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _obscurePassword
                                      ? Icons.visibility_off
                                      : Icons.visibility,
                                ),
                                onPressed: () {
                                  setState(() {
                                    _obscurePassword =
                                        !_obscurePassword;
                                  });
                                },
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              filled: true,
                              fillColor: const Color(0xFFF8FAFC),
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'กรุณากรอกรหัสผ่าน';
                              }
                              return null;
                            },
                            onFieldSubmitted: (_) => _login(),
                          ),

                          const SizedBox(height: 12),

                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton(
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        const ForgotPasswordScreen(),
                                  ),
                                );
                              },
                              child: const Text('ลืมรหัสผ่าน?'),
                            ),
                          ),

                          const SizedBox(height: 12),

                          SizedBox(
                            height: 52,
                            child: ElevatedButton(
                              onPressed: _isLoading ||
                                      _isLoadingEmployees
                                  ? null
                                  : _login,
                              style: ElevatedButton.styleFrom(
                                backgroundColor:
                                    const Color(0xFF2563EB),
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius:
                                      BorderRadius.circular(12),
                                ),
                              ),
                              child: _isLoading
                                  ? const SizedBox(
                                      width: 24,
                                      height: 24,
                                      child:
                                          CircularProgressIndicator(
                                        color: Colors.white,
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Text(
                                      'เข้าสู่ระบบ',
                                      style: TextStyle(
                                        fontSize: 17,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),

          // ปุ่มย้อนกลับหน้าหลัก
          Positioned(
            top: 16,
            left: 16,
            child: SafeArea(
              child: Material(
                color: Colors.white,
                elevation: 3,
                shape: const CircleBorder(),
                child: IconButton(
                  tooltip: 'กลับหน้าหลัก',
                  icon: const Icon(
                    Icons.arrow_back_rounded,
                    color: Color(0xFF1E293B),
                    size: 24,
                  ),
                  onPressed: () {
                    if (Navigator.canPop(context)) {
                      Navigator.pop(context);
                    }
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
