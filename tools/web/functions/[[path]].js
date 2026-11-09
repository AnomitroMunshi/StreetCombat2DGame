// Serves the files too big for Pages (index.wasm, index.pck) from R2, on the
// same site as the page. Only those paths reach this function (_routes.json,
// written by deploy.sh). The engine is stored gzipped (Content-Encoding set at
// upload), so it is passed through as is and the browser unpacks it. ETags let
// a returning player's browser revalidate instead of downloading again.
export async function onRequest({ request, env }) {
  if (request.method !== "GET" && request.method !== "HEAD") {
    return new Response("Method not allowed", { status: 405 });
  }
  const key = new URL(request.url).pathname.slice(1);
  const object = await env.GAME.get(key, { onlyIf: request.headers });
  if (object === null) {
    return new Response("Not found", { status: 404 });
  }
  const headers = new Headers();
  object.writeHttpMetadata(headers);
  headers.set("etag", object.httpEtag);
  headers.set("cache-control", "public, max-age=0, must-revalidate");
  if (!("body" in object)) {
    return new Response(null, { status: 304, headers });
  }
  return new Response(request.method === "HEAD" ? null : object.body, { headers, encodeBody: "manual" });
}
