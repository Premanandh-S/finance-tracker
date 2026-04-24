/**
 * jest.setup.ts
 *
 * Global Jest setup file. Runs after the test framework is installed in the
 * environment (setupFilesAfterEnv).
 *
 * Note: authApi.test.ts uses @jest-environment node so it runs in the Node.js
 * environment where native fetch (Node.js 18+) is available. No polyfill is
 * needed here for that test file.
 *
 * This file is reserved for any additional global test setup that applies to
 * all test environments.
 */

// react-router-dom v7 requires TextEncoder/TextDecoder which jsdom does not
// provide. Polyfill them from Node.js's built-in `util` module.
import { TextEncoder, TextDecoder } from "util";
if (typeof globalThis.TextEncoder === "undefined") {
  globalThis.TextEncoder = TextEncoder as typeof globalThis.TextEncoder;
}
if (typeof globalThis.TextDecoder === "undefined") {
  globalThis.TextDecoder = TextDecoder as typeof globalThis.TextDecoder;
}
