//// Generated from a route-map JSON. Do not edit by hand.
//// Exhaustive `RouteKey` case is the backend compile check.

/// Digest of the normalized RPC contract and docs bundle.
pub const rpc_contract_sha256: String = "e6652aebd9612e0aef08d4bf3817460fd3892f5ea6f3cf45cb81c41185d5ce15"
/// Full route mechanism metadata, bound by rpc_contract_sha256.
pub const rpc_mechanisms_json: String = "{\"css_asset\":{\"delivery\":\"direct\",\"key\":\"css_asset\",\"methods\":[\"GET\"],\"path\":\"/static/app.css\",\"transports\":[\"http\"]},\"dashboard\":{\"delivery\":\"direct\",\"key\":\"dashboard\",\"methods\":[\"GET\"],\"path\":\"/\",\"transports\":[\"http\"]},\"healthz\":{\"delivery\":\"direct\",\"key\":\"healthz\",\"methods\":[\"GET\"],\"path\":\"/healthz\",\"transports\":[\"http\"]},\"htmx_asset\":{\"delivery\":\"direct\",\"key\":\"htmx_asset\",\"methods\":[\"GET\"],\"path\":\"/static/htmx.min.js\",\"transports\":[\"http\"]},\"preview\":{\"delivery\":\"direct\",\"key\":\"preview\",\"methods\":[\"POST\"],\"path\":\"/preview\",\"transports\":[\"http\"]},\"websocket\":{\"delivery\":\"direct\",\"key\":\"websocket\",\"methods\":[\"GET\"],\"path\":\"/ws\",\"transports\":[\"http\"]}}"

pub const service: String = "ores-workflows-development"

pub type RouteKey {
  Dashboard
  Preview
  Healthz
  Websocket
  HtmxAsset
  CssAsset
}

pub fn all() -> List(RouteKey) {
  [Dashboard, Preview, Healthz, Websocket, HtmxAsset, CssAsset]
}

pub fn to_string(key: RouteKey) -> String {
  case key {
    Dashboard -> "dashboard"
    Preview -> "preview"
    Healthz -> "healthz"
    Websocket -> "websocket"
    HtmxAsset -> "htmx_asset"
    CssAsset -> "css_asset"
  }
}

pub fn parse(key: String) -> Result(RouteKey, Nil) {
  case key {
    "dashboard" -> Ok(Dashboard)
    "preview" -> Ok(Preview)
    "healthz" -> Ok(Healthz)
    "websocket" -> Ok(Websocket)
    "htmx_asset" -> Ok(HtmxAsset)
    "css_asset" -> Ok(CssAsset)
    _ -> Error(Nil)
  }
}

pub fn path(key: RouteKey) -> String {
  case key {
    Dashboard -> "/"
    Preview -> "/preview"
    Healthz -> "/healthz"
    Websocket -> "/ws"
    HtmxAsset -> "/static/htmx.min.js"
    CssAsset -> "/static/app.css"
  }
}

pub fn methods(key: RouteKey) -> List(String) {
  case key {
    Dashboard -> ["GET"]
    Preview -> ["POST"]
    Healthz -> ["GET"]
    Websocket -> ["GET"]
    HtmxAsset -> ["GET"]
    CssAsset -> ["GET"]
  }
}

pub fn transports(key: RouteKey) -> List(String) {
  case key {
    Dashboard -> ["http"]
    Preview -> ["http"]
    Healthz -> ["http"]
    Websocket -> ["http"]
    HtmxAsset -> ["http"]
    CssAsset -> ["http"]
  }
}
