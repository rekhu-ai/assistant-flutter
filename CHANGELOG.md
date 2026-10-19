# Changelog

All notable changes to `rekhu_assistant`. Versions follow [semantic versioning](https://semver.org).

## 0.1.0 · 19 October 2026

- First release: Rekhu Assistant in a Flutter app, connected to your own back end (`rekhu/assistant-laravel` or `@rekhu/assistant-node`), protocol 1.
- `RekhuChat`: a ready chat screen or bottom sheet, with answers as they stream, steps, page buttons, confirm cards, quick questions and "New"; English, Arabic (right to left) and Dutch built in, your own words and colours on top.
- `RekhuChatController`: the chat as state, for a chat screen of your own design.
- `RekhuAssistantClient`: sign-in headers per call, the public chat for visitors with an anonymous id, the conversation kept in a store of your choice, failures in the user's language.
