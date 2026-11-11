---
title: TransFlex giờ là app Mac native
description: TransFlex được viết lại bằng Swift, thành app nằm trên thanh menu của macOS. Miễn phí và mã nguồn mở.
date: 2026-11-11
authors: truongtc
excerpt: TransFlex được viết lại bằng Swift, thành app nằm trên thanh menu của macOS. App miễn phí, giấy phép MIT; bản đa nền tảng trước đây đã ngừng phát triển.
---

TransFlex khởi đầu là một app đa nền tảng. Giờ nó là app Mac native, viết bằng Swift, nằm trên thanh menu. Bài này kể điều gì đã đổi và vì sao.

## Vì sao làm native

App dịch là thứ bạn mở vài giây, nhiều lần mỗi ngày. Muốn vậy nó phải chạy như một phần của hệ thống: một phím tắt từ bất kỳ app nào, cửa sổ hiện ngay chỗ bạn đang làm, và Esc để đóng. Dùng chính công cụ của Mac thì những việc đó làm được gọn, nên công sức dồn vào đó.

## App làm được gì

- **Cửa sổ dịch trên <kbd>⌥</kbd> <kbd>T</kbd>.** Gõ hoặc dán, bấm <kbd>⌘</kbd> <kbd>⏎</kbd>, bản dịch hiện dần. <kbd>⌘</kbd> <kbd>C</kbd> để copy và đóng cửa sổ.
- **Translate Selection và Replace Selection.** Gán phím tắt riêng cho một preset để dịch đoạn bạn đang chọn trong app khác, hoặc thay nó bằng bản dịch ngay tại chỗ.
- **Preset.** Mỗi preset chọn nhà cung cấp, mô hình và chỉ dẫn. Có sẵn ba preset; bạn sửa được hoặc tự viết.
- **Nhà cung cấp của bạn.** OpenAI, Anthropic, Gemini, hoặc bất kỳ máy chủ tương thích OpenAI nào, kể cả máy chủ chạy ngay trên Mac của bạn.
- **Ảnh.** Thả hoặc dán ảnh vào cửa sổ dịch để dịch chữ trong ảnh.
- **Lịch sử.** Mọi bản dịch nằm trên Mac của bạn, tìm kiếm và xuất ra được.

Phần [hướng dẫn](/vi/docs/install/) nói kỹ từng mục.

## Miễn phí và mã nguồn mở

TransFlex cho Mac miễn phí, giấy phép MIT. Không tài khoản, không gói trả tiền; bạn chỉ trả cho nhà cung cấp AI theo mức dùng. Mã nguồn ở [GitHub](https://github.com/dratct/TransFlex).

Bản đa nền tảng trước đây đã ngừng phát triển, và app mới không có bản Windows hay Linux.

## Tải về

[Tải TransFlex cho Mac](https://github.com/dratct/TransFlex/releases/latest/download/TransFlex-macos.zip). Cần macOS 13 trở lên, chạy trên chip Apple và Intel.

Nếu app giúp bạn tiết kiệm thời gian, bạn có thể [ủng hộ việc phát triển](/vi/support/).
