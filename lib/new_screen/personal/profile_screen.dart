import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:flutter/material.dart';
import 'package:new_renitek/const/custom_color.dart';
import 'package:new_renitek/const/custom_textstyle.dart';
import 'package:new_renitek/providers/app_provider.dart';
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
              // NÚT TEST TẠM THỜI DÀNH CHO BẠN
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 36),
                child: ElevatedButton(
                  onPressed: () async {
                    showDialog(
                      context: context,
                      builder: (ctx) =>
                          const Center(child: CircularProgressIndicator()),
                    );
                    // Giả lập Server vừa trả về file mới tinh cho AV01_NEW_HW
                    const hardwareVersion = "AV01_NEW_HW";
                    // Đổi thành URL có thật (đuôi 12102025) để tải thành công
                    const url =
                        "http://27.71.226.192:2602/AV01_NEW_HW_12102025.bin";
                    try {
                      final response = await http
                          .get(Uri.parse(url))
                          .timeout(const Duration(seconds: 15));
                      if (response.statusCode == 200) {
                        final directory =
                            await getApplicationDocumentsDirectory();
                        final permanentPath =
                            '${directory.path}/fw_TEST_AV01_NEW_HW.bin';
                        final permanentFile = File(permanentPath);
                        await permanentFile.writeAsBytes(response.bodyBytes);

                        // Kích hoạt hàm lưu Dynamic
                        await OfflineOTAService.saveDynamicHardwareMapping(
                            hardwareVersion, url, permanentPath);

                        if (context.mounted) Navigator.pop(context); // Tắt xoay
                        if (context.mounted) {
                          ScaffoldMessenger.of(context)
                              .showSnackBar(const SnackBar(
                            content: Text(
                                'TEST: Đã tải xong file DYNAMIC cho AV01_NEW_HW!'),
                            backgroundColor: Colors.green,
                          ));
                        }
                      } else {
                        if (context.mounted)
                          Navigator.pop(context); // Tắt xoay nếu lỗi 404
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                            content: Text('Lỗi Server: ${response.statusCode}'),
                            backgroundColor: Colors.red,
                          ));
                        }
                      }
                    } catch (e) {
                      if (context.mounted)
                        Navigator.pop(context); // Tắt xoay nếu mất mạng
                      if (context.mounted) {
                        ScaffoldMessenger.of(context)
                            .showSnackBar(const SnackBar(
                          content: Text('Vui lòng kết nối Internet!'),
                          backgroundColor: Colors.red,
                        ));
                      }
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    minimumSize: const Size.fromHeight(50),
                  ),
                  child: const Text('Tải DYNAMIC FW',
                      style: TextStyle(color: Colors.white)),
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
