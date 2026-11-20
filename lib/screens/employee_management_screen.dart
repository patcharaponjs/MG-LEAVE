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

  // โหลดข้อมูลบุคลากร
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

  // แสดงเฉพาะบัญชีที่เปิดใช้งาน
  void filterEmployees() {
    final keyword = searchText.toLowerCase().trim();

    filteredEmployees = employees.where((employee) {
      if (employee['is_active'] != true) {
        return false;
      }

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

  // ค้นหาชื่อแผนก
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

  // เพิ่มพนักงาน
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

  // แก้ไขข้อมูลพนักงาน
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

  // ปิดบัญชี หรือ เปิดบัญชีกลับ
  // เก็บข้อมูลพนักงานและประวัติไว้
  Future<void> changeEmployeeStatus(
    Map<String, dynamic> employee,
    bool newStatus,
  ) async {
    final id = employee['id']?.toString();
    final name = employee['full_name']?.toString() ?? 'พนักงาน';

    if (id == null || id.isEmpty) return;

    final currentUserId = supabase.auth.currentUser?.id;

    // ห้ามปิดบัญชีตัวเอง
    if (currentUserId == id && !newStatus) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('ไม่สามารถปิดบัญชีที่กำลังเข้าสู่ระบบได้'),
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
          title: Row(
            children: [
              Icon(
                newStatus ? Icons.person_add_alt_1 : Icons.person_off,
                color: newStatus ? Colors.green : Colors.orange,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  newStatus ? 'เปิดบัญชีอีกครั้ง' : 'ปิดบัญชีพนักงาน',
                ),
              ),
            ],
          ),
          content: Text(
            newStatus
                ? 'ต้องการเปิดบัญชี "$name" กลับมาใช้งานอีกครั้งหรือไม่?'
                : 'ต้องการปิดบัญชี "$name" หรือไม่?\n\n'
                    'ข้อมูลพนักงาน ประวัติการลา และ OT จะยังคงอยู่ '
                    'และสามารถเปิดบัญชีนี้กลับมาได้ภายหลัง',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('ยกเลิก'),
            ),
            ElevatedButton.icon(
              onPressed: () => Navigator.pop(dialogContext, true),
              icon: Icon(
                newStatus ? Icons.check_circle : Icons.person_off,
              ),
              label: Text(newStatus ? 'เปิดบัญชี' : 'ปิดบัญชี'),
              style: ElevatedButton.styleFrom(
                backgroundColor: newStatus ? Colors.green : Colors.orange,
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
          .update({'is_active': newStatus})
          .eq('id', id);

      await loadEmployees();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            newStatus
                ? 'เปิดบัญชี "$name" เรียบร้อยแล้ว'
                : 'ปิดบัญชี "$name" เรียบร้อยแล้ว',
          ),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      debugPrint('CHANGE STATUS ERROR: $e');

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('เปลี่ยนสถานะบัญชีไม่สำเร็จ: $e'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 10),
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

  // ลบข้อมูลพนักงานจริงจาก profiles
  Future<void> deleteEmployeePermanently(
    Map<String, dynamic> employee,
  ) async {
    final id = employee['id']?.toString();
    final name = employee['full_name']?.toString() ?? 'พนักงาน';

    if (id == null || id.isEmpty) return;

    final currentUserId = supabase.auth.currentUser?.id;

    // ห้ามลบบัญชีที่กำลังเข้าสู่ระบบ
    if (currentUserId == id) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('ไม่สามารถลบข้อมูลบัญชีที่กำลังเข้าสู่ระบบได้'),
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
              Icon(Icons.delete_forever, color: Colors.red),
              SizedBox(width: 10),
              Expanded(
                child: Text('ลบข้อมูลพนักงานจริง'),
              ),
            ],
          ),
          content: Text(
            'คุณกำลังลบข้อมูล "$name" ออกจากตาราง profiles\n\n'
            'การดำเนินการนี้ไม่ใช่การปิดบัญชี '
            'ข้อมูลโปรไฟล์จะถูกลบออกจากตาราง profiles จริง '
            'และไม่สามารถเปิดใช้งานจากหน้ารายการปิดบัญชีได้อีก\n\n'
            'หากมีประวัติการลา OT หรือข้อมูลอื่นเชื่อมโยงอยู่ '
            'ระบบฐานข้อมูลอาจปฏิเสธการลบ\n\n'
            'ต้องการดำเนินการต่อหรือไม่?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('ยกเลิก'),
            ),
            ElevatedButton.icon(
              onPressed: () => Navigator.pop(dialogContext, true),
              icon: const Icon(Icons.delete_forever),
              label: const Text('ลบข้อมูลจริง'),
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
      // ลบเฉพาะข้อมูลโปรไฟล์ของพนักงานที่เลือก
      await supabase
          .from('profiles')
          .delete()
          .eq('id', id);

      await loadEmployees();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('ลบข้อมูล "$name" จาก profiles แล้ว'),
          backgroundColor: Colors.green,
        ),
      );
    } on PostgrestException catch (e) {
      // แสดงข้อความ Error จริงจาก Supabase
      debugPrint('DELETE EMPLOYEE POSTGRES ERROR: ${e.message}');
      debugPrint('DELETE EMPLOYEE CODE: ${e.code}');
      debugPrint('DELETE EMPLOYEE DETAILS: ${e.details}');
      debugPrint('DELETE EMPLOYEE HINT: ${e.hint}');

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'ลบไม่สำเร็จ\n'
            'ข้อความ: ${e.message}\n'
            'รหัส: ${e.code ?? "-"}\n'
            'รายละเอียด: ${e.details ?? "-"}\n'
            'คำแนะนำ: ${e.hint ?? "-"}',
          ),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 15),
        ),
      );
    } catch (e) {
      debugPrint('DELETE EMPLOYEE ERROR: $e');

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('ลบไม่สำเร็จ: $e'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 15),
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

  // เปิดหน้าต่างดูบัญชีที่ปิดใช้งาน
  Future<void> showInactiveEmployees() async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, dialogSetState) {
            final currentInactive = employees
                .where((e) => e['is_active'] != true)
                .toList();

            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
              title: Row(
                children: [
                  const Icon(
                    Icons.person_off,
                    color: Colors.orange,
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text('บัญชีที่ปิดใช้งาน'),
                  ),
                  Text(
                    '${currentInactive.length}',
                    style: const TextStyle(
                      color: Colors.orange,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              content: SizedBox(
                width: 500,
                height: 450,
                child: currentInactive.isEmpty
                    ? const Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.check_circle_outline,
                              size: 60,
                              color: Colors.green,
                            ),
                            SizedBox(height: 12),
                            Text('ไม่มีบัญชีที่ปิดใช้งาน'),
                          ],
                        ),
                      )
                    : ListView.builder(
                        itemCount: currentInactive.length,
                        itemBuilder: (context, index) {
                          final employee = currentInactive[index];

                          final id =
                              employee['id']?.toString() ?? '';

                          final name =
                              employee['full_name']?.toString() ??
                                  'ไม่ระบุชื่อ';

                          final code =
                              employee['employee_code']?.toString() ??
                                  '-';

                          final isBusy = deletingIds.contains(id);

                          return Card(
                            color: Colors.orange.shade50,
                            margin: const EdgeInsets.only(bottom: 10),
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    name,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text('รหัสพนักงาน: $code'),
                                  const SizedBox(height: 4),
                                  Text(
                                    getDepartmentName(
                                      employee['department_id'],
                                    ),
                                  ),
                                  const SizedBox(height: 10),

                                  // เปิดบัญชีกลับ
                                  SizedBox(
                                    width: double.infinity,
                                    child: ElevatedButton.icon(
                                      onPressed: isBusy
                                          ? null
                                          : () async {
                                              await changeEmployeeStatus(
                                                employee,
                                                true,
                                              );

                                              dialogSetState(() {});
                                            },
                                      icon: const Icon(
                                        Icons.person_add_alt_1,
                                      ),
                                      label: const Text(
                                        'เปิดใช้งานบัญชีนี้',
                                      ),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.green,
                                        foregroundColor: Colors.white,
                                      ),
                                    ),
                                  ),

                                  const SizedBox(height: 6),

                                  // ลบข้อมูลจริง
                                  SizedBox(
                                    width: double.infinity,
                                    child: OutlinedButton.icon(
                                      onPressed: isBusy
                                          ? null
                                          : () async {
                                              await deleteEmployeePermanently(
                                                employee,
                                              );

                                              dialogSetState(() {});
                                            },
                                      icon: isBusy
                                          ? const SizedBox(
                                              width: 16,
                                              height: 16,
                                              child:
                                                  CircularProgressIndicator(
                                                strokeWidth: 2,
                                              ),
                                            )
                                          : const Icon(
                                              Icons.delete_forever,
                                            ),
                                      label: const Text(
                                        'ลบข้อมูลพนักงานจริง',
                                      ),
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: Colors.red,
                                        side: const BorderSide(
                                          color: Colors.red,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('ปิด'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // นับจำนวนบัญชีที่เปิดใช้งาน
    final activeCount =
        employees.where((e) => e['is_active'] == true).length;

    // นับบัญชีที่ปิดใช้งาน
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
          // ดูบัญชีที่ปิดใช้งาน
          IconButton(
            onPressed: showInactiveEmployees,
            icon: const Icon(Icons.manage_accounts),
            tooltip: 'จัดการบัญชีที่ปิดใช้งาน',
          ),

          // โหลดใหม่
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
          // สรุปข้อมูล
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
                        activeCount.toString(),
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
                const SizedBox(height: 12),

                // ปุ่มดูบัญชีที่ปิดใช้งาน
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: showInactiveEmployees,
                    icon: const Icon(Icons.manage_accounts),
                    label: Text(
                      'จัดการบัญชีที่ปิดใช้งาน ($inactiveCount)',
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: const BorderSide(
                        color: Colors.white,
                      ),
                    ),
                  ),
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

          // รายชื่อพนักงานที่เปิดใช้งาน
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
                              activeCount == 0
                                  ? 'ยังไม่มีพนักงานที่ใช้งานอยู่'
                                  : 'ไม่พบข้อมูลที่ค้นหา',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.grey.shade600,
                              ),
                            ),
                            const SizedBox(height: 8),
                            if (activeCount == 0)
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
                                (employee['full_name'] ??
                                        'ไม่ระบุชื่อ')
                                    .toString();

                            final employeeCode =
                                (employee['employee_code'] ?? '-')
                                    .toString();

                            final phone =
                                (employee['phone'] ??
                                        'ยังไม่ได้ระบุเบอร์โทรศัพท์')
                                    .toString();

                            final position =
                                (employee['position'] ??
                                        'ไม่ระบุตำแหน่ง')
                                    .toString();

                            final departmentName =
                                getDepartmentName(
                              employee['department_id'],
                            );

                            final employeeId =
                                employee['id']?.toString() ?? '';

                            final isBusy =
                                deletingIds.contains(employeeId);

                            final firstLetter =
                                fullName.trim().isNotEmpty
                                    ? fullName.trim().substring(0, 1)
                                    : '?';

                            return Card(
                              elevation: 1,
                              color: Colors.white,
                              margin: const EdgeInsets.only(
                                bottom: 12,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius:
                                    BorderRadius.circular(16),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(15),
                                child: Row(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
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
                                          fontWeight:
                                              FontWeight.bold,
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
                                              fontWeight:
                                                  FontWeight.bold,
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

                                          // สถานะบัญชี
                                          Container(
                                            padding:
                                                const EdgeInsets.symmetric(
                                              horizontal: 10,
                                              vertical: 4,
                                            ),
                                            decoration: BoxDecoration(
                                              color: Colors.green.shade50,
                                              borderRadius:
                                                  BorderRadius.circular(
                                                20,
                                              ),
                                            ),
                                            child: Text(
                                              'กำลังปฏิบัติงาน',
                                              style: TextStyle(
                                                color: Colors.green.shade700,
                                                fontSize: 11,
                                                fontWeight:
                                                    FontWeight.bold,
                                              ),
                                            ),
                                          ),

                                          const SizedBox(height: 10),

                                          // แก้ไขข้อมูล
                                          SizedBox(
                                            width: double.infinity,
                                            child: OutlinedButton.icon(
                                              onPressed: isBusy
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
                                                      BorderRadius.circular(
                                                    10,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),

                                          const SizedBox(height: 8),

                                          // ปิดบัญชี - เก็บข้อมูลไว้
                                          SizedBox(
                                            width: double.infinity,
                                            child: OutlinedButton.icon(
                                              onPressed: isBusy
                                                  ? null
                                                  : () =>
                                                      changeEmployeeStatus(
                                                        employee,
                                                        false,
                                                      ),
                                              icon: isBusy
                                                  ? const SizedBox(
                                                      width: 16,
                                                      height: 16,
                                                      child:
                                                          CircularProgressIndicator(
                                                        strokeWidth: 2,
                                                      ),
                                                    )
                                                  : const Icon(
                                                      Icons.person_off,
                                                      size: 18,
                                                    ),
                                              label: Text(
                                                isBusy
                                                    ? 'กำลังดำเนินการ'
                                                    : 'ปิดบัญชี (เก็บข้อมูลไว้)',
                                              ),
                                              style: OutlinedButton
                                                  .styleFrom(
                                                foregroundColor:
                                                    Colors.orange.shade800,
                                                side: BorderSide(
                                                  color:
                                                      Colors.orange.shade700,
                                                ),
                                                shape:
                                                    RoundedRectangleBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(
                                                    10,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),

                                          const SizedBox(height: 8),

                                          // ลบข้อมูลพนักงานจริง
                                          SizedBox(
                                            width: double.infinity,
                                            child: OutlinedButton.icon(
                                              onPressed: isBusy
                                                  ? null
                                                  : () =>
                                                      deleteEmployeePermanently(
                                                        employee,
                                                      ),
                                              icon: const Icon(
                                                Icons.delete_forever,
                                                size: 18,
                                              ),
                                              label: const Text(
                                                'ลบข้อมูลพนักงานจริง',
                                              ),
                                              style: OutlinedButton
                                                  .styleFrom(
                                                foregroundColor: Colors.red,
                                                side: const BorderSide(
                                                  color: Colors.red,
                                                ),
                                                shape:
                                                    RoundedRectangleBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(
                                                    10,
                                                  ),
                                                ),
                                              ),
                                            ),
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