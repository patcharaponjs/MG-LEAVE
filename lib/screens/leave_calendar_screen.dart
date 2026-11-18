
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class LeaveCalendarScreen extends StatefulWidget {
  final bool showAllEmployees;

  const LeaveCalendarScreen({
    super.key,
    this.showAllEmployees = false,
  });

  @override
  State<LeaveCalendarScreen> createState() => _LeaveCalendarScreenState();
}

class _LeaveCalendarScreenState extends State<LeaveCalendarScreen> {
  final SupabaseClient supabase = Supabase.instance.client;

  bool isLoading = true;
  String? errorMessage;

  DateTime currentMonth = DateTime.now();
  DateTime selectedDate = DateTime.now();

  List<Map<String, dynamic>> leaveRequests = [];
  List<Map<String, dynamic>> leaveTypes = [];
  List<Map<String, dynamic>> employees = [];

  final List<Color> typeColors = [
    const Color(0xFF2196F3),
    const Color(0xFF9C27B0),
    const Color(0xFF009688),
    const Color(0xFFFF9800),
    const Color(0xFFE91E63),
    const Color(0xFF607D8B),
    const Color(0xFF795548),
    const Color(0xFF3F51B5),
  ];

  final List<String> thaiMonths = [
    'มกราคม',
    'กุมภาพันธ์',
    'มีนาคม',
    'เมษายน',
    'พฤษภาคม',
    'มิถุนายน',
    'กรกฎาคม',
    'สิงหาคม',
    'กันยายน',
    'ตุลาคม',
    'พฤศจิกายน',
    'ธันวาคม',
  ];

  final List<String> weekdays = [
    'จ.',
    'อ.',
    'พ.',
    'พฤ.',
    'ศ.',
    'ส.',
    'อา.',
  ];

  @override
  void initState() {
    super.initState();
    loadCalendarData();
  }

  Future<void> loadCalendarData() async {
    if (mounted) {
      setState(() {
        isLoading = true;
        errorMessage = null;
      });
    }

    try {
      final user = supabase.auth.currentUser;

      if (user == null) {
        throw Exception('กรุณาเข้าสู่ระบบก่อนใช้งาน');
      }

      final typeResponse = await supabase
          .from('leave_types')
          .select('id, leave_name')
          .order('id');

      final employeeResponse = await supabase
          .from('profiles')
          .select('id, full_name');

      var requestQuery = supabase
          .from('leave_requests')
          .select(
            'id, employee_id, leave_type_id, start_date, '
            'end_date, total_days, reason, status',
          );

      if (!widget.showAllEmployees) {
        requestQuery = requestQuery.eq('employee_id', user.id);
      }

      final requestResponse =
          await requestQuery.order('start_date', ascending: true);

      if (!mounted) return;

      setState(() {
        leaveTypes = List<Map<String, dynamic>>.from(typeResponse);
        employees = List<Map<String, dynamic>>.from(employeeResponse);

        leaveRequests =
            List<Map<String, dynamic>>.from(requestResponse).where((request) {
          final status = normalizeStatus(request['status']);

          return status != 'cancelled' &&
              status != 'canceled' &&
              status != 'ยกเลิก';
        }).toList();

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

  Color colorForStatus(dynamic status) {
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

      default:
        return const Color(0xFF78909C);
    }
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

      default:
        return (status ?? 'ไม่ระบุ').toString();
    }
  }

  DateTime dateOnly(DateTime date) {
    return DateTime(date.year, date.month, date.day);
  }

  DateTime parseDate(dynamic value) {
    return DateTime.parse(value.toString());
  }

  String formatDate(DateTime date) {
    return '${date.day} ${thaiMonths[date.month - 1]} '
        '${date.year + 543}';
  }

  String formatShortDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year + 543}';
  }

  String monthTitle(DateTime date) {
    return '${thaiMonths[date.month - 1]} ${date.year + 543}';
  }

  String employeeName(dynamic employeeId) {
    final employee = employees.firstWhere(
      (item) => item['id'].toString() == employeeId.toString(),
      orElse: () => {},
    );

    return employee['full_name']?.toString() ?? 'ไม่ระบุชื่อ';
  }

  String leaveTypeName(dynamic typeId) {
    final type = leaveTypes.firstWhere(
      (item) => item['id'].toString() == typeId.toString(),
      orElse: () => {},
    );

    return type['leave_name']?.toString() ?? 'ไม่ระบุประเภท';
  }

  Color colorForLeaveType(dynamic typeId) {
    final index = leaveTypes.indexWhere(
      (item) => item['id'].toString() == typeId.toString(),
    );

    if (index < 0) {
      return typeColors[0];
    }

    return typeColors[index % typeColors.length];
  }

  List<Map<String, dynamic>> recordsForDate(DateTime date) {
    final targetDate = dateOnly(date);

    return leaveRequests.where((request) {
      try {
        final start = dateOnly(parseDate(request['start_date']));
        final end = dateOnly(parseDate(request['end_date']));

        return !targetDate.isBefore(start) &&
            !targetDate.isAfter(end);
      } catch (_) {
        return false;
      }
    }).toList();
  }

  void changeMonth(int amount) {
    setState(() {
      currentMonth = DateTime(
        currentMonth.year,
        currentMonth.month + amount,
        1,
      );
    });
  }

  void goToToday() {
    setState(() {
      currentMonth = DateTime(
        DateTime.now().year,
        DateTime.now().month,
        1,
      );
      selectedDate = DateTime.now();
    });
  }

  List<DateTime> getCalendarDates() {
    final firstDay = DateTime(
      currentMonth.year,
      currentMonth.month,
      1,
    );

    final startOffset = firstDay.weekday - 1;
    final startDate = firstDay.subtract(Duration(days: startOffset));

    return List.generate(
      42,
      (index) => startDate.add(Duration(days: index)),
    );
  }

  Widget buildHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF242424),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFF424242),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(
                Icons.calendar_month,
                color: Color(0xFFE53935),
                size: 25,
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  widget.showAllEmployees
                      ? 'ปฏิทินการลาทั้งหมด'
                      : 'ปฏิทินการลาของฉัน',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
              IconButton(
                onPressed: loadCalendarData,
                tooltip: 'รีเฟรช',
                color: Colors.white70,
                icon: const Icon(Icons.refresh),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                onPressed: () => changeMonth(-1),
                color: Colors.white,
                icon: const Icon(Icons.chevron_left),
              ),
              Expanded(
                child: Center(
                  child: Text(
                    monthTitle(currentMonth),
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFFFF5252),
                    ),
                  ),
                ),
              ),
              IconButton(
                onPressed: () => changeMonth(1),
                color: Colors.white,
                icon: const Icon(Icons.chevron_right),
              ),
              TextButton(
                onPressed: goToToday,
                child: const Text(
                  'วันนี้',
                  style: TextStyle(
                    color: Color(0xFFFF5252),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget buildWeekdayHeader() {
    return Row(
      children: weekdays.map((day) {
        final isWeekend = day == 'ส.' || day == 'อา.';

        return Expanded(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 7),
              child: Text(
                day,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: isWeekend
                      ? const Color(0xFFFF5252)
                      : Colors.white,
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget buildCalendarCell(DateTime date) {
    final records = recordsForDate(date);

    final isCurrentMonth = date.month == currentMonth.month &&
        date.year == currentMonth.year;

    final isSelected = dateOnly(date) == dateOnly(selectedDate);
    final isToday = dateOnly(date) == dateOnly(DateTime.now());

    final visibleRecords = records.take(2).toList();
    final remainingCount = records.length - visibleRecords.length;

    final backgroundColor = isToday
        ? const Color(0xFFE53935)
        : isSelected
            ? const Color(0xFF8B0000)
            : isCurrentMonth
                ? const Color(0xFF292929)
                : const Color(0xFF202020);

    return GestureDetector(
      onTap: () {
        setState(() {
          selectedDate = date;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.fromLTRB(3, 3, 3, 2),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isToday
                ? const Color(0xFFFF8A80)
                : isSelected
                    ? const Color(0xFFFF5252)
                    : const Color(0xFF424242),
            width: isToday || isSelected ? 2 : 1,
          ),
          boxShadow: isToday
              ? [
                  BoxShadow(
                    color: const Color(0xFFE53935)
                        .withValues(alpha: 0.4),
                    blurRadius: 7,
                    spreadRadius: 1,
                  ),
                ]
              : [],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Align(
              alignment: Alignment.topCenter,
              child: Text(
                '${date.day}',
                style: TextStyle(
                  fontSize: 10,
                  height: 1.1,
                  fontWeight: isToday || isSelected
                      ? FontWeight.bold
                      : FontWeight.w500,
                  color: !isCurrentMonth
                      ? Colors.white30
                      : Colors.white,
                ),
              ),
            ),
            const SizedBox(height: 3),
            ...visibleRecords.map((record) {
              final statusColor = colorForStatus(record['status']);
              final typeName = leaveTypeName(record['leave_type_id']);

              return Container(
                margin: const EdgeInsets.only(bottom: 2),
                padding: const EdgeInsets.symmetric(
                  horizontal: 2,
                  vertical: 2,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 5,
                      height: 5,
                      decoration: BoxDecoration(
                        color: statusColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 3),
                    Expanded(
                      child: Text(
                        typeName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 9,
                          height: 1.2,
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
            if (remainingCount > 0)
              Text(
                '+$remainingCount',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 9,
                  color: Colors.white70,
                  fontWeight: FontWeight.bold,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget buildCalendar() {
    final dates = getCalendarDates();

    return Container(
      padding: const EdgeInsets.all(9),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFF161616),
            Color(0xFF242424),
            Color(0xFF111111),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFF424242),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          buildWeekdayHeader(),
          const Divider(
            height: 1,
            color: Color(0xFF555555),
          ),
          const SizedBox(height: 6),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: dates.length,
            gridDelegate:
                const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              childAspectRatio: 0.78,
              mainAxisSpacing: 4,
              crossAxisSpacing: 4,
            ),
            itemBuilder: (context, index) {
              return buildCalendarCell(dates[index]);
            },
          ),
        ],
      ),
    );
  }

  Widget buildStatusLegend() {
    return Wrap(
      spacing: 14,
      runSpacing: 8,
      children: [
        buildLegendItem(
          const Color(0xFFFF9800),
          'รออนุมัติ',
        ),
        buildLegendItem(
          const Color(0xFF2EAD68),
          'อนุมัติแล้ว',
        ),
        buildLegendItem(
          const Color(0xFFE53935),
          'ไม่อนุมัติ',
        ),
      ],
    );
  }

  Widget buildLegendItem(Color color, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 5),
        Text(
          text,
          style: const TextStyle(
            fontSize: 11,
            color: Colors.white70,
          ),
        ),
      ],
    );
  }

  Widget buildInfoRow(
    IconData icon,
    String title,
    String value, {
    Color? color,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            size: 18,
            color: color ?? Colors.white70,
          ),
          const SizedBox(width: 9),
          SizedBox(
            width: 95,
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 13,
                color: Colors.white60,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: color ?? Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget buildLeaveCard(Map<String, dynamic> record) {
    final typeId = record['leave_type_id'];
    final typeColor = colorForLeaveType(typeId);
    final statusColor = colorForStatus(record['status']);

    DateTime start;
    DateTime end;

    try {
      start = parseDate(record['start_date']);
      end = parseDate(record['end_date']);
    } catch (_) {
      start = selectedDate;
      end = selectedDate;
    }

    final totalDays = record['total_days']?.toString() ?? '-';
    final reason = record['reason']?.toString();

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: const Color(0xFF292929),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFF424242),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 9,
                height: 9,
                decoration: BoxDecoration(
                  color: typeColor,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  leaveTypeName(typeId),
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: typeColor,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 9,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  statusText(record['status']),
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: statusColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (widget.showAllEmployees)
            buildInfoRow(
              Icons.person_outline,
              'พนักงาน',
              employeeName(record['employee_id']),
            ),
          buildInfoRow(
            Icons.calendar_today_outlined,
            'วันที่ลา',
            '${formatShortDate(start)} - ${formatShortDate(end)}',
          ),
          buildInfoRow(
            Icons.timelapse,
            'จำนวนวัน',
            '$totalDays วัน',
          ),
          if (reason != null && reason.trim().isNotEmpty)
            buildInfoRow(
              Icons.description_outlined,
              'เหตุผล',
              reason,
            ),
        ],
      ),
    );
  }

  Widget buildSelectedDateDetails() {
    final records = recordsForDate(selectedDate);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF242424),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: const Color(0xFF424242),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.event_note,
                color: Color(0xFFE53935),
                size: 21,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'รายการลา วันที่ ${formatDate(selectedDate)}',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF8B0000),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${records.length} รายการ',
                  style: const TextStyle(
                    fontSize: 11,
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 13),
          if (records.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 22),
              child: const Column(
                children: [
                  Icon(
                    Icons.event_available,
                    size: 34,
                    color: Colors.white38,
                  ),
                  SizedBox(height: 7),
                  Text(
                    'ไม่มีรายการลาในวันนี้',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.white60,
                    ),
                  ),
                ],
              ),
            )
          else
            ...records.map(buildLeaveCard),
        ],
      ),
    );
  }

  Widget buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.error_outline,
              color: Color(0xFFE53935),
              size: 42,
            ),
            const SizedBox(height: 10),
            const Text(
              'ไม่สามารถโหลดข้อมูลปฏิทินได้',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              errorMessage ?? 'เกิดข้อผิดพลาด',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white60,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 14),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFE53935),
                foregroundColor: Colors.white,
              ),
              onPressed: loadCalendarData,
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
    return Scaffold(
      backgroundColor: const Color(0xFF181818),
      appBar: AppBar(
        title: const Text(
          'ปฏิทินการลา',
          style: TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: const Color(0xFF202020),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: isLoading
          ? const Center(
              child: CircularProgressIndicator(
                color: Color(0xFFE53935),
              ),
            )
          : errorMessage != null
              ? buildError()
              : RefreshIndicator(
                  color: const Color(0xFFE53935),
                  onRefresh: loadCalendarData,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        buildHeader(),
                        const SizedBox(height: 12),
                        buildCalendar(),
                        const SizedBox(height: 10),
                        buildStatusLegend(),
                        const SizedBox(height: 16),
                        buildSelectedDateDetails(),
                        const SizedBox(height: 20),
                      ],
                    ),
                  ),
                ),
    );
  }
}
