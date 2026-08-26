import 'dart:async';
import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image/image.dart' as img;
import '../../../core/providers/repository_providers.dart';
import '../../../core/providers/session_providers.dart';

/// Picks an image and re-encodes it as a small square JPEG thumbnail
/// entirely in Dart — no native platform plugin, no image-cropping UI —
/// before base64-storing it as `UserProfile.photoBase64`. Resizing
/// client-side (rather than capping raw file size the way the resume
/// upload does) means any photo works regardless of the original's
/// resolution, and keeps this well clear of the resume's own share of the
/// 1MiB Firestore document cap.
class ProfilePhotoController extends AsyncNotifier<void> {
  @override
  FutureOr<void> build() {}

  static const _thumbnailEdge = 320;
  static const _jpegQuality = 70;

  Future<void> pickAndUpload() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      withData: true,
    );
    final file = result?.files.singleOrNull;
    if (file == null || file.bytes == null) return;
    await _uploadBytes(file.bytes!);
  }

  Future<void> _uploadBytes(Uint8List bytes) async {
    final uid = ref.read(currentUidProvider);
    if (uid == null) return;
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final thumbnail = await _resizeToThumbnail(bytes);
      await ref.read(profileRepositoryProvider).setPhotoBase64(uid, base64Encode(thumbnail));
    });
  }

  /// Decodes on a background isolate via `compute` — JPEG decode/resize/
  /// re-encode of a multi-megapixel phone photo is heavy enough to jank a
  /// frame if run on the UI isolate.
  Future<Uint8List> _resizeToThumbnail(Uint8List bytes) {
    return compute(_resizeToThumbnailSync, bytes);
  }

  static Uint8List _resizeToThumbnailSync(Uint8List bytes) {
    final decoded = img.decodeImage(bytes);
    if (decoded == null) {
      throw const FormatException('That doesn\'t look like a supported image file.');
    }
    final resized = img.copyResizeCropSquare(decoded, size: _thumbnailEdge);
    return Uint8List.fromList(img.encodeJpg(resized, quality: _jpegQuality));
  }

  Future<void> removePhoto() async {
    final uid = ref.read(currentUidProvider);
    if (uid == null) return;
    state = const AsyncLoading();
    state = await AsyncValue.guard(() {
      return ref.read(profileRepositoryProvider).setPhotoBase64(uid, null);
    });
  }
}

final profilePhotoControllerProvider = AsyncNotifierProvider<ProfilePhotoController, void>(
  ProfilePhotoController.new,
);
