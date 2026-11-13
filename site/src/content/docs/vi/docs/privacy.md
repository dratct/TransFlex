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

## Kiểm tra secret

Trước khi văn bản của bạn được gửi tới nhà cung cấp, TransFlex tìm trong đó các API key và token có dạng đã biết: key của OpenAI, Anthropic và Google, token của GitHub, AWS, Slack và Stripe, khối private key, và đường link có kèm mật khẩu. Tìm thấy thì TransFlex không gửi gì. Nó cho biết loại đã tìm thấy, chỉ kèm bốn ký tự đầu và bốn ký tự cuối, rồi để bạn chọn: quay lại văn bản, hoặc **Send anyway**.

- Chỉ đọc chữ. Ảnh không bao giờ được kiểm tra.
- Chỉ biết các dạng trên. Mật khẩu thường, hoặc token không có dạng cố định, sẽ lọt qua.
- Bỏ qua khi mô hình chạy ngay trên Mac của bạn.
- Bản dịch gửi bằng **Send anyway** không được lưu vào Lịch sử.
- Văn bản bị chặn không được giữ lại trong Popup sau khi Popup đóng.

Đây là một lưới an toàn, không phải một bảo đảm. Tính năng bật sẵn; tắt ở **Settings › General › Check for secrets before sending**.

## Những gì nằm lại trên Mac

- **API key**: trong Keychain của macOS.
- **Lịch sử**: `~/Library/Application Support/TransFlex/history.sqlite`. Xem [Lịch sử](/vi/docs/history/).
- **Preset và cài đặt máy chủ**: các file trong cùng thư mục đó. Key không bao giờ được ghi vào đây.

## Clipboard

- Kết quả được copy khi bạn bấm **Copy & Close**, hoặc mọi lần nếu bạn đã bật **Copy result automatically**.
- **Translate selection** copy đoạn bạn chọn để đọc, rồi trả lại clipboard cũ của bạn. Kết quả của nó theo quy tắc trên.
- **Replace selection** copy đoạn bạn chọn, dán bản dịch, rồi trả lại clipboard cũ sau khoảng nửa giây. Nếu dán không được, bản dịch ở lại trên clipboard.

Trình quản lý clipboard có thể ghi lại những mục tồn tại ngắn ngủi này.

## Quyền Accessibility

Chỉ Translate selection và Replace selection dùng quyền này, để bấm <kbd>⌘</kbd> <kbd>C</kbd> và <kbd>⌘</kbd> <kbd>V</kbd> thay bạn trong app phía trước. Popup không cần quyền này.

## Tự kiểm chứng

TransFlex là mã nguồn mở. Mã nằm trên [GitHub](https://github.com/dratct/TransFlex).
