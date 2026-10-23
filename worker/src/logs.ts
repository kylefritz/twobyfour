// Logs sent from the app's Help → Send Logs, so problems people hit can be
// read and fixed. Anyone can send; reading needs the admin token.

/** Biggest report accepted, in characters. The app sends about 300 log lines. */
export const MAX_REPORT = 1_000_000;

/** What the app sends. Everything but `report` is optional. */
interface Upload {
  user?: { username?: string; fullName?: string; computer?: string };
  device?: { platform?: string; osVersion?: string; model?: string };
  app?: { version?: string; commit?: string; channel?: string };
  note?: string;
  report?: string;
}

/** Values from the internet: keep them short and printable. */
function clean(value: unknown, max = 128): string {
  return (typeof value === "string" ? value : "").replace(/[\u0000-\u001f\u007f]/g, "").slice(0, max);
}

/** Ten lowercase letters and digits: short enough to read out. */
function newId(): string {
  const alphabet = "abcdefghijkmnpqrstuvwxyz23456789";
  return Array.from(crypto.getRandomValues(new Uint8Array(10)), (b) => alphabet[b % alphabet.length]).join("");
}

export async function receive(request: Request, env: Env): Promise<Response> {
  let upload: Upload;
  try {
    upload = await request.json();
  } catch {
    return Response.json({ error: "not JSON" }, { status: 400 });
  }
  if (typeof upload?.report !== "string" || upload.report.length === 0) {
    return Response.json({ error: "no report" }, { status: 400 });
  }
  if (upload.report.length > MAX_REPORT) {
    return Response.json({ error: "report too large" }, { status: 413 });
  }
  const cf = (request as Request & { cf?: { country?: string } }).cf;
  const id = newId();
  await env.DB.prepare(
    `INSERT INTO log_reports (id, received_at, username, full_name, computer, platform, os_version, model,
       app_version, app_commit, channel, note, report, ip, country)
     VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
  )
    .bind(
      id,
      new Date().toISOString(),
      clean(upload.user?.username),
      clean(upload.user?.fullName),
      clean(upload.user?.computer),
      clean(upload.device?.platform),
      clean(upload.device?.osVersion),
      clean(upload.device?.model),
      clean(upload.app?.version),
      clean(upload.app?.commit),
      clean(upload.app?.channel),
      (typeof upload.note === "string" ? upload.note : "").slice(0, 10_000),
      upload.report,
      clean(request.headers.get("cf-connecting-ip"), 64),
      clean(cf?.country, 4),
    )
    .run();
  return Response.json({ id }, { status: 201 });
}

/** Newest first, without the reports themselves. */
export async function list(env: Env, limit: number): Promise<Response> {
  const { results } = await env.DB.prepare(
    `SELECT id, received_at, username, full_name, computer, platform, os_version, model,
       app_version, app_commit, channel, note, ip, country
     FROM log_reports ORDER BY received_at DESC, rowid DESC LIMIT ?`,
  )
    .bind(limit)
    .all();
  return Response.json(results);
}

export async function show(env: Env, id: string): Promise<Response> {
  const row = await env.DB.prepare(`SELECT * FROM log_reports WHERE id = ?`).bind(id).first();
  return row ? Response.json(row) : Response.json({ error: "not found" }, { status: 404 });
}
