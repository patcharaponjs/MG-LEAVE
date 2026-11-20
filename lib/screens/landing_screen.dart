import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'login_screen.dart';
import 'dashboard_screen.dart';

class LandingScreen extends StatefulWidget {
  const LandingScreen({super.key});

  @override
  State<LandingScreen> createState() => _LandingScreenState();
}

class _LandingScreenState extends State<LandingScreen> {
  final supabase = Supabase.instance.client;
  final ScrollController _scrollController = ScrollController();
  final GlobalKey _calendarKey = GlobalKey();

  StreamSubscription<AuthState>? authSubscription;

  String fullName = '';
  String role = '';
  String avatarUrl = '';
  bool isLoggedIn = false;
  bool profileLoading = true;

  bool dataLoading = true;
  String? dataError;

  int totalRequests = 0;
  int pendingRequests = 0;
  int approvedRequests = 0;
  int rejectedRequests = 0;

  Map<String, int> calendarData = {};

  // ข้อมูล OT
  bool overtimeLoading = true;
  String? overtimeError;
  List<Map<String, dynamic>> overtimeSchedules = [];

  // รายการลาอนุมัติ
  bool approvedLeaveLoading = true;
  String? approvedLeaveError;
  List<Map<String, dynamic>> approvedLeaveSchedules = [];

  DateTime selectedMonth = DateTime.now();
  DateTime selectedCalendarDate = DateTime.now();

  static const Color primary = Color(0xFF087FD0);
  static const Color dark = Color(0xFF142B4A);
  static const Color background = Color(0xFFF4F7FB);

  static const List<String> months = [
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

  @override
  void initState() {
    super.initState();

    loadUser();
    loadPublicData();
    loadOvertimeSchedules();
    loadApprovedLeaveSchedules();

    authSubscription = supabase.auth.onAuthStateChange.listen((data) {
      loadUser();
    });
  }

  @override
  void dispose() {
    authSubscription?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  // เลื่อนหน้าจอไปยังปฏิทินการลา
  void scrollToCalendar() {
    final calendarContext = _calendarKey.currentContext;

    if (calendarContext == null) return;

    Scrollable.ensureVisible(
      calendarContext,
      duration: const Duration(milliseconds: 700),
      curve: Curves.easeInOut,
      alignment: 0.05,
    );
  }

  // โหลดข้อมูลผู้ใช้งาน
  Future<void> loadUser() async {
    final user = supabase.auth.currentUser;

    if (user == null) {
      if (!mounted) return;

      setState(() {
        isLoggedIn = false;
        fullName = '';
        role = '';
        avatarUrl = '';
        profileLoading = false;
      });
      return;
    }

    try {
      final profile = await supabase
          .from('profiles')
          .select('full_name, role, is_active, avatar_url')
          .eq('id', user.id)
          .maybeSingle();

      if (!mounted) return;

      if (profile == null || profile['is_active'] != true) {
        await supabase.auth.signOut();
        return;
      }

      setState(() {
        isLoggedIn = true;
        fullName = profile['full_name']?.toString() ?? 'ผู้ใช้งาน';
        role = profile['role']?.toString() ?? '';
        avatarUrl = profile['avatar_url']?.toString() ?? '';
        profileLoading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        isLoggedIn = true;
        fullName = user.email ?? 'ผู้ใช้งาน';
        role = '';
        avatarUrl = '';
        profileLoading = false;
      });
    }
  }

  // โหลดข้อมูลภาพรวมและปฏิทิน
  Future<void> loadPublicData() async {
    if (!mounted) return;

    setState(() {
      dataLoading = true;
      dataError = null;
    });

    try {
      final summary = await supabase
          .from('public_leave_summary')
          .select()
          .maybeSingle();

      final firstDay = DateTime(
        selectedMonth.year,
        selectedMonth.month,
        1,
      );

      final lastDay = DateTime(
        selectedMonth.year,
        selectedMonth.month + 1,
        0,
      );

      final calendar = await supabase
          .from('public_leave_calendar')
          .select('leave_date, total_on_leave')
          .gte('leave_date', dateKey(firstDay))
          .lte('leave_date', dateKey(lastDay))
          .order('leave_date');

      if (!mounted) return;

      final Map<String, int> values = {};

      for (final item in calendar) {
        final date = item['leave_date']?.toString();

        final count = int.tryParse(
              item['total_on_leave']?.toString() ?? '',
            ) ??
            0;

        if (date != null) {
          values[date] = count;
        }
      }

      setState(() {
        totalRequests = int.tryParse(
              summary?['total_requests']?.toString() ?? '',
            ) ??
            0;

        pendingRequests = int.tryParse(
              summary?['pending_requests']?.toString() ?? '',
            ) ??
            0;

        approvedRequests = int.tryParse(
              summary?['approved_requests']?.toString() ?? '',
            ) ??
            0;

        rejectedRequests = int.tryParse(
              summary?['rejected_requests']?.toString() ?? '',
            ) ??
            0;

        calendarData = values;
        dataLoading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        dataLoading = false;
        dataError = e.toString();
      });
    }
  }

  // โหลดรายการ OT ที่อนุมัติแล้ว
  Future<void> loadOvertimeSchedules() async {
    if (!mounted) return;

    setState(() {
      overtimeLoading = true;
      overtimeError = null;
    });

    try {
      final response = await supabase
          .from('public_overtime_schedule')
          .select(
            'id, work_date, start_time, end_time, total_hours, employee_name, avatar_url',
          )
          .order('work_date', ascending: true)
          .order('start_time', ascending: true);

      final result = List<Map<String, dynamic>>.from(response);

      if (!mounted) return;

      setState(() {
        overtimeSchedules = result;
        overtimeLoading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        overtimeLoading = false;
        overtimeError = e.toString();
      });
    }
  }

  // โหลดรายการลาอนุมัติจาก public_approved_leaves
  Future<void> loadApprovedLeaveSchedules() async {
    if (!mounted) return;

    setState(() {
      approvedLeaveLoading = true;
      approvedLeaveError = null;
    });

    try {
      final response = await supabase
          .from('public_approved_leaves')
          .select('id, full_name, start_date, end_date, leave_name')
          .order('start_date', ascending: true);

      final result = List<Map<String, dynamic>>.from(response);

      if (!mounted) return;

      setState(() {
        approvedLeaveSchedules = result;
        approvedLeaveLoading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        approvedLeaveLoading = false;
        approvedLeaveError = e.toString();
      });
    }
  }

  // รีเฟรชข้อมูลทั้งหมด
  Future<void> refreshLanding() async {
    await Future.wait([
      loadPublicData(),
      loadOvertimeSchedules(),
      loadApprovedLeaveSchedules(),
    ]);
  }

  // รูปแบบวันที่
  String dateKey(DateTime date) {
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');

    return '${date.year}-$month-$day';
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

  String formatTime(dynamic value) {
    if (value == null) return '-';

    final time = value.toString();

    return time.length >= 5 ? time.substring(0, 5) : time;
  }

  // เข้าสู่ระบบ
  Future<void> openLogin() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const LoginScreen(),
      ),
    );

    loadUser();
  }

  // ออกจากระบบ
  Future<void> logout() async {
    await supabase.auth.signOut();

    if (!mounted) return;

    setState(() {
      isLoggedIn = false;
      fullName = '';
      role = '';
      avatarUrl = '';
      profileLoading = false;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('ออกจากระบบเรียบร้อยแล้ว'),
      ),
    );
  }

  // เปิด Dashboard
  void openDashboard() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => DashboardScreen(fullName: fullName),
      ),
    );
  }

  // เปลี่ยนเดือน
  void changeMonth(int amount) {
    setState(() {
      selectedMonth = DateTime(
        selectedMonth.year,
        selectedMonth.month + amount,
        1,
      );
      selectedCalendarDate = selectedMonth;
    });

    loadPublicData();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: background,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: refreshLanding,
          child: CustomScrollView(
            controller: _scrollController,
            slivers: [
              SliverToBoxAdapter(child: _buildHeader()),
              SliverToBoxAdapter(child: _buildHero()),
              SliverToBoxAdapter(child: _buildOverview()),
              SliverToBoxAdapter(child: _buildApprovedLeaveSection()),
              SliverToBoxAdapter(child: _buildOvertimeSchedule()),
              SliverToBoxAdapter(child: _buildCalendar()),
              SliverToBoxAdapter(child: _buildFooter()),
            ],
          ),
        ),
      ),
    );
  }

  // HEADER
  Widget _buildHeader() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(
        horizontal: 28,
        vertical: 15,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: Row(
            children: [
              Container(
                width: 45,
                height: 45,
                decoration: BoxDecoration(
                  color: primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: const Icon(
                  Icons.event_available,
                  color: primary,
                  size: 27,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'MG LEAVE MANAGEMENT',
                      style: TextStyle(
                        color: dark,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    Text(
                      'ระบบลางานและลงงานโอที',
                      style: TextStyle(
                        color: Colors.grey,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              if (profileLoading)
                const SizedBox(
                  width: 25,
                  height: 25,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                  ),
                )
              else if (isLoggedIn)
                PopupMenuButton<String>(
                  onSelected: (value) {
                    if (value == 'dashboard') {
                      openDashboard();
                    } else if (value == 'logout') {
                      logout();
                    }
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(
                      value: 'dashboard',
                      child: ListTile(
                        leading: Icon(Icons.dashboard_outlined),
                        title: Text('ไปยังหน้าระบบ'),
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                    PopupMenuItem(
                      value: 'logout',
                      child: ListTile(
                        leading: Icon(
                          Icons.logout,
                          color: Colors.red,
                        ),
                        title: Text('ออกจากระบบ'),
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  ],
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0F5FA),
                      borderRadius: BorderRadius.circular(30),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircleAvatar(
                          radius: 17,
                          backgroundColor: primary,
                          backgroundImage: avatarUrl.isNotEmpty
                              ? NetworkImage(avatarUrl)
                              : null,
                          child: avatarUrl.isEmpty
                              ? const Icon(
                                  Icons.person,
                                  color: Colors.white,
                                  size: 20,
                                )
                              : null,
                        ),
                        const SizedBox(width: 8),
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 130),
                          child: Text(
                            fullName,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: dark,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                        ),
                        const SizedBox(width: 5),
                        const Icon(Icons.keyboard_arrow_down),
                      ],
                    ),
                  ),
                )
              else
                OutlinedButton.icon(
                  onPressed: openLogin,
                  icon: const Icon(Icons.login, size: 18),
                  label: const Text('เข้าสู่ระบบ'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: primary,
                    side: const BorderSide(color: primary),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 13,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  // HERO
  Widget _buildHero() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.all(20),
      padding: const EdgeInsets.symmetric(
        horizontal: 30,
        vertical: 42,
      ),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFF075A9E),
            Color(0xFF087FD0),
            Color(0xFF08A4C8),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: primary.withValues(alpha: 0.2),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1100),
          child: Row(
            children: [
              Expanded(
                flex: 3,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 13,
                        vertical: 7,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(30),
                      ),
                      child: const Text(
                        'LEAVE & OVERTIME MANAGEMENT SYSTEM',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          letterSpacing: 1.2,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(height: 22),
                    const Text(
                      'ระบบลางานและลงงานโอที',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 30,
                        fontWeight: FontWeight.bold,
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 13),
                    const Text(
                      'ตรวจสอบภาพรวมการลา ดูปฏิทินวันลา '
                      'และติดตามข้อมูลการลาได้สะดวกในที่เดียว',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 15,
                        height: 1.7,
                      ),
                    ),
                    const SizedBox(height: 25),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        ElevatedButton.icon(
                          onPressed: isLoggedIn
                              ? openDashboard
                              : openLogin,
                          icon: Icon(
                            isLoggedIn
                                ? Icons.dashboard
                                : Icons.login,
                          ),
                          label: Text(
                            isLoggedIn
                                ? 'เข้าสู่หน้าระบบ'
                                : 'เข้าสู่ระบบเพื่อใช้งาน',
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: primary,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 15,
                            ),
                          ),
                        ),
                        OutlinedButton.icon(
                          onPressed: scrollToCalendar,
                          icon: const Icon(Icons.calendar_month),
                          label: const Text('ปฏิทินการลา'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white,
                            side: const BorderSide(
                              color: Colors.white70,
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 18,
                              vertical: 15,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 25),
              const Expanded(
                flex: 2,
                child: Icon(
                  Icons.calendar_month_rounded,
                  color: Colors.white24,
                  size: 170,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ภาพรวมการลา
  Widget _buildOverview() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1100),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'ภาพรวมการลา',
                style: TextStyle(
                  color: dark,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 5),
              const Text(
                'ข้อมูลสรุปคำขอลาจากระบบ',
                style: TextStyle(
                  color: Colors.grey,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 17),
              if (dataLoading)
                const Center(
                  child: CircularProgressIndicator(),
                )
              else if (dataError != null)
                _buildDataError()
              else
                LayoutBuilder(
                  builder: (context, constraints) {
                    final width = constraints.maxWidth;
                    final columns = width >= 700 ? 4 : 2;

                    return GridView.count(
                      crossAxisCount: columns,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio: width >= 700 ? 1.9 : 1.5,
                      children: [
                        _statCard(
                          'ใบลาทั้งหมด',
                          totalRequests,
                          Icons.description_outlined,
                          primary,
                        ),
                        _statCard(
                          'รออนุมัติ',
                          pendingRequests,
                          Icons.pending_actions,
                          Colors.orange,
                        ),
                        _statCard(
                          'อนุมัติแล้ว',
                          approvedRequests,
                          Icons.check_circle_outline,
                          Colors.green,
                        ),
                        _statCard(
                          'ไม่อนุมัติ',
                          rejectedRequests,
                          Icons.cancel_outlined,
                          Colors.red,
                        ),
                      ],
                    );
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  // การ์ดสถิติ
  Widget _statCard(
    String title,
    int count,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFFE8EEF5),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.025),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 25),
          const Spacer(),
          Text(
            '$count',
            style: TextStyle(
              color: color,
              fontSize: 27,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            title,
            style: const TextStyle(
              color: dark,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  // Error ภาพรวม
  Widget _buildDataError() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.cloud_off_outlined,
            color: Colors.orange,
            size: 35,
          ),
          const SizedBox(height: 8),
          const Text(
            'ยังไม่สามารถโหลดข้อมูลภาพรวมได้',
            style: TextStyle(
              color: dark,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: loadPublicData,
            icon: const Icon(Icons.refresh),
            label: const Text('ลองอีกครั้ง'),
          ),
        ],
      ),
    );
  }

  // รายการลาอนุมัติแล้ว
  Widget _buildApprovedLeaveSection() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 35, 20, 10),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1100),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: const Color(0xFFE8EEF5),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.025),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: Colors.green.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(
                        Icons.event_available,
                        color: Colors.green,
                        size: 27,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'รายการลาที่อนุมัติแล้ว',
                            style: TextStyle(
                              color: dark,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'แสดงรายการวันลาและประเภทการลา',
                            style: TextStyle(
                              color: Colors.grey,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'รีเฟรชรายการลา',
                      onPressed: approvedLeaveLoading
                          ? null
                          : loadApprovedLeaveSchedules,
                      icon: const Icon(Icons.refresh),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                if (approvedLeaveLoading)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(25),
                      child: CircularProgressIndicator(),
                    ),
                  )
                else if (approvedLeaveError != null)
                  _buildApprovedLeaveError()
                else if (approvedLeaveSchedules.isEmpty)
                  _buildEmptyApprovedLeave()
                else
                  Column(
                    children: approvedLeaveSchedules
                        .map((item) => _buildApprovedLeaveCard(item))
                        .toList(),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // การ์ดรายการลา
  Widget _buildApprovedLeaveCard(Map<String, dynamic> item) {
    final employeeName =
        item['full_name']?.toString() ?? 'ไม่ระบุชื่อ';

    final leaveName =
        item['leave_name']?.toString() ?? 'ไม่ระบุประเภทการลา';

    final startDate = formatDate(item['start_date']);
    final endDate = formatDate(item['end_date']);

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFF),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(
          color: const Color(0xFFE6EDF5),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 23,
                backgroundColor: Colors.green.withValues(alpha: 0.12),
                child: const Icon(
                  Icons.person_outline,
                  color: Colors.green,
                  size: 27,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  employeeName,
                  style: const TextStyle(
                    color: dark,
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  'อนุมัติแล้ว',
                  style: TextStyle(
                    color: Colors.green,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 15),
          Row(
            children: [
              const Icon(
                Icons.category_outlined,
                color: primary,
                size: 22,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  leaveName,
                  style: const TextStyle(
                    color: dark,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.date_range,
                color: Colors.orange,
                size: 22,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  startDate == endDate
                      ? startDate
                      : '$startDate - $endDate',
                  style: const TextStyle(
                    color: dark,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ไม่มีรายการลา
  Widget _buildEmptyApprovedLeave() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(25),
      decoration: BoxDecoration(
        color: const Color(0xFFF4F7FB),
        borderRadius: BorderRadius.circular(15),
      ),
      child: const Column(
        children: [
          Icon(
            Icons.event_busy,
            color: Colors.grey,
            size: 40,
          ),
          SizedBox(height: 10),
          Text(
            'ยังไม่มีรายการลาที่อนุมัติ',
            style: TextStyle(
              color: Colors.grey,
              fontSize: 15,
            ),
          ),
        ],
      ),
    );
  }

  // Error รายการลา
  Widget _buildApprovedLeaveError() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF5F5),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.cloud_off_outlined,
            color: Colors.red,
            size: 35,
          ),
          const SizedBox(height: 10),
          const Text(
            'ไม่สามารถโหลดรายการลาได้',
            style: TextStyle(
              color: Colors.red,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            approvedLeaveError!,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.grey,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 10),
          ElevatedButton.icon(
            onPressed: loadApprovedLeaveSchedules,
            icon: const Icon(Icons.refresh),
            label: const Text('ลองอีกครั้ง'),
          ),
        ],
      ),
    );
  }

  // ตาราง OT
  Widget _buildOvertimeSchedule() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 35, 20, 10),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1100),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: const Color(0xFFE8EEF5),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.025),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: Colors.deepOrange.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(
                        Icons.more_time,
                        color: Colors.deepOrange,
                        size: 27,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'ตารางผู้ปฏิบัติงาน OT',
                            style: TextStyle(
                              color: dark,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'รายการ OT ที่ได้รับอนุมัติ',
                            style: TextStyle(
                              color: Colors.grey,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'รีเฟรชรายการ OT',
                      onPressed: overtimeLoading
                          ? null
                          : loadOvertimeSchedules,
                      icon: const Icon(Icons.refresh),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                if (overtimeLoading)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(25),
                      child: CircularProgressIndicator(),
                    ),
                  )
                else if (overtimeError != null)
                  _buildOvertimeError()
                else if (overtimeSchedules.isEmpty)
                  _buildEmptyOvertime()
                else
                  Column(
                    children: overtimeSchedules
                        .map((item) => _buildOvertimeCard(item))
                        .toList(),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // การ์ด OT
  Widget _buildOvertimeCard(Map<String, dynamic> item) {
    final avatarUrl = item['avatar_url']?.toString() ?? '';
    final employeeName =
        item['employee_name']?.toString() ?? 'ไม่ระบุชื่อพนักงาน';

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFF),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(
          color: const Color(0xFFE6EDF5),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.calendar_month,
                color: primary,
                size: 22,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  formatDate(item['work_date']),
                  style: const TextStyle(
                    color: dark,
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  'อนุมัติแล้ว',
                  style: TextStyle(
                    color: Colors.green,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 15),
          Row(
            children: [
              CircleAvatar(
                radius: 25,
                backgroundColor: const Color(0xFFE8F3FC),
                backgroundImage: avatarUrl.isNotEmpty
                    ? NetworkImage(avatarUrl)
                    : null,
                child: avatarUrl.isEmpty
                    ? const Icon(
                        Icons.person,
                        color: Colors.teal,
                        size: 28,
                      )
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  employeeName,
                  style: const TextStyle(
                    color: dark,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(
                Icons.access_time,
                color: Colors.orange,
                size: 22,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '${formatTime(item['start_time'])} - '
                  '${formatTime(item['end_time'])} น.',
                  style: const TextStyle(
                    color: dark,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(
                Icons.timelapse,
                color: Colors.indigo,
                size: 22,
              ),
              const SizedBox(width: 10),
              Text(
                'รวม ${item['total_hours'] ?? '-'} ชั่วโมง',
                style: const TextStyle(
                  color: dark,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ไม่มีข้อมูล OT
  Widget _buildEmptyOvertime() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(25),
      decoration: BoxDecoration(
        color: const Color(0xFFF4F7FB),
        borderRadius: BorderRadius.circular(15),
      ),
      child: const Column(
        children: [
          Icon(
            Icons.event_busy,
            color: Colors.grey,
            size: 40,
          ),
          SizedBox(height: 10),
          Text(
            'ยังไม่มีรายการ OT ที่อนุมัติ',
            style: TextStyle(
              color: Colors.grey,
              fontSize: 15,
            ),
          ),
        ],
      ),
    );
  }

  // Error OT
  Widget _buildOvertimeError() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF5F5),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.cloud_off_outlined,
            color: Colors.red,
            size: 35,
          ),
          const SizedBox(height: 10),
          const Text(
            'ไม่สามารถโหลดรายการ OT ได้',
            style: TextStyle(
              color: Colors.red,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            overtimeError!,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.grey,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 10),
          ElevatedButton.icon(
            onPressed: loadOvertimeSchedules,
            icon: const Icon(Icons.refresh),
            label: const Text('ลองอีกครั้ง'),
          ),
        ],
      ),
    );
  }

  // ปฏิทินการลา
  Widget _buildCalendar() {
    final firstDay = DateTime(
      selectedMonth.year,
      selectedMonth.month,
      1,
    );

    final daysInMonth = DateTime(
      selectedMonth.year,
      selectedMonth.month + 1,
      0,
    ).day;

    final offset = firstDay.weekday % 7;
    final selectedKey = dateKey(selectedCalendarDate);
    final selectedCount = calendarData[selectedKey] ?? 0;

    return Padding(
      key: _calendarKey,
      padding: const EdgeInsets.fromLTRB(20, 35, 20, 30),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1100),
          child: Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: const Color(0xFFE8EEF5),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.035),
                  blurRadius: 18,
                  offset: const Offset(0, 7),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        color: primary.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(
                        Icons.calendar_month_rounded,
                        color: primary,
                        size: 26,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'ปฏิทินการลา',
                            style: TextStyle(
                              color: dark,
                              fontSize: 21,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 3),
                          Text(
                            'ภาพรวมจำนวนผู้ลาในแต่ละวัน',
                            style: TextStyle(
                              color: Colors.grey,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (dataLoading)
                      const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 22),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF6F9FD),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: const Color(0xFFE8EEF5),
                    ),
                  ),
                  child: Row(
                    children: [
                      IconButton(
                        tooltip: 'เดือนก่อน',
                        onPressed: () => changeMonth(-1),
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: primary,
                        ),
                        icon: const Icon(Icons.chevron_left_rounded),
                      ),
                      Expanded(
                        child: Column(
                          children: [
                            Text(
                              months[selectedMonth.month - 1],
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: dark,
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                              ),
                            ),
                            Text(
                              '${selectedMonth.year + 543}',
                              style: const TextStyle(
                                color: Colors.grey,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: 'เดือนถัดไป',
                        onPressed: () => changeMonth(1),
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: primary,
                        ),
                        icon: const Icon(Icons.chevron_right_rounded),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: () {
                      final now = DateTime.now();

                      setState(() {
                        selectedMonth = DateTime(now.year, now.month, 1);
                        selectedCalendarDate = now;
                      });

                      loadPublicData();
                    },
                    icon: const Icon(Icons.today_rounded, size: 18),
                    label: const Text('วันนี้'),
                    style: TextButton.styleFrom(
                      foregroundColor: primary,
                    ),
                  ),
                ),
                const SizedBox(height: 5),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final cellWidth = constraints.maxWidth / 7;
                    final ratio = cellWidth < 55 ? 0.75 : 1.05;

                    return GridView.count(
                      crossAxisCount: 7,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisSpacing: 4,
                      mainAxisSpacing: 5,
                      childAspectRatio: ratio,
                      children: [
                        for (final day in [
                          'อา',
                          'จ',
                          'อ',
                          'พ',
                          'พฤ',
                          'ศ',
                          'ส',
                        ])
                          Center(
                            child: Text(
                              day,
                              style: const TextStyle(
                                color: Color(0xFF64748B),
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        for (int i = 0; i < offset; i++)
                          const SizedBox.shrink(),
                        for (int day = 1; day <= daysInMonth; day++)
                          _calendarDay(day),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 18),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: selectedCount > 0
                        ? primary.withValues(alpha: 0.07)
                        : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: selectedCount > 0
                          ? primary.withValues(alpha: 0.20)
                          : const Color(0xFFE8EEF5),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: primary.withValues(alpha: 0.10),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.event_note_rounded,
                          color: primary,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${selectedCalendarDate.day} '
                              '${months[selectedCalendarDate.month - 1]} '
                              '${selectedCalendarDate.year + 543}',
                              style: const TextStyle(
                                color: dark,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              selectedCount > 0
                                  ? 'มีพนักงานลา $selectedCount คน'
                                  : 'ไม่มีข้อมูลการลาในวันที่เลือก',
                              style: TextStyle(
                                color: selectedCount > 0
                                    ? primary
                                    : Colors.grey,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 16,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    _calendarLegend(
                      color: primary,
                      label: 'วันที่มีพนักงานลา',
                    ),
                    _calendarLegend(
                      color: const Color(0xFF16A34A),
                      label: 'วันที่ปัจจุบัน',
                      outlined: true,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Legend ปฏิทิน
  Widget _calendarLegend({
    required Color color,
    required String label,
    bool outlined = false,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: outlined ? Colors.white : color,
            shape: BoxShape.circle,
            border: outlined ? Border.all(color: color, width: 2) : null,
          ),
        ),
        const SizedBox(width: 7),
        Text(
          label,
          style: const TextStyle(
            color: Colors.grey,
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  // วันที่ในปฏิทิน
  Widget _calendarDay(int day) {
    final date = DateTime(
      selectedMonth.year,
      selectedMonth.month,
      day,
    );

    final key = dateKey(date);
    final count = calendarData[key] ?? 0;
    final isToday = dateKey(DateTime.now()) == key;
    final isSelected = dateKey(selectedCalendarDate) == key;

    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () {
        setState(() {
          selectedCalendarDate = date;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        margin: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          color: isSelected
              ? primary.withValues(alpha: 0.13)
              : count > 0
                  ? primary.withValues(alpha: 0.055)
                  : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isToday
                ? const Color(0xFF16A34A)
                : isSelected
                    ? primary
                    : count > 0
                        ? primary.withValues(alpha: 0.18)
                        : const Color(0xFFE8EEF5),
            width: isToday || isSelected ? 1.5 : 1,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '$day',
              style: TextStyle(
                color: isSelected || count > 0 ? primary : dark,
                fontWeight: isToday || isSelected || count > 0
                    ? FontWeight.bold
                    : FontWeight.normal,
                fontSize: 13,
              ),
            ),
            if (count > 0) ...[
              const SizedBox(height: 4),
              Container(
                constraints: const BoxConstraints(minWidth: 22),
                padding: const EdgeInsets.symmetric(
                  horizontal: 5,
                  vertical: 2,
                ),
                decoration: BoxDecoration(
                  color: primary,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '$count',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ] else if (isToday) ...[
              const SizedBox(height: 4),
              Container(
                width: 5,
                height: 5,
                decoration: const BoxDecoration(
                  color: Color(0xFF16A34A),
                  shape: BoxShape.circle,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // FOOTER
  Widget _buildFooter() {
    return Container(
      width: double.infinity,
      color: const Color(0xFF10243A),
      padding: const EdgeInsets.symmetric(
        horizontal: 25,
        vertical: 30,
      ),
      child: const Column(
        children: [
          Icon(
            Icons.event_available,
            color: Colors.white,
            size: 32,
          ),
          SizedBox(height: 10),
          Text(
            'MG LEAVE MANAGEMENT',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              letterSpacing: 1,
            ),
          ),
          SizedBox(height: 5),
          Text(
            'ระบบลางานและลงงานโอที',
            style: TextStyle(
              color: Colors.white60,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}