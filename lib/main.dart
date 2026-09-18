import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'data/repository.dart';
import 'ui/app.dart';
import 'ui/app_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('en_ZA');
  final repo = await InvoiceRepository.open();
  final controller = AppController(repo);
  await controller.bootstrap();
  runApp(SafeInvoiceApp(controller: controller));
}
