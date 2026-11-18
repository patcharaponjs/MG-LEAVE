
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'change_password_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final SupabaseClient supabase = Supabase.instance.client;

  Map<String, dynamic>? profile;
  bool isLoading = true;
  bool isSaving = false;
  String? errorMessage;

  @override
  void initState() {
    super.initState();
    loadProfile();
  }

  // โหลดข้อมูลโปรไฟล์
  Future<void> loadProfile() async {
    final user = supabase.auth.currentUser;

    if (user == null) {
      setState(() {
        isLoading = false;
        errorMessage = 'กรุณาเข้าสู่ระบบใหม่';
      });
      return;
    }

    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      final response = await supabase
          .from('profiles')
          .select('''
            employee_code,
            full_name,
            email,
            position,
            role,
            department:departments(department_name)
          ''')
          .eq('id', user.id)
          .maybeSingle();

      if (!mounted) return;

      if (response == null) {
        setState(() {
          isLoading = false;
          errorMessage = 'ไม่พบข้อมูลโปรไฟล์';
        });
        return;
      }

      setState(() {
        profile = response;
        isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        isLoading = false;
        errorMessage = 'ไม่สามารถโหลดข้อมูลได้: $e';
      });
    }
  }

  // อ่านข้อมูลจากโปรไฟล์
  String getValue(String key) {
    final value = profile?[key];

    if (value == null || value.toString().trim().isEmpty) {
      return '-';
    }

    return value.toString();
  }

  // อ่านชื่อแผนก
  String getDepartmentName() {
    final department = profile?['department'];

    if (department is Map) {
      return department['department_name']?.toString() ?? '-';
    }

    if (department is List && department.isNotEmpty) {
      return department.first['department_name']?.toString() ?? '-';
    }

    return '-';
  }

  // ตัวอักษรบนรูปโปรไฟล์
  String getInitials() {
    final name = getValue('full_name');

    if (name == '-') return 'MG';

    return name.characters.first;
  }

  bool get isAdmin => getValue('role') == 'admin';

  // แก้ไขชื่อ-นามสกุล
  Future<void> editFullName() async {
    final controller = TextEditingController(
      text: getValue('full_name') == '-'
          ? ''
          : getValue('full_name'),
    );

    final newName = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          title: const Text(
            'แก้ไขชื่อ-นามสกุล',
            style: TextStyle(
              fontWeight: FontWeight.bold,
            ),
          ),
          content: TextField(
            controller: controller,
            autofocus: true,
            maxLength: 150,
            decoration: InputDecoration(
              labelText: 'ชื่อ-นามสกุล',
              hintText: 'กรอกชื่อและนามสกุล',
              prefixIcon: const Icon(Icons.person_outline),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext);
              },
              child: const Text('ยกเลิก'),
            ),
            ElevatedButton(
              onPressed: () {
                final name = controller.text.trim();

                if (name.length < 2) {
                  ScaffoldMessenger.of(dialogContext).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'กรุณากรอกชื่ออย่างน้อย 2 ตัวอักษร',
                      ),
                    ),
                  );
                  return;
                }

                Navigator.pop(dialogContext, name);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF087FD0),
                foregroundColor: Colors.white,
              ),
              child: const Text('บันทึก'),
            ),
          ],
        );
      },
    );

    controller.dispose();

    if (newName == null || !mounted) return;

    await saveFullName(newName);
  }

  // บันทึกชื่อผ่าน Supabase RPC
  Future<void> saveFullName(String newName) async {
    setState(() {
      isSaving = true;
    });

    try {
      await supabase.rpc(
        'update_my_profile',
        params: {
          'p_full_name': newName,
        },
      );

      if (!mounted) return;

      await loadProfile();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('บันทึกข้อมูลส่วนตัวเรียบร้อยแล้ว'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('ไม่สามารถบันทึกข้อมูลได้: $e'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 5),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          isSaving = false;
        });
      }
    }
  }

  // เปิดหน้าเปลี่ยนรหัสผ่าน
  void openChangePassword() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const ChangePasswordScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FB),
      appBar: AppBar(
        title: const Text(
          'ข้อมูลส่วนตัว',
          style: TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: const Color(0xFF087FD0),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            tooltip: 'รีเฟรชข้อมูล',
            onPressed: isLoading ? null : loadProfile,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: isLoading
          ? const Center(
              child: CircularProgressIndicator(),
            )
          : errorMessage != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(25),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.error_outline,
                          color: Colors.red,
                          size: 55,
                        ),
                        const SizedBox(height: 15),
                        Text(
                          errorMessage!,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 15),
                        ElevatedButton.icon(
                          onPressed: loadProfile,
                          icon: const Icon(Icons.refresh),
                          label: const Text('ลองอีกครั้ง'),
                        ),
                      ],
                    ),
                  ),
                )
              : Stack(
                  children: [
                    RefreshIndicator(
                      onRefresh: loadProfile,
                      child: SingleChildScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          children: [
                            // ส่วนหัวโปรไฟล์
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(
                                vertical: 28,
                                horizontal: 20,
                              ),
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [
                                    Color(0xFF087FD0),
                                    Color(0xFF0399D1),
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Column(
                                children: [
                                  CircleAvatar(
                                    radius: 43,
                                    backgroundColor: Colors.white,
                                    child: Text(
                                      getInitials(),
                                      style: const TextStyle(
                                        color: Color(0xFF087FD0),
                                        fontSize: 30,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 15),
                                  Text(
                                    getValue('full_name'),
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 21,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    isAdmin
                                        ? 'ผู้ดูแลระบบ (Administrator)'
                                        : 'พนักงาน (Employee)',
                                    style: const TextStyle(
                                      color: Colors.white70,
                                      fontSize: 14,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 7,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withValues(
                                        alpha: 0.2,
                                      ),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Text(
                                      isAdmin ? 'ADMIN' : 'EMPLOYEE',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 1,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            const SizedBox(height: 15),

                            // ปุ่มแก้ไขชื่อ-นามสกุล
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                onPressed: isSaving ? null : editFullName,
                                icon: const Icon(Icons.edit_outlined),
                                label: const Text('แก้ไขชื่อ-นามสกุล'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF087FD0),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 15,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                              ),
                            ),

                            const SizedBox(height: 12),

                            // ปุ่มเปลี่ยนรหัสผ่าน
                            SizedBox(
                              width: double.infinity,
                              child: OutlinedButton.icon(
                                onPressed: openChangePassword,
                                icon: const Icon(Icons.lock_reset),
                                label: const Text('เปลี่ยนรหัสผ่าน'),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: const Color(0xFF087FD0),
                                  side: const BorderSide(
                                    color: Color(0xFF087FD0),
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 15,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                              ),
                            ),

                            const SizedBox(height: 22),

                            // ข้อมูลบัญชี
                            _sectionTitle('ข้อมูลบัญชี'),

                            _infoCard(
                              icon: Icons.badge_outlined,
                              title: 'รหัสพนักงาน',
                              value: getValue('employee_code'),
                            ),

                            _infoCard(
                              icon: Icons.person_outline,
                              title: 'ชื่อ-นามสกุล',
                              value: getValue('full_name'),
                            ),

                            _infoCard(
                              icon: Icons.email_outlined,
                              title: 'อีเมล',
                              value: getValue('email'),
                            ),

                            const SizedBox(height: 12),

                            // ข้อมูลการทำงาน
                            _sectionTitle('ข้อมูลการทำงาน'),

                            _infoCard(
                              icon: Icons.apartment_outlined,
                              title: 'แผนก',
                              value: getDepartmentName(),
                            ),

                            _infoCard(
                              icon: Icons.work_outline,
                              title: 'ตำแหน่ง',
                              value: getValue('position'),
                            ),

                            _infoCard(
                              icon: Icons.admin_panel_settings_outlined,
                              title: 'สิทธิ์ผู้ใช้งาน',
                              value: isAdmin
                                  ? 'ผู้ดูแลระบบ (Admin)'
                                  : 'พนักงาน (Employee)',
                            ),

                            const SizedBox(height: 20),

                            // ข้อความท้ายหน้า
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(17),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(15),
                              ),
                              child: const Row(
                                children: [
                                  Icon(
                                    Icons.verified_user_outlined,
                                    color: Color(0xFF087FD0),
                                    size: 26,
                                  ),
                                  SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      'ข้อมูลส่วนตัวของคุณถูกดึงจากระบบ MG LEAVE MANAGEMENT',
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: Color(0xFF142B4A),
                                        height: 1.5,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // แสดงสถานะกำลังบันทึก
                    if (isSaving)
                      Container(
                        color: Colors.black.withValues(alpha: 0.08),
                        child: const Center(
                          child: Card(
                            child: Padding(
                              padding: EdgeInsets.all(22),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  CircularProgressIndicator(),
                                  SizedBox(height: 14),
                                  Text('กำลังบันทึกข้อมูล...'),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
    );
  }

  // หัวข้อแต่ละส่วน
  Widget _sectionTitle(String title) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: Color(0xFF142B4A),
        ),
      ),
    );
  }

  // การ์ดแสดงข้อมูล
  Widget _infoCard({
    required IconData icon,
    required String title,
    required String value,
  }) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 11),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Container(
            width: 45,
            height: 45,
            decoration: BoxDecoration(
              color: const Color(0xFFE8F3FC),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              color: const Color(0xFF087FD0),
              size: 24,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF142B4A),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
