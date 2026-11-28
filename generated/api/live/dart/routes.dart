/// Generated from a route-map JSON. Do not edit by hand.
library;

/// Digest of the normalized RPC contract and docs bundle.
const String rpcContractSha256 = 'e6652aebd9612e0aef08d4bf3817460fd3892f5ea6f3cf45cb81c41185d5ce15';
/// Full route mechanism metadata, bound by [rpcContractSha256].
const String rpcMechanismsJson = r'''{"css_asset":{"delivery":"direct","key":"css_asset","methods":["GET"],"path":"/static/app.css","transports":["http"]},"dashboard":{"delivery":"direct","key":"dashboard","methods":["GET"],"path":"/","transports":["http"]},"healthz":{"delivery":"direct","key":"healthz","methods":["GET"],"path":"/healthz","transports":["http"]},"htmx_asset":{"delivery":"direct","key":"htmx_asset","methods":["GET"],"path":"/static/htmx.min.js","transports":["http"]},"preview":{"delivery":"direct","key":"preview","methods":["POST"],"path":"/preview","transports":["http"]},"websocket":{"delivery":"direct","key":"websocket","methods":["GET"],"path":"/ws","transports":["http"]}}''';

const String kService = "ores-workflows-development";

class RouteMeta {
  const RouteMeta({required this.key, required this.path, required this.methods, this.transports = const ['http']});
  final String key;
  final String path;
  final List<String> methods;
  final List<String> transports;
  String expand(Map<String, String> params) {
    var out = path;
    params.forEach((k, v) {
      out = out.replaceAll('{$k}', Uri.encodeComponent(v));
    });
    return out;
  }
}

abstract final class Routes {
  static const dashboard = RouteMeta(key: "dashboard", path: "/", methods: ["GET"], transports: ["http"]);
  static const preview = RouteMeta(key: "preview", path: "/preview", methods: ["POST"], transports: ["http"]);
  static const healthz = RouteMeta(key: "healthz", path: "/healthz", methods: ["GET"], transports: ["http"]);
  static const websocket = RouteMeta(key: "websocket", path: "/ws", methods: ["GET"], transports: ["http"]);
  static const htmx_asset = RouteMeta(key: "htmx_asset", path: "/static/htmx.min.js", methods: ["GET"], transports: ["http"]);
  static const css_asset = RouteMeta(key: "css_asset", path: "/static/app.css", methods: ["GET"], transports: ["http"]);

  static const Map<String, RouteMeta> byKey = {
    "dashboard": dashboard,
    "preview": preview,
    "healthz": healthz,
    "websocket": websocket,
    "htmx_asset": htmx_asset,
    "css_asset": css_asset,
  };
}
