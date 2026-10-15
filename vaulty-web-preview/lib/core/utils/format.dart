import 'package:intl/intl.dart';
import '../l10n/app_strings.dart';

String dateLabel(DateTime value) => DateFormat.yMMMd(AppStrings.language).format(value);

String bytesLabel(int bytes) => bytes >= 1000000000
    ? '${(bytes / 1000000000).toStringAsFixed(1)} GB'
    : '${(bytes / 1000000).toStringAsFixed(1)} MB';
String eventTime(DateTime value) =>
    '${dateLabel(value)} · ${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
