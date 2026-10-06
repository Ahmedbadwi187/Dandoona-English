import 'package:flutter/widgets.dart';

/// Hand-written localisation (no code generation). The parent area uses the language chosen in settings
/// (Arabic by default, RTL); the child area always uses English. A test keeps both maps in sync.
class Strings {
  const Strings._(this._m, this.locale);

  final Map<String, String> _m;
  final Locale locale;

  static const ar = Strings._(_arabic, Locale('ar'));
  static const en = Strings._(_english, Locale('en'));

  static Strings forCode(String code) => code == 'en' ? en : ar;

  bool get isRtl => locale.languageCode == 'ar';
  TextDirection get direction => isRtl ? TextDirection.rtl : TextDirection.ltr;

  /// `s('save')`. A missing key is a bug caught by the parity test; at runtime the key itself is shown.
  String call(String key) => _m[key] ?? key;

  static Iterable<String> get arabicKeys => _arabic.keys;
  static Iterable<String> get englishKeys => _english.keys;
}

const Map<String, String> _arabic = {
  'appName': 'دندونة إنجليش',
  'welcomeTitle': 'أهلاً بك!',
  'welcomeBody': 'لنُنشئ ملفًا لطفلك ليبدأ تعلّم الإنجليزية بالأصوات والصور والمرح.',
  'start': 'ابدأ',
  'childProfiles': 'ملفات الأطفال',
  'addChild': 'إضافة طفل',
  'editChild': 'تعديل الملف',
  'childName': 'اسم الطفل (اسم مستعار)',
  'nameHint': 'من فضلك لا تُدخل الاسم الكامل',
  'birthYear': 'سنة الميلاد',
  'chooseAvatar': 'اختر صورة',
  'save': 'حفظ',
  'cancel': 'إلغاء',
  'delete': 'حذف',
  'deleteChildTitle': 'حذف الملف؟',
  'deleteChildBody': 'سيتم حذف تقدّم الطفل من هذا الجهاز.',
  'errName': 'أدخل اسمًا من حرف إلى 30 حرفًا',
  'errBirthYear': 'سنة الميلاد غير مناسبة (العمر من 2 إلى 13 سنة)',
  'parentArea': 'منطقة الأهل',
  'dashboard': 'لوحة التقدّم',
  'noChildren': 'لا توجد ملفات بعد.',
  'stars': 'النجوم',
  'lettersDone': 'الحروف المكتملة',
  'settings': 'الإعدادات',
  'language': 'اللغة',
  'arabic': 'العربية',
  'english': 'English',
  'sessionLimit': 'مدة الجلسة بالدقائق',
  'unlockAll': 'فتح جميع الحروف',
  'unlockAllHint': 'للأهل أو للتجربة',
  'openChildMode': 'وضع الطفل',
  'gateTitle': 'للكبار فقط',
  'gateHold': 'اضغط مطوّلًا على الزر',
  'gateHoldButton': 'اضغط مطوّلًا',
  'gateSolve': 'احسب الناتج للمتابعة',
  'gateWrong': 'إجابة غير صحيحة، حاول مرة أخرى',
  'back': 'رجوع',
  'timeUpTitle': 'حان وقت الاستراحة',
  'timeUpBody': 'انتهى وقت اللعب. يمكن للكبار المتابعة.',
  'continue': 'متابعة',
  'loadError': 'تعذّر تحميل الدروس',
  'retry': 'إعادة المحاولة',
  'whoIsPlaying': 'من سيلعب؟',
};

const Map<String, String> _english = {
  'appName': 'Dandoona English',
  'welcomeTitle': 'Welcome!',
  'welcomeBody': "Let's create a profile for your child to start learning English with sounds, pictures and fun.",
  'start': 'Start',
  'childProfiles': 'Child profiles',
  'addChild': 'Add child',
  'editChild': 'Edit profile',
  'childName': "Child's nickname",
  'nameHint': "Please don't enter a full name",
  'birthYear': 'Birth year',
  'chooseAvatar': 'Choose an avatar',
  'save': 'Save',
  'cancel': 'Cancel',
  'delete': 'Delete',
  'deleteChildTitle': 'Delete this profile?',
  'deleteChildBody': "The child's progress will be removed from this device.",
  'errName': 'Enter a name (1-30 characters)',
  'errBirthYear': 'Birth year must give an age of 2 to 13',
  'parentArea': 'Parent area',
  'dashboard': 'Progress dashboard',
  'noChildren': 'No profiles yet.',
  'stars': 'Stars',
  'lettersDone': 'Letters completed',
  'settings': 'Settings',
  'language': 'Language',
  'arabic': 'العربية',
  'english': 'English',
  'sessionLimit': 'Session length (minutes)',
  'unlockAll': 'Unlock all letters',
  'unlockAllHint': 'For parents or testing',
  'openChildMode': 'Child mode',
  'gateTitle': 'Grown-ups only',
  'gateHold': 'Press and hold the button',
  'gateHoldButton': 'Hold',
  'gateSolve': 'Solve to continue',
  'gateWrong': 'Not quite, try again',
  'back': 'Back',
  'timeUpTitle': 'Time to rest',
  'timeUpBody': 'Play time is over. A grown-up can continue.',
  'continue': 'Continue',
  'loadError': "Couldn't load the lessons",
  'retry': 'Try again',
  'whoIsPlaying': 'Who is playing?',
};
