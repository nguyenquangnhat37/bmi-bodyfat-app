# Hướng dẫn: chạy thử, đóng gói APK/AAB và đưa lên cửa hàng

## 1. Cấu trúc thay đổi so với bản cũ

- Sửa lỗi hiển thị: chuỗi miễn trừ y tế, phân loại BMI theo giá trị đã làm tròn, nút lưu báo lỗi đúng cách.
- Thêm: chọn chuẩn BMI (Châu Á / WHO), nhập số trực tiếp (không chỉ thanh trượt), hiển thị WHtR, xóa bản ghi có xác nhận, unit test.
- Quảng cáo: chạy debug luôn dùng ID thử nghiệm của Google, bản release dùng ID thật.

## 2. Chạy thử trên máy

```
flutter pub get
flutter test
flutter run
```

Chạy `flutter run` (debug) sẽ hiển thị quảng cáo thử nghiệm. Không bấm vào quảng cáo thật khi thử nghiệm.

## 3. Đóng gói bằng GitHub Actions

1. Đưa toàn bộ thư mục lên một repository GitHub, commit và push.
2. Vào tab **Actions** → **Build Android APK & Google Play AAB** → **Run workflow**.
3. Khi test nội bộ, bật tùy chọn **use_test_ads**. Bản này dùng quảng cáo thử nghiệm, an toàn hơn cho tài khoản AdMob.
4. Sau khoảng 3–5 phút, tải gói `bmi-bodyfat-release-files` về.
   - `.apk` (nhiều file, mỗi file cho một kiến trúc CPU): cài trực tiếp, hoặc đăng lên Samsung Galaxy Store / Amazon Appstore.
   - `.aab`: đăng lên Google Play Console.

## 4. Trước khi nộp Google Play

**a. Đổi tên gói ứng dụng.** Workflow đang dùng `vn.bmifat.bmi_bodyfat_tracker`. Hãy đổi `--org` trong `.github/workflows/build_apk.yml` sang tên riêng của bạn. Sau khi đã phát hành lên Play, không nên đổi tên gói nữa.

**b. Ký ứng dụng bằng khóa phát hành (chưa tự động hóa).** Bản build hiện tại được ký bằng khóa debug. Bản đó cài được trên điện thoại để thử, nhưng Google Play không nhận AAB ký bằng khóa debug. Bạn cần:
- Tạo khóa phát hành bằng `keytool`, lưu file `.jks` và mật khẩu ở nơi an toàn.
- Cấu hình `signingConfig` trong `android/app/build.gradle(.kts)` và lưu thông tin khóa vào GitHub Secrets.
- Mất khóa này thì không cập nhật được ứng dụng đã phát hành (phải nhờ Google đặt lại khóa tải lên).

Phần này chưa được kiểm chứng trong bản này nên tôi không đưa vào workflow.

**c. Tăng số phiên bản.** Mỗi lần nộp, tăng số sau dấu `+` trong `pubspec.yaml`. Ví dụ `1.1.0+2` → `1.1.1+3`.

**d. Chính sách quyền riêng tư.** Ứng dụng có quảng cáo nên cần một trang chính sách quyền riêng tư công khai (có URL) và khai báo trong Play Console.

**e. Khai báo có quảng cáo** trong Play Console.

**f. Đồng ý quảng cáo (GDPR/EEA).** Bản này chưa triển khai luồng xin đồng ý của người dùng ở Khu vực Kinh tế Châu Âu. Nếu ứng dụng có người dùng ở đó, cần bổ sung và kiểm tra lại theo tài liệu chính thức của Google.

## 5. Cấu hình AdMob hiện có

| Mục | Vị trí |
|---|---|
| App ID | `.github/workflows/build_apk.yml` (bước "Cấu hình Android") |
| ID banner, interstitial (thật) | `lib/admob_service.dart`, class `AdConfig` |
| ID thử nghiệm | cũng trong `AdConfig`, dùng tự động khi debug hoặc khi bật `use_test_ads` |

Interstitial hiện hiển thị sau mỗi 2 lần lưu. Có thể đổi bằng `AdMobService.interstitialEvery`.

## 6. Lưu ý về nội dung chuyên môn

- **BMI:** chuẩn Châu Á dùng ngưỡng 23 (thừa cân/tiền béo phì) và 25 (béo phì độ I). Chuẩn WHO dùng ngưỡng 25, 30, 35, 40. Nên xác nhận ngưỡng với tài liệu của Bộ Y tế Việt Nam nếu ứng dụng hướng tới người dùng trong nước.
- **Tỷ lệ mỡ:** bảng phân loại theo ACE. Các nguồn khác có ngưỡng khác, nên ghi rõ nguồn khi công bố.
- **US Navy và Deurenberg:** đều là công thức ước lượng, có sai số. Người dùng được nhắc điều này trong ứng dụng.
- **WHtR:** ngưỡng 0.5 và 0.6 là ngưỡng tham khảo phổ biến, không phải chẩn đoán.
- **Chưa kiểm chứng:** bản này chưa được compile hay chạy trên thiết bị thật. Hãy chạy `flutter test` và `flutter run` trước khi phát hành.
