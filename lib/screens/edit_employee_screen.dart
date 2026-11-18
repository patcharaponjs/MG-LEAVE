import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class EditEmployeeScreen extends StatefulWidget {
  final Map<String, dynamic> employee;

  const EditEmployeeScreen({
    super.key,
    required this.employee,
  });

  @override
  State<EditEmployeeScreen> createState() =>
      _EditEmployeeScreenState();
}

class _EditEmployeeScreenState extends State<EditEmployeeScreen> {
  final supabase = Supabase.instance.client;
  final formKey = GlobalKey<FormState>();

  late final TextEditingController codeController;
  late final TextEditingController nameController;
  late final TextEditingController phoneController;
  late final TextEditingController positionController;
  late final TextEditingController departmentController;

  List<Map<String, dynamic>> departments = [];

  int? selectedDepartmentId;
  bool isActive = true;
  bool isLoading = true;
  bool isSaving = false;
  String? departmentError;

  @override
  void initState() {
    super.initState();

    final employee = widget.employee;

    codeController = TextEditingController(
      text: employee['employee_code']?.toString() ?? '',
    );

    nameController = TextEditingController(
      text: employee['full_name']?.toString() ?? '',
    );

    phoneController = TextEditingController(
      text: employee['phone']?.toString() ?? '',
    );

    positionController = TextEditingController(
      text: employee['position']?.toString() ?? '',
    );

    departmentController = TextEditingController();

    selectedDepartmentId =
        int.tryParse(employee['department_id']?.toString() ?? '');

    isActive = employee['is_active'] == true;

    loadDepartments();
  }

  @override
  void dispose() {
    codeController.dispose();
    nameController.dispose();
    phoneController.dispose();
    positionController.dispose();
    departmentController.dispose();
    super.dispose();
  }

  // โหลดข้อมูลแผนกและแสดงชื่อแผนกเดิม
  Future<void> loadDepartments() async {
    try {
      final response = await supabase
          .from('departments')
          .select('id, department_name')
          .order('department_name');

      if (!mounted) return;

      final loadedDepartments =
          List<Map<String, dynamic>>.from(response);

      String currentDepartmentName = '';

      for (final department in loadedDepartments) {
        final id = int.tryParse(department['id'].toString());

        if (id == selectedDepartmentId) {
          currentDepartmentName =
              department['department_name']?.toString() ?? '';
          break;
        }
      }

      setState(() {
        departments = loadedDepartments;
        departmentController.text = currentDepartmentName;
        departmentError = null;
        isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        isLoading = false;
        departmentError = e.toString();
      });

      showMessage(
        'โหลดข้อมูลแผนกไม่สำเร็จ: $e',
        isError: true,
      );
    }
  }

  void showMessage(String message, {bool isError = false}) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
      ),
    );
  }

  // ค้นหาแผนกเดิม หรือเพิ่มแผนกใหม่อัตโนมัติ
  Future<int> getDepartmentId(String departmentName) async {
    final name = departmentName.trim();

    if (name.isEmpty) {
      throw Exception('กรุณากรอกชื่อแผนก');
    }

    // ค้นหาชื่อแผนกเดิมแบบไม่แยกตัวพิมพ์เล็ก-ใหญ่
    final existingDepartment = await supabase
        .from('departments')
        .select('id, department_name')
        .ilike('department_name', name)
        .maybeSingle();

    if (existingDepartment != null) {
      final id = int.tryParse(
        existingDepartment['id'].toString(),
      );

      if (id == null) {
        throw Exception('ไม่สามารถอ่านรหัสแผนกได้');
      }

      return id;
    }

    // หากไม่มีชื่อแผนกนี้ ให้เพิ่มข้อมูลใหม่
    final newDepartment = await supabase
        .from('departments')
        .insert({
          'department_name': name,
        })
        .select('id')
        .single();

    final newId = int.tryParse(
      newDepartment['id'].toString(),
    );

    if (newId == null) {
      throw Exception('ไม่สามารถสร้างรหัสแผนกใหม่ได้');
    }

    return newId;
  }

  Future<void> saveEmployee() async {
    if (!formKey.currentState!.validate()) return;

    setState(() {
      isSaving = true;
    });

    try {
      // ค้นหา ID ของแผนก หรือสร้างแผนกใหม่
      final departmentId = await getDepartmentId(
        departmentController.text,
      );

      final normalizedPhone = phoneController.text
          .trim()
          .replaceAll(RegExp(r'[\s-]'), '');

      // บันทึกข้อมูลพนักงาน
      // ไม่แก้ไข email เพราะเป็นอีเมลภายในที่ใช้สำหรับเข้าสู่ระบบ
      await supabase
          .from('profiles')
          .update({
            'employee_code': codeController.text.trim(),
            'full_name': nameController.text.trim(),
            'phone': normalizedPhone,
            'position': positionController.text.trim().isEmpty
                ? null
                : positionController.text.trim(),
            'department_id': departmentId,
            'is_active': isActive,
          })
          .eq('id', widget.employee['id']);

      if (!mounted) return;

      showMessage('บันทึกข้อมูลพนักงานเรียบร้อยแล้ว');
      Navigator.pop(context, true);
    } catch (e) {
      showMessage(
        'บันทึกข้อมูลไม่สำเร็จ: $e',
        isError: true,
      );
    } finally {
      if (mounted) {
        setState(() {
          isSaving = false;
        });
      }
    }
  }

  Widget buildTextField({
    required String label,
    required TextEditingController controller,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        validator: validator,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon),
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }

  // ช่องพิมพ์ชื่อแผนกแทน Dropdown
  Widget buildDepartmentField() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
        controller: departmentController,
        enabled: !isSaving,
        textInputAction: TextInputAction.next,
        decoration: InputDecoration(
          labelText: 'แผนก',
          hintText: 'พิมพ์ชื่อแผนก',
          helperText: 'หากเป็นแผนกใหม่ ระบบจะเพิ่มให้อัตโนมัติ',
          prefixIcon: const Icon(Icons.business_outlined),
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        validator: (value) {
          if (value == null || value.trim().isEmpty) {
            return 'กรุณากรอกชื่อแผนก';
          }
          return null;
        },
        onChanged: (value) {
          selectedDepartmentId = null;
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FB),
      appBar: AppBar(
        title: const Text(
          'แก้ไขข้อมูลพนักงาน',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFF087FD0),
        foregroundColor: Colors.white,
      ),
      body: isLoading
          ? const Center(
              child: CircularProgressIndicator(),
            )
          : Form(
              key: formKey,
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  Center(
                    child: CircleAvatar(
                      radius: 38,
                      backgroundColor: const Color(0xFFE3F2FD),
                      child: const Icon(
                        Icons.edit,
                        size: 38,
                        color: Color(0xFF087FD0),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  const Text(
                    'ข้อมูลส่วนตัว',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),

                  buildTextField(
                    label: 'รหัสพนักงาน',
                    controller: codeController,
                    icon: Icons.badge_outlined,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'กรุณากรอกรหัสพนักงาน';
                      }
                      return null;
                    },
                  ),

                  buildTextField(
                    label: 'ชื่อ-นามสกุล',
                    controller: nameController,
                    icon: Icons.person_outline,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'กรุณากรอกชื่อ-นามสกุล';
                      }
                      return null;
                    },
                  ),

                  buildTextField(
                    label: 'เบอร์โทรศัพท์',
                    controller: phoneController,
                    icon: Icons.phone_outlined,
                    keyboardType: TextInputType.phone,
                    validator: (value) {
                      final phone = (value ?? '')
                          .trim()
                          .replaceAll(RegExp(r'[\s-]'), '');

                      if (phone.isEmpty) {
                        return 'กรุณากรอกเบอร์โทรศัพท์';
                      }

                      if (!RegExp(r'^0[0-9]{9}$').hasMatch(phone)) {
                        return 'กรุณากรอกเบอร์โทรศัพท์ 10 หลัก';
                      }

                      return null;
                    },
                  ),

                  buildTextField(
                    label: 'ตำแหน่ง',
                    controller: positionController,
                    icon: Icons.work_outline,
                  ),

                  const SizedBox(height: 4),

                  buildDepartmentField(),

                  const SizedBox(height: 20),

                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text(
                        'สถานะบัญชีพนักงาน',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      subtitle: Text(
                        isActive
                            ? 'บัญชีนี้สามารถใช้งานได้'
                            : 'บัญชีนี้ถูกปิดใช้งาน',
                      ),
                      value: isActive,
                      activeThumbColor: Colors.green,
                      onChanged: isSaving
                          ? null
                          : (value) {
                              setState(() {
                                isActive = value;
                              });
                            },
                    ),
                  ),

                  const SizedBox(height: 28),

                  SizedBox(
                    height: 52,
                    child: ElevatedButton.icon(
                      onPressed: isSaving ? null : saveEmployee,
                      icon: isSaving
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.save),
                      label: Text(
                        isSaving
                            ? 'กำลังบันทึก...'
                            : 'บันทึกข้อมูล',
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF087FD0),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
