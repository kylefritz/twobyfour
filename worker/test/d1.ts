// A D1Database backed by bun:sqlite, with the real migrations applied, so
// tests run the Worker's actual SQL. Covers the calls the Worker makes.
import { Database } from "bun:sqlite";
import { readdirSync, readFileSync } from "node:fs";
import { join } from "node:path";

export function testDatabase(): D1Database {
  const db = new Database(":memory:");
  const dir = join(import.meta.dir, "../migrations");
  for (const file of readdirSync(dir).filter((f) => f.endsWith(".sql")).sort()) {
    db.exec(readFileSync(join(dir, file), "utf8"));
  }
  const statement = (sql: string, params: unknown[] = []) => ({
    bind: (...values: unknown[]) => statement(sql, values),
    async run() {
      const result = db.query(sql).run(...(params as never[]));
      return { success: true, meta: { changes: result.changes }, results: [] };
    },
    async first<T>() {
      return (db.query(sql).get(...(params as never[])) as T) ?? null;
    },
    async all<T>() {
      return { success: true, meta: {}, results: db.query(sql).all(...(params as never[])) as T[] };
    },
  });
  return { prepare: (sql: string) => statement(sql) } as unknown as D1Database;
}
