// Rekhu Assistant in a Flutter app. Run it against your back end's chat route:
//
//   flutter run --dart-define=REKHU_ENDPOINT=https://api.example.com/rekhu/assistant/chat
//   flutter run --dart-define=REKHU_ENDPOINT=https://api.example.com/rekhu/assistant/visitor/chat --dart-define=REKHU_VISITOR=true
//   … --dart-define=REKHU_LOCALE=ar-SA   (Arabic, right to left)
import 'package:flutter/material.dart';
import 'package:rekhu_assistant/rekhu_assistant.dart';

const endpoint = String.fromEnvironment('REKHU_ENDPOINT', defaultValue: 'http://127.0.0.1:8000/rekhu/assistant/visitor/chat');
const visitor = bool.fromEnvironment('REKHU_VISITOR', defaultValue: true);
const locale = String.fromEnvironment('REKHU_LOCALE', defaultValue: 'en-GB');

void main() => runApp(const ShopApp());

class ShopApp extends StatelessWidget {
  const ShopApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'Shop',
        theme: ThemeData(colorSchemeSeed: const Color(0xFF4F46E5), useMaterial3: true),
        routes: {
          '/': (_) => const HomeScreen(),
          '/orders': (_) => const Scaffold(body: Center(child: Text('Your orders'))),
        },
      );
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // one client for the app's lifetime, so the conversation goes on when the chat is opened again
  final client = RekhuAssistantClient(
    endpoint: Uri.parse(endpoint),
    visitor: visitor,
    locale: locale,
    // a signed-in app sends its own login with every call, for example:
    // headers: () async => {'Authorization': 'Bearer ${await auth.token()}'},
  );

  @override
  void dispose() {
    client.close();
    super.dispose();
  }

  // a page card opens with the app's own router; a full address could go to url_launcher
  void open(String url) {
    final path = Uri.tryParse(url)?.path ?? url;
    if (path.startsWith('/orders')) Navigator.of(context).pushNamed('/orders');
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Shop')),
        body: const Center(child: Text('Your shop, with an assistant in the corner.')),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => RekhuChat.show(
            context,
            client: client,
            onOpenPage: open,
            // an action changed the app's data: refresh what the screens show
            onAction: (card) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(card.title ?? 'Done'))),
          ),
          icon: const Icon(Icons.chat_bubble_outline),
          label: const Text('Ask'),
        ),
      );
}
