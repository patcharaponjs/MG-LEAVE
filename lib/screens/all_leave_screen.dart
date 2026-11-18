
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AllLeaveScreen extends StatefulWidget {
  const AllLeaveScreen({super.key});

  @override
  State<AllLeaveScreen> createState() => _AllLeaveScreenState();
}

class _AllLeaveScreenState extends State<AllLeaveScreen> {
  final SupabaseClient supabase = Supabase.instance.client;
  final TextEditingController searchController = TextEditingController();

  bool isLoading = true;
  String? errorMessage;
  String selectedStatus = 'ทั้งหมด';

  List<Map<String, dynamic>> leaveRequests = [];
  List<Map<String, dynamic>> employees = [];
  List<Map<String, dynamic>> leaveTypes = [];

  @override
  void initState() {
    super.initState();
    loadData();
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  Future<void> loadData() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      final results = await Future.wait([
        supabase
            .from('leave_requests')
            .select(
              'id, employee_id, leave_type_id, start_date, end_date, '
              'total_days, reason, status',
            )
            .order('start_date', ascending: false),
        supabase
            .from('employee_directory')
            .select('id, full_name'),
        supabase
            .from('leave_types')
            .select('id, leave_name')
            .order('id'),
      ]);

      if (!mounted) return;

      setState(() {
        leaveRequests =
            List<Map<String, dynamic>>.from(results[0] as List);
        employees =
            List<Map<String, dynamic>>.from(results[1] as List);
        leaveTypes =
            List<Map<String, dynamic>>.from(results[2] as List);
        isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        isLoading = false;
        errorMessage = e.toString();
      });
    }
  }

  String normalizeStatus(dynamic status) {
    return (status ?? '').toString().trim().toLowerCase();
  }

  String statusText(dynamic status) {
    switch (normalizeStatus(status)) {
      case 'approved':
      case 'อนุมัติ':
      case 'อนุมัติแล้ว':
        return 'อนุมัติแล้ว';

      case 'pending':
      case 'รออนุมัติ':
      case 'รอดำเนินการ':
        return 'รออนุมัติ';

      case 'rejected':
      case 'ไม่อนุมัติ':
      case 'ปฏิเสธ':
        return 'ไม่อนุมัติ';

      case 'cancelled':
      case 'canceled':
      case 'ยกเลิก':
        return 'ยกเลิก';

      default:
        return (status ?? 'ไม่ระบุ').toString();
    }
  }

  Color statusColor(dynamic status) {
    switch (normalizeStatus(status)) {
      case 'approved':
      case 'อนุมัติ':
      case 'อนุมัติแล้ว':
        return const Color(0xFF2EAD68);

      case 'pending':
      case 'รออนุมัติ':
      case 'รอดำเนินการ':
        return const Color(0xFFFF9800);

      case 'rejected':
      case 'ไม่อนุมัติ':
      case 'ปฏิเสธ':
        return const Color(0xFFE53935);

      case 'cancelled':
      case 'canceled':
      case 'ยกเลิก':
        return Colors.grey;

      default:
        return const Color(0xFF607D8B);
    }
  }

  String employeeName(dynamic id) {
    final employee = employees.firstWhere(
      (item) => item['id'].toString() == id.toString(),
      orElse: () => {},
    );

    return employee['full_name']?.toString() ?? 'ไม่ระบุชื่อ';
  }

  String leaveTypeName(dynamic id) {
    final type = leaveTypes.firstWhere(
      (item) => item['id'].toString() == id.toString(),
      orElse: () => {},
    );

    return type['leave_name']?.toString() ?? 'ไม่ระบุประเภท';
  }

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

  List<Map<String, dynamic>> get filteredRequests {
    final keyword = searchController.text.trim().toLowerCase();

    return leaveRequests.where((request) {
      final status = normalizeStatus(request['status']);

      if (status == 'cancelled' ||
          status == 'canceled' ||
          status == 'ยกเลิก') {
        return false;
      }

      if (selectedStatus != 'ทั้งหมด' &&
          statusText(request['status']) != selectedStatus) {
        return false;
      }

      final name = employeeName(request['employee_id']).toLowerCase();
      final type = leaveTypeName(request['leave_type_id']).toLowerCase();
      final reason = (request['reason'] ?? '').toString().toLowerCase();

      return keyword.isEmpty ||
          name.contains(keyword) ||
          type.contains(keyword) ||
          reason.contains(keyword);
    }).toList();
  }

  Widget buildSearchAndFilter() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          TextField(
            controller: searchController,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              hintText: 'ค้นหาชื่อพนักงาน ประเภทลา หรือเหตุผล',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: searchController.text.isNotEmpty
                  ? IconButton(
                      onPressed: () {
                        searchController.clear();
                        setState(() {});
                      },
                      icon: const Icon(Icons.close),
                    )
                  : null,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 12,
              ),
            ),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: selectedStatus,
            decoration: InputDecoration(
              labelText: 'กรองตามสถานะ',
              prefixIcon: const Icon(Icons.filter_list),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 12,
              ),
            ),
            items: const [
              DropdownMenuItem(
                value: 'ทั้งหมด',
                child: Text('ทุกสถานะ'),
              ),
              DropdownMenuItem(
                value: 'รออนุมัติ',
                child: Text('รออนุมัติ'),
              ),
              DropdownMenuItem(
                value: 'อนุมัติแล้ว',
                child: Text('อนุมัติแล้ว'),
              ),
              DropdownMenuItem(
                value: 'ไม่อนุมัติ',
                child: Text('ไม่อนุมัติ'),
              ),
            ],
            onChanged: (value) {
              if (value == null) return;
              setState(() {
                selectedStatus = value;
              });
            },
          ),
        ],
      ),
    );
  }

  Widget buildLeaveCard(Map<String, dynamic> request) {
    final color = statusColor(request['status']);
    final reason = (request['reason'] ?? '').toString().trim();

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 21,
                backgroundColor: const Color(0xFFE3F2FD),
                child: const Icon(
                  Icons.person,
                  color: Color(0xFF087FD0),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  employeeName(request['employee_id']),
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF142B4A),
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 9,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  statusText(request['status']),
                  style: TextStyle(
                    color: color,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const Divider(height: 22),
          buildInfoRow(
            Icons.event_note,
            'ประเภทการลา',
            leaveTypeName(request['leave_type_id']),
          ),
          buildInfoRow(
            Icons.date_range,
            'วันที่ลา',
            '${formatDate(request['start_date'])} - '
                '${formatDate(request['end_date'])}',
          ),
          buildInfoRow(
            Icons.timelapse,
            'จำนวนวัน',
            '${request['total_days'] ?? '-'} วัน',
          ),
          if (reason.isNotEmpty)
            buildInfoRow(
              Icons.description_outlined,
              'เหตุผล',
              reason,
            ),
          const SizedBox(height: 4),
          const Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Icon(
                Icons.visibility_outlined,
                size: 15,
                color: Colors.grey,
              ),
              SizedBox(width: 5),
              Text(
                'ดูข้อมูลเท่านั้น',
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            size: 17,
            color: const Color(0xFF607D8B),
          ),
          const SizedBox(width: 9),
          SizedBox(
            width: 85,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                color: Colors.black54,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xFF263238),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget buildEmptyState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(30),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      child: const Column(
        children: [
          Icon(
            Icons.event_busy,
            size: 45,
            color: Colors.black26,
          ),
          SizedBox(height: 10),
          Text(
            'ไม่พบรายการใบลา',
            style: TextStyle(
              fontSize: 14,
              color: Colors.black54,
            ),
          ),
        ],
      ),
    );
  }

  Widget buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.error_outline,
              color: Colors.red,
              size: 42,
            ),
            const SizedBox(height: 10),
            const Text(
              'ไม่สามารถโหลดข้อมูลได้',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 7),
            Text(
              errorMessage ?? '',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.grey,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: loadData,
              icon: const Icon(Icons.refresh),
              label: const Text('ลองอีกครั้ง'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final requests = filteredRequests;

    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FB),
      appBar: AppBar(
        title: const Text(
          'ใบลาทั้งหมด',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFF087FD0),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            tooltip: 'รีเฟรช',
            onPressed: loadData,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : errorMessage != null
              ? buildError()
              : RefreshIndicator(
                  onRefresh: loadData,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(15),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [
                                Color(0xFF087FD0),
                                Color(0xFF0399D1),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Row(
                            children: [
                              Icon(
                                Icons.groups_2_outlined,
                                color: Colors.white,
                                size: 35,
                              ),
                              SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'ข้อมูลการลาของพนักงาน',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    SizedBox(height: 4),
                                    Text(
                                      'สามารถดูข้อมูลได้อย่างเดียว',
                                      style: TextStyle(
                                        color: Colors.white70,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 15),
                        buildSearchAndFilter(),
                        const SizedBox(height: 15),
                        Row(
                          children: [
                            const Expanded(
                              child: Text(
                                'รายการใบลาของพนักงาน',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF142B4A),
                                ),
                              ),
                            ),
                            Text(
                              '${requests.length} รายการ',
                              style: const TextStyle(
                                color: Color(0xFF087FD0),
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        if (requests.isEmpty)
                          buildEmptyState()
                        else
                          ...requests.map(buildLeaveCard),
                        const SizedBox(height: 20),
                      ],
                    ),
                  ),
                ),
    );
  }
}
