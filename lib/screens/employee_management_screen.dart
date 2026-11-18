import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'add_employee_screen.dart';
import 'edit_employee_screen.dart';

class EmployeeManagementScreen extends StatefulWidget {
  const EmployeeManagementScreen({super.key});

  @override
  State<EmployeeManagementScreen> createState() =>
      _EmployeeManagementScreenState();
}

class _EmployeeManagementScreenState
    extends State<EmployeeManagementScreen> {
  final SupabaseClient supabase = Supabase.instance.client;
  final TextEditingController searchController = TextEditingController();

  List<Map<String, dynamic>> employees = [];
  List<Map<String, dynamic>> filteredEmployees = [];
  List<Map<String, dynamic>> departments = [];

  final Set<String> deletingIds = {};

  bool isLoading = true;
  String searchText = '';

  @override
  void initState() {
    super.initState();
    loadEmployees();
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  // โหลดรายชื่อพนักงาน
  Future<void> loadEmployees() async {
    if (mounted) {
      setState(() {
        isLoading = true;
      });
    }

    try {
      final employeeData = await supabase
          .from('profiles')
          .select(
            'id, employee_code, full_name, phone, position, role, department_id, is_active',
          )
          .order('full_name');

      final departmentData = await supabase
          .from('departments')
          .select('id, department_name');

      if (!mounted) return;

      employees = List<Map<String, dynamic>>.from(employeeData);
      departments = List<Map<String, dynamic>>.from(departmentData);

      filterEmployees();
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('ไม่สามารถโหลดข้อมูลพนักงานได้: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  // ค้นหาพนักงานด้วยชื่อ รหัสพนักงาน หรือเบอร์โทรศัพท์
  void filterEmployees() {
    final keyword = searchText.toLowerCase().trim();

    filteredEmployees = employees.where((employee) {
      final name =
          (employee['full_name'] ?? '').toString().toLowerCase();

      final code =
          (employee['employee_code'] ?? '').toString().toLowerCase();

      final phone =
          (employee['phone'] ?? '').toString().toLowerCase();

      return name.contains(keyword) ||
          code.contains(keyword) ||
          phone.contains(keyword);
    }).toList();

    if (mounted) {
      setState(() {});
    }
  }

  // หาชื่อแผนกจาก department_id
  String getDepartmentName(dynamic departmentId) {
    if (departmentId == null) {
      return 'ยังไม่ได้ระบุแผนก';
    }

    final department = departments.where((item) {
      return item['id'].toString() == departmentId.toString();
    });

    if (department.isEmpty) {
      return 'ไม่พบข้อมูลแผนก';
    }

    return department.first['department_name']?.toString() ??
        'ไม่พบข้อมูลแผนก';
  }

  // เปิดหน้าเพิ่มพนักงาน
  Future<void> openAddEmployee() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const AddEmployeeScreen(),
      ),
    );

    if (!mounted) return;

    if (result == true) {
      await loadEmployees();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('เพิ่มพนักงานเรียบร้อยแล้ว'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  // เปิดหน้าแก้ไขพนักงาน
  Future<void> editEmployee(
    Map<String, dynamic> employee,
  ) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EditEmployeeScreen(
          employee: employee,
        ),
      ),
    );

    if (!mounted) return;

    if (result == true) {
      await loadEmployees();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('แก้ไขข้อมูลพนักงานเรียบร้อยแล้ว'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  // ปิดใช้งานพนักงาน
  Future<void> deleteEmployee(
    Map<String, dynamic> employee,
  ) async {
    final id = employee['id']?.toString();
    final name = employee['full_name']?.toString() ?? 'พนักงาน';

    if (id == null || id.isEmpty) return;

    // ป้องกันการปิดใช้งานบัญชีตัวเอง
    final currentUserId = supabase.auth.currentUser?.id;

    if (currentUserId == id) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('ไม่สามารถปิดใช้งานบัญชีที่กำลังเข้าสู่ระบบได้'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.red),
              SizedBox(width: 10),
              Text('ยืนยันการปิดใช้งาน'),
            ],
          ),
          content: Text(
            'คุณต้องการปิดใช้งานพนักงาน "$name" ใช่หรือไม่?\n\n'
            'พนักงานจะไม่สามารถเข้าสู่ระบบได้ แต่ข้อมูลและประวัติการลางานเดิมจะยังคงอยู่',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext, false);
              },
              child: const Text('ยกเลิก'),
            ),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.pop(dialogContext, true);
              },
              icon: const Icon(Icons.person_off),
              label: const Text('ยืนยันปิดใช้งาน'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        );
      },
    );

    if (confirm != true || !mounted) return;

    setState(() {
      deletingIds.add(id);
    });

    try {
      await supabase
          .from('profiles')
          .update({'is_active': false})
          .eq('id', id);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('ปิดใช้งานพนักงาน "$name" เรียบร้อยแล้ว'),
          backgroundColor: Colors.green,
        ),
      );

      await loadEmployees();
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('ไม่สามารถปิดใช้งานพนักงานได้: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          deletingIds.remove(id);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final activeCount =
        employees.where((e) => e['is_active'] == true).length;

    final inactiveCount =
        employees.where((e) => e['is_active'] != true).length;

    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FB),
      appBar: AppBar(
        title: const Text(
          'จัดการพนักงาน',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        backgroundColor: const Color(0xFF087FD0),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            onPressed: loadEmployees,
            icon: const Icon(Icons.refresh),
            tooltip: 'โหลดข้อมูลใหม่',
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: openAddEmployee,
        backgroundColor: const Color(0xFF087FD0),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.person_add),
        label: const Text('เพิ่มพนักงาน'),
      ),
      body: Column(
        children: [
          // ส่วนสรุปจำนวนพนักงาน
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: const BoxDecoration(
              color: Color(0xFF087FD0),
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(24),
                bottomRight: Radius.circular(24),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'ข้อมูลบุคลากร',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 21,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 5),
                const Text(
                  'จัดการและตรวจสอบข้อมูลพนักงานในองค์กร',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: summaryCard(
                        'พนักงานทั้งหมด',
                        employees.length.toString(),
                        Icons.people,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: summaryCard(
                        'กำลังปฏิบัติงาน',
                        activeCount.toString(),
                        Icons.check_circle,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: summaryCard(
                        'ไม่ใช้งาน',
                        inactiveCount.toString(),
                        Icons.person_off,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // ช่องค้นหา
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 18, 16, 10),
            child: TextField(
              controller: searchController,
              onChanged: (value) {
                searchText = value;
                filterEmployees();
              },
              decoration: InputDecoration(
                hintText: 'ค้นหาชื่อ รหัสพนักงาน หรือเบอร์โทรศัพท์',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: searchController.text.isNotEmpty
                    ? IconButton(
                        onPressed: () {
                          searchController.clear();
                          searchText = '';
                          filterEmployees();
                        },
                        icon: const Icon(Icons.close),
                      )
                    : null,
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),

          // รายชื่อพนักงาน
          Expanded(
            child: isLoading
                ? const Center(
                    child: CircularProgressIndicator(),
                  )
                : filteredEmployees.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.people_outline,
                              size: 65,
                              color: Colors.grey.shade400,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              employees.isEmpty
                                  ? 'ยังไม่มีข้อมูลพนักงาน'
                                  : 'ไม่พบข้อมูลที่ค้นหา',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.grey.shade600,
                              ),
                            ),
                            const SizedBox(height: 8),
                            if (employees.isEmpty)
                              const Text(
                                'กดปุ่มเพิ่มพนักงานเพื่อเริ่มต้น',
                                style: TextStyle(
                                  color: Colors.grey,
                                ),
                              ),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: loadEmployees,
                        child: ListView.builder(
                          padding: const EdgeInsets.fromLTRB(
                            16,
                            5,
                            16,
                            90,
                          ),
                          itemCount: filteredEmployees.length,
                          itemBuilder: (context, index) {
                            final employee =
                                filteredEmployees[index];

                            final fullName =
                                (employee['full_name'] ?? 'ไม่ระบุชื่อ')
                                    .toString();

                            final employeeCode =
                                (employee['employee_code'] ?? '-')
                                    .toString();

                            final phone =
                                (employee['phone'] ?? 'ยังไม่ได้ระบุเบอร์โทรศัพท์')
                                    .toString();

                            final position =
                                (employee['position'] ?? 'ไม่ระบุตำแหน่ง')
                                    .toString();

                            final departmentName =
                                getDepartmentName(
                              employee['department_id'],
                            );

                            final isActive =
                                employee['is_active'] == true;

                            final employeeId =
                                employee['id']?.toString() ?? '';

                            final isDeleting =
                                deletingIds.contains(employeeId);

                            final firstLetter =
                                fullName.trim().isNotEmpty
                                    ? fullName.trim().substring(0, 1)
                                    : '?';

                            return Card(
                              elevation: 1,
                              color: Colors.white,
                              margin: const EdgeInsets.only(bottom: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(15),
                                child: Row(
                                  children: [
                                    CircleAvatar(
                                      radius: 25,
                                      backgroundColor:
                                          const Color(0xFFE3F2FD),
                                      child: Text(
                                        firstLetter,
                                        style: const TextStyle(
                                          color: Color(0xFF087FD0),
                                          fontSize: 20,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 13),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            fullName,
                                            style: const TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          const SizedBox(height: 5),
                                          Text(
                                            'รหัสพนักงาน: $employeeCode',
                                            style: const TextStyle(
                                              fontSize: 12,
                                              color: Colors.black54,
                                            ),
                                          ),
                                          const SizedBox(height: 3),
                                          Text(
                                            'เบอร์โทรศัพท์: $phone',
                                            style: const TextStyle(
                                              fontSize: 12,
                                              color: Colors.black54,
                                            ),
                                          ),
                                          const SizedBox(height: 3),
                                          Text(
                                            position,
                                            style: const TextStyle(
                                              fontSize: 12,
                                              color: Colors.black54,
                                            ),
                                          ),
                                          const SizedBox(height: 3),
                                          Text(
                                            departmentName,
                                            style: const TextStyle(
                                              fontSize: 12,
                                              color: Colors.black54,
                                            ),
                                          ),
                                          const SizedBox(height: 8),
                                          Container(
                                            padding:
                                                const EdgeInsets.symmetric(
                                              horizontal: 10,
                                              vertical: 4,
                                            ),
                                            decoration: BoxDecoration(
                                              color: isActive
                                                  ? Colors.green.shade50
                                                  : Colors.red.shade50,
                                              borderRadius:
                                                  BorderRadius.circular(20),
                                            ),
                                            child: Text(
                                              isActive
                                                  ? 'กำลังปฏิบัติงาน'
                                                  : 'ไม่ใช้งาน',
                                              style: TextStyle(
                                                color: isActive
                                                    ? Colors.green.shade700
                                                    : Colors.red.shade700,
                                                fontSize: 11,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),

                                          // ปุ่มแก้ไขและปิดใช้งาน
                                          const SizedBox(height: 10),
                                          Row(
                                            children: [
                                              Expanded(
                                                child: OutlinedButton.icon(
                                                  onPressed: isDeleting
                                                      ? null
                                                      : () => editEmployee(
                                                            employee,
                                                          ),
                                                  icon: const Icon(
                                                    Icons.edit_outlined,
                                                    size: 18,
                                                  ),
                                                  label: const Text(
                                                    'แก้ไขข้อมูล',
                                                  ),
                                                  style: OutlinedButton
                                                      .styleFrom(
                                                    foregroundColor:
                                                        const Color(
                                                      0xFF087FD0,
                                                    ),
                                                    side: const BorderSide(
                                                      color: Color(
                                                        0xFF087FD0,
                                                      ),
                                                    ),
                                                    shape:
                                                        RoundedRectangleBorder(
                                                      borderRadius:
                                                          BorderRadius
                                                              .circular(10),
                                                    ),
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              Expanded(
                                                child: OutlinedButton.icon(
                                                  onPressed:
                                                      (!isActive ||
                                                              isDeleting)
                                                          ? null
                                                          : () =>
                                                              deleteEmployee(
                                                                employee,
                                                              ),
                                                  icon: isDeleting
                                                      ? const SizedBox(
                                                          width: 16,
                                                          height: 16,
                                                          child:
                                                              CircularProgressIndicator(
                                                            strokeWidth: 2,
                                                          ),
                                                        )
                                                      : const Icon(
                                                          Icons.delete_outline,
                                                          size: 18,
                                                        ),
                                                  label: Text(
                                                    isDeleting
                                                        ? 'กำลังดำเนินการ'
                                                        : 'ปิดใช้งาน',
                                                  ),
                                                  style: OutlinedButton
                                                      .styleFrom(
                                                    foregroundColor:
                                                        Colors.red,
                                                    side: const BorderSide(
                                                      color: Colors.red,
                                                    ),
                                                    disabledForegroundColor:
                                                        Colors.grey,
                                                    shape:
                                                        RoundedRectangleBorder(
                                                      borderRadius:
                                                          BorderRadius
                                                              .circular(10),
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  // การ์ดสรุปจำนวน
  Widget summaryCard(
    String title,
    String value,
    IconData icon,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 9,
        vertical: 13,
      ),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(13),
      ),
      child: Column(
        children: [
          Icon(
            icon,
            color: Colors.white,
            size: 22,
          ),
          const SizedBox(height: 7),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 21,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }
}
