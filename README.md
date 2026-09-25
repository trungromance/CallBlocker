# Ứng Dụng Chặn Đầu Số Cuộc Gọi iPhone (iOS Call Blocker)

Ứng dụng iOS bản địa (Swift & SwiftUI) sử dụng **CallKit Call Directory Extension** của Apple để chặn các cuộc gọi theo dải đầu số (ví dụ: `059*`, `024*`, `056*`,...), phục vụ xuất file `.ipa` để cài đặt thông qua **AltStore / AltServer / Sideloadly**.

---

## 🌟 Tính Năng Chính
1. **Công tắc Bật / Tắt (Master Toggle)**: Bật hoặc tắt tính năng chặn cuộc gọi nhanh chóng chỉ với một nút bấm.
2. **Input thêm đầu số linh hoạt**: Nhập đầu số cần chặn (ví dụ `059`, `059*`, `028...`), app sẽ tự động sinh và quản lý toàn bộ dải số liên quan.
3. **Hiển thị & Quản lý danh sách**: Thêm, xoá, bật/tắt từng quy tắc chặn cụ thể kèm ghi chú.
4. **Đồng bộ CallKit**: Cập nhật trực tiếp dữ liệu vào hệ điều hành iOS.
5. **Kiểm tra quyền**: Tự động thông báo trạng thái cấp quyền trong Cài đặt iPhone.

---

## 📁 Cấu Trúc Dự Án
```
CallBlocker/
├── CallBlocker.xcodeproj/           # Xcode Project cấu hình sẵn 2 Target
├── CallBlocker/                     # Ứng dụng chính (Giao diện SwiftUI)
│   ├── CallBlockerApp.swift
│   ├── ContentView.swift
│   ├── Info.plist
│   └── CallBlocker.entitlements
├── CallBlockerExtension/            # Call Directory App Extension (Xử lý chặn cuộc gọi)
│   ├── CallDirectoryHandler.swift
│   ├── Info.plist
│   └── CallBlockerExtension.entitlements
├── Shared/                          # Module dùng chung giữa App & Extension
│   ├── BlockListManager.swift       # Quản lý lưu trữ quy tắc và đồng bộ App Group
│   └── PhoneNumberGenerator.swift   # Thuật toán sinh và sắp xếp dải số chuẩn CallKit
└── .github/workflows/
    └── build_ipa.yml                # CI/CD tự động build file .ipa trên GitHub Actions
```

---

## 🚀 Cách Lấy File `.ipa` Để Cài Đặt Lên AltServer

### Cách 1: Tự động Build IPA trên GitHub (Dành cho máy Windows / Không cần Mac)
1. Đăng nhập [GitHub](https://github.com) và tạo một **Repository mới** (Private hoặc Public).
2. Tải toàn bộ thư mục `CallBlocker` này lên repository của bạn:
   ```bash
   cd "d:\SynologyDrive\Projects\Mobile Apps\CallBlocker"
   git init
   git add .
   git commit -m "Initial commit CallBlocker"
   git branch -M main
   git remote add origin https://github.com/<tai-khoan-cua-ban>/CallBlocker.git
   git push -u origin main
   ```
3. Sau khi push, vào tab **Actions** trên GitHub:
   - Quy trình `Build IPA for AltStore / AltServer` sẽ tự động chạy (chạy trên máy chủ macOS của GitHub hoàn toàn miễn phí).
   - Khi hoàn thành (mất khoảng 1 - 2 phút), nhấp vào workflow run và tải file **`CallBlocker-IPA`** (bên trong chứa `CallBlocker.ipa`).

---

### Cách 2: Build trên máy Mac bằng Xcode
1. Mở file `CallBlocker.xcodeproj` bằng Xcode.
2. Chọn target `CallBlocker` -> Chọn thiết bị `Any iOS Device (arm64)`.
3. Menu: `Product` -> `Archive`.
4. Sau khi archive xong, chọn `Distribute App` -> `Custom` -> `Ad Hoc` hoặc `Development` -> Xuất ra thư mục chứa file `.ipa`.

---

## 📲 Cách Cài Đặt Vào iPhone Qua AltServer / AltStore

1. Kết nối iPhone với máy tính chạy **AltServer** (hoặc mở ứng dụng **AltStore** trên iPhone nếu đã kết nối chung mạng WiFi).
2. Chuyển file `CallBlocker.ipa` sang iPhone (qua AirDrop, Google Drive, iCloud Drive hoặc gửi qua Zalo/Telegram).
3. Mở **AltStore** trên iPhone:
   - Chọn tab **My Apps** -> Nhấn dấu **`+`** ở góc trên.
   - Chọn file `CallBlocker.ipa` vừa tải.
   - Đăng nhập Apple ID để AltStore tự động ký chứng chỉ và cài app.

---

## ⚙️ Kích Hoạt Quyền Trên iPhone (Bắt buộc sau khi cài)

Sau khi cài đặt xong, bạn cần cho phép iOS nạp dữ liệu chặn cuộc gọi:
1. Mở **Cài đặt (Settings)** trên iPhone.
2. Cuộn xuống và chọn **Điện thoại (Phone)**.
3. Chọn mục **Chặn & Nhận dạng cuộc gọi (Call Blocking & Identification)**.
4. Bật công tắc của ứng dụng **Chặn 059 / Call Blocker** sang màu xanh.
5. Mở lại ứng dụng và nhấn nút **"Áp Dụng & Đồng Bộ Với iOS"** để hoàn tất!
