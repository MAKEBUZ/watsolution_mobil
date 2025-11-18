import 'package:flutter/widgets.dart';
import '../l10n/app_localizations.dart';

class Errors {
  static String errorLoading(BuildContext context) => AppLocalizations.of(context).errorLoading;
  static String userCreateError(BuildContext context) => AppLocalizations.of(context).userCreateError;
  static String loginUnexpectedError(BuildContext context) => AppLocalizations.of(context).loginUnexpectedError;
  static String invoiceOpenFailed(BuildContext context) => AppLocalizations.of(context).invoiceOpenFailed;
  static String invoiceFetchFailed(BuildContext context) => AppLocalizations.of(context).invoiceFetchFailed;

  static String invalidUser(BuildContext context) => AppLocalizations.of(context).invalidUser;
  static String missingOpenAIKey(BuildContext context) => AppLocalizations.of(context).missingOpenAIKey;
  static String aiGenerateFailed(BuildContext context) => AppLocalizations.of(context).aiGenerateFailed;
  static String invalidMeasurement(BuildContext context) => AppLocalizations.of(context).invalidMeasurement;
}