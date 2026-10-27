# Changelog

All notable changes to `rekhu_assistant`. Versions follow [semantic versioning](https://semver.org).

## 0.1.1 · 27 October 2026

- **Start free.** The README says how to begin: [create a Rekhu account](https://rekhu.com/register?ref=assistant-flutter) and it starts with $10 credit, no card needed, with links to the docs and pricing.
- The README says where the key comes from: a Rekhu account, a Laravel or Node.js project, and a key on its Connection tab.
- The public chat's address in the README carries the `api/` prefix that `routes/api.php` adds; the old example pointed at a route that does not exist there (404).

## 0.1.0 · 19 October 2026

- First release: Rekhu Assistant in a Flutter app, connected to your own back end (`rekhu/assistant-laravel` or `@rekhu/assistant-node`), protocol 1.
- `RekhuChat`: a ready chat screen or bottom sheet, with answers as they stream, steps, page buttons, confirm cards, quick questions and "New"; English, Arabic (right to left) and Dutch built in, your own words and colours on top.
- `RekhuChatController`: the chat as state, for a chat screen of your own design.
- `RekhuAssistantClient`: sign-in headers per call, the public chat for visitors with an anonymous id, the conversation kept in a store of your choice, failures in the user's language.
