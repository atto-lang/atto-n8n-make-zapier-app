/** Generated from a route-map JSON. Do not edit by hand. */

export type HttpMethod = "GET" | "POST" | "PUT" | "PATCH" | "DELETE" | "HEAD" | "OPTIONS";
export type RpcTransport = "http" | "tcp" | "websocket" | "nats";

export const RPC_CONTRACT_SHA256 = "e6652aebd9612e0aef08d4bf3817460fd3892f5ea6f3cf45cb81c41185d5ce15" as const;
export const RPC_MECHANISMS = {
  "css_asset": {
    "delivery": "direct",
    "key": "css_asset",
    "methods": [
      "GET"
    ],
    "path": "/static/app.css",
    "transports": [
      "http"
    ]
  },
  "dashboard": {
    "delivery": "direct",
    "key": "dashboard",
    "methods": [
      "GET"
    ],
    "path": "/",
    "transports": [
      "http"
    ]
  },
  "healthz": {
    "delivery": "direct",
    "key": "healthz",
    "methods": [
      "GET"
    ],
    "path": "/healthz",
    "transports": [
      "http"
    ]
  },
  "htmx_asset": {
    "delivery": "direct",
    "key": "htmx_asset",
    "methods": [
      "GET"
    ],
    "path": "/static/htmx.min.js",
    "transports": [
      "http"
    ]
  },
  "preview": {
    "delivery": "direct",
    "key": "preview",
    "methods": [
      "POST"
    ],
    "path": "/preview",
    "transports": [
      "http"
    ]
  },
  "websocket": {
    "delivery": "direct",
    "key": "websocket",
    "methods": [
      "GET"
    ],
    "path": "/ws",
    "transports": [
      "http"
    ]
  }
} as const;

export const SERVICE = "ores-workflows-development" as const;

export const Routes = {
  "dashboard": {
    key: "dashboard",
    path: "/" as const,
    methods: ["GET"] as const,
    transports: ["http"] as const,
    buildPath: undefined as ((p: Record<string, never>) => string) | undefined,
  },
  "preview": {
    key: "preview",
    path: "/preview" as const,
    methods: ["POST"] as const,
    transports: ["http"] as const,
    buildPath: undefined as ((p: Record<string, never>) => string) | undefined,
  },
  "healthz": {
    key: "healthz",
    path: "/healthz" as const,
    methods: ["GET"] as const,
    transports: ["http"] as const,
    buildPath: undefined as ((p: Record<string, never>) => string) | undefined,
  },
  "websocket": {
    key: "websocket",
    path: "/ws" as const,
    methods: ["GET"] as const,
    transports: ["http"] as const,
    buildPath: undefined as ((p: Record<string, never>) => string) | undefined,
  },
  "htmx_asset": {
    key: "htmx_asset",
    path: "/static/htmx.min.js" as const,
    methods: ["GET"] as const,
    transports: ["http"] as const,
    buildPath: undefined as ((p: Record<string, never>) => string) | undefined,
  },
  "css_asset": {
    key: "css_asset",
    path: "/static/app.css" as const,
    methods: ["GET"] as const,
    transports: ["http"] as const,
    buildPath: undefined as ((p: Record<string, never>) => string) | undefined,
  },
} as const;

export type RouteName = keyof typeof Routes;

export interface RouteTypes {
  "dashboard": { path: Record<string, never>; query: Record<string, never>; headers: Record<string, never>; body: void; response: unknown };
  "preview": { path: Record<string, never>; query: Record<string, never>; headers: Record<string, never>; body: void; response: unknown };
  "healthz": { path: Record<string, never>; query: Record<string, never>; headers: Record<string, never>; body: void; response: { "status": unknown; "durable_execution": unknown; "websocket": unknown } };
  "websocket": { path: Record<string, never>; query: Record<string, never>; headers: Record<string, never>; body: void; response: unknown };
  "htmx_asset": { path: Record<string, never>; query: Record<string, never>; headers: Record<string, never>; body: void; response: unknown };
  "css_asset": { path: Record<string, never>; query: Record<string, never>; headers: Record<string, never>; body: void; response: unknown };
}

/** Adding a map key without a handler is a TypeScript error. */
export type RouteHandlers<Ctx> = {
  [K in RouteName]: (ctx: Ctx, args: {
    path: RouteTypes[K]["path"];
    query: RouteTypes[K]["query"];
    headers: RouteTypes[K]["headers"];
    body: RouteTypes[K]["body"];
  }) => Promise<RouteTypes[K]["response"]> | RouteTypes[K]["response"];
};

export function lookup<K extends RouteName>(key: K): (typeof Routes)[K] {
  return Routes[key];
}
