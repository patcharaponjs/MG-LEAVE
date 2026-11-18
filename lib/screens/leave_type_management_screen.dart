
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class LeaveTypeManagementScreen extends StatefulWidget {
  const LeaveTypeManagementScreen({super.key});

  @override
  State<LeaveTypeManagementScreen> createState() =>
      _LeaveTypeManagementScreenState();
}

class _LeaveTypeManagementScreenState
    extends State<LeaveTypeManagementScreen> {
  final SupabaseClient supabase = Supabase.instance.client;

  List<Map<String, dynamic>> leaveTypes = [];

  bool isLoading = true;
  bool isSaving = false;
  final Set<dynamic> deletingIds = {};

  @override
  void initState() {
    super.initState();
    loadLeaveTypes();
  }

  Future<void> loadLeaveTypes() async {
    if (mounted) {
      setState(() => isLoading = true);
    }

    try {
      final response = await supabase
          .from('leave_types')
          .select(
            'id, leave_name, description, default_days, is_active',
          )
          .order('id');

      if (!mounted) return;

      setState(() {
        leaveTypes = List<Map<String, dynamic>>.from(response);
      });
    } catch (e) {
      if (!mounted) return;
      showMessage('โหลดประเภทวันลาไม่สำเร็จ: $e', isError: true);
    } finally {
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  void showMessage(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
      ),
    );
  }

  // ยืนยันและลบประเภทวันลา
  Future<void> deleteLeaveType(Map<String, dynamic> item) async {
    final id = item['id'];
    final name = item['leave_name']?.toString() ?? 'ประเภทวันลา';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Row(
            children: [
              Icon(Icons.delete_outline, color: Colors.red),
              SizedBox(width: 10),
              Text('ยืนยันการลบ'),
            ],
          ),
          content: Text(
            'คุณต้องการลบ "$name" ใช่หรือไม่?\n\n'
            'หากประเภทนี้ถูกใช้ในใบลาแล้ว ระบบจะไม่อนุญาตให้ลบ',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('ยกเลิก'),
            ),
            ElevatedButton.icon(
              onPressed: () => Navigator.pop(dialogContext, true),
              icon: const Icon(Icons.delete),
              label: const Text('ลบประเภทวันลา'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) return;

    setState(() => deletingIds.add(id));

    try {
      // ตรวจสอบก่อนว่ามีใบลาใช้ประเภทนี้อยู่หรือไม่
      final usage = await supabase
          .from('leave_requests')
          .select('id')
          .eq('leave_type_id', id)
          .limit(1);

      if (usage.isNotEmpty) {
        if (!mounted) return;

        showMessage(
          'ไม่สามารถลบได้ เนื่องจากประเภทนี้ถูกใช้ในใบลาแล้ว กรุณาปิดใช้งานแทน',
          isError: true,
        );
        return;
      }

      // ลบข้อมูลและตรวจสอบผลการลบจาก Supabase
      final deleted = await supabase
          .from('leave_types')
          .delete()
          .eq('id', id)
          .select('id');

      if (deleted.isEmpty) {
        throw Exception(
          'ไม่พบข้อมูลที่ถูกลบ หรือไม่มีสิทธิ์ลบข้อมูล '
          'กรุณาตรวจสอบ Supabase RLS Policy',
        );
      }

      if (!mounted) return;

      // โหลดรายการใหม่จากฐานข้อมูล เพื่อยืนยันว่าลบแล้วจริง
      await loadLeaveTypes();

      if (!mounted) return;

      showMessage('ลบประเภทวันลา "$name" เรียบร้อยแล้ว');
    } catch (e) {
      if (!mounted) return;

      showMessage(
        'ลบประเภทวันลาไม่สำเร็จ: $e',
        isError: true,
      );
    } finally {
      if (mounted) {
        setState(() => deletingIds.remove(id));
      }
    }
  }

  Future<void> openLeaveTypeDialog({
    Map<String, dynamic>? leaveType,
  }) async {
    final isEditing = leaveType != null;

    final nameController = TextEditingController(
      text: leaveType?['leave_name']?.toString() ?? '',
    );

    final descriptionController = TextEditingController(
      text: leaveType?['description']?.toString() ?? '',
    );

    final daysController = TextEditingController(
      text: leaveType?['default_days']?.toString() ?? '0',
    );

    final formKey = GlobalKey<FormState>();

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
              title: Text(
                isEditing ? 'แก้ไขประเภทวันลา' : 'เพิ่มประเภทวันลา',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                ),
              ),
              content: Form(
                key: formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextFormField(
                        controller: nameController,
                        decoration: const InputDecoration(
                          labelText: 'ชื่อประเภทวันลา',
                          hintText: 'เช่น ลาป่วย',
                          prefixIcon: Icon(Icons.event_note),
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'กรุณากรอกชื่อประเภทวันลา';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: descriptionController,
                        maxLines: 3,
                        decoration: const InputDecoration(
                          labelText: 'รายละเอียด',
                          hintText: 'รายละเอียดหรือเงื่อนไขการลา',
                          prefixIcon: Icon(Icons.description_outlined),
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: daysController,
                        keyboardType:
                            const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: const InputDecoration(
                          labelText: 'จำนวนวันลาต่อปี',
                          hintText: 'เช่น 10',
                          prefixIcon: Icon(Icons.calendar_month),
                          suffixText: 'วัน',
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) {
                          final days = double.tryParse(
                            (value ?? '').trim(),
                          );

                          if (days == null || days < 0) {
                            return 'กรุณากรอกจำนวนวันให้ถูกต้อง';
                          }

                          return null;
                        },
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isSaving
                      ? null
                      : () => Navigator.pop(dialogContext),
                  child: const Text('ยกเลิก'),
                ),
                ElevatedButton.icon(
                  onPressed: isSaving
                      ? null
                      : () async {
                          if (!formKey.currentState!.validate()) {
                            return;
                          }

                          final days = double.parse(
                            daysController.text.trim(),
                          );

                          setDialogState(() {
                            isSaving = true;
                          });

                          try {
                            final data = {
                              'leave_name': nameController.text.trim(),
                              'description':
                                  descriptionController.text.trim().isEmpty
                                      ? null
                                      : descriptionController.text.trim(),
                              'default_days': days,
                            };

                            if (isEditing) {
                              await supabase
                                  .from('leave_types')
                                  .update(data)
                                  .eq('id', leaveType['id']);
                            } else {
                              await supabase.from('leave_types').insert({
                                ...data,
                                'is_active': true,
                              });
                            }

                            if (!mounted) return;

                            Navigator.pop(dialogContext);
                            await loadLeaveTypes();

                            if (!mounted) return;

                            showMessage(
                              isEditing
                                  ? 'แก้ไขประเภทวันลาเรียบร้อยแล้ว'
                                  : 'เพิ่มประเภทวันลาเรียบร้อยแล้ว',
                            );
                          } catch (e) {
                            setDialogState(() {
                              isSaving = false;
                            });

                            showMessage(
                              'บันทึกข้อมูลไม่สำเร็จ: $e',
                              isError: true,
                            );
                          }
                        },
                  icon: isSaving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.save),
                  label: Text(isSaving ? 'กำลังบันทึก' : 'บันทึก'),
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

    nameController.dispose();
    descriptionController.dispose();
    daysController.dispose();
  }

  Future<void> toggleLeaveType(
    Map<String, dynamic> leaveType,
    bool value,
  ) async {
    try {
      await supabase
          .from('leave_types')
          .update({'is_active': value})
          .eq('id', leaveType['id']);

      if (!mounted) return;

      setState(() {
        leaveType['is_active'] = value;
      });

      showMessage(
        value
            ? 'เปิดใช้งานประเภทวันลาแล้ว'
            : 'ปิดใช้งานประเภทวันลาแล้ว',
      );
    } catch (e) {
      if (!mounted) return;

      showMessage(
        'เปลี่ยนสถานะไม่สำเร็จ: $e',
        isError: true,
      );
    }
  }

  Widget buildLeaveTypeCard(Map<String, dynamic> item) {
    final name = item['leave_name']?.toString() ?? '-';
    final description =
        item['description']?.toString() ?? 'ไม่มีรายละเอียด';
    final days = item['default_days']?.toString() ?? '0';
    final isActive = item['is_active'] == true;
    final isDeleting = deletingIds.contains(item['id']);

    return Card(
      color: Colors.white,
      elevation: 1,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
      ),
      child: Padding(
        padding: const EdgeInsets.all(15),
        child: Column(
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: const Color(0xFFE3F2FD),
                  child: const Icon(
                    Icons.event_available,
                    color: Color(0xFF087FD0),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        description,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.black54,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: isDeleting
                      ? null
                      : () {
                          openLeaveTypeDialog(leaveType: item);
                        },
                  icon: const Icon(
                    Icons.edit_outlined,
                    color: Color(0xFF087FD0),
                  ),
                  tooltip: 'แก้ไข',
                ),
                IconButton(
                  onPressed: isDeleting
                      ? null
                      : () => deleteLeaveType(item),
                  icon: isDeleting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.red,
                          ),
                        )
                      : const Icon(
                          Icons.delete_outline,
                          color: Colors.red,
                        ),
                  tooltip: 'ลบประเภทวันลา',
                ),
              ],
            ),
            const Divider(height: 22),
            Row(
              children: [
                const Icon(
                  Icons.calendar_month,
                  size: 18,
                  color: Colors.blueGrey,
                ),
                const SizedBox(width: 8),
                Text(
                  'สิทธิ์เริ่มต้น $days วัน/ปี',
                  style: const TextStyle(fontSize: 13),
                ),
                const Spacer(),
                Text(
                  isActive ? 'เปิดใช้งาน' : 'ปิดใช้งาน',
                  style: TextStyle(
                    color: isActive ? Colors.green : Colors.red,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
                Switch(
                  value: isActive,
                  activeThumbColor: Colors.green,
                  onChanged: isDeleting
                      ? null
                      : (value) => toggleLeaveType(item, value),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final activeCount =
        leaveTypes.where((e) => e['is_active'] == true).length;

    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FB),
      appBar: AppBar(
        title: const Text(
          'จัดการประเภทวันลา',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFF087FD0),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            onPressed: loadLeaveTypes,
            icon: const Icon(Icons.refresh),
            tooltip: 'รีเฟรช',
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => openLeaveTypeDialog(),
        backgroundColor: const Color(0xFF087FD0),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('เพิ่มประเภทวันลา'),
      ),
      body: isLoading
          ? const Center(
              child: CircularProgressIndicator(),
            )
          : RefreshIndicator(
              onRefresh: loadLeaveTypes,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: const Color(0xFF087FD0),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.event_note,
                          size: 42,
                          color: Colors.white,
                        ),
                        const SizedBox(width: 15),
                        Expanded(
                          child: Column(
                            crossAxisAlignment:
                                CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'ประเภทวันลาทั้งหมด',
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 13,
                                ),
                              ),
                              const SizedBox(height: 5),
                              Text(
                                '${leaveTypes.length} ประเภท',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 25,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                'เปิดใช้งาน $activeCount ประเภท',
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 12,
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
                    'รายการประเภทวันลา',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (leaveTypes.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(35),
                      child: Column(
                        children: [
                          Icon(
                            Icons.event_busy,
                            size: 55,
                            color: Colors.grey,
                          ),
                          SizedBox(height: 12),
                          Text(
                            'ยังไม่มีประเภทวันลา',
                            style: TextStyle(color: Colors.grey),
                          ),
                        ],
                      ),
                    )
                  else
                    ...leaveTypes.map(buildLeaveTypeCard),
                  const SizedBox(height: 80),
                ],
              ),
            ),
    );
  }
}
