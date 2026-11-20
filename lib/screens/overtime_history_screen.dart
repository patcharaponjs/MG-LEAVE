
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class OvertimeHistoryScreen extends StatefulWidget {
  const OvertimeHistoryScreen({super.key});

  @override
  State<OvertimeHistoryScreen> createState() =>
      _OvertimeHistoryScreenState();
}

class _OvertimeHistoryScreenState
    extends State<OvertimeHistoryScreen> {
  final SupabaseClient supabase = Supabase.instance.client;

  bool isLoading = true;
  bool isRefreshing = false;
  bool isDeleting = false;
  String? errorMessage;

  List<Map<String, dynamic>> requests = [];

  @override
  void initState() {
    super.initState();
    loadRequests();
  }

  Future<void> loadRequests({bool refresh = false}) async {
    if (isRefreshing) return;

    isRefreshing = true;

    if (mounted) {
      setState(() {
        if (!refresh) isLoading = true;
        errorMessage = null;
      });
    }

    try {
      final user = supabase.auth.currentUser;

      if (user == null) {
        throw Exception('กรุณาเข้าสู่ระบบก่อน');
      }

      final data = await supabase
          .from('overtime_requests')
          .select()
          .eq('user_id', user.id)
          .order('created_at', ascending: false);

      if (!mounted) return;

      setState(() {
        requests = List<Map<String, dynamic>>.from(data);
        isLoading = false;
        errorMessage = null;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        errorMessage = e.toString();
        isLoading = false;
      });
    } finally {
      isRefreshing = false;
    }
  }

  // =========================
  // ลบ OT รายรายการ
  // =========================
  Future<void> deleteRequest(Map<String, dynamic> item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('ยืนยันการลบ'),
        content: Text(
          'ต้องการลบประวัติ OT วันที่ '
          '${formatDate(item['work_date'])} '
          'เวลา ${formatTime(item['start_time'])} - '
          '${formatTime(item['end_time'])} น. หรือไม่?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('ยกเลิก'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('ลบ'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    if (isDeleting) return;

    setState(() {
      isDeleting = true;
    });

    try {
      final user = supabase.auth.currentUser;

      if (user == null) {
        throw Exception('กรุณาเข้าสู่ระบบก่อน');
      }

      await supabase
          .from('overtime_requests')
          .delete()
          .eq('id', item['id'])
          .eq('user_id', user.id);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('ลบประวัติ OT เรียบร้อยแล้ว'),
          backgroundColor: Colors.green,
        ),
      );

      await loadRequests(refresh: true);
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('ลบไม่สำเร็จ: $e'),
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

  // =========================
  // เคลียร์ประวัติ OT ทั้งหมด
  // =========================
  Future<void> clearAllRequests() async {
    if (requests.isEmpty || isDeleting) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('เคลียร์ประวัติ OT ทั้งหมด'),
        content: const Text(
          'คุณต้องการลบประวัติการขอ OT ทั้งหมดของคุณหรือไม่?\n\n'
          'ข้อมูลที่ลบแล้วจะไม่สามารถกู้คืนได้',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('ยกเลิก'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('เคลียร์ทั้งหมด'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() {
      isDeleting = true;
    });

    try {
      final user = supabase.auth.currentUser;

      if (user == null) {
        throw Exception('กรุณาเข้าสู่ระบบก่อน');
      }

      await supabase
          .from('overtime_requests')
          .delete()
          .eq('user_id', user.id);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('เคลียร์ประวัติ OT ทั้งหมดเรียบร้อยแล้ว'),
          backgroundColor: Colors.green,
        ),
      );

      await loadRequests(refresh: true);
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('เคลียร์ประวัติไม่สำเร็จ: $e'),
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

    if (time.length >= 5) {
      return time.substring(0, 5);
    }

    return time;
  }

  Color statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'approved':
        return Colors.green;
      case 'rejected':
        return Colors.red;
      default:
        return Colors.orange;
    }
  }

  String statusText(String status) {
    switch (status.toLowerCase()) {
      case 'approved':
        return 'อนุมัติแล้ว';
      case 'rejected':
        return 'ไม่อนุมัติ';
      default:
        return 'รออนุมัติ';
    }
  }

  Widget buildStatus(String status) {
    final color = statusColor(status);

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        statusText(status),
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
      ),
    );
  }

  Widget buildRequestCard(Map<String, dynamic> item) {
    final status = item['status']?.toString() ?? 'pending';
    final hours = item['total_hours'];
    final rejectionReason = item['rejection_reason']?.toString();

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
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
                const Icon(
                  Icons.calendar_month,
                  color: Colors.blue,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    formatDate(item['work_date']),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                buildStatus(status),
              ],
            ),
            const Divider(height: 24),
            Row(
              children: [
                const Icon(Icons.access_time, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${formatTime(item['start_time'])} - '
                    '${formatTime(item['end_time'])} น.',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                const Icon(Icons.timelapse, size: 18),
                const SizedBox(width: 8),
                Text('รวม ${hours ?? '-'} ชั่วโมง'),
              ],
            ),
            const SizedBox(height: 10),
            const Text(
              'เหตุผลในการขอ OT',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(item['reason']?.toString() ?? '-'),

            if (status.toLowerCase() == 'rejected' &&
                rejectionReason != null &&
                rejectionReason.trim().isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.07),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: Colors.red.withValues(alpha: 0.15),
                  ),
                ),
                child: Text(
                  'เหตุผลที่ไม่อนุมัติ: $rejectionReason',
                  style: const TextStyle(
                    color: Colors.red,
                  ),
                ),
              ),
            ],

            // ปุ่มลบรายรายการ
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: OutlinedButton.icon(
                onPressed: isDeleting
                    ? null
                    : () => deleteRequest(item),
                icon: const Icon(
                  Icons.delete_outline,
                  color: Colors.red,
                ),
                label: const Text('ลบรายการ'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.red,
                  side: const BorderSide(color: Colors.red),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget buildEmptyState() {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: const [
        SizedBox(height: 140),
        Icon(
          Icons.history,
          size: 60,
          color: Colors.grey,
        ),
        SizedBox(height: 12),
        Center(
          child: Text(
            'ยังไม่มีประวัติการขอ OT',
            style: TextStyle(
              color: Colors.grey,
              fontSize: 16,
            ),
          ),
        ),
        SizedBox(height: 8),
        Center(
          child: Text(
            'เมื่อยื่นคำขอ OT รายการจะแสดงที่นี่',
            style: TextStyle(
              color: Colors.grey,
              fontSize: 13,
            ),
          ),
        ),
      ],
    );
  }

  Widget buildErrorState() {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        const SizedBox(height: 120),
        const Icon(
          Icons.error_outline,
          color: Colors.red,
          size: 48,
        ),
        const SizedBox(height: 12),
        Center(
          child: Text(
            'โหลดข้อมูลไม่สำเร็จ\n$errorMessage',
            textAlign: TextAlign.center,
          ),
        ),
        const SizedBox(height: 12),
        Center(
          child: ElevatedButton.icon(
            onPressed: () => loadRequests(),
            icon: const Icon(Icons.refresh),
            label: const Text('ลองอีกครั้ง'),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FB),
      appBar: AppBar(
        title: const Text('ประวัติการขอ OT'),
        backgroundColor: Colors.blue.shade700,
        foregroundColor: Colors.white,
        actions: [
          // ปุ่มเคลียร์ประวัติทั้งหมด
          if (requests.isNotEmpty && !isLoading)
            IconButton(
              onPressed: isDeleting ? null : clearAllRequests,
              icon: const Icon(Icons.delete_sweep),
              tooltip: 'เคลียร์ประวัติทั้งหมด',
            ),

          IconButton(
            onPressed: isRefreshing
                ? null
                : () => loadRequests(refresh: true),
            icon: const Icon(Icons.refresh),
            tooltip: 'รีเฟรช',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => loadRequests(refresh: true),
        child: isLoading
            ? ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: const [
                  SizedBox(height: 250),
                  Center(child: CircularProgressIndicator()),
                ],
              )
            : errorMessage != null
                ? buildErrorState()
                : requests.isEmpty
                    ? buildEmptyState()
                    : ListView.builder(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.all(16),
                        itemCount: requests.length,
                        itemBuilder: (context, index) {
                          return buildRequestCard(requests[index]);
                        },
                      ),
      ),
    );
  }
}
