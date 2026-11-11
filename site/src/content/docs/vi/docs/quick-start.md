---
title: Bắt đầu nhanh
description: Thêm API key và dịch đoạn văn đầu tiên.
---

TransFlex gửi văn bản của bạn tới một nhà cung cấp AI bằng API key của chính bạn. Bạn cần một key để bắt đầu.

## 1. Thêm key

Nếu bạn đã bỏ qua bước này ở cửa sổ Welcome:

1. Mở **Settings…** từ icon trên thanh menu, chọn tab **Providers**.
2. Cạnh OpenAI, Anthropic hoặc Gemini, bấm **Add Key…**.
3. Dán key rồi bấm **Save Key**.

Ba preset có sẵn dùng OpenAI, nên có key OpenAI là dùng được ngay. Với nhà cung cấp khác, hãy đổi nhà cung cấp và mô hình của preset trước; xem [Preset](/vi/docs/presets/).

Lấy key ở đâu: [OpenAI](https://platform.openai.com/api-keys), [Anthropic](https://platform.claude.com/settings/keys), [Google AI Studio](https://aistudio.google.com/apikey).

App không kiểm tra key lúc lưu. Nếu key sai, lần dịch đầu sẽ báo **API key invalid. Update in Settings.**

## 2. Dịch

1. Bấm <kbd>⌥</kbd> <kbd>T</kbd> ở bất kỳ app nào. Popup mở ngay trên chỗ bạn đang làm.
2. Gõ hoặc dán văn bản vào ô **Original**.
3. Bấm <kbd>⌘</kbd> <kbd>⏎</kbd>.

Bản dịch hiện dần ở ô **Translation**. Dịch xong, kết quả được copy vào clipboard, và chân cửa sổ ghi mức dùng, ví dụ `96 tokens · $0.0004`.

Bấm <kbd>Esc</kbd> để đóng Popup, hoặc <kbd>⌘</kbd> <kbd>C</kbd> để copy lại kết quả rồi đóng.

## 3. Chọn preset

Menu ở góc trên bên trái Popup dùng để đổi preset. TransFlex có sẵn:

- **Natural EN ↔ VI**: tiếng Anh và tiếng Việt thường ngày, cả hai chiều.
- **Technical Doc EN ↔ VI**: văn bản kỹ thuật, cả hai chiều.
- **Any → English (Natural)**: mọi ngôn ngữ sang tiếng Anh.

Cần cặp ngôn ngữ khác thì tự viết preset: xem [Preset](/vi/docs/presets/).

## Tiếp theo

- Dịch đoạn bạn đang chọn trong app khác mà không cần mở Popup: [Phím tắt](/vi/docs/shortcuts/).
- Dịch chữ trong ảnh chụp màn hình: [Dịch ảnh](/vi/docs/images/).
