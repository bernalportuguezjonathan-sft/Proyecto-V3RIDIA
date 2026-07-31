import 'package:image_picker/image_picker.dart';

ImageSource resolvePhotoSource({required bool isWeb, required bool preferCamera}) {
  if (isWeb) {
    return ImageSource.gallery;
  }

  return preferCamera ? ImageSource.camera : ImageSource.gallery;
}
