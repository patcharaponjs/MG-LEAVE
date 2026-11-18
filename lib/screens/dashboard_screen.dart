import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'leave_request_screen.dart';
import 'leave_history_screen.dart';
import 'leave_balance_screen.dart';
import 'leave_approval_screen.dart';
import 'landing_screen.dart';
import 'employee_management_screen.dart';
import 'leave_type_management_screen.dart';
import 'leave_balance_management_screen.dart';
import 'leave_report_screen.dart';
import 'notification_screen.dart';
import 'profile_screen.dart';
import 'leave_calendar_screen.dart';
import 'all_leave_screen.dart';

class DashboardScreen extends StatefulWidget {
  final String fullName;

  const DashboardScreen({super.key, this.fullName = 'พนักงาน'});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final SupabaseClient supabase = Supabase.instance.client;

  String role = '';
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    loadUserRole();
  }

  // โหลดสิทธิ์ผู้ใช้งานจาก Supabase
  Future<void> loadUserRole() async {
    final user = supabase.auth.currentUser;

    if (user == null) {
      if (mounted) {
        setState(() => isLoading = false);
      }
      return;
    }

    try {
      final response = await supabase
          .from('profiles')
          .select('role, is_active')
          .eq('id', user.id)
          .maybeSingle();

      if (!mounted) return;

      if (response == null || response['is_active'] != true) {
        await supabase.auth.signOut();

        if (!mounted) return;

        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const LandingScreen()),
          (route) => false,
        );
        return;
      }

      setState(() {
        role = response['role']?.toString() ?? '';
        isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('ไม่สามารถตรวจสอบสิทธิ์ได้: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  bool get isAdmin => role == 'admin';

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(
        backgroundColor: Color(0xFFF4F7FB),
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (role != 'admin' && role != 'employee') {
      return Scaffold(
        backgroundColor: const Color(0xFFF4F7FB),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.lock_outline, size: 60, color: Colors.red),
              const SizedBox(height: 15),
              const Text(
                'ไม่พบสิทธิ์การใช้งานของบัญชีนี้',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 15),
              ElevatedButton(
                onPressed: () async {
                  await supabase.auth.signOut();

                  if (!context.mounted) return;

                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(builder: (_) => const LandingScreen()),
                    (route) => false,
                  );
                },
                child: const Text('กลับไปหน้าเข้าสู่ระบบ'),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FB),

      appBar: AppBar(
        title: const Text(
          'MG LEAVE MANAGEMENT',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
        ),
        backgroundColor: const Color(0xFF087FD0),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          const NotificationBell(),

          IconButton(
            tooltip: 'ออกจากระบบ',
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await supabase.auth.signOut();

              if (!context.mounted) return;

              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (_) => const LandingScreen()),
                (route) => false,
              );
            },
          ),
        ],
      ),

      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ส่วนต้อนรับ
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF087FD0), Color(0xFF0399D1)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'ยินดีต้อนรับ',
                    style: TextStyle(color: Colors.white70, fontSize: 15),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    widget.fullName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 23,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    isAdmin
                        ? 'ผู้ดูแลระบบ (Administrator)'
                        : 'พนักงาน (Employee)',
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 25),

            const Text(
              'เมนูการใช้งาน',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Color(0xFF142B4A),
              ),
            ),

            const SizedBox(height: 15),

            // เมนูที่พนักงานและ Admin ใช้ร่วมกัน
            menuCard(
              context: context,
              title: 'ยื่นใบลา',
              subtitle: 'สร้างคำขอลางานใหม่',
              icon: Icons.edit_calendar,
              color: Colors.blue,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const LeaveRequestScreen()),
                );
              },
            ),

            menuCard(
              context: context,
              title: 'ประวัติการลา',
              subtitle: 'ตรวจสอบคำขอและสถานะการลา',
              icon: Icons.history,
              color: Colors.orange,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const LeaveHistoryScreen()),
                );
              },
            ),

            menuCard(
              context: context,
              title: 'สิทธิ์วันลา',
              subtitle: 'ตรวจสอบสิทธิ์และวันลาคงเหลือ',
              icon: Icons.calendar_month,
              color: Colors.green,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const LeaveBalanceScreen()),
                );
              },
            ),

            // เมนูเฉพาะ Admin
            if (isAdmin) ...[
              const SizedBox(height: 10),

              const Text(
                'เมนูสำหรับผู้ดูแลระบบ',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF087FD0),
                ),
              ),

              const SizedBox(height: 15),

              menuCard(
                context: context,
                title: 'ดูใบลาพนักงานทั้งหมด',
                subtitle: 'ตรวจสอบประวัติใบลาของพนักงานทุกคน',
                icon: Icons.groups_2_outlined,
                color: const Color(0xFF00897B),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          const LeaveHistoryScreen(showAllEmployees: true),
                    ),
                  );
                },
              ),

              menuCard(
                context: context,
                title: 'อนุมัติใบลา',
                subtitle: 'ตรวจสอบและพิจารณาคำขอลาของพนักงาน',
                icon: Icons.fact_check,
                color: Colors.purple,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const LeaveApprovalScreen(),
                    ),
                  );
                },
              ),

              menuCard(
                context: context,
                title: 'จัดการพนักงาน',
                subtitle: 'ดูรายชื่อและข้อมูลพนักงาน',
                icon: Icons.people,
                color: Colors.teal,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const EmployeeManagementScreen(),
                    ),
                  );
                },
              ),

              menuCard(
                context: context,
                title: 'จัดการประเภทวันลา',
                subtitle: 'เพิ่ม แก้ไข และกำหนดวันลาต่อปี',
                icon: Icons.event_note,
                color: const Color(0xFF00897B),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const LeaveTypeManagementScreen(),
                    ),
                  );
                },
              ),

              menuCard(
                context: context,
                title: 'กำหนดสิทธิ์วันลา',
                subtitle: 'กำหนดจำนวนวันลาให้พนักงานรายบุคคล',
                icon: Icons.card_giftcard,
                color: Colors.indigo,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const LeaveBalanceManagementScreen(),
                    ),
                  );
                },
              ),

              menuCard(
                context: context,
                title: 'รายงานสรุปการลา',
                subtitle: 'วิเคราะห์ข้อมูลและสถิติการลา',
                icon: Icons.analytics_outlined,
                color: const Color(0xFF8E44AD),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const LeaveReportScreen(),
                    ),
                  );
                },
              ),
            ],
            menuCard(
              context: context,
              title: 'ข้อมูลส่วนตัว',
              subtitle: 'ตรวจสอบข้อมูลบัญชีและข้อมูลการทำงาน',
              icon: Icons.account_circle_outlined,
              color: const Color(0xFF087FD0),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ProfileScreen()),
                );
              },
            ),
            menuCard(
              context: context,
              title: 'ปฏิทินการลา',
              subtitle: 'ดูปฏิทินและรายการลาของพนักงาน',
              icon: Icons.calendar_month,
              color: const Color(0xFF00897B),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        LeaveCalendarScreen(showAllEmployees: isAdmin),
                  ),
                );
              },
            ),
            const SizedBox(height: 10),

            menuCard(
              context: context,
              title: 'ใบลาทั้งหมด',
              subtitle: 'ดูข้อมูลการลาของพนักงานทุกคน (ดูได้อย่างเดียว)',
              icon: Icons.groups_2_outlined,
              color: const Color(0xFF00897B),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AllLeaveScreen()),
                );
              },
            ),

            const SizedBox(height: 20),

            // ข้อมูลระบบ
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(17),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(15),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.info_outline,
                    color: Color(0xFF087FD0),
                    size: 25,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'MG LEAVE MANAGEMENT\n'
                      'ระบบบริหารจัดการการลางาน\n'
                      'สิทธิ์ผู้ใช้งาน: ${isAdmin ? 'Admin' : 'Employee'}',
                      style: const TextStyle(
                        color: Color(0xFF142B4A),
                        fontSize: 13,
                        height: 1.6,
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
  }

  // Widget เมนู
  Widget menuCard({
    required BuildContext context,
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 13),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        child: InkWell(
          borderRadius: BorderRadius.circular(15),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(17),
            child: Row(
              children: [
                Container(
                  width: 53,
                  height: 53,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(icon, color: color, size: 28),
                ),
                const SizedBox(width: 15),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF142B4A),
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.arrow_forward_ios,
                  size: 16,
                  color: Colors.grey,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ==========================================
// ปุ่มแจ้งเตือน
// ==========================================

class NotificationBell extends StatelessWidget {
  const NotificationBell({super.key});

  @override
  Widget build(BuildContext context) {
    final supabase = Supabase.instance.client;
    final user = supabase.auth.currentUser;

    if (user == null) {
      return const SizedBox.shrink();
    }

    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: supabase
          .from('notifications')
          .stream(primaryKey: ['id'])
          .eq('user_id', user.id)
          .eq('is_read', false),
      builder: (context, snapshot) {
        final unreadCount = snapshot.data?.length ?? 0;

        return IconButton(
          tooltip: 'การแจ้งเตือน',
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const NotificationScreen()),
            );
          },
          icon: Stack(
            clipBehavior: Clip.none,
            children: [
              const Icon(Icons.notifications_outlined, size: 28),

              if (unreadCount > 0)
                Positioned(
                  right: -5,
                  top: -5,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    constraints: const BoxConstraints(
                      minWidth: 18,
                      minHeight: 18,
                    ),
                    decoration: const BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      unreadCount > 99 ? '99+' : '$unreadCount',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
