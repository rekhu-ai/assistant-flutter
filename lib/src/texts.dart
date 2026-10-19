/// The chat's own words, in the user's language: English, Arabic and Dutch built in, any of them replaced with your own.
class RekhuTexts {
  const RekhuTexts({
    required this.signedOut,
    required this.busy,
    required this.unavailable,
    required this.failed,
    required this.name,
    required this.newChat,
    required this.placeholder,
    required this.send,
    required this.open,
    required this.confirm,
    required this.cancel,
    required this.confirmed,
    required this.cancelled,
  });

  final String signedOut;
  final String busy;
  final String unavailable;
  final String failed;
  final String name;
  final String newChat;
  final String placeholder;
  final String send;
  final String open;
  final String confirm;
  final String cancel;
  final String confirmed;

  /// What is sent as the user's message when they cancel a confirm card.
  final String cancelled;

  static const en = RekhuTexts(
    signedOut: 'Your session has ended. Sign in again.',
    busy: 'That was a lot of messages at once. Wait a minute and try again.',
    unavailable: 'The assistant is not available right now. Please try again in a moment.',
    failed: 'Something went wrong.',
    name: 'Assistant',
    newChat: 'New',
    placeholder: 'Type a message…',
    send: 'Send',
    open: 'Open',
    confirm: 'Confirm',
    cancel: 'Cancel',
    confirmed: 'Confirmed',
    cancelled: 'Cancel that',
  );

  static const ar = RekhuTexts(
    signedOut: 'انتهت جلستك. سجّل الدخول من جديد.',
    busy: 'رسائل كثيرة في وقت واحد. انتظر دقيقة ثم حاول مرة أخرى.',
    unavailable: 'المساعد غير متاح الآن. حاول مرة أخرى بعد قليل.',
    failed: 'حدث خطأ ما.',
    name: 'المساعد',
    newChat: 'جديد',
    placeholder: 'اكتب رسالتك…',
    send: 'إرسال',
    open: 'فتح',
    confirm: 'تأكيد',
    cancel: 'إلغاء',
    confirmed: 'تم التأكيد',
    cancelled: 'ألغِ ذلك',
  );

  static const nl = RekhuTexts(
    signedOut: 'Je sessie is verlopen. Log opnieuw in.',
    busy: 'Dat waren veel berichten tegelijk. Wacht een minuut en probeer het opnieuw.',
    unavailable: 'De assistent is nu niet beschikbaar. Probeer het zo opnieuw.',
    failed: 'Er ging iets mis.',
    name: 'Assistent',
    newChat: 'Nieuw',
    placeholder: 'Typ een bericht…',
    send: 'Verstuur',
    open: 'Openen',
    confirm: 'Bevestigen',
    cancel: 'Annuleren',
    confirmed: 'Bevestigd',
    cancelled: 'Annuleer dat',
  );

  /// The built-in words for a locale ("ar", "nl-NL", "en_GB"); English for any other.
  static RekhuTexts of(String? locale) {
    switch ((locale ?? 'en').toLowerCase().split(RegExp('[-_]')).first) {
      case 'ar':
        return ar;
      case 'nl':
        return nl;
    }
    return en;
  }

  /// A right-to-left language (Arabic, Hebrew, Persian, Urdu).
  static bool rtl(String? locale) => const {'ar', 'he', 'fa', 'ur'}.contains((locale ?? '').toLowerCase().split(RegExp('[-_]')).first);

  RekhuTexts copyWith({
    String? signedOut,
    String? busy,
    String? unavailable,
    String? failed,
    String? name,
    String? newChat,
    String? placeholder,
    String? send,
    String? open,
    String? confirm,
    String? cancel,
    String? confirmed,
    String? cancelled,
  }) =>
      RekhuTexts(
        signedOut: signedOut ?? this.signedOut,
        busy: busy ?? this.busy,
        unavailable: unavailable ?? this.unavailable,
        failed: failed ?? this.failed,
        name: name ?? this.name,
        newChat: newChat ?? this.newChat,
        placeholder: placeholder ?? this.placeholder,
        send: send ?? this.send,
        open: open ?? this.open,
        confirm: confirm ?? this.confirm,
        cancel: cancel ?? this.cancel,
        confirmed: confirmed ?? this.confirmed,
        cancelled: cancelled ?? this.cancelled,
      );
}
