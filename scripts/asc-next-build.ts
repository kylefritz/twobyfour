// Prints the next TestFlight build number for twoByFour: one more than the
// highest build App Store Connect has, so uploads from CI and from a Mac never
// collide. Reads the API key from ASC_KEY_PATH, ASC_KEY_ID and ASC_ISSUER_ID.
//
//   bun scripts/asc-next-build.ts
import { readFileSync } from "node:fs";

const bundleId = "com.kylefritz.twobyfour";
const { ASC_KEY_PATH, ASC_KEY_ID, ASC_ISSUER_ID } = process.env;
if (!ASC_KEY_PATH || !ASC_KEY_ID || !ASC_ISSUER_ID) throw new Error("set ASC_KEY_PATH, ASC_KEY_ID and ASC_ISSUER_ID");

// An ES256 JWT by hand: WebCrypto's ECDSA signature is already the raw r||s form JWTs use.
const b64url = (data: string | ArrayBuffer) => Buffer.from(data as any).toString("base64url");
const pem = readFileSync(ASC_KEY_PATH, "utf8").replace(/-----[^-]+-----|\s/g, "");
const key = await crypto.subtle.importKey("pkcs8", Buffer.from(pem, "base64"), { name: "ECDSA", namedCurve: "P-256" }, false, ["sign"]);
const now = Math.floor(Date.now() / 1000);
const unsigned = `${b64url(JSON.stringify({ alg: "ES256", kid: ASC_KEY_ID, typ: "JWT" }))}.${b64url(
  JSON.stringify({ iss: ASC_ISSUER_ID, iat: now, exp: now + 600, aud: "appstoreconnect-v1" }),
)}`;
const signature = await crypto.subtle.sign({ name: "ECDSA", hash: "SHA-256" }, key, new TextEncoder().encode(unsigned));
const headers = { Authorization: `Bearer ${unsigned}.${b64url(signature)}` };

async function get(path: string) {
  const res = await fetch(`https://api.appstoreconnect.apple.com/v1/${path}`, { headers });
  if (!res.ok) throw new Error(`App Store Connect ${res.status}: ${(await res.text()).slice(0, 300)}`);
  return res.json() as Promise<{ data: { id: string; attributes: Record<string, string> }[] }>;
}

const apps = await get(`apps?filter[bundleId]=${bundleId}`);
const app = apps.data[0];
if (!app) throw new Error(`no App Store Connect app for ${bundleId}`);
const builds = await get(`builds?filter[app]=${app.id}&limit=200&fields[builds]=version`);
const highest = Math.max(0, ...builds.data.map((b) => parseInt(b.attributes.version, 10) || 0));
console.log(highest + 1);
