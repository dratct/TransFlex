---
title: Xử lý sự cố
description: Cách sửa khi phím tắt, quyền, key hay bản dịch gặp trục trặc.
---

## Bấm phím tắt mà không có gì xảy ra

- Kiểm tra TransFlex có đang chạy không: icon của app nằm trên thanh menu.
- Có thể app khác đang dùng cùng tổ hợp phím. Ghi phím khác ở **Settings → General → Popup → Open shortcut**.

## "One permission needed"

Translate selection và Replace selection cần quyền để copy đoạn bạn chọn và dán kết quả.

1. Bấm **Open System Settings** trên thẻ thông báo.
2. Bật **TransFlex** trong danh sách. Danh sách nằm trong **Privacy & Security**, tên là **Accessibility** (trên macOS 27 là **Device Control and Data Access**).
3. Quay lại; thẻ xác nhận bằng **Permission granted**. Chọn lại đoạn văn rồi bấm phím tắt lần nữa.

## "No text selected"

App phía trước không trao đoạn đang chọn. Hãy chọn lại rồi thử lại. Có chỗ không bao giờ cho phép, ví dụ ô mật khẩu. Ở đó hãy dùng Popup: tự copy đoạn văn rồi bấm <kbd>⌥</kbd> <kbd>T</kbd>.

## "Couldn't replace the selection"

Replace selection chưa đổi gì. Thông báo nói rõ lý do:

- Bạn đã chuyển app, hoặc vùng chọn đã đổi, trong lúc app đang dịch.
- App không nhận lệnh dán, ví dụ ở ô chỉ đọc.

Trong cả hai trường hợp, bản dịch đang nằm trên clipboard: chọn lại đoạn văn rồi bấm <kbd>⌘</kbd> <kbd>V</kbd>.

## Lỗi khi dịch

| Thông báo | Cách xử lý |
|---|---|
| **API key invalid. Update in Settings.** | Thay key ở **Settings → Providers**. |
| **Add an OpenAI key** (hoặc nhà cung cấp khác) | Preset dùng một nhà cung cấp chưa có key. Thêm key, hoặc đổi preset sang nhà cung cấp bạn có. |
| **Rate limited** | Nhà cung cấp đang giới hạn số yêu cầu của bạn. Đợi rồi thử lại. |
| **The provider rejected the request: …** | Đọc lý do của nhà cung cấp sau dấu hai chấm. Thường là sai tên mô hình hoặc tài khoản của bạn chưa được dùng mô hình đó. |
| **Provider issue. Try again.** | Nhà cung cấp gặp lỗi. Bấm <kbd>⌘</kbd> <kbd>⏎</kbd> để thử lại. |
| **No internet connection.** | Kiểm tra kết nối. Yêu cầu không được trả lời trong 60 giây cũng kết thúc như vậy. |

Nếu bản dịch dừng giữa chừng, Popup giữ lại phần đã nhận. **Continue** (<kbd>⌘</kbd> <kbd>P</kbd>) dịch tiếp từ đó; **Retry** làm lại từ đầu.

## Không kết nối được máy chủ chạy tại máy

- **Base URL** của hầu hết máy chủ phải kết thúc bằng `/v1`: với Ollama là `http://localhost:11434/v1`.
- `http://` chỉ dùng được cho `localhost`. Máy chủ ở máy khác cần `https://`.
- Bấm **Load Models** trong bảng cài đặt máy chủ để thử địa chỉ.

## Preset không đọc được ảnh

Bật **Reads images** cho preset ở **Settings → Presets**, và chọn mô hình nhận được ảnh. Xem [Dịch ảnh](/vi/docs/images/).

## Vẫn chưa được

[Mở một issue](https://github.com/dratct/TransFlex/issues), kể bạn đã làm gì, mong đợi gì, và điều gì đã xảy ra. TransFlex đang được phát triển tích cực, và báo cáo của bạn rất có ích.
