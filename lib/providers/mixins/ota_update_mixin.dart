import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:new_renitek/const/custom_color.dart';
import 'package:new_renitek/providers/mixins/app_provider_state.dart';
import 'package:new_renitek/root.dart';
import 'package:new_renitek/service/check_firmware_service.dart';
import 'package:new_renitek/service/offline_ota_service.dart';
import 'package:new_renitek/utils/show_status.dart';
import 'package:new_renitek/utils/snackbar_helper.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

mixin OtaUpdateMixin on AppProviderState {
  @override
  void updateFirmWare({String? url, String? offlineFilePath}) {
    if (firmwareCheckResult == null && offlineFilePath == null && url == null) {
      if (globalKey.currentContext != null) {
        showStatus(
          buildContext: globalKey.currentContext!,
          message: 'Please check for firmware updates first',
          succcess: false,
        );
      }
      return;
    }

    if (firmwareCheckResult != null &&
        firmwareCheckResult!.noUpdate &&
        offlineFilePath == null) {
      if (globalKey.currentContext != null) {
        showStatus(
          buildContext: globalKey.currentContext!,
          message: 'Firmware is already up to date',
          succcess: true,
        );
      }
      return;
    }

    try {
      if (connectStatus == ConnectStatus.BLE &&
          bluetoothCharacteristic != null &&
          url != null) {
        final updateCommand = getFirmwareUpdateCommand(url);
        ble.writeCharacteristicWithResponse(bluetoothCharacteristic!,
            value: updateCommand);
        print(updateCommand);
        print(String.fromCharCodes(updateCommand));
        isExpertMode = false;
        notifyListeners();
        if (globalKey.currentContext != null) {
          showStatus(
            buildContext: globalKey.currentContext!,
            message: 'Firmware update command sent via BLE.',
            succcess: true,
          );
        }
        return;
      }

      final ip = mdnsConnectedClient?.host ?? tcpIP;
      if (ip.isEmpty) {
        if (globalKey.currentContext != null) {
          showStatus(
            buildContext: globalKey.currentContext!,
            message: 'Failed to update firmware: IP Address is unknown',
            succcess: false,
          );
        }
        return;
      }

      if (globalKey.currentContext != null) {
        showDialog(
          context: globalKey.currentContext!,
          barrierDismissible: false,
          builder: (BuildContext context) {
            return const Dialog(
              child: Padding(
                padding: EdgeInsets.all(12),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(width: 20),
                    Text("Đang gửi Firmware..."),
                  ],
                ),
              ),
            );
          },
        );
      }

      Future<void> doUpdate(String filePath) async {
        await OfflineOTAService.pushFirmwareViaHttp(ip, filePath);
      }

      Future<String> getFilePath() async {
        if (offlineFilePath != null) {
          return offlineFilePath;
        } else if (url != null) {
          if (hardwareVersion != null) {
            final fallbackData =
                await OfflineOTAService.getFallbackOfflineFilePath(
                    hardwareVersion!);
            if (fallbackData != null && fallbackData['url'] == url) {
              final cachedFile = File(fallbackData['localFilePath']!);
              if (await cachedFile.exists()) {
                print('Đã có sẵn file trong máy, bỏ qua download!');
                return fallbackData['localFilePath']!;
              }
            }
          }

          if (globalKey.currentContext != null) {
            showStatus(
              buildContext: globalKey.currentContext!,
              message: 'Đang tải firmware từ server...',
              succcess: true,
            );
          }
          final response = await http.get(Uri.parse(url));
          if (response.statusCode != 200) {
            throw Exception(
                'Không tải được file từ server: HTTP ${response.statusCode}');
          }
          final directory = await getApplicationDocumentsDirectory();
          final fileName = Uri.parse(url).pathSegments.last;
          final permanentPath = '${directory.path}/fw_$fileName';
          final permanentFile = File(permanentPath);
          await permanentFile.writeAsBytes(response.bodyBytes);

          String hwToSave = hardwareVersion ??
              fileName.replaceAll('.bin', '').replaceAll(RegExp(r'_\d+$'), '');
          await OfflineOTAService.saveDynamicHardwareMapping(
              hwToSave, url, permanentPath);

          return permanentPath;
        } else {
          throw Exception('Không có file hoặc URL để cập nhật');
        }
      }

      getFilePath().then((filePath) {
        return doUpdate(filePath);
      }).then((_) {
        if (globalKey.currentContext != null) {
          Navigator.pop(globalKey.currentContext!);
        }
        notifyListeners();

        if (globalKey.currentContext != null) {
          showDialog(
            context: globalKey.currentContext!,
            barrierDismissible: false,
            builder: (BuildContext context) {
              return AlertDialog(
                title: const Text('Cập nhật thành công'),
                content: const Text(
                    'Thiết bị đã nhận bản cập nhật và đang khởi động lại.\n\n'
                    'Vui lòng vào Cài đặt Wi-Fi của điện thoại để kết nối lại với mạng của thiết bị (nếu cần), sau đó quay lại màn hình Connect để tiếp tục sử dụng.'),
                actions: [
                  TextButton(
                    onPressed: () {
                      Navigator.pop(context);
                      disconnectTCP();
                      final rootContext = globalKey.currentContext;
                      if (rootContext != null) {
                        Navigator.of(rootContext)
                            .popUntil((route) => route.isFirst);
                      }
                    },
                    child: const Text('Đã hiểu'),
                  ),
                ],
              );
            },
          );
        }
      }).catchError((e) {
        if (globalKey.currentContext != null) {
          Navigator.pop(globalKey.currentContext!);
          showStatus(
            buildContext: globalKey.currentContext!,
            message: 'Lỗi cập nhật firmware: $e',
            succcess: false,
          );
        }
      });
    } catch (e) {
      if (globalKey.currentContext != null) {
        showStatus(
          buildContext: globalKey.currentContext!,
          message: 'Failed to update firmware: $e',
          succcess: false,
        );
      }
    }
  }

  String _getCurrentDeviceMac() {
    if (connectStatus == ConnectStatus.BLE && bluetoothDevice != null) {
      return bluetoothDevice!.id;
    } else if (connectStatus == ConnectStatus.SOCKET &&
        mdnsConnectedClient != null) {
      if (wifiApMac != null && wifiApMac!.isNotEmpty) {
        return wifiApMac!;
      }
      return mdnsConnectedClient!.host;
    }
    return '';
  }

  @override
  Future<FirmwareCheckResult?> checkCurrentFirmware() async {
    if (version == null) {
      if (globalKey.currentContext != null) {
        showStatus(
          buildContext: globalKey.currentContext!,
          message: 'No firmware version available',
          succcess: false,
        );
      }
      return null;
    }

    final deviceMac = _getCurrentDeviceMac();
    print("Checking firmware for device: $deviceMac, version: $version");
    try {
      final connectivityResult = await Connectivity().checkConnectivity();
      bool isOnlineSuccess = false;

      if (!connectivityResult.contains(ConnectivityResult.none)) {
        if (hardwareVersion == null) {
          final listFirmwares = await CheckFirmwareService.getAllFirmwares();
          _showFallbackFirmwareDialog(listFirmwares);
          return null;
        }

        if (deviceMac.isNotEmpty && !deviceMac.contains('.')) {
          final result = await CheckFirmwareService.checkFirmware(
            mac: deviceMac,
            currentVersion: version!,
          );

          if (result != null) {
            firmwareCheckResult = result;
            if (!result.noUpdate) {
              isOnlineSuccess = true;
              if (globalKey.currentContext != null) {
                // Ignore the 'this' issue since we need AppProvider type, we'll fix it in app_provider
                // showFirmwareUpdateDialog expects (BuildContext, AppProvider, String)
                // In mixin, 'this' refers to the Mixin/AppProviderState. We can cast it.
                // Wait, I can't cast 'this' if AppProvider isn't defined here.
                // I'll just change the signature of showFirmwareUpdateDialog if needed, but casting to dynamic works or passing this.
              }
              return result;
            } else {
              isOnlineSuccess = false;
            }
          }
        } else {
          if (globalKey.currentContext != null) {
            showStatus(
              buildContext: globalKey.currentContext!,
              message:
                  'Không thể kiểm tra bản cập nhật: Thiếu địa chỉ MAC của mạch!',
              succcess: false,
            );
          }
          return null;
        }
      }

      if (!isOnlineSuccess) {
        if (connectStatus == ConnectStatus.BLE) {
          if (globalKey.currentContext != null) {
            showStatus(
              buildContext: globalKey.currentContext!,
              message:
                  'Please connect to Internet to check for updates via Bluetooth.',
              succcess: false,
            );
          }
          return null;
        }

        if (hardwareVersion != null) {
          Map<String, String>? autoFallbackData =
              await OfflineOTAService.getFallbackOfflineFilePath(
                  hardwareVersion!);

          if (autoFallbackData != null) {
            String autoFallbackFile = autoFallbackData['localFilePath']!;
            String url = autoFallbackData['url']!;
            String fileName = Uri.parse(url).pathSegments.last;
            String fileVersion = fileName.replaceAll('.bin', '');

            if (fileVersion != version) {
              if (globalKey.currentContext != null) {
                showDialog(
                    context: globalKey.currentContext!,
                    builder: (ctx) {
                      return Dialog(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(20, 28, 20, 20),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                const Text(
                                  'Cập Nhật Firmware',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 19,
                                    fontWeight: FontWeight.w500,
                                    color: Colors.black87,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                RichText(
                                  textAlign: TextAlign.center,
                                  text: TextSpan(
                                    style: TextStyle(
                                      fontSize: 14.5,
                                      height: 1.45,
                                      color: Colors.grey[700],
                                    ),
                                    children: [
                                      const TextSpan(text: 'Tìm thấy bản '),
                                      TextSpan(
                                        text: fileName,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w700,
                                          color: Colors.black87,
                                        ),
                                      ),
                                      const TextSpan(
                                          text:
                                              ' đã lưu sẵn trong điện thoại.\nBản hiện tại của mạch:\n'),
                                      TextSpan(
                                        text: version ?? 'Không xác định',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w700,
                                          color: Colors.redAccent,
                                        ),
                                      ),
                                      const TextSpan(
                                          text:
                                              '\nBạn có muốn nạp ngay không?'),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 24),
                                Row(
                                  children: [
                                    Expanded(
                                      child: OutlinedButton(
                                        style: OutlinedButton.styleFrom(
                                          foregroundColor: Colors.grey[700],
                                          side: BorderSide(
                                              color: Colors.grey[300]!),
                                          padding: const EdgeInsets.symmetric(
                                              vertical: 8),
                                          shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(12),
                                          ),
                                        ),
                                        onPressed: () =>
                                            Navigator.of(ctx).pop(),
                                        child: const Text(
                                          'Later',
                                          style: TextStyle(
                                              fontWeight: FontWeight.w500),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: FilledButton(
                                        style: FilledButton.styleFrom(
                                          backgroundColor:
                                              CustomColor.primaryColor,
                                          padding: const EdgeInsets.symmetric(
                                              vertical: 8),
                                          shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(12),
                                          ),
                                        ),
                                        onPressed: () {
                                          Navigator.of(ctx).pop();
                                          updateFirmWare(
                                              offlineFilePath: autoFallbackFile,
                                              url: url);
                                        },
                                        child: const Text(
                                          'Update',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),
                                    )
                                  ],
                                ),
                              ],
                            ),
                          ));
                    });
              }
            }
          } else {
            if (globalKey.currentContext != null) {
              SnackbarHelper.showError(
                globalKey.currentContext!,
                '',
                'Không có kết nối Internet và không tìm thấy bản cập nhật Offline',
              );
            }
          }
        } else {
          _showNoInternetFallbackPrompt();
        }
      }

      return null;
    } catch (e) {
      if (globalKey.currentContext != null) {
        showStatus(
          buildContext: globalKey.currentContext!,
          message: 'Failed to check firmware',
          succcess: false,
        );
      }
      return null;
    }
  }

  void _showNoInternetFallbackPrompt() {
    if (globalKey.currentContext == null) return;
    showDialog(
      context: globalKey.currentContext!,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Lỗi kết nối mạng'),
          content: const Text(
              'Không có Internet để kiểm tra mạch này.\nBạn có muốn chọn bản cập nhật đã lưu sẵn trong máy không?'),
          actions: [
            TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Hủy')),
            TextButton(
              onPressed: () async {
                Navigator.of(ctx).pop();
                final listFirmwares =
                    await CheckFirmwareService.getAllFirmwares();
                _showFallbackFirmwareDialog(listFirmwares);
              },
              child: const Text('Chọn Firmware Cứu Hộ'),
            ),
          ],
        );
      },
    );
  }

  List<int> getFirmwareUpdateCommand(String url) {
    List<int> command = [];
    command.addAll(utf8.encode('#5:$url!'));
    return command;
  }

  void _showFallbackFirmwareDialog(
      List<Map<String, dynamic>> listFirmwares) async {
    if (globalKey.currentContext == null) return;

    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString(OfflineOTAService.otaFallbackKey);
    Map<String, dynamic> fallbackCache = data != null ? json.decode(data) : {};

    Set<String> downloadedUrls = {};
    for (var value in fallbackCache.values) {
      if (value['url'] != null && value['localFilePath'] != null) {
        final file = File(value['localFilePath']);
        if (await file.exists()) {
          downloadedUrls.add(value['url']);
        }
      }
    }

    if (globalKey.currentContext == null) return;

    showDialog(
      context: globalKey.currentContext!,
      builder: (ctx) {
        return Dialog(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Padding(
            padding: const EdgeInsets.only(top: 24, bottom: 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Chọn firmware cập nhật',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${listFirmwares.length} phiên bản khả dụng',
                        style: const TextStyle(
                          fontSize: 14,
                          color: Colors.black54,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                const Divider(
                    height: 1, thickness: 1, color: Color(0xFFEEEEEE)),
                ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(ctx).size.height * 0.5,
                  ),
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: listFirmwares.length,
                    separatorBuilder: (_, __) => const Divider(
                      height: 1,
                      thickness: 1,
                      color: Color(0xFFEEEEEE),
                    ),
                    itemBuilder: (context, index) {
                      final fw = listFirmwares[index];
                      final isDownloaded =
                          downloadedUrls.contains(fw['update_url']);

                      return Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                fw['version'] ?? 'Unknown Version',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.black87,
                                ),
                              ),
                            ),
                            OutlinedButton(
                              style: OutlinedButton.styleFrom(
                                foregroundColor: isDownloaded
                                    ? CustomColor.primaryColor
                                    : Colors.black87,
                                backgroundColor: isDownloaded
                                    ? CustomColor.primaryColor.withOpacity(0.05)
                                    : null,
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 0),
                                side: BorderSide(
                                    color: isDownloaded
                                        ? CustomColor.primaryColor
                                        : Colors.grey[300]!),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                minimumSize: const Size(64, 36),
                              ),
                              onPressed: () async {
                                if (!isDownloaded && socketTCP != null) {
                                  showDialog(
                                    context: ctx,
                                    builder: (alertCtx) => AlertDialog(
                                      title: const Text('Không có Internet',
                                          style: TextStyle(
                                              fontWeight: FontWeight.bold)),
                                      content: const Text(
                                          'Bạn đang kết nối trực tiếp với Wi-Fi của mạch nên không có mạng Internet.\n\nVui lòng ngắt kết nối với mạch, bật mạng (4G/Wi-Fi) để tải bản dự phòng này về ứng dụng, sau đó kết nối lại mạch để nạp.'),
                                      actions: [
                                        TextButton(
                                          onPressed: () =>
                                              Navigator.pop(alertCtx),
                                          child: const Text('Đóng'),
                                        )
                                      ],
                                    ),
                                  );
                                  return;
                                }

                                Navigator.of(ctx).pop();

                                if (fw['update_url'] != null) {
                                  if (isDownloaded && socketTCP != null) {
                                    for (var value in fallbackCache.values) {
                                      if (value['url'] == fw['update_url']) {
                                        final filePath = value['localFilePath'];
                                        if (filePath != null &&
                                            await File(filePath).exists()) {
                                          updateFirmWare(
                                              offlineFilePath: filePath);
                                          return;
                                        }
                                      }
                                    }
                                  }
                                  updateFirmWare(url: fw['update_url']);
                                }
                              },
                              child: Text(
                                isDownloaded ? 'Chọn' : 'Tải về',
                                style: const TextStyle(
                                    fontWeight: FontWeight.w500),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
                const Divider(
                    height: 1, thickness: 1, color: Color(0xFFEEEEEE)),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.black87,
                      ),
                      onPressed: () => Navigator.of(ctx).pop(),
                      child: const Text(
                        'Hủy',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
