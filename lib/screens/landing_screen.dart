
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

  // Controller และ Key สำหรับเลื่อนไปยังปฏิทิน
  final ScrollController _scrollController = ScrollController();
  final GlobalKey _calendarKey = GlobalKey();

  StreamSubscription<AuthState>? authSubscription;

  String fullName = '';
  String role = '';
  bool isLoggedIn = false;
  bool profileLoading = true;

  bool dataLoading = true;
  String? dataError;

  int totalRequests = 0;
  int pendingRequests = 0;
  int approvedRequests = 0;
  int rejectedRequests = 0;

  Map<String, int> calendarData = {};

  DateTime selectedMonth = DateTime.now();

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

    authSubscription =
        supabase.auth.onAuthStateChange.listen((data) {
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

  Future<void> loadUser() async {
    final user = supabase.auth.currentUser;

    if (user == null) {
      if (!mounted) return;

      setState(() {
        isLoggedIn = false;
        fullName = '';
        role = '';
        profileLoading = false;
      });
      return;
    }

    try {
      final profile = await supabase
          .from('profiles')
          .select('full_name, role, is_active')
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
        profileLoading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        isLoggedIn = true;
        fullName = user.email ?? 'ผู้ใช้งาน';
        profileLoading = false;
      });
    }
  }

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

  String dateKey(DateTime date) {
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');

    return '${date.year}-$month-$day';
  }

  Future<void> openLogin() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const LoginScreen(),
      ),
    );

    loadUser();
  }

  Future<void> logout() async {
    await supabase.auth.signOut();

    if (!mounted) return;

    setState(() {
      isLoggedIn = false;
      fullName = '';
      role = '';
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('ออกจากระบบเรียบร้อยแล้ว'),
      ),
    );
  }

  void openDashboard() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => DashboardScreen(fullName: fullName),
      ),
    );
  }

  void changeMonth(int amount) {
    setState(() {
      selectedMonth = DateTime(
        selectedMonth.year,
        selectedMonth.month + amount,
        1,
      );
    });

    loadPublicData();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: background,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: loadPublicData,
          child: CustomScrollView(
            controller: _scrollController,
            slivers: [
              SliverToBoxAdapter(
                child: _buildHeader(),
              ),
              SliverToBoxAdapter(
                child: _buildHero(),
              ),
              SliverToBoxAdapter(
                child: _buildOverview(),
              ),
              SliverToBoxAdapter(
                child: _buildCalendar(),
              ),
              SliverToBoxAdapter(
                child: _buildFooter(),
              ),
            ],
          ),
        ),
      ),
    );
  }

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
                      'ระบบบริหารจัดการการลางาน',
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
                  child: CircularProgressIndicator(strokeWidth: 2),
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
                        leading: Icon(Icons.logout, color: Colors.red),
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
                        const CircleAvatar(
                          radius: 17,
                          backgroundColor: primary,
                          child: Icon(
                            Icons.person,
                            color: Colors.white,
                            size: 20,
                          ),
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
                        'LEAVE MANAGEMENT SYSTEM',
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
                      'ระบบบริหารจัดการวันลาออนไลน์',
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
                            side: const BorderSide(color: Colors.white70),
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
                'ข้อมูลสรุปจากระบบบริหารจัดการวันลา',
                style: TextStyle(color: Colors.grey, fontSize: 13),
              ),
              const SizedBox(height: 17),
              if (dataLoading)
                const Center(child: CircularProgressIndicator())
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
        border: Border.all(color: const Color(0xFFE8EEF5)),
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

    // DateTime weekday: จันทร์ = 1, อาทิตย์ = 7
    final offset = firstDay.weekday % 7;

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
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFFE8EEF5)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'ปฏิทินการลา',
                  style: TextStyle(
                    color: dark,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 15),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      onPressed: () => changeMonth(-1),
                      icon: const Icon(Icons.chevron_left),
                    ),
                    Text(
                      '${months[selectedMonth.month - 1]} ${selectedMonth.year + 543}',
                      style: const TextStyle(
                        color: dark,
                        fontWeight: FontWeight.bold,
                        fontSize: 17,
                      ),
                    ),
                    IconButton(
                      onPressed: () => changeMonth(1),
                      icon: const Icon(Icons.chevron_right),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                GridView.count(
                  crossAxisCount: 7,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  childAspectRatio: 1.2,
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
                            color: Colors.grey,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    for (int i = 0; i < offset; i++)
                      const SizedBox.shrink(),
                    for (int day = 1; day <= daysInMonth; day++)
                      _calendarDay(day),
                  ],
                ),
                const SizedBox(height: 15),
                Row(
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: const BoxDecoration(
                        color: Color(0xFF087FD0),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 7),
                    const Text(
                      'วันที่มีพนักงานลา',
                      style: TextStyle(
                        color: Colors.grey,
                        fontSize: 12,
                      ),
                    ),
                    const Spacer(),
                    if (dataLoading)
                      const Text(
                        'กำลังโหลด...',
                        style: TextStyle(
                          color: Colors.grey,
                          fontSize: 11,
                        ),
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

  Widget _calendarDay(int day) {
    final date = DateTime(
      selectedMonth.year,
      selectedMonth.month,
      day,
    );

    final key = dateKey(date);
    final count = calendarData[key] ?? 0;
    final isToday = dateKey(DateTime.now()) == key;

    return Container(
      margin: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: count > 0
            ? primary.withValues(alpha: 0.12)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(9),
        border: isToday
            ? Border.all(color: primary, width: 1.5)
            : null,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            '$day',
            style: TextStyle(
              color: count > 0 ? primary : dark,
              fontWeight: isToday || count > 0
                  ? FontWeight.bold
                  : FontWeight.normal,
            ),
          ),
          if (count > 0)
            Container(
              margin: const EdgeInsets.only(top: 2),
              padding: const EdgeInsets.symmetric(
                horizontal: 5,
                vertical: 1,
              ),
              decoration: BoxDecoration(
                color: primary,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$count',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
        ],
      ),
    );
  }

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
            'ระบบบริหารจัดการการลางาน',
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
