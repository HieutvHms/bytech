import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:flutter/material.dart';
import 'package:new_renitek/const/custom_color.dart';
import 'package:new_renitek/const/custom_textstyle.dart';
import 'package:new_renitek/providers/app_provider.dart';
import 'package:new_renitek/service/check_firmware_service.dart';
import 'package:new_renitek/service/offline_ota_service.dart';
import 'package:provider/provider.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Scaffold(
        body: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 16),
              const Center(
                child: Text(
                  'Profile',
                  textAlign: TextAlign.center,
                  style: CustomTextStyle.h4Bold,
                ),
              ),
              const SizedBox(height: 32),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 24),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 18,
                      child: Icon(
                        Icons.person,
                        size: 28,
                      ),
                    ),
                    SizedBox(
                      width: 12,
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'David Nguyen',
                          style: CustomTextStyle.h5Medium,
                        ),
                        Text('davidnguyen@gmail.com'),
                      ],
                    ),
                    Spacer(),
                    Icon(Icons.arrow_forward_ios),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              Padding(
                padding: const EdgeInsets.only(left: 48),
                child: Text(
                  'Help',
                  style: CustomTextStyle.captionMedium
                      .copyWith(color: CustomColor.neutralBlack50),
                ),
              ),
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 36),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'FAQ',
                      style: CustomTextStyle.bodyMedium,
                    ),
                    Divider(
                      thickness: 0.3,
                    ),
                    Text(
                      'Hotline',
                      style: CustomTextStyle.bodyMedium,
                    ),
                    Divider(
                      thickness: 0.3,
                    ),
                    Text(
                      'Support Center',
                      style: CustomTextStyle.bodyMedium,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Padding(
                padding: const EdgeInsets.only(left: 48),
                child: Text(
                  'Device',
                  style: CustomTextStyle.captionMedium
                      .copyWith(color: CustomColor.neutralBlack50),
                ),
              ),
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 36),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Interface Settings',
                      style: CustomTextStyle.bodyMedium,
                    ),
                    const Divider(
                      thickness: 0.3,
                    ),
                    const Text(
                      'Upgrade firmware',
                      style: CustomTextStyle.bodyMedium,
                    ),
                    const Divider(
                      thickness: 0.3,
                    ),
                    Consumer<AppProvider>(
                      builder: (context, provider, child) {
                        return Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Expanded(
                              child: Text(
                                'Expert Mode',
                                style: CustomTextStyle.bodyMedium,
                              ),
                            ),
                            Switch(
                              value: provider.isExpertMode,
                              onChanged: (value) {
                                provider.toggleExpertMode(value);
                              },
                              activeThumbColor: CustomColor.primaryColor,
                            ),
                          ],
                        );
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              // NÚT KIỂM TRA & TẢI FW MỚI NHẤT TỪ SERVER
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 36),
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.system_update_alt, color: Colors.white),
                  onPressed: () async {
                    // Hiện dialog đang kiểm tra
                    showDialog(
                      context: context,
                      barrierDismissible: false,
                      builder: (ctx) => const AlertDialog(
                        content: Row(
                          children: [
                            CircularProgressIndicator(),
                            SizedBox(width: 16),
                            Expanded(child: Text('Đang kiểm tra FW mới nhất...')),
                          ],
                        ),
                      ),
                    );

                    try {
                      // Gọi API lấy danh sách FW mới nhất từ server
                      final firmwares = await CheckFirmwareService.getLatestFirmwaresFromServer();

                      if (!context.mounted) return;
                      Navigator.pop(context); // Tắt dialog kiểm tra

                      if (firmwares.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                          content: Text('Không tìm thấy FW nào trên server.'),
                          backgroundColor: Colors.orange,
                        ));
                        return;
                      }

                      // Server đã trả về bản mới nhất → tự động tải tất cả về
                      int successCount = 0;

                      for (final fw in firmwares) {
                        final url = fw['url'] ?? fw['update_url'] ?? '';
                        if (url.isEmpty) continue;
                        final fileName = Uri.parse(url).pathSegments.last;

                        // Trích xuất hardware type thuần từ tên file .bin
                        // VD: "AV01_NEW_HW_12102025.bin" → "AV01_NEW_HW"
                        // Bỏ phần .bin và bỏ phần số version cuối (8 chữ số ngày tháng)
                        final fileBase = fileName.replaceAll('.bin', '');
                        // Tách bỏ phần số ở cuối (version/date) → lấy hardware type
                        final hwType = fileBase.replaceAll(RegExp(r'_\d+$'), '');

                        // Hiện progress từng file
                        if (context.mounted) {
                          showDialog(
                            context: context,
                            barrierDismissible: false,
                            builder: (_) => AlertDialog(
                              content: Row(
                                children: [
                                  const CircularProgressIndicator(),
                                  const SizedBox(width: 16),
                                  Expanded(child: Text('Đang tải $fileName...')),
                                ],
                              ),
                            ),
                          );
                        }

                        try {
                          final res = await http
                              .get(Uri.parse(url))
                              .timeout(const Duration(seconds: 60));

                          if (context.mounted) Navigator.pop(context);

                          if (res.statusCode == 200) {
                            final dir = await getApplicationDocumentsDirectory();
                            final localPath = '${dir.path}/$fileName';
                            await File(localPath).writeAsBytes(res.bodyBytes);
                            // Lưu với hwType thuần (VD: "AV01_NEW_HW") thay vì key có revision
                            await OfflineOTAService.saveDynamicHardwareMapping(hwType, url, localPath);
                            successCount++;
                          }
                        } catch (_) {
                          if (context.mounted) Navigator.pop(context);
                        }
                      }

                      // Thông báo kết quả tổng
                      if (context.mounted) {
                        final msg = successCount > 0
                            ? 'Đã tải xong $successCount file FW mới nhất!'
                            : 'Tải thất bại. Vui lòng kiểm tra kết nối!';
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                          content: Text(msg),
                          backgroundColor: successCount > 0 ? Colors.green : Colors.red,
                        ));
                      }
                    } catch (e) {
                      if (context.mounted) Navigator.pop(context);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                          content: Text('Vui lòng kết nối Internet!'),
                          backgroundColor: Colors.red,
                        ));
                      }
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: CustomColor.primaryColor,
                    minimumSize: const Size.fromHeight(50),
                  ),
                  label: const Text('Tải toàn bộ Firmware (Offline Toolkit)',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                ),
              ),
              const SizedBox(height: 10),
              Container(
                alignment: Alignment.center,
                margin:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                    color: CustomColor.neutralWhite90,
                    borderRadius: BorderRadius.circular(12)),
                child: const Text('Log out'),
              )
            ],
          ),
        ),
      ),
    );
  }
}
