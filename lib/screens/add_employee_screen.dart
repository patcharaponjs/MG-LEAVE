import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AddEmployeeScreen extends StatefulWidget {
  const AddEmployeeScreen({super.key});

  @override
  State<AddEmployeeScreen> createState() => _AddEmployeeScreenState();
}

class _AddEmployeeScreenState extends State<AddEmployeeScreen> {
  final _formKey = GlobalKey<FormState>();

  final employeeCodeController = TextEditingController();
  final fullNameController = TextEditingController();
  final phoneController = TextEditingController();

  final SupabaseClient supabase = Supabase.instance.client;

  bool isLoading = false;
  int? selectedDepartmentId;
  String? selectedPosition;

  List<Map<String, dynamic>> departments = [];

  final List<String> positions = [
    'ช่าง (Mechanic / Technician)',
    'รถเช่า (Car Rental Staff / Rental Agent)',
    'ศูนย์ซ่อมตัวถังและสี (Body & Paint Center)',
    'เจ้าหน้าที่ธุรการ (Administrative Officer)',
    'เจ้าหน้าที่ลูกค้าสัมพันธ์ (Customer Relations Officer)',
    'เซลล์ (Sales Representative)',
    'เอสเอ (Service Advisor)',
    'วารันตี (Warranty Officer)',
    'ที่ปรึกษาด้านการขาย (Sales Consultant)',
    'เจ้าหน้าที่อะไหล่ (Parts Specialist)',
    'แคชเชียร์ (Cashier)',
  ];

  @override
  void initState() {
    super.initState();
    loadDepartments();
  }

  @override
  void dispose() {
    employeeCodeController.dispose();
    fullNameController.dispose();
    phoneController.dispose();
    super.dispose();
  }

  Future<void> loadDepartments() async {
    try {
      final result = await supabase
          .from('departments')
          .select('id, department_name')
          .order('id');

      if (!mounted) return;

      setState(() {
        departments = List<Map<String, dynamic>>.from(result);
      });
    } catch (e) {
      if (!mounted) return;
      _showMessage('โหลดข้อมูลแผนกไม่สำเร็จ: $e', isError: true);
    }
  }

  Future<void> addEmployee() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => isLoading = true);

    try {
      final response = await supabase.functions.invoke(
        'create-employee',
        body: {
          'employee_code': employeeCodeController.text.trim(),
          'full_name': fullNameController.text.trim(),
          'phone': phoneController.text.trim().replaceAll(RegExp(r'[\s-]'), ''),
          'position': selectedPosition,
          'department_id': selectedDepartmentId,
        },
      );

      final data = response.data;

      if (data is Map && data['success'] == true) {
        if (!mounted) return;

        _showMessage(
          'เพิ่มพนักงานสำเร็จ รหัสพนักงานใช้เป็นรหัสผ่านเริ่มต้น',
        );

        Navigator.pop(context, true);
      } else {
        final message = data is Map
            ? data['message']?.toString() ?? 'ไม่สามารถเพิ่มพนักงานได้'
            : 'ไม่สามารถเพิ่มพนักงานได้';

        throw Exception(message);
      }
    } on FunctionException catch (e) {
      if (!mounted) return;

      final details = e.details;
      final message = details is Map
          ? details['message']?.toString() ?? 'เกิดข้อผิดพลาด'
          : 'เกิดข้อผิดพลาด: ${e.status}';

      _showMessage(message, isError: true);
    } catch (e) {
      if (!mounted) return;

      _showMessage(
        e.toString().replaceFirst('Exception: ', ''),
        isError: true,
      );
    } finally {
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  void _showMessage(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red.shade700 : Colors.green.shade700,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  InputDecoration _decoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      filled: true,
      fillColor: const Color(0xFFF8FAFC),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FA),
      appBar: AppBar(
        title: const Text('เพิ่มพนักงาน'),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF1E293B),
        elevation: 0,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 650),
            child: Card(
              elevation: 3,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Icon(
                        Icons.person_add_alt_1,
                        size: 55,
                        color: Color(0xFF2563EB),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'ข้อมูลพนักงานใหม่',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 23,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 25),

                      TextFormField(
                        controller: employeeCodeController,
                        decoration: _decoration(
                          'รหัสพนักงาน',
                          Icons.badge_outlined,
                        ),
                        textCapitalization: TextCapitalization.characters,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'กรุณากรอกรหัสพนักงาน';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 18),

                      TextFormField(
                        controller: fullNameController,
                        decoration: _decoration(
                          'ชื่อ-นามสกุล',
                          Icons.person_outline,
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'กรุณากรอกชื่อ-นามสกุล';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 18),

                      TextFormField(
                        controller: phoneController,
                        keyboardType: TextInputType.phone,
                        decoration: _decoration(
                          'เบอร์โทรศัพท์',
                          Icons.phone_outlined,
                        ),
                        validator: (value) {
                          final phone = (value ?? '').trim();
                          if (phone.isEmpty) {
                            return 'กรุณากรอกเบอร์โทรศัพท์';
                          }
                          final normalized =
                              phone.replaceAll(RegExp(r'[\s-]'), '');
                          if (!RegExp(r'^0[0-9]{9}$').hasMatch(normalized)) {
                            return 'กรุณากรอกเบอร์โทรศัพท์ 10 หลัก';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 18),

                      DropdownButtonFormField<String>(
                        value: selectedPosition,
                        isExpanded: true,
                        decoration: _decoration(
                          'ตำแหน่ง',
                          Icons.work_outline,
                        ),
                        hint: const Text('เลือกตำแหน่ง'),
                        items: positions.map((position) {
                          return DropdownMenuItem<String>(
                            value: position,
                            child: Text(
                              position,
                              overflow: TextOverflow.ellipsis,
                            ),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setState(() {
                            selectedPosition = value;
                          });
                        },
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'กรุณาเลือกตำแหน่ง';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 18),

                      DropdownButtonFormField<int>(
                        value: selectedDepartmentId,
                        isExpanded: true,
                        decoration: _decoration(
                          'แผนก',
                          Icons.business_outlined,
                        ),
                        items: departments.map((department) {
                          return DropdownMenuItem<int>(
                            value: (department['id'] as num).toInt(),
                            child: Text(
                              department['department_name']?.toString() ?? '',
                            ),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setState(() {
                            selectedDepartmentId = value;
                          });
                        },
                        validator: (value) {
                          if (value == null) {
                            return 'กรุณาเลือกแผนก';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 18),

                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEFF6FF),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              Icons.info_outline,
                              color: Color(0xFF2563EB),
                            ),
                            SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'รหัสพนักงานจะถูกใช้เป็นรหัสผ่านเริ่มต้นสำหรับเข้าสู่ระบบ เช่น MG001',
                                style: TextStyle(
                                  color: Color(0xFF1E40AF),
                                  height: 1.5,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 25),

                      SizedBox(
                        height: 50,
                        child: ElevatedButton.icon(
                          onPressed: isLoading ? null : addEmployee,
                          icon: isLoading
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.save_outlined),
                          label: Text(
                            isLoading
                                ? 'กำลังบันทึก...'
                                : 'บันทึกข้อมูลพนักงาน',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF2563EB),
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
              ),
            ),
          ),
        ),
      ),
    );
  }
}
