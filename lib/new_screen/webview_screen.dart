import 'dart:convert';
import 'dart:io';
import 'dart:collection';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:http/http.dart' as http;
import '../utils/snackbar_helper.dart';

class WebViewScreen extends StatefulWidget {
  final String url;
  final String title;

  const WebViewScreen({
    super.key,
    required this.url,
    this.title = 'Web UI',
  });

  @override
  State<WebViewScreen> createState() => _WebViewScreenState();
}

class _WebViewScreenState extends State<WebViewScreen> {
  InAppWebViewController? webViewController;
  bool _isLoading = true;
  double _loadingProgress = 0;

  @override
  void initState() {
    super.initState();
    _requestPermissions();
  }

  Future<void> _requestPermissions() async {
    await Permission.storage.request();
    await Permission.camera.request();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              webViewController?.reload();
            },
            tooltip: 'Tải lại',
          ),
        ],
        bottom: _isLoading
            ? PreferredSize(
                preferredSize: const Size.fromHeight(3),
                child: LinearProgressIndicator(
                  value: _loadingProgress,
                  backgroundColor: Colors.grey[200],
                  color: Colors.blue,
                ),
              )
            : null,
      ),
      body: SafeArea(
        child: InAppWebView(
          initialUrlRequest: URLRequest(url: WebUri(widget.url)),
          initialSettings: InAppWebViewSettings(
            javaScriptEnabled: true,
            domStorageEnabled: true,
            allowFileAccess: true,
            allowContentAccess: true,
            supportZoom: true,
            useWideViewPort: true,
            loadWithOverviewMode: true,
            useOnDownloadStart: true,
          ),
          // Bơm đoạn mã để Ngăn trang web xóa (revoke) file ảo ngay lập tức
          initialUserScripts: UnmodifiableListView<UserScript>([
            UserScript(
              source: '''
                var originalRevoke = window.URL.revokeObjectURL;
                window.URL.revokeObjectURL = function(url) {
                  // Trì hoãn việc xóa file ảo đi 60 giây để App Flutter có thời gian đọc và tải về
                  setTimeout(function() {
                    originalRevoke(url);
                  }, 60000);
                };
              ''',
              injectionTime: UserScriptInjectionTime.AT_DOCUMENT_START,
            )
          ]),
          onWebViewCreated: (controller) {
            webViewController = controller;
          },
          onDownloadStartRequest: (controller, downloadRequest) async {
            final url = downloadRequest.url.toString();
            String fileName =
                downloadRequest.suggestedFilename ?? "downloaded_file";

            // Nếu là Blob, WebView của Android sẽ lấy cái chuỗi ID ngẫu nhiên của Blob làm tên file.
            // Do đó chúng ta ép nó trở về đúng tên config.txt
            if (url.startsWith('blob:')) {
              fileName = "config.txt";
            }

            SnackbarHelper.showInfo(
              context,
              'Tải xuống',
              'Đang tải $fileName...',
            );

            try {
              List<int> fileBytes;

              if (url.startsWith('blob:')) {
                // Đọc file ảo trực tiếp từ Javascript (giờ nó không bị xóa sớm nữa)
                final result = await controller.callAsyncJavaScript(
                  functionBody: '''
                    try {
                      const response = await fetch(downloadUrl);
                      const blob = await response.blob();
                      return await new Promise((resolve, reject) => {
                        const reader = new FileReader();
                        reader.onloadend = () => resolve(reader.result);
                        reader.onerror = () => reject("Lỗi FileReader");
                        reader.readAsDataURL(blob);
                      });
                    } catch (e) {
                      throw e.toString();
                    }
                  ''',
                  arguments: {'downloadUrl': url},
                );

                if (result == null) {
                  throw Exception("Không có phản hồi từ Javascript.");
                }

                if (result.error != null) {
                  throw Exception("JS Error: \${result.error}");
                }

                if (result.value != null) {
                  final String value = result.value.toString();
                  if (value.contains(',')) {
                    final base64String = value.split(',')[1];
                    fileBytes = base64Decode(base64String);
                  } else {
                    throw Exception("Dữ liệu không đúng chuẩn Base64.");
                  }
                } else {
                  throw Exception("Không lấy được kết quả đọc Blob.");
                }
              } else {
                // Tải file URL HTTP bình thường
                final response = await http.get(Uri.parse(url));
                if (response.statusCode == 200) {
                  fileBytes = response.bodyBytes;
                } else {
                  throw Exception("Server trả về lỗi: ${response.statusCode}");
                }
              }

              // Lưu file vào thư mục Download
              final downloadDir = Directory('/storage/emulated/0/Download');
              if (!await downloadDir.exists()) {
                await downloadDir.create(recursive: true);
              }

              final file = File('${downloadDir.path}/$fileName');
              await file.writeAsBytes(fileBytes);

              if (mounted) {
                SnackbarHelper.showSuccess(
                  context,
                  'Thành công',
                  'Đã lưu thành công $fileName vào thư mục Download!',
                );
              }
            } catch (e) {
              if (mounted) {
                SnackbarHelper.showError(
                  context,
                  'Lỗi',
                  'Lỗi khi lưu file: $e',
                );
              }
            }
          },
          onLoadStart: (controller, url) {
            setState(() {
              _isLoading = true;
            });
          },
          onLoadStop: (controller, url) async {
            setState(() {
              _isLoading = false;
            });
          },
          onProgressChanged: (controller, progress) {
            setState(() {
              _loadingProgress = progress / 100;
              if (progress == 100) {
                _isLoading = false;
              }
            });
          },
          onReceivedError: (controller, request, error) {
            print('🌐 WebView Error: ${error.description}');
          },
        ),
      ),
    );
  }
}
