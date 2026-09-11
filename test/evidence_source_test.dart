import 'package:clearcase/core/utils/evidence_source.dart';
import 'package:clearcase/views/widgets/file_type_icon.dart';
import 'package:flutter_test/flutter_test.dart';

// Shape of a Firebase Storage download URL: the object path is
// percent-encoded, followed by the media/token query.
String storageUrl(String objectPath) =>
    'https://firebasestorage.googleapis.com/v0/b/clearcase-c4af8.appspot.com/o/'
    '${Uri.encodeComponent(objectPath)}?alt=media&token=abc-123';

void main() {
  group('evidenceSourceOf', () {
    test('reads the tag from a local file path', () {
      expect(evidenceSourceOf('/tmp/Camera_20260911_101500_000_cc-camera.jpg'), EvidenceSource.camera);
      expect(evidenceSourceOf('/tmp/IMG_1234_cc-library.jpg'), EvidenceSource.library);
    });

    test('reads the tag back from a Storage download URL', () {
      final url = storageUrl('users/u1/cases/c1/custody_attachments/1757550000000_IMG_1234_cc-library.jpg');
      expect(evidenceSourceOf(url), EvidenceSource.library);
    });

    test('documents and older uploads are unknown', () {
      expect(evidenceSourceOf(storageUrl('users/u1/cases/c1/x/1757550000000_receipt.pdf')), EvidenceSource.unknown);
      expect(evidenceSourceOf(storageUrl('users/u1/cases/c1/x/1757550000000_photo.jpg')), EvidenceSource.unknown);
    });

    test('a tag elsewhere in the path does not count', () {
      expect(evidenceSourceOf(storageUrl('users/cc-library/x/1757550000000_photo.jpg')), EvidenceSource.unknown);
    });
  });

  test('taggedStorageName keeps the source for index-named uploads', () {
    expect(taggedStorageName('1757550000000_0', '/tmp/IMG_1_cc-library.jpg', 'jpg'),
        '1757550000000_0_cc-library.jpg');
    expect(taggedStorageName('1757550000000_0', '/tmp/notes.pdf', 'pdf'), '1757550000000_0.pdf');
    expect(evidenceSourceOf(taggedStorageName('1_0', '/tmp/a_cc-camera.jpg', 'jpg')), EvidenceSource.camera);
  });

  test('display names hide the internal tag', () {
    final url = storageUrl('users/u1/cases/c1/x/1757550000000_IMG_1234_cc-library.jpg');
    expect(displayNameFromUrl(url), 'IMG_1234.jpg');
  });
}
