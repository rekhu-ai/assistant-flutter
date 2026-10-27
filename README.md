# rekhu_assistant

**[Rekhu Assistant](https://rekhu.com)** for Flutter: a custom AI assistant inside your app, for your own customers. It answers from your help, opens the right screen, and does things for the signed-in user through the actions your back end allows.

Your Flutter app talks to **your own back end**, where a Rekhu server package (`rekhu/assistant-laravel` or `@rekhu/assistant-node`) knows the user, their actions, pages and help, and calls Rekhu. The app never holds a Rekhu key. This package gives you:

- **`RekhuChat`**: a ready chat screen, in a page or a bottom sheet, with answers as they stream, steps, page buttons, confirm cards and quick questions, in English, Arabic (right to left) and Dutch, or in your own words.
- **`RekhuChatController`**: the chat as state, for a chat screen of your own design.
- **`RekhuAssistantClient`**: the connection itself, protocol 1, for anything else.

One dependency: `http`. iOS, Android, web, macOS, Windows and Linux.

## Contents

- [How it works](#how-it-works)
- [Install](#install)
- [Your back end](#your-back-end)
- [Use it](#use-it)
- [Signing the user in](#signing-the-user-in)
- [A public chat for visitors](#a-public-chat-for-visitors)
- [Pages and actions](#pages-and-actions)
- [Keeping the conversation](#keeping-the-conversation)
- [Make it look like your app](#make-it-look-like-your-app)
- [Design your own chat](#design-your-own-chat)
- [Languages](#languages)
- [Testing](#testing)
- [Security](#security)
- [Versions](#versions)

## How it works

```
Flutter app  ──protocol 1──▶  your back end (rekhu/assistant-laravel or @rekhu/assistant-node)  ──▶  Rekhu  ──▶  model
```

1. The user asks something in the chat. The app sends it to your back end's chat route, signed in as the user, the way it calls the rest of your API.
2. The server package there reads your help, offers the model the actions and pages this user may use, and streams the answer back.
3. An action that changes something shows a confirm card first; it runs on your back end, as the user, only after they tap Confirm.

## Install

```sh
flutter pub add rekhu_assistant
```

## Your back end

Install the server package there first and add your secret key (`agk_…`); its README walks through it:

- Laravel: [`rekhu/assistant-laravel`](https://github.com/rekhu-ai/assistant-laravel)
- Node.js: [`@rekhu/assistant-node`](https://www.npmjs.com/package/@rekhu/assistant-node)

A mobile app signs in with a token, not a cookie, so put the chat route behind your API's middleware. In Laravel, in `routes/api.php`:

```php
use Rekhu\Assistant\RekhuAssistant;

RekhuAssistant::routes(['middleware' => ['api', 'auth:sanctum']]);
```

with `REKHU_ASSISTANT_ROUTES=false` in `.env` so the package does not also register its web routes. In Node.js, mount the handler behind the middleware that checks your token.

## Use it

```dart
import 'package:rekhu_assistant/rekhu_assistant.dart';

final client = RekhuAssistantClient(
  endpoint: Uri.parse('https://api.example.com/api/rekhu/assistant/chat'),
  headers: () async => {'Authorization': 'Bearer ${await auth.token()}'},
  locale: 'en-GB',
);

// a button that opens the chat over the current screen
FloatingActionButton(
  onPressed: () => RekhuChat.show(context, client: client, onOpenPage: (url) => context.go(url)),
  child: const Icon(Icons.chat_bubble_outline),
);

// or the chat as a screen of its own
Scaffold(body: SafeArea(child: RekhuChat(client: client, onOpenPage: (url) => context.go(url))));
```

Keep one client for as long as the user is signed in: the conversation goes on when the chat is opened again. A complete app is in [`example/`](example/lib/main.dart).

## Signing the user in

`headers` is called before every call, so a refreshed token is always used. Send whatever your API checks: `Authorization: Bearer …`, an API key header, a device id. When your back end answers 401 or 419, the chat says the session ended and `RekhuChatController.signedOut` is true, so the app can sign the user in again.

## A public chat for visitors

For people who are not signed in (a shop's customers before they log in), point the client at the server package's public route and set `visitor`:

```dart
final client = RekhuAssistantClient(
  endpoint: Uri.parse('https://api.example.com/rekhu/assistant/visitor/chat'),
  visitor: true,
);
```

The client sends an anonymous id per install as `X-Rekhu-Visitor`. Visitors reach only the actions you marked for guests, the pages that need no login, and the help, within the caps your back end sets. In Laravel, turn it on with `REKHU_ASSISTANT_GUESTS=true` and give the route your API middleware with `REKHU_ASSISTANT_GUEST_MIDDLEWARE=api`; the [Laravel package's guide](https://github.com/rekhu-ai/assistant-laravel#from-a-flutter-app-or-another-api-client) lists what a 404, 419 or 422 means. In Node.js, the public chat is the `visitor/chat` route next to the signed-in one.

## Pages and actions

- **Page cards** carry an address from your back end: an app path such as `/orders/1001`, or a full URL. `onOpenPage` opens it with your router (`go_router`, `Navigator`), or with `url_launcher` for a website.
- **Links in answers** go to `onOpenPage` too.
- **Actions** run on your back end only after the user taps Confirm on the card. When one ran, `onAction` is called with its card: the app's data changed, so refresh what the screens show.

## Keeping the conversation

By default the conversation lasts while the app runs. To keep it across app starts, give the client a store, for example with `shared_preferences`:

```dart
class PrefsStore implements RekhuStore {
  PrefsStore(this.prefs);
  final SharedPreferences prefs;

  @override
  Future<String?> read(String key) async => prefs.getString(key);

  @override
  Future<void> write(String key, String? value) async => value == null ? prefs.remove(key) : prefs.setString(key, value);
}

final client = RekhuAssistantClient(endpoint: endpoint, headers: headers, store: PrefsStore(await SharedPreferences.getInstance()));
```

The store also keeps a visitor's anonymous id. "New" in the chat (`controller.reset()`) asks the back end to forget the conversation.

## Make it look like your app

The chat follows your app's `Theme`. Change what you want with `RekhuChatTheme`:

```dart
RekhuChat(client: client, theme: const RekhuChatTheme(accent: Color(0xFF0F766E), radius: 18), header: false)
```

| Option | |
|---|---|
| `greeting` | your own first message, in markdown, instead of the server's |
| `quick` | quick questions for a fresh chat, instead of the server's |
| `texts` | your own words for the chat's buttons and messages (`RekhuTexts.en.copyWith(...)`) |
| `theme` | `accent`, `background`, `surface`, `border`, `radius` |
| `header` | the bar with the name and "New"; off when your screen has its own app bar |
| `controller` | share one chat between screens |

## Design your own chat

`RekhuChatController` is the chat as state; draw it any way you like:

```dart
final chat = RekhuChatController(client: client, onAction: (card) => refresh());
await chat.load();                          // earlier messages, or the greeting and quick questions

ListenableBuilder(
  listenable: chat,
  builder: (context, _) => ListView(children: [
    for (final item in chat.items)
      switch (item) {
        RekhuUserItem(:final text) => MyUserBubble(text),
        RekhuBotItem(:final text) => MyBotBubble(child: RekhuMarkdown(text, onLink: open)),
        RekhuStepItem(:final label) => MyStep(label, done: item.over),
        RekhuCardItem() => MyCard(item, onConfirm: () => chat.confirm(item), onCancel: () => chat.cancel(item)),
        RekhuErrorItem(:final message) => MyError(message),
      },
  ]),
);

chat.send('Where is my order?');
```

Or skip the controller and use the client's events directly: `client.send(text)` is a `Stream<RekhuEvent>` of `RekhuStart`, `RekhuText`, `RekhuStep`, `RekhuCard`, `RekhuError` and `RekhuDone` ([protocol 1](PROTOCOL.md)).

## Languages

`locale` (BCP 47: `en-GB`, `ar-SA`, `nl-NL`) is the language the user reads: answers come in it, and the chat's own words are English, Arabic or Dutch accordingly, any other language in English unless you give `texts`. Arabic, Hebrew, Persian and Urdu read right to left, whatever your app's own locale.

Flutter on the web loads fonts for Arabic and other scripts on first use; on iOS and Android the system's fonts are used.

## Testing

Give the client a fake `http.Client` (`package:http/testing.dart`) that answers like your back end; the package's own tests in [`test/`](test/) show how, for streamed answers, confirm cards and errors. To try a real back end, `REKHU_LIVE_ENDPOINT=https://…/rekhu/assistant/visitor/chat flutter test test/live_test.dart` runs a visitor's conversation in English and Arabic.

## Security

- The app holds no Rekhu key; your back end does. Never put a secret key (`agk_…`) in a mobile app: anyone can read it from the build.
- Actions run on your back end, as the signed-in user, with the rights your code checks; the app only sends the id of a confirm card the server issued to this user in this conversation.
- Answers are a small markdown: text, lists, bold, italics, code and links to http(s) or your app's own paths. Nothing in an answer is run as code.

## Versions

Follows [semantic versioning](https://semver.org). The package speaks [protocol 1](PROTOCOL.md); any Rekhu server package that speaks protocol 1 works with it. See the [changelog](CHANGELOG.md).

## Licence

Licensed to holders of a Rekhu account under the [Rekhu Terms of Service](https://rekhu.com/terms). See [LICENSE](LICENSE).
