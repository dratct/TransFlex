---
title: Preset
description: Một preset chọn nhà cung cấp, mô hình và chỉ dẫn cho một kiểu dịch.
---

Preset là một cách dịch: dùng nhà cung cấp và mô hình nào, và dặn mô hình điều gì. Đổi preset ở menu của Popup, hoặc gán phím tắt riêng cho từng preset.

## Các preset có sẵn

| Preset | Mô hình |
|---|---|
| Natural EN ↔ VI | OpenAI `gpt-4o-mini` |
| Technical Doc EN ↔ VI | OpenAI `gpt-4o` |
| Any → English (Natural) | OpenAI `gpt-4o-mini` |

Chúng là preset bình thường: bạn sửa hay xoá tuỳ ý.

## Sửa hoặc thêm preset

Mở **Settings → Presets**. Chọn một preset ở bên trái, hoặc thêm bằng **+**. Thay đổi được lưu ngay khi bạn sửa. **−** xoá preset đang chọn ngay lập tức, không hỏi lại.

- **Name**: tên hiện trong menu của Popup.
- **Provider**: OpenAI, Anthropic, Gemini, hoặc một máy chủ tương thích OpenAI bạn đã thêm. Đổi nhà cung cấp sẽ xoá mô hình đang chọn.
- **Model**: khi đã lưu key, danh sách lấy từ nhà cung cấp. Bạn cũng có thể gõ bất kỳ ID mô hình nào.
- **Reads images**: bật nếu mô hình nhận được ảnh. Xem [Dịch ảnh](/vi/docs/images/).
- **Instructions**: lời dặn cho mô hình.
- **Shortcuts**: xem [Phím tắt](/vi/docs/shortcuts/).
- **Tuning**: Temperature, Top P và Max tokens. Cứ để nguyên trừ khi bạn biết mình cần đổi.
- **Extra request fields**: JSON được gộp vào yêu cầu, dành cho tuỳ chọn riêng của từng nhà cung cấp.

## Ngôn ngữ

Không có menu chọn ngôn ngữ. Phần **Instructions** của preset quyết định dịch sang tiếng gì, nên một cặp ngôn ngữ mới là một preset mới.

Ví dụ, cho tiếng Nhật:

```text
You are a professional translator. Translate the user's text into natural Japanese.
If the text is already Japanese, translate it into Vietnamese.
Reply with the translation only.
```
