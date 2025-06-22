import "../chunk-ZGVQRVTL.js";

// node_modules/uuid/dist/esm/stringify.js
var byteToHex = [];
for (let i = 0; i < 256; ++i) {
  byteToHex.push((i + 256).toString(16).slice(1));
}
function unsafeStringify(arr, offset = 0) {
  return (byteToHex[arr[offset + 0]] + byteToHex[arr[offset + 1]] + byteToHex[arr[offset + 2]] + byteToHex[arr[offset + 3]] + "-" + byteToHex[arr[offset + 4]] + byteToHex[arr[offset + 5]] + "-" + byteToHex[arr[offset + 6]] + byteToHex[arr[offset + 7]] + "-" + byteToHex[arr[offset + 8]] + byteToHex[arr[offset + 9]] + "-" + byteToHex[arr[offset + 10]] + byteToHex[arr[offset + 11]] + byteToHex[arr[offset + 12]] + byteToHex[arr[offset + 13]] + byteToHex[arr[offset + 14]] + byteToHex[arr[offset + 15]]).toLowerCase();
}

// node_modules/uuid/dist/esm/rng.js
import { randomFillSync } from "crypto";
var rnds8Pool = new Uint8Array(256);
var poolPtr = rnds8Pool.length;
function rng() {
  if (poolPtr > rnds8Pool.length - 16) {
    randomFillSync(rnds8Pool);
    poolPtr = 0;
  }
  return rnds8Pool.slice(poolPtr, poolPtr += 16);
}

// node_modules/uuid/dist/esm/native.js
import { randomUUID } from "crypto";
var native_default = { randomUUID };

// node_modules/uuid/dist/esm/v4.js
function v4(options, buf, offset) {
  if (native_default.randomUUID && !buf && !options) {
    return native_default.randomUUID();
  }
  options = options || {};
  const rnds = options.random || (options.rng || rng)();
  rnds[6] = rnds[6] & 15 | 64;
  rnds[8] = rnds[8] & 63 | 128;
  if (buf) {
    offset = offset || 0;
    for (let i = 0; i < 16; ++i) {
      buf[offset + i] = rnds[i];
    }
    return buf;
  }
  return unsafeStringify(rnds);
}
var v4_default = v4;

// e2e/starter-plugin.test.ts
var StarterTestSuite = class {
  name = "starter";
  description = "E2E tests for the starter project";
  tests = [
    {
      name: "Character configuration test",
      fn: async (runtime) => {
        const requiredFields = ["name", "bio", "plugins", "system", "messageExamples"];
        const missingFields = requiredFields.filter((field) => !(field in void 0));
        if (missingFields.length > 0) {
          throw new Error(`Missing required fields: ${missingFields.join(", ")}`);
        }
        if ((void 0).name !== "Eliza") {
          throw new Error(`Expected character name to be 'Eliza', got '${(void 0).name}'`);
        }
        if (!Array.isArray((void 0).plugins)) {
          throw new Error("Character plugins should be an array");
        }
        if (!(void 0).system) {
          throw new Error("Character system prompt is required");
        }
        if (!Array.isArray((void 0).bio)) {
          throw new Error("Character bio should be an array");
        }
        if (!Array.isArray((void 0).messageExamples)) {
          throw new Error("Character message examples should be an array");
        }
      }
    },
    {
      name: "Plugin initialization test",
      fn: async (runtime) => {
        try {
          await runtime.registerPlugin({
            name: "starter",
            description: "A starter plugin for Eliza",
            init: async () => {
            },
            config: {}
          });
        } catch (error) {
          throw new Error(`Failed to register plugin: ${error.message}`);
        }
      }
    },
    {
      name: "Hello world action test",
      fn: async (runtime) => {
        const message = {
          entityId: v4_default(),
          roomId: v4_default(),
          content: {
            text: "Can you say hello?",
            source: "test",
            actions: ["HELLO_WORLD"]
            // Explicitly request the HELLO_WORLD action
          }
        };
        const state = {
          values: {},
          data: {},
          text: ""
        };
        let responseReceived = false;
        try {
          await runtime.processActions(message, [], state, async (content) => {
            if (content.text === "hello world!" && content.actions?.includes("HELLO_WORLD")) {
              responseReceived = true;
            }
            return [];
          });
          if (!responseReceived) {
            const helloWorldAction = runtime.actions.find((a) => a.name === "HELLO_WORLD");
            if (helloWorldAction) {
              await helloWorldAction.handler(
                runtime,
                message,
                state,
                {},
                async (content) => {
                  if (content.text === "hello world!" && content.actions?.includes("HELLO_WORLD")) {
                    responseReceived = true;
                  }
                  return [];
                },
                []
              );
            } else {
              throw new Error("HELLO_WORLD action not found in runtime.actions");
            }
          }
          if (!responseReceived) {
            throw new Error("Hello world action did not produce expected response");
          }
        } catch (error) {
          throw new Error(`Hello world action test failed: ${error.message}`);
        }
      }
    },
    {
      name: "Hello world provider test",
      fn: async (runtime) => {
        const message = {
          entityId: v4_default(),
          roomId: v4_default(),
          content: {
            text: "What can you provide?",
            source: "test"
          }
        };
        const state = {
          values: {},
          data: {},
          text: ""
        };
        try {
          if (!runtime.providers || runtime.providers.length === 0) {
            throw new Error("No providers found in runtime");
          }
          const helloWorldProvider = runtime.providers.find(
            (p) => p.name === "HELLO_WORLD_PROVIDER"
          );
          if (!helloWorldProvider) {
            throw new Error("HELLO_WORLD_PROVIDER not found in runtime providers");
          }
          const result = await helloWorldProvider.get(runtime, message, state);
          if (result.text !== "I am a provider") {
            throw new Error(`Expected provider to return "I am a provider", got "${result.text}"`);
          }
        } catch (error) {
          throw new Error(`Hello world provider test failed: ${error.message}`);
        }
      }
    },
    {
      name: "Starter service test",
      fn: async (runtime) => {
        try {
          const service = runtime.getService("starter");
          if (!service) {
            throw new Error("Starter service not found");
          }
          if (service.capabilityDescription !== "This is a starter service which is attached to the agent through the starter plugin.") {
            throw new Error("Incorrect service capability description");
          }
          await service.stop();
        } catch (error) {
          throw new Error(`Starter service test failed: ${error.message}`);
        }
      }
    }
  ];
};
var starter_plugin_test_default = new StarterTestSuite();
export {
  StarterTestSuite,
  starter_plugin_test_default as default
};
//# sourceMappingURL=starter-plugin.test.js.map