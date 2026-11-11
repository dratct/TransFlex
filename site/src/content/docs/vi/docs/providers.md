---
title: Nhà cung cấp
description: Dùng OpenAI, Anthropic, Gemini, hoặc bất kỳ máy chủ tương thích OpenAI nào, kể cả máy chủ chạy trên Mac của bạn.
---

TransFlex không có dịch vụ dịch riêng. App gửi văn bản tới nhà cung cấp bạn chọn, bằng key của bạn, và bạn trả tiền cho nhà cung cấp đó theo mức dùng.

## OpenAI, Anthropic, Gemini

Ở **Settings → Providers**, bấm **Add Key…** cạnh nhà cung cấp, dán key, rồi bấm **Save Key**. **Edit…** dùng để thay hoặc gỡ key đã lưu.

Key nằm trong Keychain của macOS và chỉ được gửi tới đúng nhà cung cấp của nó.

## Máy chủ tương thích OpenAI

Mọi thứ nói được giao thức chat của OpenAI đều dùng được: Ollama, LM Studio, OpenRouter và các dịch vụ khác.

1. Ở **Settings → Providers**, mục **OpenAI-compatible**, bấm **Add Endpoint…**.
2. Điền **Name** và **Base URL**. Base URL là địa chỉ mà app nối thêm `/chat/completions` vào, nên thường kết thúc bằng `/v1`.
3. **API key** không bắt buộc; máy chủ chạy tại máy thường không cần.
4. Bấm **Load Models** để thử địa chỉ, rồi **Add Endpoint**.
5. Ở **Settings → Presets**, đặt **Provider** của một preset thành máy chủ mới và chọn mô hình.

Địa chỉ `http://` thường chỉ được chấp nhận cho chính máy Mac này (`localhost`). Máy chủ khác phải dùng `https://`.

### Ollama trên Mac của bạn

Khi [Ollama](https://ollama.com) đang chạy và đã tải một mô hình:

- **Name**: `Local Ollama`
- **Base URL**: `http://localhost:11434/v1`
- **API key**: để trống

Văn bản dịch theo cách này không rời khỏi Mac của bạn.

## Chi phí

Sau mỗi lần dịch, Popup hiện số token đã dùng và chi phí ước tính, ví dụ `96 tokens · $0.0004`. Con số ước tính lấy từ bảng giá có sẵn trong app. Với mô hình không có trong bảng, Popup và History ghi **price unknown**.

Đây chỉ là ước tính. Hoá đơn của nhà cung cấp mới là con số thật.
