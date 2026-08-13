import 'package:flutter_test/flutter_test.dart';
import 'package:lamazon/data/catalog.dart';

void main() {
  const cloud =
      'https://res.cloudinary.com/dq3da5bkb/image/upload/v1786549855/Lamazon/PURE_BITES/burger.png';

  test('a Cloudinary upload is padded to a square', () {
    expect(
      square(cloud),
      'https://res.cloudinary.com/dq3da5bkb/image/upload/'
          'c_pad,w_512,h_512,b_auto,f_auto,q_auto/'
          'v1786549855/Lamazon/PURE_BITES/burger.png',
    );
  });

  test('transforming twice would stack, so the second time is a no-op', () {
    expect(square(square(cloud)), square(cloud));
  });

  test('a non-Cloudinary url is left alone', () {
    // The sample catalogue is Unsplash, which has no /image/upload/ to splice.
    const unsplash = 'https://images.unsplash.com/photo-1441986300917?w=400';
    expect(square(unsplash), unsplash);
  });

  test('an empty url stays empty rather than becoming a request', () {
    expect(square(''), '');
  });
}
