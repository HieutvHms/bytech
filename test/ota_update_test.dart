import 'package:flutter_test/flutter_test.dart';
import 'dart:convert';
import 'package:new_renitek/providers/mixins/ota_update_mixin.dart';

void main() {
  test('Kiểm tra hàm getFirmwareUpdateCommand sinh đúng List bytes', () {
    // 1. Arrange (Chuẩn bị đầu vào)
    String inputUrl = "http://27.71.226.192:2602/AV01_NEW_HW_12102025.bin";

    List<int> expectedOutput =
        utf8.encode('#5:http://27.71.226.192:2602/AV01_NEW_HW_12102025.bin!');

    // 2. Act (Hành động: Chạy hàm của bạn)
    List<int> actualOutput = OtaUpdateMixin.getFirmwareUpdateCommand(inputUrl);

    // 3. Assert (Xác nhận: So sánh kết quả thực tế với kết quả mong đợi)
    expect(actualOutput, equals(expectedOutput));
  });
}
