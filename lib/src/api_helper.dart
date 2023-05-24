// Author - Rashmin Dungrani

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

import 'package:dartz/dartz.dart';
import 'package:http/http.dart';

import 'utils/api_exceptions.dart';
import 'utils/internet_status.dart';
import 'utils/log_helper.dart';

enum HTTPMethod {
  post,
  get,
  delete,
  patch,
  put,
  multipartPost,
}

extension HttpMethodExtension on HTTPMethod {
  String get contentType {
    switch (this) {
      case HTTPMethod.post:
        return 'application/x-www-form-urlencoded';
      case HTTPMethod.get:
        return 'application/json';
      case HTTPMethod.delete:
        return 'application/json';
      case HTTPMethod.patch:
        return 'application/x-www-form-urlencoded';
      case HTTPMethod.multipartPost:
        return 'application/x-www-form-urlencoded';
      default:
        return 'application/json';
    }
  }
}

class APIHelper {
  final String serviceName;
  final String endPoint;
  final String baseUrl;

  final bool checkInternet;
  final bool printRequest;
  final bool printResponse;
  final bool printHeaders;

  // use kReleaseMode from foundation because dart package does not have and we can improve logging performance by not printing Logs in release mode
  final bool isReleaseMode;

  final Map<String, String>? additionalHeader;
  final Map<String, String>? useOnlyThisHeader;
  final int timeoutDurationInSeconds;

  APIHelper({
    required this.endPoint,
    required this.baseUrl,
    required this.isReleaseMode,
    this.serviceName = ' ',
    this.checkInternet = true,
    this.printRequest = true,
    this.printResponse = false,
    this.printHeaders = false,
    this.additionalHeader,
    this.useOnlyThisHeader,
    this.timeoutDurationInSeconds = 60,
  });

  Uri get apiUri => Uri.parse(baseUrl + endPoint);

  Map<String, String> getHeaders(HTTPMethod method) {
    final Map<String, String> headers = {};
    headers['Content-Type'] = method.contentType;

    if (useOnlyThisHeader != null) {
      headers.addAll(useOnlyThisHeader!);
      return headers;
    }

    headers['User-Agent'] = Platform.isIOS ? 'iOS' : 'Android';

    if (additionalHeader != null) {
      headers.addAll(additionalHeader!);
    }

    if (printHeaders) {
      Log.error(isReleaseMode, '*** HEADER in $endPoint API ***');
      Log.error(isReleaseMode, headers.toPrettyString());
    }

    return headers;
  }

  Future<Either<APIExceptionBase, Map<String, dynamic>>> getAPI() async {
    return _executeRequest(HTTPMethod.get);
  }

  Future<Either<APIExceptionBase, Map<String, dynamic>>> postAPI({
    required Map<String, dynamic> body,
    bool isFormData = false,
  }) async {
    return _executeRequest(HTTPMethod.post, body: body, isFormData: isFormData);
  }

  Future<Either<APIExceptionBase, Map<String, dynamic>>> putAPI({
    required Map<String, dynamic> body,
  }) async {
    return _executeRequest(
      HTTPMethod.put,
      body: body,
    );
  }

  Future<Either<APIExceptionBase, Map<String, dynamic>>> patchAPI({
    required Map<String, dynamic> body,
  }) async {
    return _executeRequest(HTTPMethod.patch, body: body);
  }

  Future<Either<APIExceptionBase, Map<String, dynamic>>> deleteAPI() async {
    return _executeRequest(HTTPMethod.delete);
  }

  Future<Either<APIExceptionBase, Map<String, dynamic>>> _executeRequest(
    HTTPMethod method, {
    Map<String, dynamic>? body,
    bool isFormData = false,
  }) async {
    final headers = getHeaders(method);
    _printAPIRequest(method: method, body: body);
    if (checkInternet) {
      if (!await hasNetwork()) {
        return Left(NoInternetException());
      }
    }

    late final Response response;

    try {
      switch (method) {
        case HTTPMethod.get:
          response = await Client()
              .get(
                apiUri,
                headers: headers,
              )
              .timeout(Duration(seconds: timeoutDurationInSeconds));
        case HTTPMethod.post:
          response = await Client()
              .post(
                apiUri,
                headers: headers,
                body: isFormData ? body : jsonEncode(body),
              )
              .timeout(Duration(seconds: timeoutDurationInSeconds));
        case HTTPMethod.put:
          response = await Client()
              .put(
                apiUri,
                headers: headers,
                body: body,
              )
              .timeout(Duration(seconds: timeoutDurationInSeconds));
        case HTTPMethod.patch:
          response = await Client()
              .patch(
                apiUri,
                headers: headers,
                body: body,
              )
              .timeout(Duration(seconds: timeoutDurationInSeconds));
        case HTTPMethod.delete:
          response = await Client()
              .delete(
                apiUri,
                headers: headers,
              )
              .timeout(Duration(seconds: timeoutDurationInSeconds));
        case HTTPMethod.multipartPost:
          throw UnsupportedError(
              'Multipart Post is not supported in _executeRequest');
        default:
          throw ArgumentError('Invalid HttpMethod');
      }

      _printAPIResponse(response);

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return Right(jsonDecode(response.body));
      } else {
        return Left(UnexpectedStatusCodeException(response));
      }
    } on TimeoutException {
      Log.error(isReleaseMode, 'timeout exception thrown');
      return Left(TimeoutException(timeoutDurationInSeconds));
    } catch (e) {
      Log.error(isReleaseMode, e);
      return Left(UnhandledException(e));
    }
  }

  Future<Either<APIExceptionBase, Map<String, dynamic>>> postMultipartAPI({
    required Map<String, String> body,
    required Map<String, dynamic> files,
  }) async {
    try {
      // Prepare the request body
      final request = http.MultipartRequest('POST', apiUri);

      // Add body parameters
      request.fields.addAll(body);

      // Add files
      for (final entry in files.entries) {
        final file = await http.MultipartFile.fromPath(entry.key, entry.value);
        request.files.add(file);
      }

      // Send the request
      final streamedResponse = await request.send();

      // Parse the response
      final responseBody = await streamedResponse.stream.bytesToString();
      final response = Response(
        responseBody,
        streamedResponse.statusCode,
        headers: streamedResponse.headers,
      );

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return Right(jsonDecode(response.body));
      } else {
        return Left(UnexpectedStatusCodeException(response));
      }
    } catch (e) {
      print('Error: $e');
      //  Left({'message': 'An error occurred'});
      return Left(UnhandledException(e));
    }
  }

  // API info...
  void _printAPIRequest({
    required HTTPMethod method,
    required Map<String, dynamic>? body,
  }) {
    if (isReleaseMode || printRequest == false) return;
    Log.info(isReleaseMode, """

╔════════════════════════════════════════════════════════════════════════════╗
║     API REQUEST                                                            ║
╠════════════════════════════════════════════════════════════════════════════╣
║ Type   :- ${method.name}
║ URL    :- $apiUri
║ Params :- $body
╚════════════════════════════════════════════════════════════════════════════╝
""");
  }

  // API response info...
  void _printAPIResponse(Response response) {
    late final String responseBody;
    if (printResponse) {
      try {
        responseBody = Map<String, dynamic>.from(jsonDecode(response.body))
            .toPrettyString();
      } catch (e) {
        Log.error(isReleaseMode,
            "-- RESPONSE BODY IS NOT PROPER in $endPoint API --");
        responseBody = response.body;
      }
    }
    if (printResponse &&
        response.statusCode >= 200 &&
        response.statusCode < 300) {
      Log.success(isReleaseMode, """
╔════════════════════════════════════════════════════════════════════════════╗
║      API RESPONSE                                                          ║
╠════════════════════════════════════════════════════════════════════════════╣
║ API        :- $endPoint
║ StatusCode :- ${response.statusCode}
║ Response   :- 

$responseBody

╚════════════════════════════════════════════════════════════════════════════╝
""");
    } else if (printResponse) {
      print('yes second if');
      Log.error(isReleaseMode, """
╔════════════════════════════════════════════════════════════════════════════╗
║      API RESPONSE                                                          ║
╠════════════════════════════════════════════════════════════════════════════╣
║ API        :- $endPoint
║ StatusCode :- ${response.statusCode}
║ Response   :- 

$responseBody

╚════════════════════════════════════════════════════════════════════════════╝
""");
    }
  }
}

extension APIMapBody on Map<String, dynamic> {
  String toPrettyString() {
    var encoder = const JsonEncoder.withIndent("     ");
    return encoder.convert(this);
  }
}
