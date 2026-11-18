
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class LeaveBalanceManagementScreen extends StatefulWidget {
  const LeaveBalanceManagementScreen({super.key});

  @override
  State<LeaveBalanceManagementScreen> createState() =>
      _LeaveBalanceManagementScreenState();
}

class _LeaveBalanceManagementScreenState
    extends State<LeaveBalanceManagementScreen> {
  final supabase = Supabase.instance.client;

  bool isLoading = true;
  List<Map<String, dynamic>> employees = [];
  List<Map<String, dynamic>> leaveTypes = [];
  List<Map<String, dynamic>> balances = [];

  @override
  void initState() {
    super.initState();
    loadData();
  }

  Future<void> loadData() async {
    try {
      setState(() => isLoading = true);

      final employeeData = await supabase
          .from('profiles')
          .select('id, employee_code, full_name, is_active')
          .order('full_name');

      final typeData = await supabase
          .from('leave_types')
          .select('id, leave_name, default_days, is_active')
          .order('id');

      final balanceData = await supabase
          .from('leave_balances')
          .select()
          .order('leave_year', ascending: false);

      if (!mounted) return;

      setState(() {
        employees =
            List<Map<String, dynamic>>.from(employeeData);
        leaveTypes =
            List<Map<String, dynamic>>.from(typeData);
        balances =
            List<Map<String, dynamic>>.from(balanceData);
        isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() => isLoading = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('โหลดข้อมูลไม่สำเร็จ: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  double toDouble(dynamic value) {
    if (value == null) return 0;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString()) ?? 0;
  }

  String employeeName(String id) {
    final employee = employees.firstWhere(
      (e) => e['id'].toString() == id,
      orElse: () => {},
    );

    return employee['full_name']?.toString() ??
        'ไม่พบชื่อพนักงาน';
  }

  String leaveName(String id) {
    final type = leaveTypes.firstWhere(
      (e) => e['id'].toString() == id,
      orElse: () => {},
    );

    return type['leave_name']?.toString() ??
        'ไม่พบประเภทวันลา';
  }

  // เพิ่มและแก้ไขสิทธิ์วันลา
  Future<void> showBalanceDialog({
    Map<String, dynamic>? balance,
  }) async {
    String? selectedEmployee =
        balance?['employee_id']?.toString();

    String? selectedLeaveType =
        balance?['leave_type_id']?.toString();

    final yearController = TextEditingController(
      text: balance?['leave_year']?.toString() ??
          DateTime.now().year.toString(),
    );

    final entitledController = TextEditingController(
      text: balance?['entitled_days']?.toString() ?? '',
    );

    final usedDays = toDouble(balance?['used_days'] ?? 0);

    bool saving = false;

    if (balance == null) {
      selectedEmployee = null;
      selectedLeaveType = null;
    }

    await showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final remaining = toDouble(
              entitledController.text,
            ) - usedDays;

            return AlertDialog(
              title: Text(
                balance == null
                    ? 'กำหนดสิทธิ์วันลา'
                    : 'แก้ไขสิทธิ์วันลา',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                ),
              ),
              content: SizedBox(
                width: 450,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      DropdownButtonFormField<String>(
                        value: selectedEmployee,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'เลือกพนักงาน',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.person),
                        ),
                        items: employees
                            .where((e) => e['is_active'] == true)
                            .map((e) {
                          return DropdownMenuItem<String>(
                            value: e['id'].toString(),
                            child: Text(
                              '${e['full_name']} '
                              '(${e['employee_code'] ?? '-'})',
                              overflow: TextOverflow.ellipsis,
                            ),
                          );
                        }).toList(),
                        onChanged: balance != null
                            ? null
                            : (value) {
                                setDialogState(() {
                                  selectedEmployee = value;
                                });
                              },
                      ),
                      const SizedBox(height: 15),
                      DropdownButtonFormField<String>(
                        value: selectedLeaveType,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'ประเภทวันลา',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.event_note),
                        ),
                        items: leaveTypes
                            .where((e) => e['is_active'] == true)
                            .map((e) {
                          return DropdownMenuItem<String>(
                            value: e['id'].toString(),
                            child: Text(e['leave_name'].toString()),
                          );
                        }).toList(),
                        onChanged: balance != null
                            ? null
                            : (value) {
                                setDialogState(() {
                                  selectedLeaveType = value;

                                  final type = leaveTypes.firstWhere(
                                    (e) =>
                                        e['id'].toString() == value,
                                  );

                                  entitledController.text =
                                      type['default_days'].toString();
                                });
                              },
                      ),
                      const SizedBox(height: 15),
                      TextField(
                        controller: yearController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'ปีสิทธิ์วันลา',
                          hintText: 'เช่น 2026',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.calendar_today),
                        ),
                      ),
                      const SizedBox(height: 15),
                      TextField(
                        controller: entitledController,
                        keyboardType:
                            const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: const InputDecoration(
                          labelText: 'จำนวนวันลาที่ได้รับ',
                          suffixText: 'วัน',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.card_giftcard),
                        ),
                        onChanged: (_) {
                          setDialogState(() {});
                        },
                      ),
                      const SizedBox(height: 15),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEAF7F0),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'ใช้สิทธิ์ไปแล้ว: '
                              '${usedDays.toStringAsFixed(1)} วัน',
                            ),
                            const SizedBox(height: 5),
                            Text(
                              'คงเหลือ: '
                              '${remaining.toStringAsFixed(1)} วัน',
                              style: const TextStyle(
                                color: Colors.green,
                                fontWeight: FontWeight.bold,
                                fontSize: 17,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: saving
                      ? null
                      : () => Navigator.pop(dialogContext),
                  child: const Text('ยกเลิก'),
                ),
                ElevatedButton.icon(
                  onPressed: saving
                      ? null
                      : () async {
                          final year = int.tryParse(
                            yearController.text.trim(),
                          );

                          final entitled = double.tryParse(
                            entitledController.text.trim(),
                          );

                          if (selectedEmployee == null ||
                              selectedLeaveType == null ||
                              year == null ||
                              year < 2000 ||
                              year > 9999 ||
                              entitled == null ||
                              entitled < usedDays) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'กรุณาตรวจสอบข้อมูล '
                                  'และจำนวนวันลาต้องไม่น้อยกว่า '
                                  'วันที่ใช้ไปแล้ว',
                                ),
                                backgroundColor: Colors.red,
                              ),
                            );
                            return;
                          }

                          setDialogState(() => saving = true);

                          try {
                            final data = {
                              'employee_id': selectedEmployee,
                              'leave_type_id':
                                  int.parse(selectedLeaveType!),
                              'leave_year': year,
                              'entitled_days': entitled,
                              'used_days': usedDays,
                              'remaining_days': entitled - usedDays,
                            };

                            await supabase
                                .from('leave_balances')
                                .upsert(
                                  data,
                                  onConflict:
                                      'employee_id,leave_type_id,leave_year',
                                );

                            if (!mounted) return;

                            Navigator.pop(dialogContext);
                            await loadData();

                            if (!mounted) return;

                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'บันทึกสิทธิ์วันลาเรียบร้อยแล้ว',
                                ),
                                backgroundColor: Colors.green,
                              ),
                            );
                          } catch (e) {
                            setDialogState(() => saving = false);

                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('บันทึกไม่สำเร็จ: $e'),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        },
                  icon: saving
                      ? const SizedBox(
                          width: 17,
                          height: 17,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.save),
                  label: const Text('บันทึก'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF087FD0),
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            );
          },
        );
      },
    );

    yearController.dispose();
    entitledController.dispose();
  }

  // ลบสิทธิ์รายรายการ
  Future<void> deleteBalance(
    Map<String, dynamic> item,
  ) async {
    final used = toDouble(item['used_days']);

    if (used > 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'ไม่สามารถลบได้ เนื่องจากรายการนี้มีการใช้สิทธิ์ไปแล้ว',
          ),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final employee = employeeName(
      item['employee_id'].toString(),
    );

    final type = leaveName(
      item['leave_type_id'].toString(),
    );

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('ยืนยันการลบ'),
        content: Text(
          'ต้องการลบข้อมูลสิทธิ์วันลานี้หรือไม่?\n\n'
          'พนักงาน: $employee\n'
          'ประเภท: $type\n'
          'ปี: ${item['leave_year']}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('ยกเลิก'),
          ),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(context, true),
            icon: const Icon(Icons.delete),
            label: const Text('ลบข้อมูล'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final id = item['id'];

      if (id == null) {
        throw Exception('ไม่พบรหัสรายการสิทธิ์วันลา');
      }

      await supabase
          .from('leave_balances')
          .delete()
          .eq('id', id);

      await loadData();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('ลบข้อมูลสิทธิ์วันลาเรียบร้อยแล้ว'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('ลบข้อมูลไม่สำเร็จ: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // เคลียร์สิทธิ์ที่ยังไม่เคยใช้ตามปี
  Future<void> clearBalanceByYear() async {
    if (balances.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('ไม่มีข้อมูลสิทธิ์วันลาให้เคลียร์'),
        ),
      );
      return;
    }

    final years = balances
        .map((e) => int.tryParse(e['leave_year'].toString()))
        .whereType<int>()
        .toSet()
        .toList()
      ..sort((a, b) => b.compareTo(a));

    int? selectedYear = years.first;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text(
                'เคลียร์ข้อมูลสิทธิ์วันลา',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'เลือกปีที่ต้องการเคลียร์ข้อมูล '
                    'ระบบจะลบเฉพาะรายการที่ยังไม่เคยใช้สิทธิ์',
                  ),
                  const SizedBox(height: 15),
                  DropdownButtonFormField<int>(
                    value: selectedYear,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'เลือกปี',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.calendar_month),
                    ),
                    items: years.map((year) {
                      return DropdownMenuItem<int>(
                        value: year,
                        child: Text('ปี $year'),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setDialogState(() {
                        selectedYear = value;
                      });
                    },
                  ),
                  const SizedBox(height: 15),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.orange.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Text(
                      'หมายเหตุ: รายการที่มีวันลาใช้ไปแล้ว '
                      'จะไม่ถูกลบ เพื่อป้องกันข้อมูลสิทธิ์ผิดพลาด',
                      style: TextStyle(
                        color: Colors.deepOrange,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () =>
                      Navigator.pop(dialogContext, false),
                  child: const Text('ยกเลิก'),
                ),
                ElevatedButton.icon(
                  onPressed: selectedYear == null
                      ? null
                      : () => Navigator.pop(dialogContext, true),
                  icon: const Icon(Icons.cleaning_services),
                  label: const Text('เคลียร์ข้อมูล'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            );
          },
        );
      },
    );

    if (confirm != true || selectedYear == null) return;

    try {
      final deletedRows = await supabase
          .from('leave_balances')
          .delete()
          .eq('leave_year', selectedYear!)
          .lte('used_days', 0)
          .select('id');

      await loadData();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'เคลียร์ข้อมูลปี $selectedYear เรียบร้อย '
            'ลบได้ ${deletedRows.length} รายการ',
          ),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('เคลียร์ข้อมูลไม่สำเร็จ: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FB),
      appBar: AppBar(
        title: const Text(
          'กำหนดสิทธิ์วันลา',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFF087FD0),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            tooltip: 'เคลียร์ข้อมูลตามปี',
            icon: const Icon(Icons.cleaning_services),
            onPressed: isLoading ? null : clearBalanceByYear,
          ),
          IconButton(
            tooltip: 'รีเฟรช',
            icon: const Icon(Icons.refresh),
            onPressed: isLoading ? null : loadData,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: employees.isEmpty || leaveTypes.isEmpty
            ? null
            : () => showBalanceDialog(),
        backgroundColor: const Color(0xFF087FD0),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('กำหนดสิทธิ์'),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: loadData,
              child: balances.isEmpty
                  ? ListView(
                      physics:
                          const AlwaysScrollableScrollPhysics(),
                      children: const [
                        SizedBox(height: 120),
                        Icon(
                          Icons.calendar_month,
                          size: 65,
                          color: Colors.grey,
                        ),
                        SizedBox(height: 15),
                        Center(
                          child: Text(
                            'ยังไม่มีข้อมูลสิทธิ์วันลา',
                            style: TextStyle(
                              color: Colors.grey,
                              fontSize: 16,
                            ),
                          ),
                        ),
                        SizedBox(height: 8),
                        Center(
                          child: Text(
                            'กดปุ่มกำหนดสิทธิ์เพื่อเพิ่มข้อมูล',
                            style: TextStyle(color: Colors.grey),
                          ),
                        ),
                      ],
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: balances.length,
                      itemBuilder: (context, index) {
                        final item = balances[index];

                        final employeeId =
                            item['employee_id'].toString();

                        final leaveTypeId =
                            item['leave_type_id'].toString();

                        final entitled =
                            toDouble(item['entitled_days']);

                        final used =
                            toDouble(item['used_days']);

                        final remaining =
                            toDouble(item['remaining_days']);

                        return Card(
                          color: Colors.white,
                          elevation: 1,
                          margin: const EdgeInsets.only(
                            bottom: 13,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.circular(15),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(17),
                            child: Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const CircleAvatar(
                                      backgroundColor:
                                          Color(0xFFE3F2FD),
                                      child: Icon(
                                        Icons.person,
                                        color: Color(0xFF087FD0),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            employeeName(employeeId),
                                            style: const TextStyle(
                                              fontWeight:
                                                  FontWeight.bold,
                                              fontSize: 16,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            leaveName(leaveTypeId),
                                            style: const TextStyle(
                                              color: Colors.grey,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    IconButton(
                                      tooltip: 'แก้ไขสิทธิ์',
                                      icon: const Icon(
                                        Icons.edit,
                                        color: Color(0xFF087FD0),
                                      ),
                                      onPressed: () {
                                        showBalanceDialog(
                                          balance: item,
                                        );
                                      },
                                    ),
                                    IconButton(
                                      tooltip: used > 0
                                          ? 'มีการใช้สิทธิ์แล้ว ไม่สามารถลบได้'
                                          : 'ลบสิทธิ์',
                                      icon: Icon(
                                        Icons.delete_outline,
                                        color: used > 0
                                            ? Colors.grey
                                            : Colors.red,
                                      ),
                                      onPressed: used > 0
                                          ? null
                                          : () => deleteBalance(item),
                                    ),
                                  ],
                                ),
                                const Divider(height: 25),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'ปี ${item['leave_year']}',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    Text(
                                      'ได้รับ ${entitled.toStringAsFixed(1)} วัน',
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    Expanded(
                                      child: _statBox(
                                        'ใช้ไปแล้ว',
                                        used,
                                        Colors.orange,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: _statBox(
                                        'คงเหลือ',
                                        remaining,
                                        Colors.green,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
    );
  }

  Widget _statBox(
    String title,
    double value,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Colors.grey,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            '${value.toStringAsFixed(1)} วัน',
            style: TextStyle(
              color: color,
              fontSize: 17,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
