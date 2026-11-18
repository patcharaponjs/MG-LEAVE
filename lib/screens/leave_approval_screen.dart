
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class LeaveApprovalScreen extends StatefulWidget {
  const LeaveApprovalScreen({super.key});

  @override
  State<LeaveApprovalScreen> createState() =>
      _LeaveApprovalScreenState();
}

class _LeaveApprovalScreenState extends State<LeaveApprovalScreen> {
  final SupabaseClient supabase = Supabase.instance.client;

  List<Map<String, dynamic>> requests = [];
  bool isLoading = true;
  bool isProcessing = false;
  String? errorMessage;

  final Map<String, Map<String, dynamic>> employeeMap = {};
  final Map<String, String> leaveTypeMap = {};

  @override
  void initState() {
    super.initState();
    loadRequests();
  }

  // โหลดรายการใบลาที่รออนุมัติ
  Future<void> loadRequests() async {
    if (!mounted) return;

    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      final response = await supabase
          .from('leave_requests')
          .select()
          .eq('status', 'pending')
          .order('created_at', ascending: false);

      requests = List<Map<String, dynamic>>.from(response);

      employeeMap.clear();
      leaveTypeMap.clear();

      if (requests.isNotEmpty) {
        final employeeIds = requests
            .map((e) => e['employee_id'].toString())
            .toSet()
            .toList();

        final leaveTypeIds = requests
            .map((e) => e['leave_type_id'])
            .toSet()
            .toList();

        // โหลดข้อมูลพนักงาน
        final employees = await supabase
            .from('profiles')
            .select(
              'id, full_name, employee_code, department_id, position',
            )
            .inFilter('id', employeeIds);

        for (final employee in employees) {
          employeeMap[employee['id'].toString()] =
              Map<String, dynamic>.from(employee);
        }

        // โหลดชื่อประเภทการลา
        final types = await supabase
            .from('leave_types')
            .select('id, leave_name')
            .inFilter('id', leaveTypeIds);

        for (final type in types) {
          leaveTypeMap[type['id'].toString()] =
              type['leave_name']?.toString() ?? 'ไม่ระบุประเภท';
        }
      }
    } catch (e) {
      errorMessage = e.toString();
    }

    if (mounted) {
      setState(() {
        isLoading = false;
      });
    }
  }

  // แสดงวันที่
  String formatDate(dynamic value) {
    if (value == null) return '-';

    try {
      final date = DateTime.parse(value.toString());

      return '${date.day.toString().padLeft(2, '0')}/'
          '${date.month.toString().padLeft(2, '0')}/'
          '${date.year + 543}';
    } catch (_) {
      return value.toString();
    }
  }

  // แปลงจำนวนวัน
  String formatDays(dynamic value) {
    if (value == null) return '0';

    final number = double.tryParse(value.toString()) ?? 0;

    if (number == number.roundToDouble()) {
      return number.toInt().toString();
    }

    return number.toStringAsFixed(1);
  }

  // แสดงรายละเอียดใบลา
  void showRequestDetail(Map<String, dynamic> request) {
    final employee = employeeMap[
        request['employee_id'].toString()];

    final employeeName =
        employee?['full_name']?.toString() ?? 'ไม่พบข้อมูลพนักงาน';

    final employeeCode =
        employee?['employee_code']?.toString() ?? '-';

    final leaveName =
        leaveTypeMap[request['leave_type_id'].toString()] ??
            'ไม่ระบุประเภทการลา';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(22),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(
              top: Radius.circular(24),
            ),
          ),
          child: SafeArea(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 45,
                      height: 5,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  const SizedBox(height: 22),
                  const Text(
                    'รายละเอียดใบลา',
                    style: TextStyle(
                      fontSize: 21,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 20),
                  detailRow('ชื่อพนักงาน', employeeName),
                  detailRow('รหัสพนักงาน', employeeCode),
                  detailRow('ประเภทการลา', leaveName),
                  detailRow(
                    'วันที่เริ่มลา',
                    formatDate(request['start_date']),
                  ),
                  detailRow(
                    'วันที่สิ้นสุด',
                    formatDate(request['end_date']),
                  ),
                  detailRow(
                    'จำนวนวัน',
                    '${formatDays(request['total_days'])} วัน',
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'เหตุผลในการลา',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF4F6FA),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      request['reason']?.toString() ?? '-',
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: isProcessing
                              ? null
                              : () {
                                  Navigator.pop(context);
                                  processApproval(request, false);
                                },
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.red,
                            padding: const EdgeInsets.symmetric(
                              vertical: 13,
                            ),
                          ),
                          child: const Text('ไม่อนุมัติ'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: isProcessing
                              ? null
                              : () {
                                  Navigator.pop(context);
                                  processApproval(request, true);
                                },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF16865C),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              vertical: 13,
                            ),
                          ),
                          child: const Text('อนุมัติ'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget detailRow(String title, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 13),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 115,
            child: Text(
              title,
              style: const TextStyle(color: Colors.grey),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // อนุมัติหรือไม่อนุมัติผ่าน Supabase RPC
  Future<void> processApproval(
    Map<String, dynamic> request,
    bool approved,
  ) async {
    final user = supabase.auth.currentUser;

    if (user == null) {
      showMessage('กรุณาเข้าสู่ระบบก่อน', Colors.red);
      return;
    }

    if (isProcessing) return;

    String comment = 'อนุมัติใบลา';

    // ถ้าไม่อนุมัติ ต้องระบุเหตุผล
    if (!approved) {
      final commentController = TextEditingController();

      final result = await showDialog<String>(
        context: context,
        builder: (dialogContext) {
          return AlertDialog(
            title: const Text('ระบุเหตุผลที่ไม่อนุมัติ'),
            content: TextField(
              controller: commentController,
              maxLines: 3,
              decoration: const InputDecoration(
                hintText: 'กรุณาระบุเหตุผล',
                border: OutlineInputBorder(),
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
                  if (commentController.text.trim().isEmpty) {
                    return;
                  }

                  Navigator.pop(
                    dialogContext,
                    commentController.text.trim(),
                  );
                },
                child: const Text('ยืนยัน'),
              ),
            ],
          );
        },
      );

      commentController.dispose();

      if (result == null || result.trim().isEmpty) {
        return;
      }

      comment = result.trim();
    }

    if (!mounted) return;

    setState(() {
      isProcessing = true;
    });

    try {
      final requestId = request['id'];

      // เรียกใช้ PostgreSQL Function
      // ฟังก์ชันจะจัดการเปลี่ยนสถานะ
      // บันทึกประวัติ และตัดสิทธิ์วันลาแบบ Transaction
      final response = await supabase.rpc(
        'approve_leave_request',
        params: {
          'p_leave_request_id': requestId,
          'p_action': approved ? 'approved' : 'rejected',
          'p_comment': comment,
        },
      );

      if (!mounted) return;

      final result = Map<String, dynamic>.from(response);

      if (result['success'] == true) {
        showMessage(
          result['message']?.toString() ??
              (approved
                  ? 'อนุมัติใบลาเรียบร้อยแล้ว'
                  : 'ไม่อนุมัติใบลาเรียบร้อยแล้ว'),
          approved ? Colors.green : Colors.orange,
        );

        await loadRequests();
      } else {
        showMessage(
          result['message']?.toString() ??
              'ไม่สามารถดำเนินการได้',
          Colors.red,
        );
      }
    } catch (e) {
      if (!mounted) return;

      showMessage(
        'ไม่สามารถบันทึกผลการพิจารณาได้: $e',
        Colors.red,
      );
    } finally {
      if (mounted) {
        setState(() {
          isProcessing = false;
        });
      }
    }
  }

  void showMessage(String message, Color color) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        duration: const Duration(seconds: 4),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FA),
      appBar: AppBar(
        title: const Text(
          'อนุมัติใบลา',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFF1769AA),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            onPressed: isLoading ? null : loadRequests,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: isLoading
          ? const Center(
              child: CircularProgressIndicator(),
            )
          : errorMessage != null
              ? _buildError()
              : RefreshIndicator(
                  onRefresh: loadRequests,
                  child: requests.isEmpty
                      ? _buildEmpty()
                      : _buildRequestList(),
                ),
    );
  }

  Widget _buildRequestList() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: const Color(0xFFE6F1FC),
            borderRadius: BorderRadius.circular(15),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.pending_actions,
                color: Color(0xFF1769AA),
                size: 35,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'ใบลารออนุมัติ',
                      style: TextStyle(
                        color: Color(0xFF1769AA),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      '${requests.length} รายการ',
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1769AA),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        ...requests.map((request) => _buildRequestCard(request)),
      ],
    );
  }

  Widget _buildRequestCard(Map<String, dynamic> request) {
    final employee = employeeMap[
        request['employee_id'].toString()];

    final employeeName =
        employee?['full_name']?.toString() ?? 'ไม่พบข้อมูลพนักงาน';

    final employeeCode =
        employee?['employee_code']?.toString() ?? '-';

    final leaveName =
        leaveTypeMap[request['leave_type_id'].toString()] ??
            'ไม่ระบุประเภทการลา';

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundColor: const Color(0xFFE6F1FC),
                child: Text(
                  employeeName.isNotEmpty
                      ? employeeName[0]
                      : '?',
                  style: const TextStyle(
                    color: Color(0xFF1769AA),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      employeeName,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    Text(
                      'รหัสพนักงาน: $employeeCode',
                      style: const TextStyle(
                        color: Colors.grey,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  'รออนุมัติ',
                  style: TextStyle(
                    color: Colors.orange,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const Divider(height: 25),
          Text(
            leaveName,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1769AA),
            ),
          ),
          const SizedBox(height: 10),
          _infoRow(
            Icons.calendar_today,
            '${formatDate(request['start_date'])} - '
            '${formatDate(request['end_date'])}',
          ),
          const SizedBox(height: 7),
          _infoRow(
            Icons.timelapse,
            '${formatDays(request['total_days'])} วัน',
          ),
          const SizedBox(height: 7),
          _infoRow(
            Icons.description_outlined,
            request['reason']?.toString() ?? '-',
          ),
          const SizedBox(height: 15),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: isProcessing
                  ? null
                  : () => showRequestDetail(request),
              icon: const Icon(Icons.visibility_outlined),
              label: const Text('ดูรายละเอียดและพิจารณา'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1769AA),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoRow(IconData icon, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          icon,
          size: 17,
          color: Colors.grey,
        ),
        const SizedBox(width: 9),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              color: Color(0xFF536273),
              fontSize: 13,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEmpty() {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        const SizedBox(height: 130),
        Icon(
          Icons.task_alt,
          size: 75,
          color: Colors.grey.shade400,
        ),
        const SizedBox(height: 20),
        const Center(
          child: Text(
            'ไม่มีใบลาที่รออนุมัติ',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(height: 8),
        const Center(
          child: Text(
            'เมื่อมีพนักงานยื่นใบลา รายการจะแสดงที่นี่',
            style: TextStyle(color: Colors.grey),
          ),
        ),
      ],
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.error_outline,
              size: 55,
              color: Colors.red,
            ),
            const SizedBox(height: 12),
            const Text(
              'ไม่สามารถโหลดรายการใบลาได้',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 17,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              errorMessage ?? '',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 15),
            ElevatedButton.icon(
              onPressed: loadRequests,
              icon: const Icon(Icons.refresh),
              label: const Text('ลองอีกครั้ง'),
            ),
          ],
        ),
      ),
    );
  }
}
