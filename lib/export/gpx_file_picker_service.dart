import 'package:file_selector/file_selector.dart';

abstract interface class GpxFilePickerService {
  Future<XFile?> pickImportFile();
}

class PlatformGpxFilePickerService implements GpxFilePickerService {
  const PlatformGpxFilePickerService();

  @override
  Future<XFile?> pickImportFile() async {
    return openFile(
      acceptedTypeGroups: const [
        XTypeGroup(
          label: 'GPX',
          extensions: ['gpx'],
        ),
      ],
      confirmButtonText: 'Importieren',
    );
  }
}
