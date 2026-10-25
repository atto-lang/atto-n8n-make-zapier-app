//! Generated from a route-map JSON. Do not edit by hand.
//! Exhaustive `RouteKey` match is the backend compile check.
#![allow(dead_code)]

/// Digest of the normalized RPC contract and docs bundle.
pub const RPC_CONTRACT_SHA256: &str = "e6652aebd9612e0aef08d4bf3817460fd3892f5ea6f3cf45cb81c41185d5ce15";
/// Transport, framing, delivery, alias, and queue metadata for every route.
pub const RPC_MECHANISMS_JSON: &str = r###"{"css_asset":{"delivery":"direct","key":"css_asset","methods":["GET"],"path":"/static/app.css","transports":["http"]},"dashboard":{"delivery":"direct","key":"dashboard","methods":["GET"],"path":"/","transports":["http"]},"healthz":{"delivery":"direct","key":"healthz","methods":["GET"],"path":"/healthz","transports":["http"]},"htmx_asset":{"delivery":"direct","key":"htmx_asset","methods":["GET"],"path":"/static/htmx.min.js","transports":["http"]},"preview":{"delivery":"direct","key":"preview","methods":["POST"],"path":"/preview","transports":["http"]},"websocket":{"delivery":"direct","key":"websocket","methods":["GET"],"path":"/ws","transports":["http"]}}"###;

pub const SERVICE: &str = "ores-workflows-development";

#[derive(Copy, Clone, Debug, Eq, PartialEq, Ord, PartialOrd, Hash)]
pub enum RouteKey {
    Dashboard,
    Preview,
    Healthz,
    Websocket,
    HtmxAsset,
    CssAsset,
}

impl RouteKey {
    pub const ALL: &'static [Self] = &[
        Self::Dashboard,
        Self::Preview,
        Self::Healthz,
        Self::Websocket,
        Self::HtmxAsset,
        Self::CssAsset,
    ];

    #[must_use]
    pub fn as_str(self) -> &'static str {
        match self {
            Self::Dashboard => "dashboard",
            Self::Preview => "preview",
            Self::Healthz => "healthz",
            Self::Websocket => "websocket",
            Self::HtmxAsset => "htmx_asset",
            Self::CssAsset => "css_asset",
        }
    }

    #[must_use]
    pub fn parse(key: &str) -> Option<Self> {
        match key {
            "dashboard" => Some(Self::Dashboard),
            "preview" => Some(Self::Preview),
            "healthz" => Some(Self::Healthz),
            "websocket" => Some(Self::Websocket),
            "htmx_asset" => Some(Self::HtmxAsset),
            "css_asset" => Some(Self::CssAsset),
            _ => None,
        }
    }

    #[must_use]
    pub fn path(self) -> &'static str {
        match self {
            Self::Dashboard => "/",
            Self::Preview => "/preview",
            Self::Healthz => "/healthz",
            Self::Websocket => "/ws",
            Self::HtmxAsset => "/static/htmx.min.js",
            Self::CssAsset => "/static/app.css",
        }
    }

    #[must_use]
    pub fn methods(self) -> &'static [&'static str] {
        match self {
            Self::Dashboard => &["GET"],
            Self::Preview => &["POST"],
            Self::Healthz => &["GET"],
            Self::Websocket => &["GET"],
            Self::HtmxAsset => &["GET"],
            Self::CssAsset => &["GET"],
        }
    }

    #[must_use]
    pub fn transports(self) -> &'static [&'static str] {
        match self {
            Self::Dashboard => &["http"],
            Self::Preview => &["http"],
            Self::Healthz => &["http"],
            Self::Websocket => &["http"],
            Self::HtmxAsset => &["http"],
            Self::CssAsset => &["http"],
        }
    }
}

#[derive(Clone, Debug, Default, serde::Serialize, serde::Deserialize)]
pub struct HealthzResponse {
    pub status: serde_json::Value,
    pub durable_execution: serde_json::Value,
    pub websocket: serde_json::Value,
}
