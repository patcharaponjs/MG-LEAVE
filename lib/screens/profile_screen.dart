import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:crop_your_image/crop_your_image.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'change_password_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final SupabaseClient supabase = Supabase.instance.client;

  Map<String, dynamic>? profile;
  bool isLoading = true;
  bool isSaving = false;
  String? errorMessage;

  @override
  void initState() {
    super.initState();
    loadProfile();
  }

  // โหลดข้อมูลโปรไฟล์
  Future<void> loadProfile() async {
    final user = supabase.auth.currentUser;

    if (user == null) {
      if (!mounted) return;
      setState(() {
        isLoading = false;
        errorMessage = 'กรุณาเข้าสู่ระบบใหม่';
      });
      return;
    }

    if (mounted) {
      setState(() {
        isLoading = true;
        errorMessage = null;
      });
    }

    try {
      final response = await supabase
          .from('profiles')
          .select('''
  employee_code,
  full_name,
  phone,
  avatar_url,
  position,
  role,
  department:departments(department_name)
''')
          .eq('id', user.id)
          .maybeSingle();

      if (!mounted) return;

      if (response == null) {
        setState(() {
          isLoading = false;
          errorMessage = 'ไม่พบข้อมูลโปรไฟล์';
        });
        return;
      }

      setState(() {
        profile = response;
        isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        isLoading = false;
        errorMessage = 'ไม่สามารถโหลดข้อมูลได้: $e';
      });
    }
  }

  // อ่านข้อมูลจากโปรไฟล์
  String getValue(String key) {
    final value = profile?[key];

    if (value == null || value.toString().trim().isEmpty) {
      return '-';
    }

    return value.toString();
  }

  // อ่านชื่อแผนก
  String getDepartmentName() {
    final department = profile?['department'];

    if (department is Map) {
      return department['department_name']?.toString() ?? '-';
    }

    if (department is List && department.isNotEmpty) {
      return department.first['department_name']?.toString() ?? '-';
    }

    return '-';
  }

  // ตัวอักษรบนรูปโปรไฟล์
  String getInitials() {
    final name = getValue('full_name');

    if (name == '-') return 'MG';

    return name.characters.first;
  }

  bool get isAdmin => getValue('role') == 'admin';

  // เลือกภาพ และเปิดหน้าจอจัดตำแหน่งภาพ
  Future<void> changeProfilePhoto() async {
    if (isSaving) return;

    try {
      final picker = ImagePicker();

      final pickedFile = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 95,
      );

      if (pickedFile == null || !mounted) return;

      final Uint8List originalBytes = await pickedFile.readAsBytes();

      if (!mounted) return;

      final croppedBytes = await showDialog<Uint8List>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) {
          return ProfileCropDialog(imageBytes: originalBytes);
        },
      );

      if (croppedBytes == null || !mounted) return;

      await uploadProfilePhoto(croppedBytes, pickedFile.name);
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('ไม่สามารถเลือกรูปได้: $e'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 5),
        ),
      );
    }
  }

  // อัปโหลดรูปที่ตัดแล้ว และบันทึก URL ลง profiles
  Future<void> uploadProfilePhoto(
    Uint8List bytes,
    String originalFileName,
  ) async {
    final user = supabase.auth.currentUser;

    if (user == null) {
      throw Exception('กรุณาเข้าสู่ระบบใหม่');
    }

    setState(() => isSaving = true);

    try {
      String extension = 'png';

      final fileNameParts = originalFileName.split('.');
      if (fileNameParts.length > 1) {
        final candidate = fileNameParts.last.toLowerCase();

        if (['png', 'jpg', 'jpeg', 'webp'].contains(candidate)) {
          extension = candidate == 'jpg' ? 'jpeg' : candidate;
        }
      }

      final contentType = switch (extension) {
        'png' => 'image/png',
        'webp' => 'image/webp',
        _ => 'image/jpeg',
      };

      final filePath = '${user.id}/profile.$extension';

      // อัปโหลดรูปที่จัดตำแหน่งแล้ว
      await supabase.storage
          .from('profile-photos')
          .uploadBinary(
            filePath,
            bytes,
            fileOptions: FileOptions(contentType: contentType, upsert: true),
          );

      // สร้าง URL รูป
      final imageUrl = supabase.storage
          .from('profile-photos')
          .getPublicUrl(filePath);

      // บันทึก URL ลง profiles
      await supabase
          .from('profiles')
          .update({'avatar_url': imageUrl})
          .eq('id', user.id);

      // โหลดข้อมูลใหม่
      if (!mounted) return;

      await loadProfile();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('เปลี่ยนรูปโปรไฟล์เรียบร้อยแล้ว'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('ไม่สามารถบันทึกรูปโปรไฟล์ได้: $e'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 5),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => isSaving = false);
      }
    }
  }

  // แก้ไขชื่อ-นามสกุล
  Future<void> editFullName() async {
    final controller = TextEditingController(
      text: getValue('full_name') == '-' ? '' : getValue('full_name'),
    );

    final newName = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          title: const Text(
            'แก้ไขชื่อ-นามสกุล',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          content: TextField(
            controller: controller,
            autofocus: true,
            maxLength: 150,
            decoration: InputDecoration(
              labelText: 'ชื่อ-นามสกุล',
              hintText: 'กรอกชื่อและนามสกุล',
              prefixIcon: const Icon(Icons.person_outline),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext);
              },
              child: const Text('ยกเลิก'),
            ),
            ElevatedButton(
              onPressed: () {
                final name = controller.text.trim();

                if (name.length < 2) {
                  ScaffoldMessenger.of(dialogContext).showSnackBar(
                    const SnackBar(
                      content: Text('กรุณากรอกชื่ออย่างน้อย 2 ตัวอักษร'),
                    ),
                  );
                  return;
                }

                Navigator.pop(dialogContext, name);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF087FD0),
                foregroundColor: Colors.white,
              ),
              child: const Text('บันทึก'),
            ),
          ],
        );
      },
    );

    controller.dispose();

    if (newName == null || !mounted) return;

    await saveFullName(newName);
  }

  // บันทึกชื่อผ่าน Supabase RPC
  Future<void> saveFullName(String newName) async {
    setState(() {
      isSaving = true;
    });

    try {
      await supabase.rpc('update_my_profile', params: {'p_full_name': newName});

      if (!mounted) return;

      await loadProfile();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('บันทึกข้อมูลส่วนตัวเรียบร้อยแล้ว'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('ไม่สามารถบันทึกข้อมูลได้: $e'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 5),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          isSaving = false;
        });
      }
    }
  }

  // เปิดหน้าเปลี่ยนรหัสผ่าน
  void openChangePassword() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ChangePasswordScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FB),
      appBar: AppBar(
        title: const Text(
          'ข้อมูลส่วนตัว',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFF087FD0),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            tooltip: 'รีเฟรชข้อมูล',
            onPressed: isLoading ? null : loadProfile,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : errorMessage != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(25),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      color: Colors.red,
                      size: 55,
                    ),
                    const SizedBox(height: 15),
                    Text(errorMessage!, textAlign: TextAlign.center),
                    const SizedBox(height: 15),
                    ElevatedButton.icon(
                      onPressed: loadProfile,
                      icon: const Icon(Icons.refresh),
                      label: const Text('ลองอีกครั้ง'),
                    ),
                  ],
                ),
              ),
            )
          : Stack(
              children: [
                RefreshIndicator(
                  onRefresh: loadProfile,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        // ส่วนหัวโปรไฟล์
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                            vertical: 28,
                            horizontal: 20,
                          ),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF087FD0), Color(0xFF0399D1)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Column(
                            children: [
                              GestureDetector(
                                onTap: changeProfilePhoto,
                                child: Stack(
                                  alignment: Alignment.center,
                                  children: [
                                    CircleAvatar(
                                      radius: 48,
                                      backgroundColor: Colors.white,
                                      backgroundImage:
                                          getValue('avatar_url') != '-'
                                          ? NetworkImage(
                                              '${getValue('avatar_url')}?v=${DateTime.now().millisecondsSinceEpoch}',
                                            )
                                          : null,
                                      child: getValue('avatar_url') == '-'
                                          ? Text(
                                              getInitials(),
                                              style: const TextStyle(
                                                color: Color(0xFF087FD0),
                                                fontSize: 30,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            )
                                          : null,
                                    ),
                                    Positioned(
                                      right: 0,
                                      bottom: 0,
                                      child: Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF087FD0),
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                            color: Colors.white,
                                            width: 2,
                                          ),
                                        ),
                                        child: const Icon(
                                          Icons.camera_alt,
                                          color: Colors.white,
                                          size: 18,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                'แตะรูปเพื่อเปลี่ยนรูปโปรไฟล์',
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 12,
                                ),
                              ),
                              const SizedBox(height: 15),
                              Text(
                                getValue('full_name'),
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 21,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                isAdmin
                                    ? 'ผู้ดูแลระบบ (Administrator)'
                                    : 'พนักงาน (Employee)',
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 7,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  isAdmin ? 'ADMIN' : 'EMPLOYEE',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 1,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 15),

                        // ปุ่มแก้ไขชื่อ-นามสกุล
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: isSaving ? null : editFullName,
                            icon: const Icon(Icons.edit_outlined),
                            label: const Text('แก้ไขชื่อ-นามสกุล'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF087FD0),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 15),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 12),

                        // ปุ่มเปลี่ยนรหัสผ่าน
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: openChangePassword,
                            icon: const Icon(Icons.lock_reset),
                            label: const Text('เปลี่ยนรหัสผ่าน'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFF087FD0),
                              side: const BorderSide(color: Color(0xFF087FD0)),
                              padding: const EdgeInsets.symmetric(vertical: 15),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 22),

                        // ข้อมูลบัญชี
                        _sectionTitle('ข้อมูลบัญชี'),

                        _infoCard(
                          icon: Icons.badge_outlined,
                          title: 'รหัสพนักงาน',
                          value: getValue('employee_code'),
                        ),

                        _infoCard(
                          icon: Icons.person_outline,
                          title: 'ชื่อ-นามสกุล',
                          value: getValue('full_name'),
                        ),

                        _infoCard(
                          icon: Icons.phone_outlined,
                          title: 'เบอร์โทรศัพท์',
                          value: getValue('phone'),
                        ),
                        const SizedBox(height: 12),

                        // ข้อมูลการทำงาน
                        _sectionTitle('ข้อมูลการทำงาน'),

                        _infoCard(
                          icon: Icons.apartment_outlined,
                          title: 'แผนก',
                          value: getDepartmentName(),
                        ),

                        _infoCard(
                          icon: Icons.work_outline,
                          title: 'ตำแหน่ง',
                          value: getValue('position'),
                        ),

                        _infoCard(
                          icon: Icons.admin_panel_settings_outlined,
                          title: 'สิทธิ์ผู้ใช้งาน',
                          value: isAdmin
                              ? 'ผู้ดูแลระบบ (Admin)'
                              : 'พนักงาน (Employee)',
                        ),

                        const SizedBox(height: 20),

                        // ข้อความท้ายหน้า
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(17),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(15),
                          ),
                          child: const Row(
                            children: [
                              Icon(
                                Icons.verified_user_outlined,
                                color: Color(0xFF087FD0),
                                size: 26,
                              ),
                              SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  'ข้อมูลส่วนตัวของคุณถูกดึงจากระบบ MG LEAVE MANAGEMENT',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Color(0xFF142B4A),
                                    height: 1.5,
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

                // แสดงสถานะกำลังบันทึก
                if (isSaving)
                  Container(
                    color: Colors.black.withValues(alpha: 0.08),
                    child: const Center(
                      child: Card(
                        child: Padding(
                          padding: EdgeInsets.all(22),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              CircularProgressIndicator(),
                              SizedBox(height: 14),
                              Text('กำลังบันทึกข้อมูล...'),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
    );
  }

  // หัวข้อแต่ละส่วน
  Widget _sectionTitle(String title) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: Color(0xFF142B4A),
        ),
      ),
    );
  }

  // การ์ดแสดงข้อมูล
  Widget _infoCard({
    required IconData icon,
    required String title,
    required String value,
  }) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 11),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Container(
            width: 45,
            height: 45,
            decoration: BoxDecoration(
              color: const Color(0xFFE8F3FC),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: const Color(0xFF087FD0), size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
                const SizedBox(height: 5),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF142B4A),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================
// หน้าจอจัดตำแหน่งรูปโปรไฟล์
// =============================================================

class ProfileCropDialog extends StatefulWidget {
  final Uint8List imageBytes;

  const ProfileCropDialog({super.key, required this.imageBytes});

  @override
  State<ProfileCropDialog> createState() => _ProfileCropDialogState();
}

class _ProfileCropDialogState extends State<ProfileCropDialog> {
  final CropController cropController = CropController();

  bool isCropping = false;

  void cropImage() {
    if (isCropping) return;

    setState(() {
      isCropping = true;
    });

    // ตัดรูปเป็นวงกลม
    cropController.cropCircle();
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;

    return Dialog(
      insetPadding: const EdgeInsets.all(16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        width: 520,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: screenSize.height * 0.85),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // หัวข้อ
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF087FD0), Color(0xFF0399D1)],
                  ),
                ),
                child: const Column(
                  children: [
                    Icon(Icons.account_circle, color: Colors.white, size: 35),
                    SizedBox(height: 8),
                    Text(
                      'จัดตำแหน่งรูปโปรไฟล์',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    SizedBox(height: 6),
                    Text(
                      'ลากรูปเพื่อจัดตำแหน่ง และซูมเพื่อปรับขนาด',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white70, fontSize: 13),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 18),

              // คำแนะนำ
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.touch_app, color: Color(0xFF087FD0)),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        'ลากภาพและซูมเพื่อให้รูปพอดีกับกรอบ',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.grey.shade700,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 15),

              // พื้นที่ตัดรูป
              Flexible(
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  height: screenSize.height * 0.38,
                  decoration: BoxDecoration(
                    color: const Color(0xFF202936),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Crop(
                    image: widget.imageBytes,
                    controller: cropController,
                    withCircleUi: true,
                    interactive: true,
                    fixCropRect: true,
                    aspectRatio: 1,
                    baseColor: const Color(0xFF202936),
                    maskColor: Colors.black.withValues(alpha: 0.65),
                    radius: 20,
                    willUpdateScale: (newScale) => newScale < 5,
                    onCropped: (result) {
                      switch (result) {
                        case CropSuccess(:final croppedImage):
                          Navigator.of(context).pop(croppedImage);

                        case CropFailure(:final cause):
                          if (mounted) {
                            setState(() {
                              isCropping = false;
                            });

                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('ตัดรูปไม่สำเร็จ: $cause'),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                      }
                    },
                  ),
                ),
              ),

              const SizedBox(height: 15),

              // ปุ่ม
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: isCropping
                            ? null
                            : () {
                                Navigator.of(context).pop();
                              },
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.grey.shade700,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text('ยกเลิก'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: isCropping ? null : cropImage,
                        icon: isCropping
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.check_circle_outline),
                        label: Text(
                          isCropping ? 'กำลังตัดรูป...' : 'ใช้รูปนี้',
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF087FD0),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
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
  }
}
