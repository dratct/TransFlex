---
title: Quyền riêng tư
description: TransFlex gửi gì, gửi đi đâu, và giữ gì trên Mac của bạn.
---

TransFlex không có tài khoản, không có máy chủ riêng, và không có telemetry hay analytics.

## Những gì rời khỏi Mac của bạn

| Gửi tới | Gửi gì | Khi nào |
|---|---|---|
| Nhà cung cấp của preset bạn dùng (OpenAI, Anthropic, Google, hoặc máy chủ bạn đã thêm) | Văn bản hoặc ảnh của bạn, chỉ dẫn của preset, và key của bạn | Khi bạn dịch |
| Cũng nhà cung cấp đó | Yêu cầu lấy danh sách mô hình, kèm key của bạn | Khi Settings hiện danh sách mô hình |
| GitHub | Yêu cầu lấy thông tin bản cập nhật, và chính bản cập nhật | Khi kiểm tra bản mới |

Ngoài ra không còn gì khác. Nhà cung cấp làm gì với văn bản của bạn thì theo điều khoản của chính nhà cung cấp đó.

Với mô hình chạy ngay trên Mac của bạn, như Ollama, văn bản không rời khỏi máy; xem [Nhà cung cấp](/vi/docs/providers/).

## Những gì nằm lại trên Mac

- **API key**: trong Keychain của macOS.
- **Lịch sử**: `~/Library/Application Support/TransFlex/history.sqlite`. Xem [Lịch sử](/vi/docs/history/).
- **Preset và cài đặt máy chủ**: các file trong cùng thư mục đó. Key không bao giờ được ghi vào đây.

## Clipboard

- Bản dịch hoàn tất trong Popup được copy vào clipboard.
- **Translate selection** copy đoạn bạn chọn để đọc, rồi trả lại clipboard cũ của bạn. Sau đó bản dịch hoàn tất được copy, như trên.
- **Replace selection** copy đoạn bạn chọn, dán bản dịch, rồi trả lại clipboard cũ sau khoảng nửa giây. Nếu dán không được, bản dịch ở lại trên clipboard.

Trình quản lý clipboard có thể ghi lại những mục tồn tại ngắn ngủi này.

## Quyền Accessibility

Chỉ Translate selection và Replace selection dùng quyền này, để bấm <kbd>⌘</kbd> <kbd>C</kbd> và <kbd>⌘</kbd> <kbd>V</kbd> thay bạn trong app phía trước. Popup không cần quyền này.

## Tự kiểm chứng

TransFlex là mã nguồn mở. Mã nằm trên [GitHub](https://github.com/dratct/TransFlex).
