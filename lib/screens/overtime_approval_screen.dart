
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class OvertimeApprovalScreen extends StatefulWidget {
  const OvertimeApprovalScreen({super.key});

  @override
  State<OvertimeApprovalScreen> createState() =>
      _OvertimeApprovalScreenState();
}

class _OvertimeApprovalScreenState
    extends State<OvertimeApprovalScreen> {
  final SupabaseClient supabase = Supabase.instance.client;

  bool isLoading = true;
  bool isDeleting = false;
  String selectedStatus = 'pending';

  List<Map<String, dynamic>> requests = [];
  Map<String, Map<String, dynamic>> employees = {};

  @override
  void initState() {
    super.initState();
    loadRequests();
  }

  // โหลดข้อมูลคำขอ OT
  Future<void> loadRequests() async {
    if (!mounted) return;

    setState(() => isLoading = true);

    try {
      final data = await supabase
          .from('overtime_requests')
          .select()
          .order('created_at', ascending: false);

      final rows = List<Map<String, dynamic>>.from(data);

      final userIds = rows
          .map((e) => e['user_id'].toString())
          .toSet()
          .toList();

      Map<String, Map<String, dynamic>> employeeMap = {};

      if (userIds.isNotEmpty) {
        final profileData = await supabase
            .from('profiles')
            .select('id, full_name, employee_code, position')
            .inFilter('id', userIds);

        for (final profile in profileData) {
          employeeMap[profile['id'].toString()] =
              Map<String, dynamic>.from(profile);
        }
      }

      if (!mounted) return;

      setState(() {
        requests = rows;
        employees = employeeMap;
        isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() => isLoading = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('โหลดคำขอ OT ไม่สำเร็จ: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // รายการตามสถานะที่เลือก
  List<Map<String, dynamic>> get filteredRequests {
    return requests.where((item) {
      return (item['status']?.toString() ?? 'pending') ==
          selectedStatus;
    }).toList();
  }

  // ชื่อสถานะ
  String getStatusName(String status) {
    switch (status) {
      case 'pending':
        return 'รออนุมัติ';
      case 'approved':
        return 'อนุมัติแล้ว';
      case 'rejected':
        return 'ไม่อนุมัติ';
      default:
        return status;
    }
  }

  // ล้างข้อมูลคำขอ OT ตามสถานะที่เลือก
  Future<void> clearRequestsByStatus() async {
    if (isDeleting) return;

    final count = requests
        .where((item) =>
            item['status']?.toString() == selectedStatus)
        .length;

    if (count == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('ไม่มีข้อมูลให้ล้าง'),
        ),
      );
      return;
    }

    final statusName = getStatusName(selectedStatus);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Row(
            children: [
              Icon(
                Icons.delete_forever,
                color: Colors.red,
              ),
              SizedBox(width: 10),
              Expanded(
                child: Text('ยืนยันล้างข้อมูล OT'),
              ),
            ],
          ),
          content: Text(
            'คุณต้องการลบคำขอ OT สถานะ "$statusName" '
            'ทั้งหมดจำนวน $count รายการใช่หรือไม่?\n\n'
            'ข้อมูลที่ลบจะไม่สามารถกู้คืนจากหน้านี้ได้',
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
              icon: const Icon(Icons.delete_forever),
              label: const Text('ล้างข้อมูล'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) return;

    setState(() {
      isDeleting = true;
    });

    try {
      // ลบเฉพาะรายการในสถานะที่เลือก
      final deletedData = await supabase
          .from('overtime_requests')
          .delete()
          .eq('status', selectedStatus)
          .select('id');

      final deletedCount = deletedData.length;

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'ลบข้อมูล OT "$statusName" '
            'เรียบร้อยแล้ว $deletedCount รายการ',
          ),
          backgroundColor: Colors.green,
        ),
      );

      await loadRequests();
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('ล้างข้อมูลไม่สำเร็จ: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          isDeleting = false;
        });
      }
    }
  }

  // แปลงวันที่
  String formatDate(dynamic value) {
    if (value == null) return '-';

    final date = DateTime.tryParse(value.toString());
    if (date == null) return value.toString();

    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/'
        '${date.year + 543}';
  }

  // แปลงเวลา
  String formatTime(dynamic value) {
    if (value == null) return '-';

    final time = value.toString();
    return time.length >= 5 ? time.substring(0, 5) : time;
  }

  // อนุมัติ / ไม่อนุมัติคำขอ
  Future<void> updateRequest({
    required Map<String, dynamic> item,
    required String status,
    String? rejectionReason,
  }) async {
    try {
      final user = supabase.auth.currentUser;

      if (user == null) {
        throw Exception('ไม่พบข้อมูลผู้ใช้งาน');
      }

      if (status != 'approved' && status != 'rejected') {
        throw Exception('สถานะคำขอไม่ถูกต้อง');
      }

      if (status == 'rejected' &&
          (rejectionReason == null ||
              rejectionReason.trim().isEmpty)) {
        throw Exception('กรุณาระบุเหตุผลที่ไม่อนุมัติ');
      }

      final now = DateTime.now().toUtc().toIso8601String();

      // อัปเดตเฉพาะคำขอที่ยังรออนุมัติ
      final result = await supabase
          .from('overtime_requests')
          .update({
            'status': status,
            'approved_by': user.id,
            'approved_at': now,
            'rejection_reason':
                status == 'rejected'
                    ? rejectionReason!.trim()
                    : null,
            'updated_at': now,
          })
          .eq('id', item['id'])
          .eq('status', 'pending')
          .select()
          .maybeSingle();

      if (result == null) {
        throw Exception(
          'ไม่พบคำขอที่รออนุมัติ อาจมีผู้พิจารณารายการนี้ไปแล้ว กรุณารีเฟรช',
        );
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            status == 'approved'
                ? 'อนุมัติคำขอ OT เรียบร้อยแล้ว'
                : 'ไม่อนุมัติคำขอ OT เรียบร้อยแล้ว',
          ),
          backgroundColor:
              status == 'approved'
                  ? Colors.green
                  : Colors.orange,
        ),
      );

      await loadRequests();
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('ดำเนินการไม่สำเร็จ: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // ปฏิเสธคำขอ OT
  Future<void> rejectRequest(
      Map<String, dynamic> item) async {
    final controller = TextEditingController();

    final reason = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('ไม่อนุมัติคำขอ OT'),
          content: TextField(
            controller: controller,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'เหตุผลที่ไม่อนุมัติ',
              hintText: 'กรุณาระบุเหตุผล',
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () =>
                  Navigator.pop(dialogContext),
              child: const Text('ยกเลิก'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              onPressed: () {
                if (controller.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'กรุณาระบุเหตุผลที่ไม่อนุมัติ',
                      ),
                    ),
                  );
                  return;
                }

                Navigator.pop(
                  dialogContext,
                  controller.text.trim(),
                );
              },
              child: const Text('ยืนยันไม่อนุมัติ'),
            ),
          ],
        );
      },
    );

    controller.dispose();

    if (reason == null || reason.isEmpty) return;

    await updateRequest(
      item: item,
      status: 'rejected',
      rejectionReason: reason,
    );
  }

  // ยืนยันการอนุมัติ
  Future<void> confirmApproval(
      Map<String, dynamic> item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('ยืนยันการอนุมัติ'),
          content: const Text(
            'ต้องการอนุมัติคำขอ OT นี้ใช่หรือไม่?',
          ),
          actions: [
            TextButton(
              onPressed: () =>
                  Navigator.pop(dialogContext, false),
              child: const Text('ยกเลิก'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
              ),
              onPressed: () =>
                  Navigator.pop(dialogContext, true),
              child: const Text('อนุมัติ'),
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      await updateRequest(
        item: item,
        status: 'approved',
      );
    }
  }

  // การ์ดคำขอ OT
  Widget buildRequestCard(Map<String, dynamic> item) {
    final userId = item['user_id'].toString();
    final employee = employees[userId];

    final name =
        employee?['full_name']?.toString() ??
            'ไม่พบชื่อพนักงาน';
    final code =
        employee?['employee_code']?.toString() ?? '-';
    final position =
        employee?['position']?.toString() ?? '-';

    final status = item['status']?.toString() ?? 'pending';

    return Card(
      margin: const EdgeInsets.only(bottom: 13),
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const CircleAvatar(
                  backgroundColor: Color(0xFFE3F2FD),
                  child: Icon(
                    Icons.person,
                    color: Color(0xFF087FD0),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
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
                      Text(
                        'รหัสพนักงาน: $code',
                        style: const TextStyle(
                          color: Colors.grey,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                if (status == 'pending')
                  const Chip(
                    label: Text('รออนุมัติ'),
                    backgroundColor: Color(0xFFFFF3E0),
                    labelStyle:
                        TextStyle(color: Colors.orange),
                  )
                else if (status == 'approved')
                  const Chip(
                    label: Text('อนุมัติแล้ว'),
                    backgroundColor: Color(0xFFE8F5E9),
                    labelStyle:
                        TextStyle(color: Colors.green),
                  )
                else
                  const Chip(
                    label: Text('ไม่อนุมัติ'),
                    backgroundColor: Color(0xFFFFEBEE),
                    labelStyle:
                        TextStyle(color: Colors.red),
                  ),
              ],
            ),
            const Divider(height: 25),
            Text('ตำแหน่ง: $position'),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.calendar_month, size: 18),
                const SizedBox(width: 8),
                Text(formatDate(item['work_date'])),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.access_time, size: 18),
                const SizedBox(width: 8),
                Text(
                  '${formatTime(item['start_time'])} - '
                  '${formatTime(item['end_time'])} น.',
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.timelapse, size: 18),
                const SizedBox(width: 8),
                Text(
                  'รวม ${item['total_hours'] ?? '-'} ชั่วโมง',
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Text(
              'เหตุผลในการขอ OT',
              style: TextStyle(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 5),
            Text(item['reason']?.toString() ?? '-'),

            if (status == 'rejected' &&
                item['rejection_reason'] != null) ...[
              const SizedBox(height: 12),
              Text(
                'เหตุผลที่ไม่อนุมัติ: '
                '${item['rejection_reason']}',
                style: const TextStyle(color: Colors.red),
              ),
            ],

            if (status == 'pending') ...[
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => rejectRequest(item),
                      icon: const Icon(Icons.close),
                      label: const Text('ไม่อนุมัติ'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () =>
                          confirmApproval(item),
                      icon: const Icon(Icons.check),
                      label: const Text('อนุมัติ'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  // แท็บสถานะ
  Widget buildStatusTab(String value, String label) {
    final count = requests
        .where(
          (item) => item['status']?.toString() == value,
        )
        .length;

    return ChoiceChip(
      label: Text('$label ($count)'),
      selected: selectedStatus == value,
      onSelected: (_) {
        setState(() => selectedStatus = value);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentCount = requests
        .where((item) =>
            item['status']?.toString() == selectedStatus)
        .length;

    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FB),
      appBar: AppBar(
        title: const Text('อนุมัติคำขอ OT'),
        backgroundColor: const Color(0xFF087FD0),
        foregroundColor: Colors.white,
        actions: [
          // ปุ่มล้างข้อมูลตามแท็บ
          IconButton(
            onPressed:
                isDeleting || currentCount == 0
                    ? null
                    : clearRequestsByStatus,
            icon: isDeleting
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.delete_sweep),
            tooltip: 'ล้างข้อมูลตามสถานะที่เลือก',
          ),

          // ปุ่มรีเฟรช
          IconButton(
            onPressed: isDeleting ? null : loadRequests,
            icon: const Icon(Icons.refresh),
            tooltip: 'รีเฟรช',
          ),
        ],
      ),
      body: isLoading
          ? const Center(
              child: CircularProgressIndicator(),
            )
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      buildStatusTab(
                        'pending',
                        'รออนุมัติ',
                      ),
                      buildStatusTab(
                        'approved',
                        'อนุมัติแล้ว',
                      ),
                      buildStatusTab(
                        'rejected',
                        'ไม่อนุมัติ',
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: filteredRequests.isEmpty
                      ? const Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.inbox_outlined,
                                size: 60,
                                color: Colors.grey,
                              ),
                              SizedBox(height: 12),
                              Text(
                                'ไม่มีคำขอ OT ในรายการนี้',
                                style: TextStyle(
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ),
                        )
                      : RefreshIndicator(
                          onRefresh: loadRequests,
                          child: ListView.builder(
                            padding: const EdgeInsets.all(16),
                            itemCount: filteredRequests.length,
                            itemBuilder: (context, index) {
                              return buildRequestCard(
                                filteredRequests[index],
                              );
                            },
                          ),
                        ),
                ),
              ],
            ),
    );
  }
}
