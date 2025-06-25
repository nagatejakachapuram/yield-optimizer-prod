// src/agent.ts
import axios from "axios";
var kv;
try {
  const elizaKv = await import("@elizaos/kv");
  kv = {
    set: elizaKv.set,
    get: elizaKv.get
    // Ensure 'get' is also assigned if available from ElizaOS KV
  };
} catch (e) {
  console.warn(" Falling back to local KV for agent.ts");
  const fs = await import("fs/promises");
  kv = {
    set: async (key, val) => {
      await fs.writeFile(`.local-kv-${key}.json`, val, "utf-8");
    },
    get: async (key) => {
      try {
        return await fs.readFile(`.local-kv-${key}.json`, "utf-8");
      } catch (readError) {
        return null;
      }
    }
  };
}
var DEFILLAMA_API = process.env.DEFILLAMA_API || "https://yields.llama.fi";
var COINGECKO_API = process.env.COINGECKO_API || "https://api.coingecko.com/api/v3";
var USDC_CG_ID = "usd-coin";
var DAYS_LOOKBACK = 25;
async function isDowntrend(assetId) {
  const url = `${COINGECKO_API}/coins/${assetId}/market_chart?vs_currency=usd&days=${DAYS_LOOKBACK}`;
  const res = await axios.get(url);
  const prices = res.data.prices.map((p) => p[1]);
  if (prices.length < 8) throw new Error("Not enough price history for trend detection");
  const current = prices[prices.length - 1];
  const day7 = prices[prices.length - 8];
  const day25 = prices[0];
  return current < day7 && current < day25;
}
async function getDefiLlamaYields() {
  const res = await axios.get(`${DEFILLAMA_API}/pools`);
  return res.data.data;
}
async function getBestLowRiskPool() {
  const yields = await getDefiLlamaYields();
  return yields.filter(
    (y) => y.project?.toLowerCase().includes("aave") && y.apyBase && y.symbol?.toLowerCase() === "usdc"
  ).map((y) => ({
    address: y.pool,
    apy: y.apyBase,
    apyBps: Math.round(y.apyBase * 1e4),
    platform: "Aave",
    asset: y.symbol
  })).sort((a, b) => b.apy - a.apy)[0] || null;
}
async function getBestHighRiskPool() {
  const yields = await getDefiLlamaYields();
  return yields.filter(
    (y) => y.project?.toLowerCase().includes("morpho") && y.apyBase && y.symbol?.toLowerCase() === "usdc"
  ).map((y) => ({
    address: y.pool,
    apy: y.apyBase,
    apyBps: Math.round(y.apyBase * 1e4),
    platform: "Morpho",
    asset: y.symbol
  })).sort((a, b) => b.apy - a.apy)[0] || null;
}
async function runForRisk(risk) {
  try {
    const downtrend = await isDowntrend(USDC_CG_ID);
    const trend = downtrend ? "downtrend" : "uptrend";
    const bestPool = risk === "low" ? await getBestLowRiskPool() : await getBestHighRiskPool();
    if (!bestPool) {
      console.warn(` No ${risk}-risk pool found.`);
      return;
    }
    const result = {
      timestamp: Date.now(),
      trend,
      risk,
      selectedPool: bestPool
    };
    await kv.set(`strategy:${risk}`, JSON.stringify(result));
    console.log(` Stored ${risk}-risk strategy:`, result);
  } catch (err) {
    console.error(` Failed to process ${risk} strategy:`, err);
  }
}
async function main() {
  await runForRisk("low");
  await runForRisk("high");
}
if (import.meta.url === `file://${process.argv[1]}`) {
  const INTERVAL_MS = 15 * 60 * 1e3;
  console.log(" Eliza strategy agent started (15 min interval)");
  await main();
  setInterval(() => {
    main().catch((err) => console.error("Agent error:", err));
  }, INTERVAL_MS);
}

// src/index.ts
import {
  Service,
  logger
} from "@elizaos/core";
import { z } from "zod";
var kv2;
try {
  const elizaKv = await import("@elizaos/kv");
  kv2 = {
    get: elizaKv.get,
    set: elizaKv.set
  };
} catch (e) {
  console.warn(" Falling back to local KV for src/index.ts (plugin actions)");
  const fs = await import("fs/promises");
  kv2 = {
    get: async (key) => {
      try {
        return await fs.readFile(`.local-kv-${key}.json`, "utf-8");
      } catch (readError) {
        return null;
      }
    },
    set: async (key, val) => {
      await fs.writeFile(`.local-kv-${key}.json`, val, "utf-8");
    }
  };
}
async function startApplication() {
  try {
    await main();
    console.log("Initial yield strategies calculated and stored by YieldBot agent.");
  } catch (error) {
    console.error("YieldBot agent failed during initial strategy calculation:", error);
  }
}
startApplication();
var configSchema = z.object({
  EXAMPLE_PLUGIN_VARIABLE: z.string().min(1, "Example plugin variable is not provided").optional().transform((val) => {
    if (!val) {
      console.warn("Warning: Example plugin variable is not provided");
    }
    return val;
  })
});
var GetYieldStrategyParamsSchema = z.object({
  risk: z.enum(["low", "high"], {
    errorMap: (issue, ctx) => {
      if (issue.code === z.ZodIssueCode.invalid_enum_value) {
        return { message: `Risk level must be 'low' or 'high'. Received: ${ctx.data}` };
      }
      return { message: ctx.defaultError };
    }
  })
});
var getYieldStrategyAction = {
  name: "GET_YIELD_STRATEGY",
  similes: ["GET_STRATEGY", "FETCH_YIELD", "CHECK_YIELD_OPPORTUNITIES", "YIELD_STRATEGY_INFO"],
  description: "Fetches the current yield optimization strategy for a given risk level (low or high).",
  validate: async (_runtime, _message, _state) => {
    return true;
  },
  handler: async (_runtime, message, _state, options, callback, _responses) => {
    try {
      logger.info("Handling GET_YIELD_STRATEGY action");
      const { risk } = GetYieldStrategyParamsSchema.parse(options);
      const strategyKey = `strategy:${risk}`;
      const storedStrategy = await kv2.get(strategyKey);
      let responseText;
      if (storedStrategy) {
        const strategy = JSON.parse(storedStrategy);
        responseText = `Here is the current ${risk}-risk yield strategy:
\`\`\`json
${JSON.stringify(strategy, null, 2)}
\`\`\``;
        logger.info(`Successfully retrieved ${risk}-risk strategy.`);
      } else {
        responseText = `I could not find a ${risk}-risk yield strategy at the moment. The data might not have been calculated yet or there was an issue. Please try again later.`;
        logger.warn(`No ${risk}-risk strategy found in KV.`);
      }
      const responseContent = {
        text: responseText,
        actions: ["GET_YIELD_STRATEGY"],
        // Indicate which action produced this response
        source: message.content.source
        // Maintain the source of the original message
      };
      await callback(responseContent);
      return responseContent;
    } catch (error) {
      logger.error("Error in GET_YIELD_STRATEGY action:", error);
      const errorMessage = error instanceof Error ? error.message : String(error);
      const errorContent = {
        text: `An error occurred while fetching the yield strategy: ${errorMessage}. Please check the server logs for details.`,
        actions: ["GET_YIELD_STRATEGY"],
        source: message.content.source
      };
      await callback(errorContent);
      throw error;
    }
  },
  // Add examples for the LLM to learn from (crucial for good action calling)
  examples: [
    [
      {
        name: "user",
        content: {
          text: "What is the low-risk strategy?"
        }
      },
      {
        name: "YieldBot",
        // Make sure this matches your character's 'name' in character.json
        content: {
          // This is the XML format the LLM needs to generate
          text: "<call:GET_YIELD_STRATEGY><risk>low</risk></call:GET_YIELD_STRATEGY>",
          actions: ["GET_YIELD_STRATEGY"]
        }
      }
    ],
    [
      {
        name: "user",
        content: {
          text: "Tell me about the high-risk yield."
        }
      },
      {
        name: "YieldBot",
        content: {
          text: "<call:GET_YIELD_STRATEGY><risk>high</risk></call:GET_YIELD_STRATEGY>",
          actions: ["GET_YIELD_STRATEGY"]
        }
      }
    ],
    [
      {
        name: "user",
        content: {
          text: "I need a safe investment strategy."
        }
      },
      {
        name: "YieldBot",
        content: {
          text: "<call:GET_YIELD_STRATEGY><risk>low</risk></call:GET_YIELD_STRATEGY>",
          actions: ["GET_YIELD_STRATEGY"]
        }
      }
    ],
    [
      {
        name: "user",
        content: {
          text: "What are the current high return options?"
        }
      },
      {
        name: "YieldBot",
        content: {
          text: "<call:GET_YIELD_STRATEGY><risk>high</risk></call:GET_YIELD_STRATEGY>",
          actions: ["GET_YIELD_STRATEGY"]
        }
      }
    ]
  ]
};
var helloWorldAction = {
  name: "HELLO_WORLD",
  similes: ["GREET", "SAY_HELLO"],
  description: "Responds with a simple hello world message",
  validate: async (_runtime, _message, _state) => true,
  handler: async (_runtime, message, _state, _options, callback, _responses) => {
    try {
      logger.info("Handling HELLO_WORLD action");
      const responseContent = { text: "hello world!", actions: ["HELLO_WORLD"], source: message.content.source };
      await callback(responseContent);
      return responseContent;
    } catch (error) {
      logger.error("Error in HELLO_WORLD action:", error);
      throw error;
    }
  },
  examples: [
    [
      { name: "{{name1}}", content: { text: "Can you say hello?" } },
      { name: "{{name2}}", content: { text: "hello world!", actions: ["HELLO_WORLD"] } }
    ]
  ]
};
var helloWorldProvider = {
  name: "HELLO_WORLD_PROVIDER",
  description: "A simple example provider",
  get: async (_runtime, _message, _state) => {
    return { text: "I am a provider", values: {}, data: {} };
  }
};
var StarterService = class _StarterService extends Service {
  static serviceType = "starter";
  capabilityDescription = "This is a starter service which is attached to the agent through the starter plugin.";
  constructor(runtime) {
    super(runtime);
  }
  static async start(runtime) {
    logger.info("*** Starting starter service ***");
    const service = new _StarterService(runtime);
    return service;
  }
  static async stop(runtime) {
    logger.info("*** Stopping starter service ***");
    const service = runtime.getService(_StarterService.serviceType);
    if (!service) {
      throw new Error("Starter service not found");
    }
    service.stop();
  }
  async stop() {
    logger.info("*** Stopping starter service instance ***");
  }
};
var plugin = {
  name: "yield-bot-plugin",
  // Giving your plugin a more specific name
  description: "Plugin for the YieldBot agent, managing yield strategy calculations and fetching.",
  // Set a default priority. Adjust if you have other plugins that might conflict.
  priority: 0,
  config: {
    EXAMPLE_PLUGIN_VARIABLE: process.env.EXAMPLE_PLUGIN_VARIABLE
  },
  async init(config) {
    logger.info("*** Initializing YieldBot plugin ***");
    try {
      const validatedConfig = await configSchema.parseAsync(config);
      for (const [key, value] of Object.entries(validatedConfig)) {
        if (value) process.env[key] = value;
      }
    } catch (error) {
      if (error instanceof z.ZodError) {
        throw new Error(
          `Invalid plugin configuration: ${error.errors.map((e) => e.message).join(", ")}`
        );
      }
      throw error;
    }
  },
  // IMPORTANT: REMOVED THE `models` BLOCK HERE.
  // This allows ElizaOS to use the modelProvider specified in your character.json
  // (e.g., local-ai or openai) instead of hardcoding responses.
  routes: [
    {
      name: "helloworld",
      path: "/helloworld",
      type: "GET",
      handler: async (_req, res) => {
        res.json({ message: "Hello World from YieldBot Plugin!" });
      }
    }
  ],
  events: {
    MESSAGE_RECEIVED: [
      async (params) => {
        logger.info("YieldBot Plugin: MESSAGE_RECEIVED event received");
        logger.debug(Object.keys(params));
      }
    ]
    // You can keep or remove other event handlers as needed
  },
  services: [StarterService],
  // If you don't need StarterService, you can remove it.
  actions: [helloWorldAction, getYieldStrategyAction],
  // IMPORTANT: Added your new action here!
  providers: [helloWorldProvider]
  // If you don't need helloWorldProvider, you can remove it.
};
var index_default = plugin;
export {
  StarterService,
  index_default as default
};
//# sourceMappingURL=index.js.map