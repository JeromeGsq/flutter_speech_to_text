/// Options for permission request dialogs (Android only).
///
/// On iOS, the system handles permission dialogs automatically using
/// the strings defined in Info.plist.
class PermissionOptions {
  /// Title for the permission dialog.
  final String? title;

  /// Message explaining why the permission is needed.
  final String? message;

  /// Text for the neutral button.
  final String? buttonNeutral;

  /// Text for the negative button.
  final String? buttonNegative;

  /// Text for the positive button.
  final String? buttonPositive;

  const PermissionOptions({
    this.title,
    this.message,
    this.buttonNeutral,
    this.buttonNegative,
    this.buttonPositive,
  });

  Map<String, dynamic> toMap() {
    return {
      if (title != null) 'title': title,
      if (message != null) 'message': message,
      if (buttonNeutral != null) 'buttonNeutral': buttonNeutral,
      if (buttonNegative != null) 'buttonNegative': buttonNegative,
      if (buttonPositive != null) 'buttonPositive': buttonPositive,
    };
  }
}
