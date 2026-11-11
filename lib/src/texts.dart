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
    this.conversations = 'Conversations',
    this.newConversation = 'New chat',
    this.search = 'Search',
    this.noConversations = 'No conversations yet',
    this.nothingFound = 'Nothing found',
    this.more = 'More',
    this.rename = 'Rename',
    this.renameTitle = 'Rename conversation',
    this.renameHint = 'Leave empty to use the first question',
    this.save = 'Save',
    this.delete = 'Delete',
    this.deleteTitle = 'Delete this conversation?',
    this.deleteBody = 'It is deleted for good and cannot be brought back.',
    this.oneQuestion = '1 question',
    this.questions = '{n} questions',
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

  /// The list of earlier conversations, and the button that shows or hides it.
  final String conversations;

  /// The button that starts a new chat from the list.
  final String newConversation;

  /// The search field above the list.
  final String search;

  /// The list when there is none yet.
  final String noConversations;

  /// The list when the search found none.
  final String nothingFound;

  /// The menu of a conversation in the list.
  final String more;
  final String rename;

  /// The title of the rename dialog.
  final String renameTitle;

  /// The rename field when it is empty: the name goes back to the first question.
  final String renameHint;
  final String save;
  final String delete;

  /// The question of the delete dialog.
  final String deleteTitle;

  /// What the delete dialog says will happen.
  final String deleteBody;

  /// A conversation with one question.
  final String oneQuestion;

  /// A conversation with more questions; {n} is the number.
  final String questions;

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
    conversations: 'Conversations',
    newConversation: 'New chat',
    search: 'Search',
    noConversations: 'No conversations yet',
    nothingFound: 'Nothing found',
    more: 'More',
    rename: 'Rename',
    renameTitle: 'Rename conversation',
    renameHint: 'Leave empty to use the first question',
    save: 'Save',
    delete: 'Delete',
    deleteTitle: 'Delete this conversation?',
    deleteBody: 'It is deleted for good and cannot be brought back.',
    oneQuestion: '1 question',
    questions: '{n} questions',
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
    conversations: 'المحادثات',
    newConversation: 'محادثة جديدة',
    search: 'بحث',
    noConversations: 'لا توجد محادثات بعد',
    nothingFound: 'لم يُعثر على شيء',
    more: 'المزيد',
    rename: 'إعادة التسمية',
    renameTitle: 'إعادة تسمية المحادثة',
    renameHint: 'اتركه فارغًا لاستخدام السؤال الأول',
    save: 'حفظ',
    delete: 'حذف',
    deleteTitle: 'حذف هذه المحادثة؟',
    deleteBody: 'ستُحذف نهائيًا ولا يمكن استعادتها.',
    oneQuestion: 'سؤال واحد',
    questions: 'الأسئلة: {n}',
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
    conversations: 'Gesprekken',
    newConversation: 'Nieuw gesprek',
    search: 'Zoeken',
    noConversations: 'Nog geen gesprekken',
    nothingFound: 'Niets gevonden',
    more: 'Meer',
    rename: 'Hernoemen',
    renameTitle: 'Gesprek hernoemen',
    renameHint: 'Laat leeg om de eerste vraag te gebruiken',
    save: 'Opslaan',
    delete: 'Verwijderen',
    deleteTitle: 'Dit gesprek verwijderen?',
    deleteBody: 'Het wordt voorgoed verwijderd en kan niet terug.',
    oneQuestion: '1 vraag',
    questions: '{n} vragen',
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

  /// "N questions" for a conversation in the list.
  String questionCount(int n) => n == 1 ? oneQuestion : questions.replaceAll('{n}', '$n');

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
    String? conversations,
    String? newConversation,
    String? search,
    String? noConversations,
    String? nothingFound,
    String? more,
    String? rename,
    String? renameTitle,
    String? renameHint,
    String? save,
    String? delete,
    String? deleteTitle,
    String? deleteBody,
    String? oneQuestion,
    String? questions,
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
        conversations: conversations ?? this.conversations,
        newConversation: newConversation ?? this.newConversation,
        search: search ?? this.search,
        noConversations: noConversations ?? this.noConversations,
        nothingFound: nothingFound ?? this.nothingFound,
        more: more ?? this.more,
        rename: rename ?? this.rename,
        renameTitle: renameTitle ?? this.renameTitle,
        renameHint: renameHint ?? this.renameHint,
        save: save ?? this.save,
        delete: delete ?? this.delete,
        deleteTitle: deleteTitle ?? this.deleteTitle,
        deleteBody: deleteBody ?? this.deleteBody,
        oneQuestion: oneQuestion ?? this.oneQuestion,
        questions: questions ?? this.questions,
      );
}
