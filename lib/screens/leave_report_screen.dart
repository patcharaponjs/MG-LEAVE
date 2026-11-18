
import 'dart:typed_data';
import 'dart:html' as html;

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:excel/excel.dart';

class LeaveReportScreen extends StatefulWidget {
  const LeaveReportScreen({super.key});

  @override
  State<LeaveReportScreen> createState() => _LeaveReportScreenState();
}

class _LeaveReportScreenState extends State<LeaveReportScreen> {
  final SupabaseClient supabase = Supabase.instance.client;

  bool isLoading = true;
  bool isExporting = false;
  String? errorMessage;

  int selectedYear = DateTime.now().year;

  List<Map<String, dynamic>> allRequests = [];
  List<Map<String, dynamic>> departments = [];

  Map<int, String> leaveTypeNames = {};
  Map<String, String> employeeDepartments = {};
  Map<String, String> employeeNames = {};
  Map<String, String> employeeCodes = {};

  @override
  void initState() {
    super.initState();
    loadReport();
  }

  Future<void> loadReport() async {
    if (!mounted) return;

    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      final requestsResponse = await supabase
          .from('leave_requests')
          .select(
            'id, employee_id, leave_type_id, start_date, '
            'end_date, total_days, reason, status, created_at',
          )
          .order('created_at', ascending: false);

      final requests =
          List<Map<String, dynamic>>.from(requestsResponse);

      final typesResponse = await supabase
          .from('leave_types')
          .select('id, leave_name');

      final Map<int, String> types = {};

      for (final type in typesResponse) {
        final id = (type['id'] as num).toInt();
        types[id] = type['leave_name']?.toString() ?? '-';
      }

      final departmentsResponse = await supabase
          .from('departments')
          .select('id, department_name');

      final departmentList =
          List<Map<String, dynamic>>.from(departmentsResponse);

      final Map<String, String> departmentNames = {};

      for (final department in departmentList) {
        departmentNames[department['id'].toString()] =
            department['department_name']?.toString() ?? '-';
      }

      final profilesResponse = await supabase
          .from('profiles')
          .select('id, employee_code, full_name, department_id');

      final Map<String, String> departmentMap = {};
      final Map<String, String> nameMap = {};
      final Map<String, String> codeMap = {};

      for (final profile in profilesResponse) {
        final employeeId = profile['id']?.toString();
        final departmentId = profile['department_id']?.toString();

        if (employeeId != null) {
          departmentMap[employeeId] =
              departmentNames[departmentId] ?? 'ไม่ระบุแผนก';
          nameMap[employeeId] =
              profile['full_name']?.toString() ?? '-';
          codeMap[employeeId] =
              profile['employee_code']?.toString() ?? '-';
        }
      }

      if (!mounted) return;

      setState(() {
        allRequests = requests;
        leaveTypeNames = types;
        departments = departmentList;
        employeeDepartments = departmentMap;
        employeeNames = nameMap;
        employeeCodes = codeMap;
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

  List<Map<String, dynamic>> get yearRequests {
    return allRequests.where((request) {
      final date = DateTime.tryParse(
        request['start_date']?.toString() ?? '',
      );
      return date != null && date.year == selectedYear;
    }).toList();
  }

  int countStatus(String status) {
    return yearRequests.where((request) {
      return request['status']?.toString().toLowerCase() == status;
    }).length;
  }

  double get approvedDays {
    double total = 0;

    for (final request in yearRequests) {
      if (request['status']?.toString().toLowerCase() == 'approved') {
        total += double.tryParse(
              request['total_days']?.toString() ?? '0',
            ) ??
            0;
      }
    }

    return total;
  }

  String formatDays(double value) {
    if (value == value.roundToDouble()) {
      return value.toInt().toString();
    }
    return value.toStringAsFixed(1);
  }

  Map<String, int> get leaveTypeSummary {
    final Map<String, int> result = {};

    for (final request in yearRequests) {
      final id = (request['leave_type_id'] as num?)?.toInt();
      final name = leaveTypeNames[id] ?? 'ไม่ระบุประเภท';
      result[name] = (result[name] ?? 0) + 1;
    }

    return result;
  }

  Map<String, int> get departmentSummary {
    final Map<String, int> result = {};

    for (final request in yearRequests) {
      final employeeId = request['employee_id']?.toString();
      final department =
          employeeDepartments[employeeId] ?? 'ไม่ระบุแผนก';

      result[department] = (result[department] ?? 0) + 1;
    }

    return result;
  }

  Map<String, int> get employeeSummary {
    final Map<String, int> result = {};

    for (final request in yearRequests) {
      final employeeId = request['employee_id']?.toString() ?? '';
      final name = employeeNames[employeeId] ?? 'ไม่ระบุชื่อ';
      final code = employeeCodes[employeeId] ?? '-';
      final label = '$code - $name';

      result[label] = (result[label] ?? 0) + 1;
    }

    return result;
  }

  int get totalEmployeesWithLeave {
    return yearRequests
        .map((request) => request['employee_id']?.toString())
        .where((id) => id != null && id.isNotEmpty)
        .toSet()
        .length;
  }

  int get totalRequests => yearRequests.length;

  String get totalDaysText => formatDays(approvedDays);

  Color statusColor(String status) {
    switch (status) {
      case 'approved':
        return Colors.green;
      case 'pending':
        return Colors.orange;
      case 'rejected':
        return Colors.red;
      default:
        return Colors.blueGrey;
    }
  }

  String statusText(String status) {
    switch (status.toLowerCase()) {
      case 'approved':
        return 'อนุมัติ';
      case 'pending':
        return 'รออนุมัติ';
      case 'rejected':
        return 'ไม่อนุมัติ';
      case 'cancelled':
        return 'ยกเลิก';
      default:
        return status;
    }
  }

  // ส่งออก Excel สำหรับ Flutter Web
  Future<void> exportLeaveReport() async {
    if (isExporting) return;

    setState(() {
      isExporting = true;
    });

    try {
      final requests = yearRequests;

      if (requests.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('ไม่มีข้อมูลใบลาในปีที่เลือก'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }

      final excel = Excel.createExcel();
      final sheet = excel['รายงานการลา'];

      final headerStyle = CellStyle(
        bold: true,
        fontSize: 12,
        backgroundColorHex: ExcelColor.fromHexString('#D9EAF7'),
        horizontalAlign: HorizontalAlign.Center,
        verticalAlign: VerticalAlign.Center,
      );

      sheet.appendRow([
        TextCellValue('รายงานสรุปการลา'),
      ]);

      sheet.appendRow([
        TextCellValue('ปี พ.ศ. ${selectedYear + 543}'),
      ]);

      sheet.appendRow([
        TextCellValue('วันที่ส่งออกรายงาน'),
        TextCellValue(DateTime.now().toString().substring(0, 10)),
      ]);

      sheet.appendRow([]);

      final headers = [
        'รหัสใบลา',
        'รหัสพนักงาน',
        'ชื่อพนักงาน',
        'แผนก',
        'ประเภทการลา',
        'วันที่เริ่มลา',
        'วันที่สิ้นสุด',
        'จำนวนวัน',
        'เหตุผล',
        'สถานะ',
        'วันที่ยื่นใบลา',
      ];

      sheet.appendRow(
        headers.map((item) => TextCellValue(item)).toList(),
      );

      for (int i = 0; i < headers.length; i++) {
        sheet
            .cell(
              CellIndex.indexByColumnRow(
                columnIndex: i,
                rowIndex: 4,
              ),
            )
            .cellStyle = headerStyle;
      }

      for (final request in requests) {
        final employeeId =
            request['employee_id']?.toString() ?? '';

        final leaveTypeId =
            (request['leave_type_id'] as num?)?.toInt();

        final status = request['status']?.toString() ?? '';

        sheet.appendRow([
          TextCellValue(request['id']?.toString() ?? ''),
          TextCellValue(employeeCodes[employeeId] ?? '-'),
          TextCellValue(employeeNames[employeeId] ?? '-'),
          TextCellValue(
            employeeDepartments[employeeId] ?? 'ไม่ระบุแผนก',
          ),
          TextCellValue(
            leaveTypeNames[leaveTypeId] ?? 'ไม่ระบุประเภท',
          ),
          TextCellValue(request['start_date']?.toString() ?? ''),
          TextCellValue(request['end_date']?.toString() ?? ''),
          TextCellValue(request['total_days']?.toString() ?? '0'),
          TextCellValue(request['reason']?.toString() ?? ''),
          TextCellValue(statusText(status)),
          TextCellValue(request['created_at']?.toString() ?? ''),
        ]);
      }

      sheet.appendRow([]);
      sheet.appendRow([TextCellValue('สรุปผลการลา')]);

      sheet.appendRow([
        TextCellValue('จำนวนใบลาทั้งหมด'),
        TextCellValue(totalRequests.toString()),
      ]);
      sheet.appendRow([
        TextCellValue('อนุมัติแล้ว'),
        TextCellValue(countStatus('approved').toString()),
      ]);
      sheet.appendRow([
        TextCellValue('รออนุมัติ'),
        TextCellValue(countStatus('pending').toString()),
      ]);
      sheet.appendRow([
        TextCellValue('ไม่อนุมัติ'),
        TextCellValue(countStatus('rejected').toString()),
      ]);
      sheet.appendRow([
        TextCellValue('จำนวนวันลาที่อนุมัติรวม'),
        TextCellValue(formatDays(approvedDays)),
      ]);
      sheet.appendRow([
        TextCellValue('จำนวนพนักงานที่มีใบลา'),
        TextCellValue(totalEmployeesWithLeave.toString()),
      ]);

      sheet.appendRow([]);
      sheet.appendRow([TextCellValue('สรุปตามประเภทการลา')]);
      sheet.appendRow([
        TextCellValue('ประเภทการลา'),
        TextCellValue('จำนวนรายการ'),
      ]);

      final typeSummary = leaveTypeSummary.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));

      for (final entry in typeSummary) {
        sheet.appendRow([
          TextCellValue(entry.key),
          TextCellValue(entry.value.toString()),
        ]);
      }

      sheet.appendRow([]);
      sheet.appendRow([TextCellValue('สรุปตามแผนก')]);
      sheet.appendRow([
        TextCellValue('แผนก'),
        TextCellValue('จำนวนรายการ'),
      ]);

      final deptSummary = departmentSummary.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));

      for (final entry in deptSummary) {
        sheet.appendRow([
          TextCellValue(entry.key),
          TextCellValue(entry.value.toString()),
        ]);
      }

      sheet.appendRow([]);
      sheet.appendRow([TextCellValue('สรุปตามพนักงาน')]);
      sheet.appendRow([
        TextCellValue('พนักงาน'),
        TextCellValue('จำนวนใบลา'),
      ]);

      final empSummary = employeeSummary.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));

      for (final entry in empSummary) {
        sheet.appendRow([
          TextCellValue(entry.key),
          TextCellValue(entry.value.toString()),
        ]);
      }

      sheet.setColumnWidth(0, 25);
      sheet.setColumnWidth(1, 18);
      sheet.setColumnWidth(2, 25);
      sheet.setColumnWidth(3, 25);
      sheet.setColumnWidth(4, 22);
      sheet.setColumnWidth(5, 16);
      sheet.setColumnWidth(6, 16);
      sheet.setColumnWidth(7, 14);
      sheet.setColumnWidth(8, 35);
      sheet.setColumnWidth(9, 18);
      sheet.setColumnWidth(10, 23);

      final bytes = excel.save();

      if (bytes == null) {
        throw Exception('ไม่สามารถสร้างไฟล์ Excel ได้');
      }

      final fileName = 'MG_LEAVE_REPORT_$selectedYear.xlsx';

      final blob = html.Blob(
        [Uint8List.fromList(bytes)],
        'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      );

      final url = html.Url.createObjectUrlFromBlob(blob);

      final anchor = html.AnchorElement(href: url)
        ..setAttribute('download', fileName)
        ..style.display = 'none';

      html.document.body?.children.add(anchor);
      anchor.click();
      anchor.remove();

      html.Url.revokeObjectUrl(url);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('ดาวน์โหลดไฟล์ Excel เรียบร้อยแล้ว'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('ส่งออก Excel ไม่สำเร็จ: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 6),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          isExporting = false;
        });
      }
    }
  }

  Widget buildExportButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: isExporting ? null : exportLeaveReport,
        icon: isExporting
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : const Icon(Icons.file_download_outlined),
        label: Text(
          isExporting
              ? 'กำลังสร้างไฟล์ Excel...'
              : 'ส่งออกรายงาน Excel',
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF168653),
          foregroundColor: Colors.white,
          disabledBackgroundColor: Colors.grey,
          padding: const EdgeInsets.symmetric(vertical: 15),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }

  Widget summaryCard(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 23),
          ),
          const SizedBox(height: 15),
          Text(
            value,
            style: TextStyle(
              fontSize: 25,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            title,
            style: const TextStyle(
              color: Colors.grey,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget sectionTitle(String title, String subtitle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.bold,
            color: Color(0xFF142B4A),
          ),
        ),
        const SizedBox(height: 5),
        Text(
          subtitle,
          style: const TextStyle(color: Colors.grey, fontSize: 12),
        ),
      ],
    );
  }

  Widget reportBar({
    required String title,
    required int count,
    required int maxCount,
    required Color color,
  }) {
    final progress = maxCount == 0 ? 0.0 : count / maxCount;

    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF34465A),
                  ),
                ),
              ),
              Text(
                '$count รายการ',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF142B4A),
                ),
              ),
            ],
          ),
          const SizedBox(height: 9),
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 11,
              backgroundColor: const Color(0xFFEDF1F5),
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
        ],
      ),
    );
  }

  Widget _emptyReport() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(25),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
      ),
      child: const Column(
        children: [
          Icon(Icons.bar_chart, size: 42, color: Colors.grey),
          SizedBox(height: 10),
          Text(
            'ยังไม่มีข้อมูลรายงาน',
            style: TextStyle(color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget buildStatusReport() {
    final statuses = [
      ('อนุมัติแล้ว', 'approved', Colors.green),
      ('รออนุมัติ', 'pending', Colors.orange),
      ('ไม่อนุมัติ', 'rejected', Colors.red),
    ];

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
      ),
      child: Column(
        children: statuses.map((item) {
          return reportBar(
            title: item.$1,
            count: countStatus(item.$2),
            maxCount: totalRequests,
            color: item.$3,
          );
        }).toList(),
      ),
    );
  }

  Widget buildSummaryReport(
    Map<String, int> summary,
    Color color,
  ) {
    if (summary.isEmpty) return _emptyReport();

    final sorted = summary.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final maxCount = sorted.first.value;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
      ),
      child: Column(
        children: sorted.map((entry) {
          return reportBar(
            title: entry.key,
            count: entry.value,
            maxCount: maxCount,
            color: color,
          );
        }).toList(),
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
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
              'ไม่สามารถโหลดรายงานได้',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
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
              onPressed: loadReport,
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
    final currentYear = DateTime.now().year;

    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FB),
      appBar: AppBar(
        title: const Text(
          'รายงานสรุปการลา',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFF1769AA),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            onPressed: isLoading ? null : loadReport,
            icon: const Icon(Icons.refresh),
            tooltip: 'รีเฟรชข้อมูล',
          ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : errorMessage != null
              ? _buildError()
              : RefreshIndicator(
                  onRefresh: loadReport,
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(18),
                    children: [
                      const Text(
                        'ภาพรวมการลางาน',
                        style: TextStyle(
                          fontSize: 23,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF142B4A),
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'รายงานและวิเคราะห์ข้อมูลการลาของพนักงาน',
                        style: TextStyle(color: Colors.grey),
                      ),
                      const SizedBox(height: 20),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.calendar_month,
                              color: Color(0xFF1769AA),
                            ),
                            const SizedBox(width: 12),
                            const Expanded(
                              child: Text(
                                'ปีที่ต้องการดูรายงาน',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            DropdownButton<int>(
                              value: selectedYear,
                              underline: const SizedBox(),
                              items: List.generate(5, (index) {
                                final year = currentYear - index;
                                return DropdownMenuItem<int>(
                                  value: year,
                                  child: Text('${year + 543}'),
                                );
                              }),
                              onChanged: (value) {
                                if (value == null) return;
                                setState(() {
                                  selectedYear = value;
                                });
                              },
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      buildExportButton(),
                      const SizedBox(height: 22),
                      const Text(
                        'สรุปข้อมูลประจำปี',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF142B4A),
                        ),
                      ),
                      const SizedBox(height: 13),
                      Row(
                        children: [
                          Expanded(
                            child: summaryCard(
                              'ใบลาทั้งหมด',
                              '$totalRequests',
                              Icons.description_outlined,
                              Colors.blue,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: summaryCard(
                              'วันลาที่อนุมัติ',
                              totalDaysText,
                              Icons.event_available,
                              Colors.green,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: summaryCard(
                              'อนุมัติแล้ว',
                              '${countStatus('approved')}',
                              Icons.check_circle_outline,
                              Colors.green,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: summaryCard(
                              'รออนุมัติ',
                              '${countStatus('pending')}',
                              Icons.hourglass_empty,
                              Colors.orange,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: summaryCard(
                              'ไม่อนุมัติ',
                              '${countStatus('rejected')}',
                              Icons.cancel_outlined,
                              Colors.red,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: summaryCard(
                              'พนักงานที่มีใบลา',
                              '$totalEmployeesWithLeave',
                              Icons.people_outline,
                              Colors.purple,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 25),
                      sectionTitle(
                        'สรุปตามสถานะ',
                        'จำนวนใบลาแยกตามผลการพิจารณา',
                      ),
                      const SizedBox(height: 13),
                      buildStatusReport(),
                      const SizedBox(height: 25),
                      sectionTitle(
                        'ประเภทการลา',
                        'จำนวนคำขอแยกตามประเภทการลา',
                      ),
                      const SizedBox(height: 13),
                      buildSummaryReport(
                        leaveTypeSummary,
                        const Color(0xFF1686CC),
                      ),
                      const SizedBox(height: 25),
                      sectionTitle(
                        'สรุปตามแผนก',
                        'จำนวนคำขอลาของแต่ละแผนก',
                      ),
                      const SizedBox(height: 13),
                      buildSummaryReport(
                        departmentSummary,
                        const Color(0xFF16865C),
                      ),
                      const SizedBox(height: 25),
                      sectionTitle(
                        'สรุปตามพนักงาน',
                        'จำนวนใบลาที่พนักงานแต่ละคนยื่นในปีที่เลือก',
                      ),
                      const SizedBox(height: 13),
                      buildSummaryReport(
                        employeeSummary,
                        const Color(0xFF8B5CF6),
                      ),
                      const SizedBox(height: 25),
                      Container(
                        padding: const EdgeInsets.all(15),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE6F1FC),
                          borderRadius: BorderRadius.circular(13),
                        ),
                        child: const Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              Icons.info_outline,
                              color: Color(0xFF1769AA),
                            ),
                            SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'รายงานนี้นับใบลาตามปีของวันที่เริ่มลา '
                                'และนับจำนวนวันลาเฉพาะรายการที่ได้รับอนุมัติแล้ว',
                                style: TextStyle(
                                  color: Color(0xFF1769AA),
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
    );
  }
}
