import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../documents/providers/document_providers.dart';

final trashProvider = Provider(
  (ref) => ref
      .watch(documentsProvider)
      .whenData((docs) => docs.where((d) => d.isDeleted).toList()),
);
