import { beforeEach, describe, expect, it } from "bun:test";
import worker from "../src/index.ts";
import { testDatabase } from "./d1.ts";

const ADMIN_TOKEN = "test-admin-token";
let env: Env;

beforeEach(() => {
  env = { DB: testDatabase(), ADMIN_TOKEN } as Env;
});

function call(path: string, init: RequestInit = {}) {
  const request = new Request(`https://twobyfour.kylefritz.co${path}`, init);
  return worker.fetch(request as Parameters<typeof worker.fetch>[0], env);
}

const upload = {
  user: { username: "kyle", fullName: "Kyle Fritz", computer: "Kyle's MacBook Pro" },
  device: { platform: "macOS", osVersion: "26.6.2", model: "Mac16,7" },
  app: { version: "0.1.1-beta.3", commit: "abc1234", channel: "beta" },
  note: "105\" came out wrong",
  report: "twoByFour 0.1.1-beta.3 (abc1234)\nline 1: 105\" → 8' 9\"\n",
};

function send(body: unknown, headers: Record<string, string> = {}) {
  return call("/v1/logs", {
    method: "POST",
    headers: { "content-type": "application/json", "cf-connecting-ip": "203.0.113.7", ...headers },
    body: typeof body === "string" ? body : JSON.stringify(body),
  });
}

const admin = { authorization: `Bearer ${ADMIN_TOKEN}` };

describe("sending logs", () => {
  it("stores the report and answers with a short reference", async () => {
    const response = await send(upload);
    expect(response.status).toBe(201);
    const { id } = (await response.json()) as { id: string };
    expect(id).toMatch(/^[a-z0-9]{10}$/);

    const stored = (await (await call(`/v1/logs/${id}`, { headers: admin })).json()) as Record<string, string>;
    expect(stored).toMatchObject({
      id,
      username: "kyle",
      full_name: "Kyle Fritz",
      computer: "Kyle's MacBook Pro",
      platform: "macOS",
      os_version: "26.6.2",
      model: "Mac16,7",
      app_version: "0.1.1-beta.3",
      app_commit: "abc1234",
      channel: "beta",
      note: "105\" came out wrong",
      report: upload.report,
      ip: "203.0.113.7",
    });
    expect(Date.parse(stored.received_at)).toBeGreaterThan(0);
  });

  it("accepts a report with only the log in it", async () => {
    const response = await send({ report: "just the log" });
    expect(response.status).toBe(201);
  });

  it("refuses a missing report, bad JSON and anything too big", async () => {
    expect((await send({ note: "no report" })).status).toBe(400);
    expect((await send("{not json")).status).toBe(400);
    expect((await send({ report: "x".repeat(1_000_001) })).status).toBe(413);
  });

  it("keeps identity fields short and printable", async () => {
    const { id } = (await (await send({ ...upload, user: { username: "k\u0000y" + "x".repeat(500) } })).json()) as {
      id: string;
    };
    const stored = (await (await call(`/v1/logs/${id}`, { headers: admin })).json()) as Record<string, string>;
    expect(stored.username.startsWith("ky")).toBe(true);
    expect(stored.username.length).toBe(128);
  });
});

describe("reading logs", () => {
  it("lists the newest first, without the full report", async () => {
    await send({ ...upload, note: "first" });
    await send({ ...upload, note: "second" });
    const response = await call("/v1/logs", { headers: admin });
    expect(response.status).toBe(200);
    const list = (await response.json()) as Record<string, string>[];
    expect(list.map((r) => r.note)).toEqual(["second", "first"]);
    expect(list[0].report).toBeUndefined();
    expect(list[0].username).toBe("kyle");
  });

  it("needs the admin token", async () => {
    const { id } = (await (await send(upload)).json()) as { id: string };
    expect((await call("/v1/logs")).status).toBe(401);
    expect((await call(`/v1/logs/${id}`, { headers: { authorization: "Bearer wrong" } })).status).toBe(401);
  });

  it("says when a report doesn't exist", async () => {
    expect((await call("/v1/logs/nosuchthing", { headers: admin })).status).toBe(404);
  });
});

describe("routes", () => {
  it("sends the home page to the project and answers nothing else", async () => {
    const home = await call("/");
    expect(home.status).toBe(302);
    expect(home.headers.get("location")).toBe("https://github.com/kylefritz/twobyfour");
    expect((await call("/v1/nope")).status).toBe(404);
    expect((await call("/v1/logs", { method: "DELETE", headers: admin })).status).toBe(405);
  });
});
