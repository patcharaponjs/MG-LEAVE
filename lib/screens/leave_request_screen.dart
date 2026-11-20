import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:file_picker/file_picker.dart' as fp;

class LeaveRequestScreen extends StatefulWidget {
  const LeaveRequestScreen({super.key});

  @override
  State<LeaveRequestScreen> createState() => _LeaveRequestScreenState();
}

class _LeaveRequestScreenState extends State<LeaveRequestScreen> {
  final SupabaseClient supabase = Supabase.instance.client;
  final TextEditingController reasonController = TextEditingController();

  static const String bucketName = 'leave-attachments';
  static const int maxFileSize = 10 * 1024 * 1024;

  List<Map<String, dynamic>> leaveTypes = [];
  List<fp.PlatformFile> selectedFiles = [];
  final Map<String, int> selectedFileSizes = {};

  int? selectedLeaveTypeId;
  DateTime? startDate;
  DateTime? endDate;

  bool isLoading = true;
  bool isSubmitting = false;

  @override
  void initState() {
    super.initState();
    loadLeaveTypes();
  }

  @override
  void dispose() {
    reasonController.dispose();
    super.dispose();
  }

  Future<void> loadLeaveTypes() async {
    try {
      final response = await supabase
          .from('leave_types')
          .select('id, leave_name, description, default_days')
          .eq('is_active', true)
          .order('id');

      if (!mounted) return;

      setState(() {
        leaveTypes = List<Map<String, dynamic>>.from(response);
        isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => isLoading = false);
      showMessage('โหลดประเภทการลาไม่สำเร็จ: $e', Colors.red);
    }
  }

  Future<void> selectDate(bool isStart) async {
    final initialDate = isStart
        ? (startDate ?? DateTime.now())
        : (endDate ?? startDate ?? DateTime.now());

    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      helpText: isStart ? 'เลือกวันเริ่มลา' : 'เลือกวันสิ้นสุด',
      locale: const Locale('th', 'TH'),
    );

    if (picked == null || !mounted) return;

    setState(() {
      if (isStart) {
        startDate = picked;

        if (endDate != null && endDate!.isBefore(picked)) {
          endDate = null;
        }
      } else {
        if (startDate == null) {
          showMessage('กรุณาเลือกวันเริ่มลาก่อน', Colors.orange);
          return;
        }

        if (picked.isBefore(startDate!)) {
          showMessage(
            'วันสิ้นสุดต้องไม่อยู่ก่อนวันเริ่มลา',
            Colors.orange,
          );
          return;
        }

        endDate = picked;
      }
    });
  }

  String formatDate(DateTime? date) {
    if (date == null) return 'เลือกวันที่';

    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/'
        '${date.year + 543}';
  }

  String dateToDatabase(DateTime date) {
    return '${date.year}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';
  }

  // ลาคลอดและลาอุปสมบทนับทุกวัน
  // ประเภทลาอื่นนับเฉพาะวันจันทร์ถึงศุกร์
  int get totalDays {
    if (startDate == null || endDate == null) return 0;

    final countAllDays =
        selectedLeaveName == 'ลาคลอด' ||
        selectedLeaveName == 'ลาอุปสมบท';

    int days = 0;

    for (
      DateTime date = startDate!;
      !date.isAfter(endDate!);
      date = date.add(const Duration(days: 1))
    ) {
      if (countAllDays ||
          (date.weekday >= DateTime.monday &&
              date.weekday <= DateTime.friday)) {
        days++;
      }
    }

    return days;
  }

  void showMessage(String message, Color color) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: color,
          duration: const Duration(seconds: 4),
        ),
      );
  }

  String get selectedLeaveName {
    if (selectedLeaveTypeId == null) return '';

    final matches = leaveTypes.where(
      (type) => (type['id'] as num).toInt() == selectedLeaveTypeId,
    );

    if (matches.isEmpty) return '';

    return matches.first['leave_name']?.toString() ?? '';
  }

  bool get isSickLeave => selectedLeaveName.contains('ป่วย');

  Future<void> pickAttachments() async {
    try {
      final files = await fp.FilePicker.pickFiles(
        type: fp.FileType.custom,
        allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
      );

      if (!mounted || files.isEmpty) return;

      final validFiles = <fp.PlatformFile>[];
      final validFileSizes = <String, int>{};
      final rejected = <String>[];

      for (final file in files) {
        final fileSize = file.lengthSync() ?? await file.length();

        if (fileSize == null) {
          rejected.add('${file.name} (ไม่สามารถอ่านขนาดไฟล์ได้)');
        } else if (fileSize > maxFileSize) {
          rejected.add('${file.name} (เกิน 10 MB)');
        } else {
          validFiles.add(file);
          validFileSizes[file.name] = fileSize;
        }
      }

      setState(() {
        for (final file in validFiles) {
          final alreadyAdded =
              selectedFiles.any((item) => item.name == file.name);

          if (!alreadyAdded) {
            selectedFiles.add(file);
            selectedFileSizes[file.name] = validFileSizes[file.name]!;
          }
        }
      });

      if (rejected.isNotEmpty) {
        showMessage(
          'ไม่สามารถเพิ่มไฟล์: ${rejected.join(', ')}',
          Colors.orange,
        );
      }
    } catch (e) {
      showMessage('เลือกเอกสารไม่สำเร็จ: $e', Colors.red);
    }
  }

  void removeAttachment(int index) {
    setState(() {
      final removed = selectedFiles.removeAt(index);
      selectedFileSizes.remove(removed.name);
    });
  }

  String mimeTypeFor(String fileName) {
    final extension = fileName.split('.').last.toLowerCase();

    switch (extension) {
      case 'pdf':
        return 'application/pdf';
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      default:
        return 'application/octet-stream';
    }
  }

  String safeFileName(String name) {
    return name.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
  }

  Future<void> uploadAttachments({
    required String employeeId,
    required int requestId,
    required List<fp.PlatformFile> files,
  }) async {
    for (final file in files) {
      final bytes = await file.readAsBytes();

      final timestamp = DateTime.now().microsecondsSinceEpoch;

      final storagePath =
          '$employeeId/$requestId/${timestamp}_${safeFileName(file.name)}';

      await supabase.storage.from(bucketName).uploadBinary(
            storagePath,
            bytes,
            fileOptions: FileOptions(
              contentType: mimeTypeFor(file.name),
              upsert: false,
            ),
          );

      await supabase.from('leave_attachments').insert({
        'leave_request_id': requestId,
        'employee_id': employeeId,
        'file_name': file.name,
        'storage_path': storagePath,
        'mime_type': mimeTypeFor(file.name),
      });
    }
  }

  bool validateForm() {
    if (selectedLeaveTypeId == null) {
      showMessage('กรุณาเลือกประเภทการลา', Colors.orange);
      return false;
    }

    if (startDate == null) {
      showMessage('กรุณาเลือกวันเริ่มลา', Colors.orange);
      return false;
    }

    if (endDate == null) {
      showMessage('กรุณาเลือกวันสิ้นสุด', Colors.orange);
      return false;
    }

    if (totalDays <= 0) {
      showMessage(
        'ช่วงวันที่เลือกไม่มีวันทำการให้ลา',
        Colors.orange,
      );
      return false;
    }

    if (reasonController.text.trim().isEmpty) {
      showMessage('กรุณาระบุเหตุผลในการลา', Colors.orange);
      return false;
    }

    return true;
  }

  // =========================================================
  // ส่งคำขอลา และแจ้งเตือน LINE ผ่าน Edge Function
  // =========================================================
  Future<void> submitRequest() async {
    if (isSubmitting || !validateForm()) return;

    final user = supabase.auth.currentUser;

    if (user == null) {
      showMessage(
        'ไม่พบข้อมูลผู้ใช้งาน กรุณาเข้าสู่ระบบใหม่',
        Colors.red,
      );
      return;
    }

    final filesToUpload = List<fp.PlatformFile>.from(selectedFiles);
    final leaveTypeId = selectedLeaveTypeId!;
    final reason = reasonController.text.trim();

    final requestStartDate = dateToDatabase(startDate!);
    final requestEndDate = dateToDatabase(endDate!);

    setState(() => isSubmitting = true);

    bool requestCreated = false;
    String? lineNotifyError;

    try {
      // 1. สร้างใบลาผ่าน RPC ตามเดิม
      final result = await supabase.rpc(
        'submit_leave_request',
        params: {
          'p_leave_type_id': leaveTypeId,
          'p_start_date': requestStartDate,
          'p_end_date': requestEndDate,
          'p_reason': reason,
        },
      );

      final requestId = int.tryParse(result.toString());

      if (requestId == null || requestId <= 0) {
        throw Exception('ไม่สามารถรับเลขที่ใบลาจากฐานข้อมูลได้');
      }

      requestCreated = true;

      // 2. แจ้งเตือน LINE หลังสร้างใบลาสำเร็จ
      //    ใช้ Edge Function mg-leave-notify
      //    ไม่ใช้ LINE API Key ใน Flutter
      try {
        final lineResponse = await supabase.functions.invoke(
          'mg-leave-notify',
          body: {
            'request_id': requestId,
          },
        );

        if (lineResponse.status < 200 ||
            lineResponse.status >= 300) {
          lineNotifyError =
              'LINE แจ้งเตือนไม่สำเร็จ (${lineResponse.status})';

          debugPrint(
            'LINE notification status: ${lineResponse.status}',
          );

          debugPrint(
            'LINE notification response: ${lineResponse.data}',
          );
        } else {
          debugPrint('LINE notification sent successfully');
        }
      } catch (e) {
        lineNotifyError = 'LINE แจ้งเตือนไม่สำเร็จ';

        debugPrint('mg-leave-notify error: $e');
      }

      // 3. อัปโหลดเอกสารหลังสร้างคำขอสำเร็จ
      if (filesToUpload.isNotEmpty) {
        await uploadAttachments(
          employeeId: user.id,
          requestId: requestId,
          files: filesToUpload,
        );
      }

      if (!mounted) return;

      // 4. รีเซ็ตแบบฟอร์ม
      setState(() {
        selectedLeaveTypeId = null;
        startDate = null;
        endDate = null;
        reasonController.clear();
        selectedFiles.clear();
        selectedFileSizes.clear();
      });

      // 5. แสดงผลการส่งคำขอ
      showMessage(
        lineNotifyError == null
            ? (filesToUpload.isNotEmpty
                ? 'ส่งคำขอลาพร้อมเอกสารแนบสำเร็จ รอการอนุมัติ'
                : 'ส่งคำขอลางานสำเร็จ รอการอนุมัติจากผู้บังคับบัญชา')
            : 'บันทึกใบลาสำเร็จ แต่ $lineNotifyError',
        lineNotifyError == null ? Colors.green : Colors.orange,
      );
    } on PostgrestException catch (e) {
      showMessage(
        requestCreated
            ? 'บันทึกใบลาแล้ว แต่บันทึกข้อมูลเอกสารไม่สำเร็จ: ${e.message}'
            : 'บันทึกคำขอไม่สำเร็จ: ${e.message}',
        Colors.red,
      );
    } catch (e) {
      showMessage(
        requestCreated
            ? 'สร้างใบลาแล้ว แต่แนบเอกสารไม่สำเร็จ: $e'
            : 'เกิดข้อผิดพลาด: $e',
        Colors.red,
      );
    } finally {
      if (mounted) {
        setState(() => isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FB),
      appBar: AppBar(
        title: const Text(
          'ยื่นใบลางาน',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFF087FD0),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: loadLeaveTypes,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'แบบฟอร์มขอลางาน',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF142B4A),
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'กรุณากรอกข้อมูลการลาให้ครบถ้วน',
                      style: TextStyle(color: Colors.grey),
                    ),
                    const SizedBox(height: 25),

                    sectionTitle('ประเภทการลา'),

                    if (leaveTypes.isEmpty)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Text(
                          'ยังไม่มีประเภทการลาที่เปิดใช้งาน',
                          style: TextStyle(color: Colors.red),
                        ),
                      )
                    else
                      DropdownButtonFormField<int>(
                        initialValue: selectedLeaveTypeId,
                        isExpanded: true,
                        decoration: inputDecoration('เลือกประเภทการลา'),
                        items: leaveTypes.map((type) {
                          final id = (type['id'] as num).toInt();

                          return DropdownMenuItem<int>(
                            value: id,
                            child: Text(
                              type['leave_name']?.toString() ?? '',
                            ),
                          );
                        }).toList(),
                        onChanged: isSubmitting
                            ? null
                            : (value) {
                                setState(() {
                                  selectedLeaveTypeId = value;
                                });
                              },
                      ),

                    const SizedBox(height: 20),

                    if (selectedLeaveTypeId != null)
                      Builder(
                        builder: (context) {
                          final selectedType = leaveTypes.firstWhere(
                            (type) =>
                                (type['id'] as num).toInt() ==
                                selectedLeaveTypeId,
                          );

                          final description =
                              selectedType['description']?.toString() ?? '';

                          return Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEAF5FF),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              description.isEmpty
                                  ? 'ประเภทการลา: ${selectedType['leave_name']}'
                                  : description,
                              style: const TextStyle(
                                color: Color(0xFF087FD0),
                              ),
                            ),
                          );
                        },
                      ),

                    const SizedBox(height: 20),

                    sectionTitle('วันที่เริ่มลา'),
                    dateField(
                      date: startDate,
                      onTap: isSubmitting ? null : () => selectDate(true),
                    ),

                    const SizedBox(height: 20),

                    sectionTitle('วันที่สิ้นสุด'),
                    dateField(
                      date: endDate,
                      onTap: isSubmitting ? null : () => selectDate(false),
                    ),

                    const SizedBox(height: 20),

                    sectionTitle('จำนวนวันลา'),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: const Color(0xFFE0E7EF),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.event_available,
                            color: Color(0xFF087FD0),
                            size: 28,
                          ),
                          const SizedBox(width: 12),
                          Text(
                            '$totalDays วัน',
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF087FD0),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    sectionTitle('เหตุผลในการลา'),
                    TextField(
                      controller: reasonController,
                      enabled: !isSubmitting,
                      maxLines: 4,
                      decoration: inputDecoration(
                        'ระบุเหตุผลหรือรายละเอียดการลา',
                      ),
                    ),

                    const SizedBox(height: 22),

                    sectionTitle(
                      isSickLeave
                          ? 'ใบรับรองแพทย์ / เอกสารประกอบการลา'
                          : 'เอกสารประกอบการลา',
                    ),

                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(15),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: const Color(0xFFE0E7EF),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(
                                Icons.attach_file,
                                color: Color(0xFF087FD0),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  isSickLeave
                                      ? 'แนบใบรับรองแพทย์ (ถ้ามี) หรือเอกสารอื่น'
                                      : 'แนบเอกสารที่เกี่ยวข้องกับการลา (ถ้ามี)',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF142B4A),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'รองรับ PDF, JPG, JPEG, PNG ขนาดไม่เกิน 10 MB ต่อไฟล์',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey,
                            ),
                          ),
                          const SizedBox(height: 12),
                          OutlinedButton.icon(
                            onPressed:
                                isSubmitting ? null : pickAttachments,
                            icon: const Icon(Icons.upload_file),
                            label: const Text('เลือกเอกสาร'),
                          ),
                          if (selectedFiles.isNotEmpty) ...[
                            const Divider(height: 22),
                            ...List.generate(selectedFiles.length, (index) {
                              final file = selectedFiles[index];

                              return ListTile(
                                contentPadding: EdgeInsets.zero,
                                leading: Icon(
                                  file.extension?.toLowerCase() == 'pdf'
                                      ? Icons.picture_as_pdf
                                      : Icons.image_outlined,
                                  color: const Color(0xFF087FD0),
                                ),
                                title: Text(
                                  file.name,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                subtitle: Text(
                                  '${((selectedFileSizes[file.name] ?? 0) / 1024 / 1024).toStringAsFixed(2)} MB',
                                ),
                                trailing: IconButton(
                                  tooltip: 'นำไฟล์ออก',
                                  onPressed: isSubmitting
                                      ? null
                                      : () => removeAttachment(index),
                                  icon: const Icon(
                                    Icons.close,
                                    color: Colors.red,
                                  ),
                                ),
                              );
                            }),
                          ],
                        ],
                      ),
                    ),

                    const SizedBox(height: 30),

                    SizedBox(
                      width: double.infinity,
                      height: 54,
                      child: ElevatedButton.icon(
                        onPressed: isSubmitting || leaveTypes.isEmpty
                            ? null
                            : submitRequest,
                        icon: isSubmitting
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.send),
                        label: Text(
                          isSubmitting
                              ? 'กำลังส่งคำขอ...'
                              : 'ส่งคำขอลางาน',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF087FD0),
                          foregroundColor: Colors.white,
                          disabledBackgroundColor: Colors.grey,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
    );
  }

  Widget sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.bold,
          color: Color(0xFF142B4A),
        ),
      ),
    );
  }

  InputDecoration inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 15,
        vertical: 16,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFE0E7EF)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFE0E7EF)),
      ),
    );
  }

  Widget dateField({
    required DateTime? date,
    required VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: InputDecorator(
        decoration: inputDecoration('เลือกวันที่'),
        child: Row(
          children: [
            Expanded(child: Text(formatDate(date))),
            const Icon(
              Icons.calendar_month,
              color: Color(0xFF087FD0),
            ),
          ],
        ),
      ),
    );
  }
}