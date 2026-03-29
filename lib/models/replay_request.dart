import 'captured_exchange.dart';

class ReplayRequest {
  final String originalExchangeId;
  String method;
  String url;
  List<HttpHeader> headers;
  String? body;
  bool followRedirects;

  ReplayRequest({
    required this.originalExchangeId,
    required this.method,
    required this.url,
    required this.headers,
    this.body,
    this.followRedirects = true,
  });

  factory ReplayRequest.fromExchange(CapturedExchange exchange) {
    return ReplayRequest(
      originalExchangeId: exchange.id,
      method: exchange.method,
      url: exchange.url,
      headers: List.from(exchange.requestHeaders),
      body: exchange.cachedRequestBody != null
          ? String.fromCharCodes(exchange.cachedRequestBody!)
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'originalExchangeId': originalExchangeId,
      'method': method,
      'url': url,
      'headers': headers.map((h) => {'name': h.name, 'value': h.value}).toList(),
      'body': body,
      'followRedirects': followRedirects,
    };
  }
}