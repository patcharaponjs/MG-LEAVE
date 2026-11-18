
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:file_picker/file_picker.dart' as fp;
import 'package:url_launcher/url_launcher.dart';

class LeaveHistoryScreen extends StatefulWidget {
  final bool showAllEmployees;

  const LeaveHistoryScreen({
    super.key,
    this.showAllEmployees = false,
  });

  @override
  State<LeaveHistoryScreen> createState() => _LeaveHistoryScreenState();
}

class _LeaveHistoryScreenState extends State<LeaveHistoryScreen> {
  final SupabaseClient supabase = Supabase.instance.client;

  static const String bucketName = 'leave-attachments';
  static const int maxFileSize = 10 * 1024 * 1024;

  List<Map<String, dynamic>> leaveRequests = [];

  Map<int, String> leaveTypeNames = {};
  Map<int, Map<String, dynamic>> approvalByRequestId = {};
  Map<String, String> approverNames = {};
  Map<String, String> employeeNames = {};
  Map<int, List<Map<String, dynamic>>> attachmentsByRequestId = {};

  bool isLoading = true;
  bool isClearingAll = false;

  String selectedFilter = 'ทั้งหมด';
  String? errorMessage;
  String? approvalLoadError;
  String? attachmentLoadError;

  @override
  void initState() {
    super.initState();
    loadLeaveHistory();
  }

  // ============================================================
  // โหลดประวัติการลา
  // ============================================================

  Future<void> loadLeaveHistory() async {
    final user = supabase.auth.currentUser;

    if (user == null) {
      if (!mounted) return;
      setState(() {
        isLoading = false;
        errorMessage = 'กรุณาเข้าสู่ระบบก่อน';
      });
      return;
    }

    setState(() {
      isLoading = true;
      errorMessage = null;
      approvalLoadError = null;
      attachmentLoadError = null;
    });

    try {
      if (widget.showAllEmployees) {
        final profile = await supabase
            .from('profiles')
            .select('role')
            .eq('id', user.id)
            .maybeSingle();

        if (profile == null || profile['role'] != 'admin') {
          throw Exception('ไม่มีสิทธิ์ดูประวัติการลาของพนักงานทุกคน');
        }
      }

      final typesResponse =
          await supabase.from('leave_types').select('id, leave_name');

      final Map<int, String> names = {};

      for (final type in typesResponse) {
        names[(type['id'] as num).toInt()] =
            type['leave_name']?.toString() ?? 'ไม่ระบุประเภท';
      }

      final requestsResponse = widget.showAllEmployees
          ? await supabase
              .from('leave_requests')
              .select()
              .order('created_at', ascending: false)
          : await supabase
              .from('leave_requests')
              .select()
              .eq('employee_id', user.id)
              .order('created_at', ascending: false);

      final requests =
          List<Map<String, dynamic>>.from(requestsResponse);

      final requestIds = requests
          .where((r) => r['id'] != null)
          .map((r) => (r['id'] as num).toInt())
          .toList();

      final Map<int, Map<String, dynamic>> approvalMap = {};
      final Map<String, String> nameMap = {};
      final Map<String, String> employeeNameMap = {};
      final Map<int, List<Map<String, dynamic>>> attachmentMap = {};

      String? localApprovalError;
      String? localAttachmentError;

      // โหลดชื่อพนักงานสำหรับหน้า Admin
      if (widget.showAllEmployees && requests.isNotEmpty) {
        try {
          final employeeIds = requests
              .map((r) => r['employee_id']?.toString())
              .whereType<String>()
              .where((id) => id.isNotEmpty)
              .toSet()
              .toList();

          if (employeeIds.isNotEmpty) {
            final profiles = await supabase
                .from('profiles')
                .select('id, full_name')
                .inFilter('id', employeeIds);

            for (final profile in profiles) {
              final id = profile['id']?.toString();
              final fullName = profile['full_name']?.toString();

              if (id != null && fullName != null) {
                employeeNameMap[id] = fullName;
              }
            }
          }
        } catch (e) {
          debugPrint('โหลดชื่อพนักงานไม่สำเร็จ: $e');
        }
      }

      if (requestIds.isNotEmpty) {
        // โหลดประวัติการอนุมัติ
        try {
          final approvalsResponse = await supabase
              .from('leave_approvals')
              .select(
                'leave_request_id, approver_id, approval_level, '
                'action, comment, created_at',
              )
              .inFilter('leave_request_id', requestIds)
              .order('created_at', ascending: false);

          final approvals =
              List<Map<String, dynamic>>.from(approvalsResponse);

          final Set<int> processedIds = {};
          final Set<String> approverIds = {};

          for (final approval in approvals) {
            final id =
                (approval['leave_request_id'] as num?)?.toInt();

            if (id == null) continue;

            if (!processedIds.contains(id)) {
              approvalMap[id] = approval;
              processedIds.add(id);
            }

            final approverId =
                approval['approver_id']?.toString();

            if (approverId != null && approverId.isNotEmpty) {
              approverIds.add(approverId);
            }
          }

          if (approverIds.isNotEmpty) {
            final profiles = await supabase
                .from('profiles')
                .select('id, full_name')
                .inFilter('id', approverIds.toList());

            for (final profile in profiles) {
              final id = profile['id']?.toString();
              final fullName = profile['full_name']?.toString();

              if (id != null && fullName != null) {
                nameMap[id] = fullName;
              }
            }
          }
        } catch (e) {
          localApprovalError = e.toString();
          debugPrint('โหลดข้อมูลผู้อนุมัติไม่สำเร็จ: $e');
        }

        // โหลดเอกสารแนบ
        try {
          final attachmentsResponse = widget.showAllEmployees
              ? await supabase
                  .from('leave_attachments')
                  .select(
                    'id, leave_request_id, employee_id, '
                    'file_name, storage_path, mime_type, created_at',
                  )
                  .inFilter('leave_request_id', requestIds)
                  .order('created_at')
              : await supabase
                  .from('leave_attachments')
                  .select(
                    'id, leave_request_id, employee_id, '
                    'file_name, storage_path, mime_type, created_at',
                  )
                  .eq('employee_id', user.id)
                  .inFilter('leave_request_id', requestIds)
                  .order('created_at');

          for (final item in attachmentsResponse) {
            final id =
                (item['leave_request_id'] as num?)?.toInt();

            if (id == null) continue;

            attachmentMap.putIfAbsent(id, () => []);
            attachmentMap[id]!.add(
              Map<String, dynamic>.from(item),
            );
          }
        } catch (e) {
          localAttachmentError = e.toString();
          debugPrint('โหลดเอกสารแนบไม่สำเร็จ: $e');
        }
      }

      if (!mounted) return;

      setState(() {
        leaveTypeNames = names;
        leaveRequests = requests;
        approvalByRequestId = approvalMap;
        approverNames = nameMap;
        employeeNames = employeeNameMap;
        attachmentsByRequestId = attachmentMap;
        approvalLoadError = localApprovalError;
        attachmentLoadError = localAttachmentError;
        isLoading = false;
      });
    } catch (e, stackTrace) {
      debugPrint('LEAVE HISTORY ERROR: $e');
      debugPrint('$stackTrace');

      if (!mounted) return;

      setState(() {
        isLoading = false;
        errorMessage = e.toString();
      });

      showMessage('โหลดประวัติการลาไม่สำเร็จ: $e', Colors.red);
    }
  }

  // ============================================================
  // แจ้งเตือน
  // ============================================================

  void showMessage(String message, Color color) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: color,
        ),
      );
  }

  // ============================================================
  // วันที่และสถานะ
  // ============================================================

  String formatDate(dynamic value) {
    if (value == null) return '-';

    final date = DateTime.tryParse(value.toString());
    if (date == null) return '-';

    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/'
        '${date.year + 543}';
  }

  String formatDateTime(dynamic value) {
    if (value == null) return '-';

    final date = DateTime.tryParse(value.toString());
    if (date == null) return '-';

    final d = date.toLocal();

    return '${d.day.toString().padLeft(2, '0')}/'
        '${d.month.toString().padLeft(2, '0')}/'
        '${d.year + 543} '
        'เวลา ${d.hour.toString().padLeft(2, '0')}:'
        '${d.minute.toString().padLeft(2, '0')} น.';
  }

  String statusText(String? status) {
    switch (status?.toLowerCase()) {
      case 'pending':
        return 'รออนุมัติ';
      case 'approved':
        return 'อนุมัติแล้ว';
      case 'rejected':
        return 'ไม่อนุมัติ';
      case 'cancelled':
        return 'ยกเลิก';
      default:
        return status ?? 'ไม่ระบุสถานะ';
    }
  }

  Color statusColor(String? status) {
    switch (status?.toLowerCase()) {
      case 'pending':
        return Colors.orange;
      case 'approved':
        return Colors.green;
      case 'rejected':
        return Colors.red;
      case 'cancelled':
        return Colors.grey;
      default:
        return Colors.blueGrey;
    }
  }

  String approvalActionText(dynamic action) {
    switch (action?.toString().toLowerCase()) {
      case 'approved':
        return 'อนุมัติ';
      case 'rejected':
        return 'ไม่อนุมัติ';
      case 'pending':
        return 'รอพิจารณา';
      default:
        return action?.toString() ?? '-';
    }
  }

  Color approvalActionColor(dynamic action) {
    switch (action?.toString().toLowerCase()) {
      case 'approved':
        return Colors.green;
      case 'rejected':
        return Colors.red;
      case 'pending':
        return Colors.orange;
      default:
        return Colors.blueGrey;
    }
  }

  // ============================================================
  // ตัวกรองและจำนวนรายการ
  // ============================================================

  List<Map<String, dynamic>> get filteredRequests {
    if (selectedFilter == 'ทั้งหมด') return leaveRequests;

    const statusMap = {
      'รออนุมัติ': 'pending',
      'อนุมัติแล้ว': 'approved',
      'ไม่อนุมัติ': 'rejected',
      'ยกเลิก': 'cancelled',
    };

    final targetStatus = statusMap[selectedFilter];

    return leaveRequests.where((request) {
      return request['status']?.toString().toLowerCase() ==
          targetStatus;
    }).toList();
  }

  int countStatus(String status) {
    return leaveRequests.where((request) {
      return request['status']?.toString().toLowerCase() ==
          status;
    }).length;
  }

  // ============================================================
  // MIME TYPE
  // ============================================================

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

  // ============================================================
  // แนบเอกสารย้อนหลัง - รองรับ file_picker 13.4.0
  // ============================================================

  Future<void> pickAndUploadHistoricalAttachments(
    Map<String, dynamic> request,
  ) async {
    final user = supabase.auth.currentUser;

    if (user == null) {
      showMessage('กรุณาเข้าสู่ระบบก่อน', Colors.red);
      return;
    }

    final requestId = (request['id'] as num?)?.toInt();

    if (requestId == null) {
      showMessage('ไม่พบรหัสใบลา', Colors.red);
      return;
    }

    try {
      // v13 คืนค่า List<PlatformFile> โดยตรง
      // เลือกได้หลายไฟล์เป็นค่าเริ่มต้น
      final List<fp.PlatformFile> files =
          await fp.FilePicker.pickFiles(
        type: fp.FileType.custom,
        allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
      );

      if (!mounted || files.isEmpty) return;

      final validFiles = <fp.PlatformFile>[];
      final rejected = <String>[];

      for (final file in files) {
        final fileLength =
            file.lengthSync() ?? await file.length();

        if (fileLength == null) {
          rejected.add('${file.name} (อ่านขนาดไฟล์ไม่ได้)');
        } else if (fileLength > maxFileSize) {
          rejected.add('${file.name} (เกิน 10 MB)');
        } else {
          validFiles.add(file);
        }
      }

      if (rejected.isNotEmpty) {
        showMessage(
          'ข้ามไฟล์ต่อไปนี้: ${rejected.join(', ')}',
          Colors.orange,
        );
      }

      if (validFiles.isEmpty) return;

      int uploadedCount = 0;

      for (final file in validFiles) {
        final bytes = await file.readAsBytes();

        if (bytes.isEmpty) {
          throw Exception('ไฟล์ ${file.name} ไม่มีข้อมูล');
        }

        final mimeType = mimeTypeFor(file.name);
        final timestamp =
            DateTime.now().microsecondsSinceEpoch;

        final safeName = file.name.replaceAll(
          RegExp(r'[^a-zA-Z0-9._-]'),
          '_',
        );

        final storagePath =
            '${user.id}/$requestId/${timestamp}_$safeName';

        await supabase.storage.from(bucketName).uploadBinary(
          storagePath,
          bytes,
          fileOptions: FileOptions(
            contentType: mimeType,
            upsert: false,
          ),
        );

        try {
          await supabase.from('leave_attachments').insert({
            'leave_request_id': requestId,
            'employee_id': user.id,
            'file_name': file.name,
            'storage_path': storagePath,
            'mime_type': mimeType,
          });
        } catch (e) {
          try {
            await supabase.storage
                .from(bucketName)
                .remove([storagePath]);
          } catch (_) {}

          rethrow;
        }

        uploadedCount++;
      }

      if (!mounted) return;

      showMessage(
        'แนบเอกสารย้อนหลังสำเร็จ $uploadedCount ไฟล์',
        Colors.green,
      );

      await loadLeaveHistory();
    } catch (e) {
      if (!mounted) return;

      showMessage(
        'แนบเอกสารย้อนหลังไม่สำเร็จ: $e',
        Colors.red,
      );
    }
  }

  // ============================================================
  // เปิดเอกสารแนบ
  // ============================================================

  Future<void> openAttachment(
    Map<String, dynamic> attachment,
  ) async {
    try {
      final path = attachment['storage_path']?.toString();

      if (path == null || path.isEmpty) {
        throw Exception('ไม่พบตำแหน่งไฟล์');
      }

      final signedUrl = await supabase.storage
          .from(bucketName)
          .createSignedUrl(path, 600);

      final opened = await launchUrl(
        Uri.parse(signedUrl),
        mode: LaunchMode.externalApplication,
      );

      if (!opened) {
        throw Exception('ไม่สามารถเปิดเอกสารได้');
      }
    } catch (e) {
      showMessage('เปิดเอกสารไม่สำเร็จ: $e', Colors.red);
    }
  }

  // ============================================================
  // แสดงเอกสารแนบ
  // ============================================================

  Widget buildAttachments(
    int requestId,
    Map<String, dynamic> request,
  ) {
    final attachments =
        attachmentsByRequestId[requestId] ?? [];

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 17),
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: const Color(0xFFF7FAFD),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE3EBF3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.attach_file,
                  color: Color(0xFF087FD0), size: 19),
              SizedBox(width: 8),
              Text(
                'เอกสารแนบ',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF142B4A),
                ),
              ),
            ],
          ),
          const SizedBox(height: 9),
          if (attachments.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 7),
              child: Text(
                'ยังไม่มีเอกสารแนบ',
                style: TextStyle(color: Colors.grey, fontSize: 13),
              ),
            )
          else
            ...attachments.map((attachment) {
              final fileName =
                  attachment['file_name']?.toString() ?? 'เอกสาร';

              final isPdf = fileName.toLowerCase().endsWith('.pdf');

              return ListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                leading: Icon(
                  isPdf
                      ? Icons.picture_as_pdf
                      : Icons.image_outlined,
                  color: isPdf ? Colors.red : const Color(0xFF087FD0),
                ),
                title: Text(
                  fileName,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 13),
                ),
                trailing: IconButton(
                  tooltip: 'เปิดเอกสาร',
                  onPressed: () => openAttachment(attachment),
                  icon: const Icon(
                    Icons.open_in_new,
                    color: Color(0xFF087FD0),
                  ),
                ),
              );
            }),
          if (!widget.showAllEmployees) ...[
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () =>
                    pickAndUploadHistoricalAttachments(request),
                icon: const Icon(Icons.add_to_photos_outlined, size: 18),
                label: const Text('แนบเอกสารย้อนหลัง'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF087FD0),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ============================================================
  // แก้ไขใบลาที่ยังรออนุมัติ
  // ============================================================

  Future<void> editLeaveRequest(
    Map<String, dynamic> request,
  ) async {
    final user = supabase.auth.currentUser;

    if (user == null) {
      showMessage('กรุณาเข้าสู่ระบบก่อน', Colors.red);
      return;
    }

    final requestId = (request['id'] as num?)?.toInt();

    if (requestId == null ||
        request['status']?.toString().toLowerCase() != 'pending') {
      return;
    }

    int? selectedLeaveTypeId =
        (request['leave_type_id'] as num?)?.toInt();

    DateTime? startDate =
        DateTime.tryParse(request['start_date']?.toString() ?? '');

    DateTime? endDate =
        DateTime.tryParse(request['end_date']?.toString() ?? '');

    final reasonController = TextEditingController(
      text: request['reason']?.toString() ?? '',
    );

    bool isSaving = false;

    if (startDate == null ||
        endDate == null ||
        leaveTypeNames.isEmpty) {
      reasonController.dispose();
      showMessage('ข้อมูลใบลาไม่ครบถ้วน', Colors.red);
      return;
    }

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            final totalDays =
                endDate!.difference(startDate!).inDays + 1;

            return AlertDialog(
              title: const Text('แก้ไขใบลา'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('ประเภทการลา'),
                    const SizedBox(height: 7),
                    DropdownButtonFormField<int>(
                      initialValue:
                          leaveTypeNames.containsKey(selectedLeaveTypeId)
                              ? selectedLeaveTypeId
                              : null,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                      ),
                      items: leaveTypeNames.entries.map((entry) {
                        return DropdownMenuItem<int>(
                          value: entry.key,
                          child: Text(entry.value),
                        );
                      }).toList(),
                      onChanged: isSaving
                          ? null
                          : (value) {
                              setDialogState(() {
                                selectedLeaveTypeId = value;
                              });
                            },
                    ),
                    const SizedBox(height: 15),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.calendar_today),
                      label: Text(
                        'วันเริ่มลา: ${formatDate(startDate!.toIso8601String())}',
                      ),
                      onPressed: isSaving
                          ? null
                          : () async {
                              final picked = await showDatePicker(
                                context: dialogContext,
                                initialDate: startDate!,
                                firstDate: DateTime(2000),
                                lastDate: DateTime(2100),
                                locale: const Locale('th'),
                              );

                              if (picked != null) {
                                setDialogState(() {
                                  startDate = DateTime(
                                    picked.year,
                                    picked.month,
                                    picked.day,
                                  );

                                  if (endDate!.isBefore(startDate!)) {
                                    endDate = startDate;
                                  }
                                });
                              }
                            },
                    ),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.event),
                      label: Text(
                        'วันสิ้นสุด: ${formatDate(endDate!.toIso8601String())}',
                      ),
                      onPressed: isSaving
                          ? null
                          : () async {
                              final picked = await showDatePicker(
                                context: dialogContext,
                                initialDate: endDate!,
                                firstDate: startDate!,
                                lastDate: DateTime(2100),
                                locale: const Locale('th'),
                              );

                              if (picked != null) {
                                setDialogState(() {
                                  endDate = DateTime(
                                    picked.year,
                                    picked.month,
                                    picked.day,
                                  );
                                });
                              }
                            },
                    ),
                    const SizedBox(height: 5),
                    Text(
                      'รวม $totalDays วัน',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 15),
                    const Text('เหตุผลการลา'),
                    const SizedBox(height: 7),
                    TextField(
                      controller: reasonController,
                      minLines: 3,
                      maxLines: 5,
                      enabled: !isSaving,
                      decoration: const InputDecoration(
                        hintText: 'ระบุเหตุผลการลา',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isSaving
                      ? null
                      : () => Navigator.pop(dialogContext),
                  child: const Text('ปิด'),
                ),
                ElevatedButton.icon(
                  onPressed: isSaving
                      ? null
                      : () async {
                          if (selectedLeaveTypeId == null) {
                            showMessage('กรุณาเลือกประเภทการลา', Colors.orange);
                            return;
                          }

                          if (reasonController.text.trim().isEmpty) {
                            showMessage('กรุณาระบุเหตุผลการลา', Colors.orange);
                            return;
                          }

                          if (endDate!.isBefore(startDate!)) {
                            showMessage('วันสิ้นสุดต้องไม่ก่อนวันเริ่มลา', Colors.orange);
                            return;
                          }

                          setDialogState(() {
                            isSaving = true;
                          });

                          try {
                            final updated = await supabase
                                .from('leave_requests')
                                .update({
                                  'leave_type_id': selectedLeaveTypeId,
                                  'start_date': startDate!
                                      .toIso8601String()
                                      .split('T')
                                      .first,
                                  'end_date': endDate!
                                      .toIso8601String()
                                      .split('T')
                                      .first,
                                  'total_days':
                                      endDate!.difference(startDate!).inDays + 1,
                                  'reason': reasonController.text.trim(),
                                  'updated_at': DateTime.now()
                                      .toUtc()
                                      .toIso8601String(),
                                })
                                .eq('id', requestId)
                                .eq('employee_id', user.id)
                                .eq('status', 'pending')
                                .select('id');

                            if (updated.isEmpty) {
                              throw Exception(
                                'ไม่มีสิทธิ์แก้ไข หรือใบลานี้ไม่ได้อยู่ในสถานะรออนุมัติแล้ว',
                              );
                            }

                            if (dialogContext.mounted) {
                              Navigator.pop(dialogContext);
                            }

                            showMessage('แก้ไขใบลาเรียบร้อยแล้ว', Colors.green);
                            await loadLeaveHistory();
                          } catch (e) {
                            setDialogState(() {
                              isSaving = false;
                            });

                            showMessage('แก้ไขใบลาไม่สำเร็จ: $e', Colors.red);
                          }
                        },
                  icon: isSaving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.save),
                  label: const Text('บันทึก'),
                ),
              ],
            );
          },
        );
      },
    );

    reasonController.dispose();
  }

  // ============================================================
  // ยกเลิกใบลาที่ยังรออนุมัติ
  // ============================================================

  Future<void> cancelLeaveRequest(
    Map<String, dynamic> request,
  ) async {
    final user = supabase.auth.currentUser;

    if (user == null) {
      showMessage('กรุณาเข้าสู่ระบบก่อน', Colors.red);
      return;
    }

    final requestId = (request['id'] as num?)?.toInt();

    if (requestId == null ||
        request['status']?.toString().toLowerCase() != 'pending') {
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('ยืนยันการยกเลิกใบลา'),
        content: const Text(
          'ต้องการยกเลิกใบลานี้ใช่หรือไม่?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('กลับ'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('ยืนยันยกเลิก'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    try {
      final updated = await supabase
          .from('leave_requests')
          .update({
            'status': 'cancelled',
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('id', requestId)
          .eq('employee_id', user.id)
          .eq('status', 'pending')
          .select('id');

      if (updated.isEmpty) {
        throw Exception('ไม่สามารถยกเลิกได้ ใบลาอาจถูกพิจารณาไปแล้ว');
      }

      showMessage('ยกเลิกใบลาเรียบร้อยแล้ว', Colors.green);
      await loadLeaveHistory();
    } catch (e) {
      showMessage('ยกเลิกใบลาไม่สำเร็จ: $e', Colors.red);
    }
  }

  // ============================================================
  // ลบใบลาที่ยังรออนุมัติ
  // ============================================================

  Future<void> deleteLeaveRequest(
    Map<String, dynamic> request,
  ) async {
    final user = supabase.auth.currentUser;

    if (user == null) {
      showMessage('กรุณาเข้าสู่ระบบก่อน', Colors.red);
      return;
    }

    final requestId = (request['id'] as num?)?.toInt();

    if (requestId == null ||
        request['status']?.toString().toLowerCase() != 'pending') {
      showMessage('ลบได้เฉพาะใบลาที่รออนุมัติเท่านั้น', Colors.orange);
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('ยืนยันการลบใบลา'),
        content: const Text(
          'ต้องการลบใบลานี้อย่างถาวรใช่หรือไม่?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('กลับ'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('ยืนยันลบ'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    try {
      final deleted = await supabase
          .from('leave_requests')
          .delete()
          .eq('id', requestId)
          .eq('employee_id', user.id)
          .eq('status', 'pending')
          .select('id');

      if (deleted.isEmpty) {
        throw Exception('ไม่สามารถลบได้ กรุณาตรวจสอบสิทธิ์ RLS');
      }

      showMessage('ลบใบลาเรียบร้อยแล้ว', Colors.green);
      await loadLeaveHistory();
    } catch (e) {
      showMessage('ลบใบลาไม่สำเร็จ: $e', Colors.red);
    }
  }

  // ============================================================
  // ลบใบลาที่อนุมัติแล้ว พร้อมคืนวันลา
  // ============================================================

  Future<void> deleteApprovedLeaveRequest(
    Map<String, dynamic> request,
  ) async {
    final requestId = (request['id'] as num?)?.toInt();

    if (requestId == null ||
        request['status']?.toString().toLowerCase() != 'approved') {
      showMessage('ลบได้เฉพาะใบลาที่อนุมัติแล้วเท่านั้น', Colors.orange);
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('ยืนยันการลบใบลาที่อนุมัติแล้ว'),
        content: const Text(
          'ระบบจะคืนจำนวนวันลากลับเข้ายอดคงเหลือก่อนลบ '
          'และลบประวัติการพิจารณาของใบลานี้ด้วย',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('กลับ'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('ยืนยันลบ'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    try {
      await supabase.rpc(
        'delete_approved_leave_request',
        params: {'p_leave_request_id': requestId},
      );

      showMessage('ลบใบลาและคืนวันลาเรียบร้อยแล้ว', Colors.green);
      await loadLeaveHistory();
    } catch (e) {
      showMessage('ลบใบลาไม่สำเร็จ: $e', Colors.red);
    }
  }

  // ============================================================
  // ล้างใบลาที่อนุมัติแล้วของพนักงานปัจจุบัน
  // ============================================================

  Future<void> clearApprovedLeaveRequests() async {
    final approvedCount = countStatus('approved');

    if (approvedCount == 0) {
      showMessage('ไม่มีรายการใบลาที่อนุมัติแล้ว', Colors.orange);
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('ยืนยันการล้างประวัติ'),
        content: Text(
          'ต้องการลบประวัติใบลาที่อนุมัติแล้วทั้งหมด '
          '$approvedCount รายการใช่หรือไม่?\n\n'
          'ระบบจะคืนจำนวนวันลากลับเข้ายอดคงเหลือ',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('กลับ'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('ล้างทั้งหมด'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    try {
      final result =
          await supabase.rpc('clear_approved_leave_requests');

      final deletedCount = (result as num?)?.toInt() ?? 0;

      showMessage(
        deletedCount > 0
            ? 'ล้างประวัติ $deletedCount รายการ และคืนวันลาเรียบร้อยแล้ว'
            : 'ไม่มีรายการที่ถูกลบ',
        deletedCount > 0 ? Colors.green : Colors.orange,
      );

      await loadLeaveHistory();
    } catch (e) {
      showMessage('ล้างประวัติไม่สำเร็จ: $e', Colors.red);
    }
  }

  // ============================================================
  // ลบใบลาที่ถูกยกเลิกเป็นรายใบ
  // ============================================================

  Future<void> deleteCancelledLeaveRequest(
    Map<String, dynamic> request,
  ) async {
    final requestId = (request['id'] as num?)?.toInt();

    if (requestId == null ||
        request['status']?.toString().toLowerCase() != 'cancelled') {
      showMessage('ลบได้เฉพาะใบลาที่ถูกยกเลิกแล้วเท่านั้น', Colors.orange);
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('ยืนยันการลบประวัติใบลาที่ถูกยกเลิก'),
        content: const Text('ต้องการลบประวัติใบลานี้ใช่หรือไม่?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('กลับ'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('ยืนยันลบ'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    try {
      await supabase.rpc(
        'delete_cancelled_leave_request',
        params: {'p_leave_request_id': requestId},
      );

      showMessage('ลบประวัติใบลาที่ถูกยกเลิกเรียบร้อยแล้ว', Colors.green);
      await loadLeaveHistory();
    } catch (e) {
      showMessage('ลบประวัติไม่สำเร็จ: $e', Colors.red);
    }
  }

  // ============================================================
  // ล้างใบลาที่ถูกยกเลิกของพนักงานปัจจุบัน
  // ============================================================

  Future<void> clearCancelledLeaveRequests() async {
    final cancelledCount = countStatus('cancelled');

    if (cancelledCount == 0) {
      showMessage('ไม่มีรายการใบลาที่ถูกยกเลิก', Colors.orange);
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('ยืนยันการล้างประวัติที่ยกเลิก'),
        content: Text(
          'ต้องการลบประวัติใบลาที่ถูกยกเลิกทั้งหมด '
          '$cancelledCount รายการใช่หรือไม่?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('กลับ'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('ล้างทั้งหมด'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    try {
      final result =
          await supabase.rpc('clear_cancelled_leave_requests');

      final deletedCount = (result as num?)?.toInt() ?? 0;

      showMessage(
        deletedCount > 0
            ? 'ล้างประวัติที่ยกเลิก $deletedCount รายการเรียบร้อยแล้ว'
            : 'ไม่มีรายการที่ถูกลบ',
        deletedCount > 0 ? Colors.green : Colors.orange,
      );

      await loadLeaveHistory();
    } catch (e) {
      showMessage('ล้างประวัติที่ยกเลิกไม่สำเร็จ: $e', Colors.red);
    }
  }

  // ============================================================
  // ADMIN: ล้างใบลาพนักงานทุกคน ทุกสถานะ
  // ============================================================

  Future<void> adminClearAllLeaveRequests() async {
    if (!widget.showAllEmployees) {
      showMessage('ฟังก์ชันนี้สำหรับผู้ดูแลระบบเท่านั้น', Colors.red);
      return;
    }

    if (isClearingAll) return;

    final totalCount = leaveRequests.length;

    if (totalCount == 0) {
      showMessage('ไม่มีรายการใบลาให้ลบ', Colors.orange);
      return;
    }

    final approvedCount = countStatus('approved');

    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.red),
            SizedBox(width: 9),
            Expanded(child: Text('ยืนยันล้างใบลาทั้งหมด')),
          ],
        ),
        content: Text(
          'คุณกำลังจะลบใบลาของพนักงานทุกคนอย่างถาวร\n\n'
          'จำนวนใบลาทั้งหมด: $totalCount รายการ\n'
          'ใบลาที่อนุมัติแล้ว: $approvedCount รายการ\n\n'
          'ระบบจะคืนจำนวนวันลาที่เคยหัก '
          'และลบประวัติการพิจารณา การแจ้งเตือน '
          'รวมถึงข้อมูลเอกสารแนบที่เกี่ยวข้อง\n\n'
          'การดำเนินการนี้ไม่สามารถย้อนกลับได้',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('ยกเลิก'),
          ),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(dialogContext, true),
            icon: const Icon(Icons.delete_forever),
            label: const Text('ยืนยันลบทั้งหมด'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() {
      isClearingAll = true;
    });

    try {
      final result = await supabase.rpc(
        'admin_clear_all_leave_requests',
      );

      if (result is! Map) {
        throw Exception('รูปแบบผลลัพธ์จาก Supabase ไม่ถูกต้อง');
      }

      final response = Map<String, dynamic>.from(result);

      if (response['success'] != true) {
        throw Exception('Supabase ไม่สามารถล้างข้อมูลได้');
      }

      final deletedCount =
          (response['deleted_count'] as num?)?.toInt() ?? 0;

      final storagePaths =
          (response['storage_paths'] as List?)
                  ?.map((path) => path.toString())
                  .where((path) => path.isNotEmpty)
                  .toList() ??
              <String>[];

      int deletedFileCount = 0;
      bool storageDeleteFailed = false;

      // ลบไฟล์ Storage เป็นชุด ชุดละ 100 ไฟล์
      for (int i = 0; i < storagePaths.length; i += 100) {
        final end = (i + 100 < storagePaths.length)
            ? i + 100
            : storagePaths.length;

        final batch = storagePaths.sublist(i, end);

        try {
          final removed = await supabase.storage
              .from(bucketName)
              .remove(batch);

          deletedFileCount += removed.length;
        } catch (e) {
          storageDeleteFailed = true;
          debugPrint('ลบไฟล์ Storage ไม่สำเร็จ: $e');
        }
      }

      if (!mounted) return;

      await loadLeaveHistory();

      if (!mounted) return;

      if (storageDeleteFailed) {
        showMessage(
          'ลบใบลา $deletedCount รายการสำเร็จ '
          'แต่มีไฟล์แนบบางส่วนลบไม่สำเร็จ '
          'กรุณาตรวจสอบ Storage ใน Supabase',
          Colors.orange,
        );
      } else {
        showMessage(
          'ล้างใบลาสำเร็จ $deletedCount รายการ '
          'และลบไฟล์แนบ $deletedFileCount ไฟล์',
          Colors.green,
        );
      }
    } catch (e) {
      debugPrint('ADMIN CLEAR ALL ERROR: $e');

      if (mounted) {
        showMessage('ล้างใบลาทั้งหมดไม่สำเร็จ: $e', Colors.red);
        await loadLeaveHistory();
      }
    } finally {
      if (mounted) {
        setState(() {
          isClearingAll = false;
        });
      }
    }
  }

  // ============================================================
  // หน้าจอหลัก
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FB),
      appBar: AppBar(
        title: Text(
          widget.showAllEmployees
              ? 'ใบลาพนักงานทั้งหมด'
              : 'ประวัติการลา',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFF087FD0),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            onPressed: isLoading ? null : loadLeaveHistory,
            icon: const Icon(Icons.refresh),
            tooltip: 'รีเฟรช',
          ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : errorMessage != null
              ? _buildError()
              : RefreshIndicator(
                  onRefresh: loadLeaveHistory,
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(20),
                    children: [
                      Text(
                        widget.showAllEmployees
                            ? 'ประวัติการลาของพนักงานทั้งหมด'
                            : 'ประวัติการลางานของฉัน',
                        style: const TextStyle(
                          fontSize: 23,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF142B4A),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        widget.showAllEmployees
                            ? 'ตรวจสอบใบลาและสถานะของพนักงานทุกคน'
                            : 'ตรวจสอบรายการและสถานะคำขอลาของคุณ',
                        style: const TextStyle(color: Colors.grey),
                      ),

                      if (widget.showAllEmployees) ...[
                        const SizedBox(height: 18),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed:
                                isClearingAll || leaveRequests.isEmpty
                                    ? null
                                    : adminClearAllLeaveRequests,
                            icon: isClearingAll
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Icon(Icons.delete_forever),
                            label: Text(
                              isClearingAll
                                  ? 'กำลังล้างข้อมูล...'
                                  : 'ล้างใบลาพนักงานทั้งหมด '
                                      '(${leaveRequests.length} รายการ)',
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red,
                              foregroundColor: Colors.white,
                              disabledBackgroundColor:
                                  Colors.red.withValues(alpha: 0.4),
                              padding: const EdgeInsets.symmetric(
                                vertical: 15,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                      ],

                      const SizedBox(height: 22),

                      Row(
                        children: [
                          Expanded(
                            child: summaryCard(
                              'ทั้งหมด',
                              leaveRequests.length,
                              Colors.blue,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: summaryCard(
                              'รออนุมัติ',
                              countStatus('pending'),
                              Colors.orange,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: summaryCard(
                              'อนุมัติแล้ว',
                              countStatus('approved'),
                              Colors.green,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 25),

                      const Text(
                        'กรองรายการ',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: Color(0xFF142B4A),
                        ),
                      ),

                      const SizedBox(height: 12),

                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            'ทั้งหมด',
                            'รออนุมัติ',
                            'อนุมัติแล้ว',
                            'ไม่อนุมัติ',
                            'ยกเลิก',
                          ].map((filter) {
                            final isSelected =
                                selectedFilter == filter;

                            return Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: ChoiceChip(
                                label: Text(filter),
                                selected: isSelected,
                                selectedColor:
                                    const Color(0xFFDCEEFF),
                                onSelected: (_) {
                                  setState(() {
                                    selectedFilter = filter;
                                  });
                                },
                              ),
                            );
                          }).toList(),
                        ),
                      ),

                      const SizedBox(height: 18),

                      if (selectedFilter == 'อนุมัติแล้ว' &&
                          countStatus('approved') > 0 &&
                          !widget.showAllEmployees) ...[
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: clearApprovedLeaveRequests,
                            icon: const Icon(Icons.delete_sweep),
                            label: Text(
                              'ล้างประวัติที่อนุมัติแล้วทั้งหมด '
                              '(${countStatus('approved')} รายการ)',
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red,
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ),
                        const SizedBox(height: 15),
                      ],

                      if (selectedFilter == 'ยกเลิก' &&
                          countStatus('cancelled') > 0 &&
                          !widget.showAllEmployees) ...[
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: clearCancelledLeaveRequests,
                            icon: const Icon(Icons.delete_sweep),
                            label: Text(
                              'ล้างประวัติที่ยกเลิกทั้งหมด '
                              '(${countStatus('cancelled')} รายการ)',
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red,
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ),
                        const SizedBox(height: 15),
                      ],

                      if (approvalLoadError != null)
                        _warningMessage(
                          'ไม่สามารถโหลดข้อมูลผู้พิจารณาได้ '
                          'กรุณาตรวจสอบสิทธิ์การอ่านข้อมูลใน Supabase',
                        ),

                      if (attachmentLoadError != null)
                        _warningMessage(
                          'ไม่สามารถโหลดรายการเอกสารแนบได้ '
                          'กรุณาตรวจสอบตาราง leave_attachments และ RLS',
                        ),

                      if (filteredRequests.isEmpty)
                        Container(
                          padding: const EdgeInsets.all(30),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(15),
                          ),
                          child: const Column(
                            children: [
                              Icon(
                                Icons.event_busy,
                                size: 55,
                                color: Colors.grey,
                              ),
                              SizedBox(height: 12),
                              Text(
                                'ไม่พบรายการลางาน',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ),
                        )
                      else
                        ...filteredRequests.map(buildLeaveCard),
                    ],
                  ),
                ),
    );
  }

  // ============================================================
  // ข้อความแจ้งเตือน
  // ============================================================

  Widget _warningMessage(String message) {
    return Container(
      margin: const EdgeInsets.only(bottom: 15),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.orange.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline, color: Colors.orange),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: Colors.deepOrange,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // หน้าจอ Error
  // ============================================================

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.error_outline,
              size: 55,
              color: Colors.red,
            ),
            const SizedBox(height: 12),
            const Text(
              'ไม่สามารถโหลดประวัติการลาได้',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              errorMessage ?? '',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 15),
            ElevatedButton.icon(
              onPressed: loadLeaveHistory,
              icon: const Icon(Icons.refresh),
              label: const Text('ลองอีกครั้ง'),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // การ์ดสรุป
  // ============================================================

  Widget summaryCard(
    String title,
    int count,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(13),
      ),
      child: Column(
        children: [
          Text(
            count.toString(),
            style: TextStyle(
              fontSize: 23,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 11,
              color: Colors.grey,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // การ์ดใบลา
  // ============================================================

  Widget buildLeaveCard(Map<String, dynamic> request) {
    final leaveTypeId =
        (request['leave_type_id'] as num?)?.toInt() ?? -1;

    final leaveName =
        leaveTypeNames[leaveTypeId] ?? 'ไม่ทราบประเภทการลา';

    final status = request['status']?.toString();

    final requestId =
        (request['id'] as num?)?.toInt() ?? -1;

    final approval = approvalByRequestId[requestId];

    final approverId = approval?['approver_id']?.toString();

    final approverName = approverId == null
        ? '-'
        : approverNames[approverId] ?? 'ไม่พบชื่อผู้อนุมัติ';

    final approvalAction = approval?['action'];
    final comment = approval?['comment']?.toString();

    return Container(
      margin: const EdgeInsets.only(bottom: 13),
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const CircleAvatar(
                backgroundColor: Color(0xFFEAF5FF),
                child: Icon(
                  Icons.event_note,
                  color: Color(0xFF087FD0),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  leaveName,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF142B4A),
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: statusColor(status).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  statusText(status),
                  style: TextStyle(
                    color: statusColor(status),
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),

          const Divider(height: 25),

          if (widget.showAllEmployees) ...[
            detailRow(
              Icons.person_outline,
              'พนักงาน',
              employeeNames[request['employee_id']?.toString()] ??
                  'ไม่พบชื่อพนักงาน',
            ),
            const SizedBox(height: 10),
          ],

          detailRow(
            Icons.calendar_today,
            'วันเริ่มลา',
            formatDate(request['start_date']),
          ),
          const SizedBox(height: 10),

          detailRow(
            Icons.event,
            'วันสิ้นสุด',
            formatDate(request['end_date']),
          ),
          const SizedBox(height: 10),

          detailRow(
            Icons.timelapse,
            'จำนวนวันลา',
            '${request['total_days'] ?? 0} วัน',
          ),
          const SizedBox(height: 10),

          detailRow(
            Icons.description_outlined,
            'เหตุผล',
            request['reason']?.toString() ?? '-',
          ),

          buildAttachments(requestId, request),

          if (approval != null) ...[
            const Divider(height: 28),
            const Row(
              children: [
                Icon(
                  Icons.verified_user,
                  color: Color(0xFF087FD0),
                  size: 19,
                ),
                SizedBox(width: 8),
                Text(
                  'ข้อมูลการพิจารณา',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF142B4A),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 15),

            detailRow(
              Icons.person_outline,
              'ผู้พิจารณา',
              approverName,
            ),
            const SizedBox(height: 10),

            detailRow(
              Icons.layers_outlined,
              'ระดับอนุมัติ',
              approval['approval_level']?.toString() ?? '-',
            ),
            const SizedBox(height: 10),

            detailRow(
              Icons.fact_check_outlined,
              'ผลพิจารณา',
              approvalActionText(approvalAction),
            ),
            const SizedBox(height: 10),

            detailRow(
              Icons.calendar_month,
              'วันที่พิจารณา',
              formatDateTime(approval['created_at']),
            ),

            if (comment != null && comment.trim().isNotEmpty) ...[
              const SizedBox(height: 10),
              detailRow(
                Icons.comment_outlined,
                'ความคิดเห็น',
                comment,
              ),
            ],

            const SizedBox(height: 8),

            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 10,
                vertical: 7,
              ),
              decoration: BoxDecoration(
                color: approvalActionColor(approvalAction)
                    .withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'ผลการพิจารณา: ${approvalActionText(approvalAction)}',
                style: TextStyle(
                  color: approvalActionColor(approvalAction),
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ] else if (!widget.showAllEmployees && status == 'pending') ...[
            const Divider(height: 28),
            const Row(
              children: [
                Icon(
                  Icons.hourglass_empty,
                  color: Colors.orange,
                  size: 19,
                ),
                SizedBox(width: 8),
                Text(
                  'กำลังรอการพิจารณาจากผู้อนุมัติ',
                  style: TextStyle(
                    color: Colors.orange,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ] else ...[
            const Divider(height: 28),
            const Row(
              children: [
                Icon(
                  Icons.info_outline,
                  color: Colors.blueGrey,
                  size: 19,
                ),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'ไม่พบข้อมูลรายละเอียดการพิจารณา',
                    style: TextStyle(
                      color: Colors.blueGrey,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          ],

          // ปุ่มสำหรับใบลารออนุมัติ
          if (!widget.showAllEmployees && status == 'pending') ...[
            const SizedBox(height: 16),
            const Divider(height: 1),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => editLeaveRequest(request),
                    icon: const Icon(Icons.edit_outlined, size: 18),
                    label: const Text('แก้ไขใบลา'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF087FD0),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => cancelLeaveRequest(request),
                    icon: const Icon(Icons.cancel_outlined, size: 18),
                    label: const Text('ยกเลิกใบลา'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                      side: const BorderSide(color: Colors.red),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 9),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => deleteLeaveRequest(request),
                icon: const Icon(Icons.delete_outline, size: 18),
                label: const Text('ลบใบลา'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  backgroundColor: Colors.red,
                  side: const BorderSide(color: Colors.red),
                ),
              ),
            ),
          ],

          // ปุ่มลบใบลาที่อนุมัติแล้ว
          if (!widget.showAllEmployees && status == 'approved') ...[
            const SizedBox(height: 16),
            const Divider(height: 1),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => deleteApprovedLeaveRequest(request),
                icon: const Icon(Icons.delete_outline, size: 18),
                label: const Text('ลบใบลาที่อนุมัติแล้ว'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  backgroundColor: Colors.red,
                  side: const BorderSide(color: Colors.red),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ],

          // ปุ่มลบใบลาที่ยกเลิก
          if (!widget.showAllEmployees && status == 'cancelled') ...[
            const SizedBox(height: 16),
            const Divider(height: 1),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => deleteCancelledLeaveRequest(request),
                icon: const Icon(Icons.delete_outline, size: 18),
                label: const Text('ลบประวัติใบลาที่ยกเลิก'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  backgroundColor: Colors.red,
                  side: const BorderSide(color: Colors.red),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ============================================================
  // แถวรายละเอียด
  // ============================================================

  Widget detailRow(
    IconData icon,
    String title,
    String value,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: Colors.blueGrey),
        const SizedBox(width: 10),
        SizedBox(
          width: 85,
          child: Text(
            title,
            style: const TextStyle(
              color: Colors.grey,
              fontSize: 13,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 13,
              color: Color(0xFF142B4A),
            ),
          ),
        ),
      ],
    );
  }
}
