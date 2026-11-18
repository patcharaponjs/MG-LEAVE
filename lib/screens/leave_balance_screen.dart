
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class LeaveBalanceScreen extends StatefulWidget {
  const LeaveBalanceScreen({super.key});

  @override
  State<LeaveBalanceScreen> createState() =>
      _LeaveBalanceScreenState();
}

class _LeaveBalanceScreenState extends State<LeaveBalanceScreen> {
  final SupabaseClient supabase = Supabase.instance.client;

  List<Map<String, dynamic>> balances = [];
  bool isLoading = true;
  String? errorMessage;

  @override
  void initState() {
    super.initState();
    loadLeaveBalances();
  }

  Future<void> loadLeaveBalances() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      final user = supabase.auth.currentUser;

      if (user == null) {
        throw Exception('กรุณาเข้าสู่ระบบก่อน');
      }

      final currentYear = DateTime.now().year;

      final response = await supabase
          .from('leave_balances')
          .select('''
            id,
            employee_id,
            leave_type_id,
            leave_year,
            entitled_days,
            used_days,
            remaining_days,
            leave_types (
              leave_name
            )
          ''')
          .eq('employee_id', user.id)
          .eq('leave_year', currentYear)
          .order('id');

      balances = List<Map<String, dynamic>>.from(response);
    } catch (e) {
      errorMessage = e.toString();
    }

    if (mounted) {
      setState(() {
        isLoading = false;
      });
    }
  }

  double toDouble(dynamic value) {
    if (value == null) return 0;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString()) ?? 0;
  }

  String formatDays(dynamic value) {
    final number = toDouble(value);

    if (number == number.roundToDouble()) {
      return number.toInt().toString();
    }

    return number.toStringAsFixed(1);
  }

  @override
  Widget build(BuildContext context) {
    final currentYear = DateTime.now().year;

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FA),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1769AA),
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'สิทธิ์วันลา',
          style: TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            onPressed: loadLeaveBalances,
            icon: const Icon(Icons.refresh),
            tooltip: 'รีเฟรชข้อมูล',
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
                  onRefresh: loadLeaveBalances,
                  child: balances.isEmpty
                      ? _buildEmpty(currentYear)
                      : _buildContent(currentYear),
                ),
    );
  }

  Widget _buildContent(int year) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [
                Color(0xFF1769AA),
                Color(0xFF3295D5),
              ],
            ),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.calendar_month,
                  color: Colors.white,
                  size: 30,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'สิทธิ์การลาของฉัน',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 19,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      'รายละเอียดสิทธิ์วันลาประจำปี $year',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 22),
        const Text(
          'รายละเอียดสิทธิ์การลา',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Color(0xFF263445),
          ),
        ),
        const SizedBox(height: 5),
        const Text(
          'ตรวจสอบสิทธิ์และจำนวนวันลาคงเหลือแยกตามประเภท',
          style: TextStyle(
            fontSize: 13,
            color: Colors.grey,
          ),
        ),
        const SizedBox(height: 15),
        ...balances.map((item) => _buildBalanceCard(item)),
      ],
    );
  }

  String getLeaveDescription(String leaveName) {
    final name = leaveName.trim();

    if (name.contains('ป่วย')) {
      return 'สามารถลาได้ตามความจำเป็นเมื่อเจ็บป่วยจริง '
          'โดยได้รับค่าจ้างไม่เกิน 30 วันทำงานต่อปี';
    }

    if (name.contains('กิจ')) {
      return 'มีสิทธิ์ลากิจธุระอันจำเป็นไม่น้อยกว่า '
          '3 วันทำงานต่อปี โดยได้รับค่าจ้างตามกฎหมาย';
    }

    if (name.contains('พักร้อน') || name.contains('ประจำปี')) {
      return 'เมื่อทำงานครบ 1 ปี มีสิทธิ์วันหยุดพักผ่อนประจำปี '
          'ไม่น้อยกว่า 6 วันทำงาน';
    }

    if (name.contains('คลอด')) {
      return 'มีสิทธิ์ลาคลอดบุตรได้ไม่เกิน 120 วันต่อครรภ์ '
          'รวมวันหยุดตามกฎหมาย';
    }

    if (name.contains('อุปสมบท')) {
      return 'ตรวจสอบจำนวนวันลาและเงื่อนไขตามระเบียบของหน่วยงาน';
    }

    return 'ตรวจสอบสิทธิ์และเงื่อนไขการลาตามระเบียบของหน่วยงาน';
  }

  IconData getLeaveIcon(String leaveName) {
    final name = leaveName.trim();

    if (name.contains('ป่วย')) {
      return Icons.local_hospital_outlined;
    }

    if (name.contains('กิจ')) {
      return Icons.business_center_outlined;
    }

    if (name.contains('พักร้อน') || name.contains('ประจำปี')) {
      return Icons.beach_access_outlined;
    }

    if (name.contains('คลอด')) {
      return Icons.child_friendly_outlined;
    }

    if (name.contains('อุปสมบท')) {
      return Icons.temple_buddhist_outlined;
    }

    return Icons.event_available;
  }

  Color getLeaveColor(String leaveName) {
    final name = leaveName.trim();

    if (name.contains('ป่วย')) {
      return const Color(0xFFE74C3C);
    }

    if (name.contains('กิจ')) {
      return const Color(0xFF2196A5);
    }

    if (name.contains('พักร้อน') || name.contains('ประจำปี')) {
      return const Color(0xFF2E9D65);
    }

    if (name.contains('คลอด')) {
      return const Color(0xFF9B59B6);
    }

    if (name.contains('อุปสมบท')) {
      return const Color(0xFFE39A27);
    }

    return const Color(0xFF1769AA);
  }

  Widget _buildBalanceCard(Map<String, dynamic> item) {
    final leaveType = item['leave_types'];

    final leaveName = leaveType is Map
        ? (leaveType['leave_name'] ?? 'ไม่ระบุประเภทการลา')
            .toString()
        : 'ไม่ระบุประเภทการลา';

    final entitled = toDouble(item['entitled_days']);
    final used = toDouble(item['used_days']);
    final remaining = toDouble(item['remaining_days']);

    final progress = entitled > 0
        ? (used / entitled).clamp(0.0, 1.0)
        : 0.0;

    final color = getLeaveColor(leaveName);

    return Container(
      margin: const EdgeInsets.only(bottom: 15),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(17),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.045),
            blurRadius: 12,
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
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(
                  getLeaveIcon(leaveName),
                  color: color,
                  size: 27,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  leaveName,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF263445),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 13),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF5F7FA),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.info_outline,
                  color: color,
                  size: 19,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    getLeaveDescription(leaveName),
                    style: const TextStyle(
                      fontSize: 12,
                      height: 1.5,
                      color: Color(0xFF596579),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _dayColumn(
                  'สิทธิ์ทั้งหมด',
                  entitled,
                  color,
                ),
              ),
              Expanded(
                child: _dayColumn(
                  'ใช้ไปแล้ว',
                  used,
                  const Color(0xFFE39A27),
                ),
              ),
              Expanded(
                child: _dayColumn(
                  'คงเหลือ',
                  remaining,
                  const Color(0xFF21965F),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'การใช้สิทธิ์วันลา',
                style: TextStyle(
                  fontSize: 12,
                  color: Color(0xFF596579),
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                '${(progress * 100).toStringAsFixed(0)}%',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 9,
              backgroundColor: const Color(0xFFE9EDF2),
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'ใช้สิทธิ์แล้ว ${formatDays(used)} จาก ${formatDays(entitled)} วัน',
            style: const TextStyle(
              fontSize: 12,
              color: Colors.grey,
            ),
          ),
        ],
      ),
    );
  }

  Widget _dayColumn(String title, double value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: Colors.grey,
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 7),
        Text(
          '${formatDays(value)} วัน',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildEmpty(int year) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(25),
      children: [
        const SizedBox(height: 100),
        Icon(
          Icons.calendar_month_outlined,
          size: 75,
          color: Colors.grey.shade400,
        ),
        const SizedBox(height: 20),
        const Center(
          child: Text(
            'ยังไม่มีข้อมูลสิทธิ์วันลา',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(height: 10),
        Center(
          child: Text(
            'ยังไม่มีข้อมูลสิทธิ์วันลาสำหรับปี $year',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.grey,
            ),
          ),
        ),
        const SizedBox(height: 18),
        const Center(
          child: Text(
            'กรุณาติดต่อผู้ดูแลระบบเพื่อกำหนดสิทธิ์วันลา',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Color(0xFF1769AA),
              fontSize: 13,
            ),
          ),
        ),
      ],
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
              color: Colors.red,
              size: 55,
            ),
            const SizedBox(height: 12),
            const Text(
              'ไม่สามารถโหลดข้อมูลสิทธิ์วันลาได้',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              errorMessage ?? '',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 18),
            ElevatedButton.icon(
              onPressed: loadLeaveBalances,
              icon: const Icon(Icons.refresh),
              label: const Text('ลองอีกครั้ง'),
            ),
          ],
        ),
      ),
    );
  }
}
