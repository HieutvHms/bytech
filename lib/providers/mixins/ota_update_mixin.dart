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
  void updateFirmWare(
      {String? url, String? offlineFilePath, String? targetVersion}) {
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
      // update qua BLE
      if (connectStatus == ConnectStatus.BLE &&
          bluetoothCharacteristic != null &&
          url != null) {
        final updateCommand = OtaUpdateMixin.getFirmwareUpdateCommand(url);

        print("====== OTA BLE UPDATE ======");
        print("URL: $url");
        print("Command Bytes: $updateCommand");
        print(
            "Command String: ${utf8.decode(updateCommand, allowMalformed: true)}");
        print("============================");

        ble
            .writeCharacteristicWithResponse(bluetoothCharacteristic!,
                value: updateCommand)
            .then((_) {
          isExpertMode = false;
          notifyListeners();

          if (globalKey.currentContext != null) {
            showDialog(
              context: globalKey.currentContext!,
              barrierDismissible: false,
              builder: (BuildContext context) {
                return Dialog(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  elevation: 0,
                  backgroundColor: Colors.transparent,
                  child: Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.rectangle,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: const [
                        BoxShadow(
                          color: Colors.black26,
                          blurRadius: 10.0,
                          offset: Offset(0.0, 10.0),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'Update Initiated',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w500,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'The device has received the update command and is currently downloading the firmware. This process may take 1-3 minutes.\n\n'
                          'The device will restart automatically upon completion',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.black54,
                            height: 1.5,
                          ),
                        ),
                        const SizedBox(height: 24),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton(
                            style: FilledButton.styleFrom(
                              backgroundColor: CustomColor.primaryColor,
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            onPressed: () {
                              Navigator.pop(context);
                              // Pop ra màn hình chính, vì đằng nào thiết bị cũng sẽ ngắt kết nối
                              final rootContext = globalKey.currentContext;
                              if (rootContext != null) {
                                Navigator.of(rootContext)
                                    .popUntil((route) => route.isFirst);
                              }
                            },
                            child: const Text(
                              'Got it',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
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
        }).catchError((e) {
          if (globalKey.currentContext != null) {
            showStatus(
              buildContext: globalKey.currentContext!,
              message: 'Failed to send command via BLE: $e',
              succcess: false,
            );
          }
        });
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
            return Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              elevation: 0,
              backgroundColor: Colors.transparent,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(vertical: 24, horizontal: 24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.rectangle,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.black26,
                      blurRadius: 10.0,
                      offset: Offset(0.0, 10.0),
                    ),
                  ],
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: 28,
                      height: 28,
                      child: CircularProgressIndicator(
                        strokeWidth: 3.5,
                        color: CustomColor.primaryColor,
                      ),
                    ),
                    SizedBox(width: 24),
                    Text(
                      "Sending Firmware...",
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      }

      Future<void> doUpdate(String filePath, String expectedVersion) async {
        await OfflineOTAService.pushFirmwareViaHttp(
            ip, filePath, expectedVersion);
      }

      // Trả về CẢ filePath lẫn version tương ứng, để doUpdate() luôn biết
      // đang mong đợi mạch báo về FW nào sau khi update xong.
      Future<(String filePath, String version)> getFilePath() async {
        if (offlineFilePath != null) {
          // Suy version từ tên file cục bộ (vd fw_AV01-NEW_HW-20260921.bin)
          final fileName = offlineFilePath.split('/').last;
          final version = fileName
              .replaceAll('fw_fallback_', '')
              .replaceAll('fw_', '')
              .replaceAll('.bin', '');
          return (offlineFilePath, version);
        } else if (url != null) {
          final parsedUri = Uri.tryParse(url);
          final isRemoteUrl = parsedUri != null &&
              (parsedUri.scheme == 'http' || parsedUri.scheme == 'https') &&
              parsedUri.host.isNotEmpty;

          if (!isRemoteUrl) {
            // url thực chất là local path (phòng trường hợp nơi gọi truyền nhầm)
            final localFile = File(url);
            if (await localFile.exists()) {
              final fileName = url.split('/').last;
              final version = fileName
                  .replaceAll('fw_fallback_', '')
                  .replaceAll('fw_', '')
                  .replaceAll('.bin', '');
              return (url, version);
            }
            throw Exception('Invalid path and not a URL: $url');
          }

          if (version != null) {
            final fallbackData =
                await OfflineOTAService.getFallbackOfflineFilePath(version!);
            if (fallbackData != null && fallbackData['url'] == url) {
              final cachedFile = File(fallbackData['localFilePath']!);
              if (await cachedFile.exists()) {
                print('File already exists on device, skipping download!');
                return (
                  fallbackData['localFilePath']!,
                  fallbackData['version'] ??
                      firmwareCheckResult?.latestVersion ??
                      ''
                );
              }
            }
          }

          if (globalKey.currentContext != null) {
            showStatus(
              buildContext: globalKey.currentContext!,
              message: 'Downloading firmware from server...',
              succcess: true,
            );
          }
          final response = await http.get(Uri.parse(url));
          if (response.statusCode != 200) {
            throw Exception(
                'Failed to download file from server: HTTP ${response.statusCode}');
          }
          final directory = await getApplicationDocumentsDirectory();
          final fileName = Uri.parse(url).pathSegments.last;
          final permanentPath = '${directory.path}/fw_$fileName';
          final permanentFile = File(permanentPath);
          await permanentFile.writeAsBytes(response.bodyBytes);
          final String exactVersion =
              targetVersion ?? fileName.replaceAll('.bin', '');

          final String hwFamily = hardwareVersion ??
              CheckFirmwareService.getFirmwareFamily(exactVersion);

          await OfflineOTAService.saveDynamicHardwareMapping(
              hwFamily, exactVersion, url, permanentPath);

          return (permanentPath, exactVersion);
        } else {
          throw Exception('No file or URL to update');
        }
      }

      getFilePath().then((result) {
        final (filePath, expectedVersion) = result;
        return doUpdate(filePath, expectedVersion);
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
              return Dialog(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                elevation: 0,
                backgroundColor: Colors.transparent,
                child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.rectangle,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: const [
                      BoxShadow(
                        color: Colors.black26,
                        blurRadius: 10.0,
                        offset: Offset(0.0, 10.0),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'Update Successful',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w500,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'The device has received the update and is currently restarting.\n'
                        'Please reconnect to the device\'s Wi-Fi network in your phone settings, then return to the Connect screen to continue.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.black54,
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          style: FilledButton.styleFrom(
                            backgroundColor: CustomColor.primaryColor,
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          onPressed: () {
                            Navigator.pop(context);
                            disconnectTCP();
                            final rootContext = globalKey.currentContext;
                            if (rootContext != null) {
                              Navigator.of(rootContext)
                                  .popUntil((route) => route.isFirst);
                            }
                          },
                          child: const Text(
                            'Got it',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
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
      }).catchError((e) {
        if (globalKey.currentContext != null) {
          // Tắt cái dialog "Đang gửi Firmware..."
          Navigator.pop(globalKey.currentContext!);

          // Hiện Dialog báo lỗi / timeout
          showDialog(
            context: globalKey.currentContext!,
            builder: (BuildContext context) {
              final isCfosError = e.toString().toLowerCase().contains('cfos');
              return AlertDialog(
                title: const Text('Update Failed',
                    style: TextStyle(color: Colors.red)),
                content: Text(isCfosError
                    ? 'An error occurred during the update process. Please restart the device and try again.'
                    : 'The connection timed out or an error occurred while updating the firmware.\n\n'
                        'Please restart the device and try again.'),
                actions: [
                  TextButton(
                    onPressed: () {
                      Navigator.pop(context);
                    },
                    child: const Text('Close'),
                  ),
                ],
              );
            },
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
      bool apiCallSucceeded = false;

      if (!connectivityResult.contains(ConnectivityResult.none)) {
        if (hardwareVersion == null) {
          List<Map<String, dynamic>> listFirmwares = [];
          try {
            listFirmwares = await CheckFirmwareService.getBackupFirmwares();
          } catch (e) {
            // Không có Internet (VD: đang ở WiFi AP riêng của mạch) -> dùng cache cục bộ
            print('Unable to get firmware from server, using local cache: $e');
            listFirmwares = await OfflineOTAService.getCachedBackupFirmwares();
          }

          if (listFirmwares.isEmpty) {
            if (globalKey.currentContext != null) {
              SnackbarHelper.showError(
                globalKey.currentContext!,
                '',
                'Unable to identify hardware and no firmware is cached on the device.\nPlease connect to the Internet at least once to download the firmware.',
              );
            }
            return null;
          }

          _showFallbackFirmwareDialog(listFirmwares);
          return null;
        }

        if (deviceMac.isNotEmpty && !deviceMac.contains('.')) {
          final result = await CheckFirmwareService.checkFirmware(
            mac: deviceMac,
            currentVersion: version!,
          );

          if (result != null) {
            apiCallSucceeded = true;
            firmwareCheckResult = result;
            if (!result.noUpdate) {
              _showOnlineUpdateDialog(result);
              return result;
            } else {
              if (globalKey.currentContext != null) {
                showStatus(
                  buildContext: globalKey.currentContext!,
                  message: 'Firmware is already up to date',
                  succcess: true,
                );
              }
              return result; // hoặc null tùy bạn muốn xử lý tiếp thế nào
            }
          }
        } else {
          if (globalKey.currentContext != null) {
            showStatus(
              buildContext: globalKey.currentContext!,
              message:
                  'Unable to check for updates: Missing device MAC address!',
              succcess: false,
            );
          }
          return null;
        }
      }

      if (!apiCallSucceeded) {
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

        if (version != null) {
          Map<String, String>? autoFallbackData =
              await OfflineOTAService.getFallbackOfflineFilePath(version!);

          if (autoFallbackData != null) {
            String autoFallbackFile = autoFallbackData['localFilePath']!;
            String url = autoFallbackData['url']!;
            String fileName = Uri.parse(url).pathSegments.last;
            // DÙNG VERSION THẬT TRẢ VỀ TỪ GET FALLBACK
            String fileVersion =
                autoFallbackData['version'] ?? fileName.replaceAll('.bin', '');

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
                                  'Firmware Update',
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
                                      const TextSpan(text: 'Found version '),
                                      TextSpan(
                                        text:
                                            fileVersion, // HIỂN THỊ VERSION THẬT THAY VÌ TÊN FILE
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
                                            url: url,
                                            targetVersion: firmwareCheckResult
                                                ?.latestVersion,
                                          );
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
              SnackbarHelper.showSuccess(
                globalKey.currentContext!,
                '',
                'The device is using the latest Firmware version',
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
          title: const Text('Network Error'),
          content: const Text(
              'No Internet connection to check this device.\nDo you want to select a locally cached update?'),
          actions: [
            TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Cancel')),
            TextButton(
              onPressed: () async {
                Navigator.of(ctx).pop();
                final listFirmwares =
                    await CheckFirmwareService.getBackupFirmwares();
                _showFallbackFirmwareDialog(listFirmwares);
              },
              child: const Text('Select Fallback Firmware'),
            ),
          ],
        );
      },
    );
  }

  static List<int> getFirmwareUpdateCommand(String url) {
    List<int> command = [];
    command.addAll(utf8.encode('#5:$url!'));
    return command;
  }

  void _showOnlineUpdateDialog(FirmwareCheckResult result) {
    if (globalKey.currentContext == null) return;

    showDialog(
      context: globalKey.currentContext!,
      barrierDismissible: false,
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
                  'Firmware Update',
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
                      const TextSpan(text: 'New update available: '),
                      TextSpan(
                        text: result.latestVersion,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          color: Colors.black87,
                        ),
                      ),
                      const TextSpan(text: '\nCurrent device version:\n'),
                      TextSpan(
                        text: result.currentVersion,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          color: Colors.redAccent,
                        ),
                      ),
                      const TextSpan(text: '\nDo you want to update now?'),
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
                          side: BorderSide(color: Colors.grey[300]!),
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: () => Navigator.of(ctx).pop(),
                        child: const Text('Later',
                            style: TextStyle(fontWeight: FontWeight.w500)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: CustomColor.primaryColor,
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: () {
                          Navigator.of(ctx).pop();
                          if (result.isOffline) {
                            // result.updateUrl lúc này là đường dẫn file cục bộ, không phải URL server
                            updateFirmWare(
                                offlineFilePath: result.updateUrl,
                                targetVersion: result.latestVersion);
                          } else {
                            updateFirmWare(
                                url: result.updateUrl,
                                targetVersion: result.latestVersion);
                          }
                        },
                        child: const Text(
                          'Update',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
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
                        'Select firmware update',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${listFirmwares.length} available versions',
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
                                      title: const Text('No Internet',
                                          style: TextStyle(
                                              fontWeight: FontWeight.bold)),
                                      content: const Text(
                                          'You are directly connected to the device\'s Wi-Fi network, which has no Internet access.\n\nPlease disconnect from the device, turn on your Internet (4G/Wi-Fi) to download this fallback version to the app, then reconnect to the device to flash it.'),
                                      actions: [
                                        TextButton(
                                          onPressed: () =>
                                              Navigator.pop(alertCtx),
                                          child: const Text('Close'),
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
                                              offlineFilePath: filePath,
                                              targetVersion: fw['version']);
                                          return;
                                        }
                                      }
                                    }
                                  }
                                  updateFirmWare(
                                      url: fw['update_url'],
                                      targetVersion: fw['version']);
                                }
                              },
                              child: Text(
                                isDownloaded ? 'Select' : 'Download',
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
                        'Cancel',
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
