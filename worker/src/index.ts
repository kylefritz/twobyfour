// twoByFour's server at https://twobyfour.kylefritz.co. For now it takes
// logs people send from the app; later it'll answer Claude lookups too.
// See README.md in this folder.
import * as logs from "./logs.ts";

const REPO = "kylefritz/twobyfour";

/** Compares without leaking, through timing, how much of a guess was right. */
function sameSecret(a: string, b: string): boolean {
  const x = new TextEncoder().encode(a);
  const y = new TextEncoder().encode(b);
  let diff = x.length ^ y.length;
  for (let i = 0; i < Math.max(x.length, y.length); i++) diff |= (x[i] ?? 0) ^ (y[i] ?? 0);
  return diff === 0;
}

function isAdmin(request: Request, env: Env): boolean {
  const header = request.headers.get("authorization") ?? "";
  return env.ADMIN_TOKEN.length > 0 && sameSecret(header, `Bearer ${env.ADMIN_TOKEN}`);
}

const notFound = () => Response.json({ error: "not found" }, { status: 404 });
const notAllowed = () => Response.json({ error: "method not allowed" }, { status: 405 });
const unauthorized = () => Response.json({ error: "unauthorized" }, { status: 401 });

export default {
  async fetch(request, env): Promise<Response> {
    const url = new URL(request.url);
    const path = url.pathname;

    if (path === "/") return Response.redirect(`https://github.com/${REPO}`, 302);

    if (path === "/v1/logs") {
      if (request.method === "POST") return logs.receive(request, env);
      if (request.method !== "GET") return notAllowed();
      if (!isAdmin(request, env)) return unauthorized();
      const limit = Math.min(Math.max(Number(url.searchParams.get("limit")) || 50, 1), 500);
      return logs.list(env, limit);
    }

    const report = path.match(/^\/v1\/logs\/([a-z0-9]+)$/);
    if (report) {
      if (request.method !== "GET") return notAllowed();
      if (!isAdmin(request, env)) return unauthorized();
      return logs.show(env, report[1]);
    }

    return notFound();
  },
} satisfies ExportedHandler<Env>;
