
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class OvertimeRequestScreen extends StatefulWidget {
  const OvertimeRequestScreen({super.key});

  @override
  State<OvertimeRequestScreen> createState() =>
      _OvertimeRequestScreenState();
}

class _OvertimeRequestScreenState
    extends State<OvertimeRequestScreen> {
  final SupabaseClient supabase = Supabase.instance.client;
  final GlobalKey<FormState> formKey = GlobalKey<FormState>();
  final TextEditingController reasonController =
      TextEditingController();

  DateTime workDate = DateTime.now();

  TimeOfDay startTime =
      const TimeOfDay(hour: 17, minute: 0);

  TimeOfDay endTime =
      const TimeOfDay(hour: 19, minute: 0);

  bool isSaving = false;

  int get startMinutes =>
      startTime.hour * 60 + startTime.minute;

  int get endMinutes =>
      endTime.hour * 60 + endTime.minute;

  double get totalHours {
    int difference = endMinutes - startMinutes;

    if (difference < 0) {
      difference += 24 * 60;
    }

    return difference / 60;
  }

  String formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/'
        '${date.year + 543}';
  }

  String formatTime(TimeOfDay time) {
    return '${time.hour.toString().padLeft(2, '0')}:'
        '${time.minute.toString().padLeft(2, '0')}:00';
  }

  void showMessage(
    String message, {
    bool isError = false,
  }) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor:
            isError ? Colors.red.shade700 : Colors.green.shade700,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> selectDate() async {
    final selected = await showDatePicker(
      context: context,
      initialDate: workDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(
        const Duration(days: 365),
      ),
      helpText: 'เลือกวันที่ทำ OT',
      cancelText: 'ยกเลิก',
      confirmText: 'ตกลง',
    );

    if (selected != null && mounted) {
      setState(() {
        workDate = DateTime(
          selected.year,
          selected.month,
          selected.day,
        );
      });
    }
  }

  Future<void> selectTime({
    required bool isStart,
  }) async {
    final selected = await showTimePicker(
      context: context,
      initialTime: isStart ? startTime : endTime,
      helpText: isStart
          ? 'เลือกเวลาเริ่มต้น'
          : 'เลือกเวลาสิ้นสุด',
      cancelText: 'ยกเลิก',
      confirmText: 'ตกลง',
    );

    if (selected != null && mounted) {
      setState(() {
        if (isStart) {
          startTime = selected;
        } else {
          endTime = selected;
        }
      });
    }
  }

  Future<void> submitRequest() async {
    if (!formKey.currentState!.validate()) return;

    final user = supabase.auth.currentUser;

    if (user == null) {
      showMessage(
        'กรุณาเข้าสู่ระบบก่อนส่งคำขอ',
        isError: true,
      );
      return;
    }

    if (totalHours <= 0) {
      showMessage(
        'กรุณาตรวจสอบเวลาเริ่มต้นและเวลาสิ้นสุด',
        isError: true,
      );
      return;
    }

    setState(() {
      isSaving = true;
    });

    try {
      final dateString =
          '${workDate.year.toString().padLeft(4, '0')}-'
          '${workDate.month.toString().padLeft(2, '0')}-'
          '${workDate.day.toString().padLeft(2, '0')}';

      await supabase
          .from('overtime_requests')
          .insert({
        'user_id': user.id,
        'work_date': dateString,
        'start_time': formatTime(startTime),
        'end_time': formatTime(endTime),
        'reason': reasonController.text.trim(),
        'status': 'pending',
      });

      if (!mounted) return;

      showMessage(
        'ส่งคำขอ OT เรียบร้อยแล้ว รอ Admin อนุมัติ',
      );

      Navigator.pop(context, true);
    } on PostgrestException catch (e) {
      showMessage(
        'ส่งคำขอไม่สำเร็จ: ${e.message}',
        isError: true,
      );
    } catch (e) {
      showMessage(
        'เกิดข้อผิดพลาด: $e',
        isError: true,
      );
    } finally {
      if (mounted) {
        setState(() {
          isSaving = false;
        });
      }
    }
  }

  Widget selectionTile({
    required String title,
    required String value,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: isSaving ? null : onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          border: Border.all(
            color: const Color(0xFFE2E8F0),
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: const Color(0xFF087FD0),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.black54,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    value,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.edit_calendar_outlined,
              color: Colors.black45,
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    reasonController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FB),
      appBar: AppBar(
        title: const Text(
          'ขออนุมัติทำงาน OT',
          style: TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: const Color(0xFF087FD0),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(18),
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: 650,
            ),
            child: Card(
              elevation: 2,
              color: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
              child: Padding(
                padding: const EdgeInsets.all(22),
                child: Form(
                  key: formKey,
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.stretch,
                    children: [
                      const Icon(
                        Icons.more_time,
                        size: 52,
                        color: Color(0xFF087FD0),
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        'แบบฟอร์มขอทำงานล่วงเวลา',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 21,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'กรอกข้อมูลเพื่อส่งให้ผู้ดูแลระบบพิจารณา',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.black54,
                        ),
                      ),
                      const SizedBox(height: 25),

                      selectionTile(
                        title: 'วันที่ต้องการทำ OT',
                        value: formatDate(workDate),
                        icon: Icons.calendar_month,
                        onTap: selectDate,
                      ),

                      const SizedBox(height: 14),

                      Row(
                        children: [
                          Expanded(
                            child: selectionTile(
                              title: 'เวลาเริ่มต้น',
                              value: startTime.format(context),
                              icon: Icons.login,
                              onTap: () =>
                                  selectTime(isStart: true),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: selectionTile(
                              title: 'เวลาสิ้นสุด',
                              value: endTime.format(context),
                              icon: Icons.logout,
                              onTap: () =>
                                  selectTime(isStart: false),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 14),

                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEFF6FF),
                          borderRadius:
                              BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.schedule,
                              color: Color(0xFF087FD0),
                              size: 28,
                            ),
                            const SizedBox(width: 12),
                            const Expanded(
                              child: Text(
                                'จำนวนชั่วโมง OT',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            Text(
                              '${totalHours.toStringAsFixed(2)} ชม.',
                              style: const TextStyle(
                                color: Color(0xFF087FD0),
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 20),

                      TextFormField(
                        controller: reasonController,
                        enabled: !isSaving,
                        maxLines: 4,
                        maxLength: 500,
                        decoration: InputDecoration(
                          labelText: 'เหตุผลในการขอทำ OT',
                          hintText:
                              'ระบุรายละเอียดงานที่ต้องทำล่วงเวลา',
                          alignLabelWithHint: true,
                          prefixIcon: const Padding(
                            padding: EdgeInsets.only(bottom: 58),
                            child: Icon(
                              Icons.description_outlined,
                            ),
                          ),
                          filled: true,
                          fillColor:
                              const Color(0xFFF8FAFC),
                          border: OutlineInputBorder(
                            borderRadius:
                                BorderRadius.circular(12),
                          ),
                        ),
                        validator: (value) {
                          if (value == null ||
                              value.trim().isEmpty) {
                            return 'กรุณาระบุเหตุผลในการขอทำ OT';
                          }
                          return null;
                        },
                      ),

                      const SizedBox(height: 12),

                      Container(
                        padding: const EdgeInsets.all(13),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF7ED),
                          borderRadius:
                              BorderRadius.circular(10),
                        ),
                        child: const Row(
                          crossAxisAlignment:
                              CrossAxisAlignment.start,
                          children: [
                            Icon(
                              Icons.info_outline,
                              color: Colors.orange,
                            ),
                            SizedBox(width: 9),
                            Expanded(
                              child: Text(
                                'เมื่อส่งคำขอแล้ว สถานะจะเป็น '
                                '“รออนุมัติ” และต้องรอ Admin '
                                'พิจารณา',
                                style: TextStyle(
                                  color: Color(0xFF9A3412),
                                  height: 1.45,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 22),

                      SizedBox(
                        height: 50,
                        child: ElevatedButton.icon(
                          onPressed: isSaving
                              ? null
                              : submitRequest,
                          icon: isSaving
                              ? const SizedBox(
                                  width: 19,
                                  height: 19,
                                  child:
                                      CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.send),
                          label: Text(
                            isSaving
                                ? 'กำลังส่งคำขอ...'
                                : 'ส่งคำขอ OT',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor:
                                const Color(0xFF087FD0),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
