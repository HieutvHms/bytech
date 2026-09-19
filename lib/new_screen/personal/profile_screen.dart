import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:flutter/material.dart';
import 'package:new_renitek/const/custom_color.dart';
import 'package:new_renitek/const/custom_textstyle.dart';
import 'package:new_renitek/providers/app_provider.dart';
import 'package:new_renitek/service/check_firmware_service.dart';
import 'package:new_renitek/service/offline_ota_service.dart';
import 'package:new_renitek/utils/snackbar_helper.dart';
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
              const SizedBox(height: 12),
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
              const SizedBox(height: 12),
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
              const SizedBox(height: 12),
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
              const SizedBox(height: 24),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  children: [
                    ElevatedButton.icon(
                      icon:
                          const Icon(Icons.cloud_download, color: Colors.white),
                      onPressed: () => _downloadFirmwares(context, true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: CustomColor.primaryColor,
                        minimumSize: const Size.fromHeight(50),
                      ),
                      label: const Text('Tải FW Mới Nhất (Server)',
                          style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 15)),
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.save_alt,
                          color: CustomColor.primaryColor),
                      onPressed: () => _downloadFirmwares(context, false),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: CustomColor.primaryColor,
                        side: const BorderSide(color: CustomColor.primaryColor),
                        minimumSize: const Size.fromHeight(50),
                      ),
                      label: const Text('Tải Kho Dự Phòng (Bản ổn định)',
                          style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 15)),
                    ),
                  ],
                ),
              ),
              // const SizedBox(height: 10),
              // Container(
              //   alignment: Alignment.center,
              //   margin:
              //       const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
              //   padding: const EdgeInsets.symmetric(vertical: 12),
              //   decoration: BoxDecoration(
              //       color: CustomColor.neutralWhite90,
              //       borderRadius: BorderRadius.circular(12)),
              //   child: const Text('Log out'),
              // )
            ],
          ),
        ),
      ),
    );
  }
}

Future<void> _downloadFirmwares(BuildContext context, bool useApi) async {
  // Hiển thị 1 Dialog duy nhất cho toàn bộ quá trình
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => const AlertDialog(
      content: Row(
        children: [
          CircularProgressIndicator(),
          SizedBox(width: 16),
          Expanded(child: Text('Đang tải dữ liệu. Vui lòng đợi...')),
        ],
      ),
    ),
  );

  try {
    final firmwares = useApi
        ? await CheckFirmwareService.getLatestFirmwaresFromServer()
        : await CheckFirmwareService.getAllFirmwares();

    if (firmwares.isEmpty) {
      if (context.mounted) Navigator.pop(context); // Tắt dialog
      if (context.mounted) {
        SnackbarHelper.showInfo(context, 'Thông báo', 'Không tìm thấy FW nào.');
      }
      return;
    }

    int successCount = 0;
    for (final fw in firmwares) {
      final url = fw['url'] ?? fw['update_url'] ?? '';
      if (url.isEmpty) continue;
      final fileName = Uri.parse(url).pathSegments.last;
      final fileBase = fileName.replaceAll('.bin', '');
      final hwType = fileBase.replaceAll(RegExp(r'_\d+$'), '');

      final dir = await getApplicationDocumentsDirectory();
      final localPath = '${dir.path}/$fileName';

      // CHẶN TẢI LẠI: Kiểm tra xem file đã tồn tại trong máy chưa
      if (await File(localPath).exists()) {
        await OfflineOTAService.saveDynamicHardwareMapping(
            hwType, url, localPath);
        successCount++;
        continue;
      }

      try {
        final res =
            await http.get(Uri.parse(url)).timeout(const Duration(seconds: 15));
        if (res.statusCode == 200) {
          await File(localPath).writeAsBytes(res.bodyBytes);
          await OfflineOTAService.saveDynamicHardwareMapping(
              hwType, url, localPath);
          successCount++;
        }
      } catch (e) {
        print('Lỗi tải $fileName: $e');
        // Tiếp tục thử tải file khác nếu có
      }
    }

    if (context.mounted) Navigator.pop(context); // Tắt dialog

    if (context.mounted) {
      if (successCount > 0) {
        final message = useApi
            ? 'Đã tải xong $successCount file FW mới nhất từ server!'
            : 'Đã tải xong $successCount file FW dự phòng!';
        SnackbarHelper.showSuccess(context, 'Hoàn tất', message);
      } else {
        SnackbarHelper.showError(context, 'Tải thất bại',
            'Không tải được file nào. Vui lòng kiểm tra kết nối mạng!');
      }
    }
  } catch (e) {
    if (context.mounted) Navigator.pop(context); // Tắt dialog
    if (context.mounted) {
      SnackbarHelper.showError(
          context, 'Lỗi kết nối', 'Vui lòng kiểm tra lại kết nối Internet!');
    }
  }
}
