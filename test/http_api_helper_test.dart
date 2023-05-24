import 'package:http_api_helper/http_api_helper.dart';
import 'package:test/test.dart';

void main() {
  group('A group of tests', () {
    setUp(() {
      // Additional setup goes here.
    });

    test('First Test', () async {
      final apiHelper = APIHelper(
        baseUrl: "https://dummyjson.com",
        endPoint: "/products",
        isReleaseMode: false,
        printRequest: true,
        printHeaders: true,
        printResponse: false,
        timeoutDurationInSeconds: 10,
        serviceName: "Get Products",
      );
      final result = await apiHelper.getAPI();
      result.fold((l) {
        // Bad Response
        print(l);
      }, (r) {
        // Success Response
        // print(r);
      });
    });
  });
}
