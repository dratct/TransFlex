---
title: Phím tắt
description: Mọi phím tắt trong TransFlex, và cách đổi chúng.
---

## Mở Popup

<kbd>⌥</kbd> <kbd>T</kbd> mở Popup từ bất kỳ app nào; bấm lần nữa để đóng.

Đổi phím ở **Settings → General → Popup → Open shortcut**.

## Phím tắt của từng preset

Mỗi preset có thể có ba phím tắt riêng. Chưa phím nào được đặt sẵn; bạn tự ghi phím ở **Settings → Presets**, mục **Shortcuts**:

| Phím tắt | Tác dụng |
|---|---|
| **Choose this preset** | Chọn preset này cho Popup, và mở Popup nếu đang ẩn. |
| **Translate selection** | Copy đoạn bạn đang chọn trong app phía trước và hiện bản dịch trong một cửa sổ nhỏ. |
| **Replace selection** | Dịch đoạn đang chọn rồi dán bản dịch đè lên. Popup không mở. |

Translate selection và Replace selection cần quyền Accessibility; TransFlex sẽ xin quyền ở lần dùng đầu. Xem [Xử lý sự cố](/vi/docs/troubleshooting/).

### Replace selection, từng bước

1. Chọn một đoạn văn trong bất kỳ app nào rồi bấm phím tắt.
2. Một ô nhỏ cạnh con trỏ ghi **Translating with** kèm tên preset. <kbd>Esc</kbd> để huỷ.
3. Đoạn đang chọn được thay bằng bản dịch, và ô nhỏ ghi **Replaced · ⌘Z to undo**.

Clipboard của bạn được trả lại như cũ ngay sau đó. Nếu không thay được, app không đổi gì và để bản dịch trên clipboard cho bạn tự dán.

## Trong Popup

| Phím | Tác dụng |
|---|---|
| <kbd>⌘</kbd> <kbd>⏎</kbd> | Dịch. Khi đã có kết quả: dịch lại đúng đoạn đó. |
| <kbd>⌘</kbd> <kbd>C</kbd> | Khi đang có kết quả: copy kết quả rồi đóng Popup. |
| <kbd>⌘</kbd> <kbd>N</kbd> | Mới: xoá văn bản, ảnh và kết quả. |
| <kbd>⌘</kbd> <kbd>I</kbd> | Ở cửa sổ nhỏ của Translate selection: hiện cả văn bản gốc. |
| <kbd>⌘</kbd> <kbd>P</kbd> | Khi bản dịch dừng giữa chừng: dịch tiếp từ phần đã có. |
| <kbd>⌘</kbd> <kbd>⇧</kbd> <kbd>V</kbd> | Dán ảnh từ clipboard. |
| <kbd>⌘</kbd> <kbd>⇧</kbd> <kbd>O</kbd> | Chọn một file ảnh. |
| <kbd>⌘</kbd> <kbd>Y</kbd> | Mở History. |
| <kbd>⌘</kbd> <kbd>,</kbd> | Mở Settings. |
| <kbd>Esc</kbd> | Dừng bản dịch đang chạy; nếu không thì đóng Popup. |

## Giữ bản dịch gần nhất

**Settings → General → Popup → Keep last translation** quyết định Popup hiện gì khi bạn mở lại: văn bản và kết quả lần trước, hay một Popup trống.

Các lựa chọn là **Don't keep**, từ **1** tới **5 minutes**, và **Always**. Mặc định là 2 phút, tính từ lúc Popup được ẩn lần cuối.
