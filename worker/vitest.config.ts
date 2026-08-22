import { defineConfig } from 'vitest/config';

/**
 * Plain (non-Workers-pool) Vitest config, scoped to the pure logic in
 * `scamRules.ts` — regex/math with no Workers-runtime APIs, so it runs
 * fine under plain Node. Modules that touch Workers globals (`auth.ts`,
 * `firestoreClient.ts`, `gemini.ts` — `crypto.subtle` for JWT
 * verification/signing, `KVNamespace` bindings) need the real Workers
 * runtime (`@cloudflare/vitest-pool-workers`, already a devDependency) to
 * test properly; that runtime requires macOS 13.5+ or Linux, which this
 * dev machine doesn't have (see worker-configuration.d.ts). Wire up
 * `defineWorkersConfig` from that package once running on a supported OS
 * or in CI, rather than skipping those modules' tests indefinitely.
 */
export default defineConfig({
  test: {
    include: ['test/**/*.test.ts'],
  },
});
