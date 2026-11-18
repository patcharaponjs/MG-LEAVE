
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class NotificationScreen extends StatefulWidget {
  const NotificationScreen({super.key});

  @override
  State<NotificationScreen> createState() =>
      _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  final SupabaseClient supabase = Supabase.instance.client;

  List<Map<String, dynamic>> notifications = [];

  bool isLoading = true;
  bool isMarkingAll = false;

  Timer? _notificationTimer;
  bool _isRefreshing = false;

  @override
  void initState() {
    super.initState();

    loadNotifications();

    // ตรวจสอบการแจ้งเตือนใหม่ทุก 10 วินาที
    _notificationTimer = Timer.periodic(
      const Duration(seconds: 10),
      (_) {
        loadNotifications(silent: true);
      },
    );
  }

  @override
  void dispose() {
    _notificationTimer?.cancel();
    super.dispose();
  }

  // โหลดรายการแจ้งเตือน
  Future<void> loadNotifications({
    bool silent = false,
  }) async {
    if (_isRefreshing) return;

    final user = supabase.auth.currentUser;

    if (user == null) {
      if (!mounted) return;

      setState(() {
        isLoading = false;
      });

      return;
    }

    _isRefreshing = true;

    try {
      final response = await supabase
          .from('notifications')
          .select()
          .eq('user_id', user.id)
          .order('created_at', ascending: false);

      if (!mounted) return;

      setState(() {
        notifications =
            List<Map<String, dynamic>>.from(response);
        isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        isLoading = false;
      });

      // ไม่แสดง SnackBar ซ้ำระหว่างตรวจสอบอัตโนมัติ
      if (!silent) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('โหลดการแจ้งเตือนไม่สำเร็จ: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      _isRefreshing = false;
    }
  }

  // อ่านการแจ้งเตือนรายการเดียว
  Future<void> markAsRead(int id) async {
    final user = supabase.auth.currentUser;

    if (user == null) return;

    try {
      await supabase
          .from('notifications')
          .update({'is_read': true})
          .eq('id', id)
          .eq('user_id', user.id);

      if (!mounted) return;

      setState(() {
        final index = notifications.indexWhere(
          (item) => item['id'] == id,
        );

        if (index != -1) {
          notifications[index]['is_read'] = true;
        }
      });
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('ไม่สามารถอ่านแจ้งเตือนได้: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // อ่านแจ้งเตือนทั้งหมด
  Future<void> markAllAsRead() async {
    final user = supabase.auth.currentUser;

    if (user == null) return;

    setState(() => isMarkingAll = true);

    try {
      await supabase
          .from('notifications')
          .update({'is_read': true})
          .eq('user_id', user.id)
          .eq('is_read', false);

      if (!mounted) return;

      setState(() {
        for (final item in notifications) {
          item['is_read'] = true;
        }

        isMarkingAll = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('อ่านการแจ้งเตือนทั้งหมดแล้ว'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;

      setState(() => isMarkingAll = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('เกิดข้อผิดพลาด: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  int get unreadCount {
    return notifications
        .where((item) => item['is_read'] == false)
        .length;
  }

  // แปลงวันที่
  String formatDate(dynamic value) {
    if (value == null) return '-';

    try {
      final date = DateTime.parse(value.toString()).toLocal();

      final day = date.day.toString().padLeft(2, '0');
      final month = date.month.toString().padLeft(2, '0');
      final year = date.year + 543;
      final hour = date.hour.toString().padLeft(2, '0');
      final minute = date.minute.toString().padLeft(2, '0');

      return '$day/$month/$year เวลา $hour:$minute น.';
    } catch (_) {
      return '-';
    }
  }

  IconData getNotificationIcon(String title) {
    if (title.contains('อนุมัติ')) {
      return Icons.check_circle;
    }

    if (title.contains('ปฏิเสธ')) {
      return Icons.cancel;
    }

    if (title.contains('คำขอลาใหม่')) {
      return Icons.assignment_add;
    }

    return Icons.notifications_active;
  }

  Color getNotificationColor(String title) {
    if (title.contains('อนุมัติ')) {
      return Colors.green;
    }

    if (title.contains('ปฏิเสธ')) {
      return Colors.red;
    }

    if (title.contains('คำขอลาใหม่')) {
      return Colors.blue;
    }

    return Colors.orange;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FB),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1769AA),
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'การแจ้งเตือน',
          style: TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          if (unreadCount > 0)
            TextButton.icon(
              onPressed: isMarkingAll ? null : markAllAsRead,
              icon: isMarkingAll
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(
                      Icons.done_all,
                      color: Colors.white,
                      size: 19,
                    ),
              label: const Text(
                'อ่านทั้งหมด',
                style: TextStyle(color: Colors.white),
              ),
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => loadNotifications(),
        child: isLoading
            ? const Center(
                child: CircularProgressIndicator(),
              )
            : notifications.isEmpty
                ? ListView(
                    children: const [
                      SizedBox(height: 150),
                      Icon(
                        Icons.notifications_off_outlined,
                        size: 75,
                        color: Colors.grey,
                      ),
                      SizedBox(height: 16),
                      Center(
                        child: Text(
                          'ยังไม่มีการแจ้งเตือน',
                          style: TextStyle(
                            fontSize: 17,
                            color: Colors.grey,
                          ),
                        ),
                      ),
                    ],
                  )
                : Column(
                    children: [
                      Container(
                        width: double.infinity,
                        margin: const EdgeInsets.all(16),
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.notifications_active,
                              color: Color(0xFF1769AA),
                              size: 32,
                            ),
                            const SizedBox(width: 14),
                            const Expanded(
                              child: Text(
                                'รายการแจ้งเตือนทั้งหมด',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 13,
                                vertical: 7,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFE3F2FD),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                'ยังไม่อ่าน $unreadCount',
                                style: const TextStyle(
                                  color: Color(0xFF1769AA),
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: ListView.builder(
                          padding: const EdgeInsets.fromLTRB(
                            16,
                            0,
                            16,
                            20,
                          ),
                          itemCount: notifications.length,
                          itemBuilder: (context, index) {
                            final item = notifications[index];

                            final id = item['id'] as int;
                            final title =
                                item['title']?.toString() ?? 'แจ้งเตือน';
                            final message =
                                item['message']?.toString() ?? '';
                            final isRead =
                                item['is_read'] == true;

                            final color =
                                getNotificationColor(title);

                            return Card(
                              elevation: 1,
                              margin: const EdgeInsets.only(
                                bottom: 12,
                              ),
                              color: isRead
                                  ? Colors.white
                                  : const Color(0xFFEAF4FF),
                              shape: RoundedRectangleBorder(
                                borderRadius:
                                    BorderRadius.circular(15),
                                side: BorderSide(
                                  color: isRead
                                      ? Colors.transparent
                                      : const Color(0xFFB9D9F5),
                                ),
                              ),
                              child: InkWell(
                                borderRadius:
                                    BorderRadius.circular(15),
                                onTap: () {
                                  if (!isRead) {
                                    markAsRead(id);
                                  }
                                },
                                child: Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      CircleAvatar(
                                        radius: 23,
                                        backgroundColor:
                                            color.withValues(alpha: 0.12),
                                        child: Icon(
                                          getNotificationIcon(title),
                                          color: color,
                                          size: 25,
                                        ),
                                      ),
                                      const SizedBox(width: 13),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                Expanded(
                                                  child: Text(
                                                    title,
                                                    style: const TextStyle(
                                                      fontSize: 15,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                    ),
                                                  ),
                                                ),
                                                if (!isRead)
                                                  Container(
                                                    width: 9,
                                                    height: 9,
                                                    decoration:
                                                        const BoxDecoration(
                                                      color: Colors.blue,
                                                      shape:
                                                          BoxShape.circle,
                                                    ),
                                                  ),
                                              ],
                                            ),
                                            const SizedBox(height: 7),
                                            Text(
                                              message,
                                              style: const TextStyle(
                                                fontSize: 14,
                                                color: Colors.black87,
                                              ),
                                            ),
                                            const SizedBox(height: 10),
                                            Text(
                                              formatDate(
                                                item['created_at'],
                                              ),
                                              style: const TextStyle(
                                                fontSize: 12,
                                                color: Colors.grey,
                                              ),
                                            ),
                                            if (!isRead)
                                              const Padding(
                                                padding:
                                                    EdgeInsets.only(top: 8),
                                                child: Text(
                                                  'แตะเพื่อทำเครื่องหมายว่าอ่านแล้ว',
                                                  style: TextStyle(
                                                    fontSize: 11,
                                                    color: Colors.blue,
                                                  ),
                                                ),
                                              ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
      ),
    );
  }
}
