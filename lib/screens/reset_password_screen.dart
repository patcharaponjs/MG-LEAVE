
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'login_screen.dart';

class ResetPasswordScreen extends StatefulWidget {
  const ResetPasswordScreen({super.key});

  @override
  State<ResetPasswordScreen> createState() =>
      _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final SupabaseClient supabase = Supabase.instance.client;

  final _formKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool isLoading = false;
  bool obscurePassword = true;
  bool obscureConfirmPassword = true;
  bool isSuccess = false;

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  // บันทึกรหัสผ่านใหม่
  Future<void> resetPassword() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      isLoading = true;
    });

    try {
      await supabase.auth.updateUser(
        UserAttributes(
          password: _passwordController.text,
        ),
      );

      if (!mounted) return;

      setState(() {
        isLoading = false;
        isSuccess = true;
      });
    } on AuthException catch (e) {
      if (!mounted) return;

      setState(() {
        isLoading = false;
      });

      showMessage(
        'เปลี่ยนรหัสผ่านไม่สำเร็จ: ${e.message}',
        isError: true,
      );
    } catch (e) {
      if (!mounted) return;

      setState(() {
        isLoading = false;
      });

      showMessage(
        'เกิดข้อผิดพลาด กรุณาลองใหม่อีกครั้ง',
        isError: true,
      );
    }
  }

  // แสดงข้อความแจ้งเตือน
  void showMessage(
    String message, {
    bool isError = false,
  }) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // กลับไปหน้า Login และออกจาก session เดิม
  Future<void> backToLogin() async {
    try {
      await supabase.auth.signOut();
    } catch (_) {
      // หากออกจากระบบไม่สำเร็จ ยังคงกลับหน้า Login ได้
    }

    if (!mounted) return;

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (_) => const LoginScreen(),
      ),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FB),
      appBar: AppBar(
        title: const Text(
          'ตั้งรหัสผ่านใหม่',
          style: TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: const Color(0xFF087FD0),
        foregroundColor: Colors.white,
        elevation: 0,
        automaticallyImplyLeading: !isSuccess,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: 430,
            ),
            child: Container(
              padding: const EdgeInsets.all(25),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(22),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 18,
                    offset: const Offset(0, 7),
                  ),
                ],
              ),
              child: isSuccess
                  ? successView()
                  : resetForm(),
            ),
          ),
        ),
      ),
    );
  }

  // แบบฟอร์มตั้งรหัสผ่านใหม่
  Widget resetForm() {
    return Form(
      key: _formKey,
      child: Column(
        children: [
          Container(
            width: 85,
            height: 85,
            decoration: BoxDecoration(
              color: const Color(0xFFE8F3FC),
              borderRadius: BorderRadius.circular(25),
            ),
            child: const Icon(
              Icons.lock_reset,
              size: 45,
              color: Color(0xFF087FD0),
            ),
          ),

          const SizedBox(height: 22),

          const Text(
            'ตั้งรหัสผ่านใหม่',
            style: TextStyle(
              fontSize: 23,
              fontWeight: FontWeight.bold,
              color: Color(0xFF142B4A),
            ),
            textAlign: TextAlign.center,
          ),

          const SizedBox(height: 12),

          const Text(
            'กรุณากำหนดรหัสผ่านใหม่ของคุณ '
            'และยืนยันรหัสผ่านอีกครั้ง',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey,
              height: 1.6,
            ),
            textAlign: TextAlign.center,
          ),

          const SizedBox(height: 28),

          // รหัสผ่านใหม่
          TextFormField(
            controller: _passwordController,
            obscureText: obscurePassword,
            enabled: !isLoading,
            decoration: InputDecoration(
              labelText: 'รหัสผ่านใหม่',
              prefixIcon: const Icon(
                Icons.lock_outline,
                color: Color(0xFF087FD0),
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(13),
              ),
              suffixIcon: IconButton(
                icon: Icon(
                  obscurePassword
                      ? Icons.visibility_off
                      : Icons.visibility,
                ),
                onPressed: () {
                  setState(() {
                    obscurePassword = !obscurePassword;
                  });
                },
              ),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'กรุณากรอกรหัสผ่านใหม่';
              }

              if (value.length < 6) {
                return 'รหัสผ่านต้องมีอย่างน้อย 6 ตัวอักษร';
              }

              return null;
            },
          ),

          const SizedBox(height: 20),

          // ยืนยันรหัสผ่าน
          TextFormField(
            controller: _confirmPasswordController,
            obscureText: obscureConfirmPassword,
            enabled: !isLoading,
            decoration: InputDecoration(
              labelText: 'ยืนยันรหัสผ่านใหม่',
              prefixIcon: const Icon(
                Icons.lock_person_outlined,
                color: Color(0xFF087FD0),
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(13),
              ),
              suffixIcon: IconButton(
                icon: Icon(
                  obscureConfirmPassword
                      ? Icons.visibility_off
                      : Icons.visibility,
                ),
                onPressed: () {
                  setState(() {
                    obscureConfirmPassword =
                        !obscureConfirmPassword;
                  });
                },
              ),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'กรุณายืนยันรหัสผ่าน';
              }

              if (value != _passwordController.text) {
                return 'รหัสผ่านไม่ตรงกัน';
              }

              return null;
            },
          ),

          const SizedBox(height: 25),

          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: isLoading ? null : resetPassword,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF087FD0),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(13),
                ),
              ),
              child: isLoading
                  ? const SizedBox(
                      width: 23,
                      height: 23,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Text(
                      'บันทึกรหัสผ่านใหม่',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ),
          ),

          const SizedBox(height: 15),

          const Text(
            'รหัสผ่านต้องมีอย่างน้อย 6 ตัวอักษร',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey,
            ),
          ),
        ],
      ),
    );
  }

  // หน้าสำเร็จ
  Widget successView() {
    return Column(
      children: [
        Container(
          width: 90,
          height: 90,
          decoration: BoxDecoration(
            color: const Color(0xFFE7F8EE),
            borderRadius: BorderRadius.circular(50),
          ),
          child: const Icon(
            Icons.check_circle_outline,
            size: 50,
            color: Colors.green,
          ),
        ),

        const SizedBox(height: 22),

        const Text(
          'เปลี่ยนรหัสผ่านสำเร็จ',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: Color(0xFF142B4A),
          ),
          textAlign: TextAlign.center,
        ),

        const SizedBox(height: 12),

        const Text(
          'รหัสผ่านใหม่ของคุณได้รับการบันทึกแล้ว '
          'กรุณาเข้าสู่ระบบอีกครั้งด้วยรหัสผ่านใหม่',
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey,
            height: 1.7,
          ),
          textAlign: TextAlign.center,
        ),

        const SizedBox(height: 25),

        SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton(
            onPressed: backToLogin,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF087FD0),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(13),
              ),
            ),
            child: const Text(
              'กลับไปเข้าสู่ระบบ',
              style: TextStyle(
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
