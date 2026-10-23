// twoByFour's server. See README.md in this folder.
import { bindings, defineConfig } from "cf/config";
import * as entrypoint from "./src/index.ts" with { type: "cf-worker" };

export default defineConfig({
	worker: {
		name: "twobyfour",
		compatibilityDate: "2026-10-19",
		entrypoint,
		domains: ["twobyfour.kylefritz.co"],
		env: {
			DB: bindings.d1({ name: "twobyfour" }),
			// Reading logs back needs `Authorization: Bearer <ADMIN_TOKEN>`.
			ADMIN_TOKEN: bindings.secret(),
		},
		observability: { enabled: true },
	},
});
