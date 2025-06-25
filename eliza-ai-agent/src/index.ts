// src/index.ts

// ====== Imports for KV and Agent Main Logic ======
// We need 'kv' for the action handler to retrieve stored strategies.
// The `kv` object is expected to have 'get' and 'set' methods.
// When running within ElizaOS, it typically provides its own KV via '@elizaos/kv'.
// When testing the plugin directly, or if ElizaOS KV isn't available, we need a fallback.
let kv: { get: (key: string) => Promise<string | null>; set: (key: string, val: string) => Promise<void> };

try {
  const elizaKv = await import("@elizaos/kv");
  kv = {
    get: elizaKv.get,
    set: elizaKv.set
  };
} catch (e) {
  console.warn(" Falling back to local KV for src/index.ts (plugin actions)");
  const fs = await import("fs/promises");
  kv = {
    get: async (key: string) => {
      try {
        return await fs.readFile(`.local-kv-${key}.json`, "utf-8");
      } catch (readError) {
        return null; // Return null if file not found or other read error
      }
    },
    set: async (key: string, val: string) => {
      await fs.writeFile(`.local-kv-${key}.json`, val, "utf-8");
    },
  };
}


// Import the 'main' function from your agent logic file (e.g., src/agent.ts)
// This `agentMain` function contains your strategy calculation and storage logic,
// including its own internal setInterval.
import { main as agentMain } from './agent';

// Define a local function to orchestrate the start-up of your agent's service logic.
// This is called once when the ElizaOS plugin initializes.
async function startApplication() {
  try {
    // Call the imported agent's main function.
    // The setInterval inside agentMain will handle periodic execution.
    await agentMain();
    console.log("Initial yield strategies calculated and stored by YieldBot agent.");
  } catch (error) {
    console.error("YieldBot agent failed during initial strategy calculation:", error);
  }
}

// Call the start-up function immediately when the plugin loads.
// This ensures your strategies are calculated and the 15-minute interval begins.
startApplication();


// ====== ElizaOS Plugin Framework Imports ======
import type { Plugin } from '@elizaos/core';
import {
  type Action,
  type Content,
  type GenerateTextParams, // Still imported, but not used in the 'models' block now
  type HandlerCallback,
  type IAgentRuntime,
  type Memory,
  ModelType, // Still imported, but not used in the 'models' block now
  type Provider,
  type ProviderResult,
  Service,
  type State,
  logger,
} from '@elizaos/core';
import { z } from 'zod'; // For schema validation

// ====== Configuration Schema (kept for example) ======
const configSchema = z.object({
  EXAMPLE_PLUGIN_VARIABLE: z
    .string()
    .min(1, 'Example plugin variable is not provided')
    .optional()
    .transform((val) => {
      if (!val) {
        console.warn('Warning: Example plugin variable is not provided');
      }
      return val;
    }),
});

// ====== New: Define the Zod schema for GET_YIELD_STRATEGY action parameters ======
const GetYieldStrategyParamsSchema = z.object({
  risk: z.enum(['low', 'high'], {
    errorMap: (issue, ctx) => {
      if (issue.code === z.ZodIssueCode.invalid_enum_value) {
        return { message: `Risk level must be 'low' or 'high'. Received: ${ctx.data}` };
      }
      return { message: ctx.defaultError };
    },
  }),
});

// ====== New: Define the GET_YIELD_STRATEGY Action Handler ======
const getYieldStrategyAction: Action = {
  name: 'GET_YIELD_STRATEGY',
  similes: ['GET_STRATEGY', 'FETCH_YIELD', 'CHECK_YIELD_OPPORTUNITIES', 'YIELD_STRATEGY_INFO'],
  description: 'Fetches the current yield optimization strategy for a given risk level (low or high).',

  validate: async (_runtime: IAgentRuntime, _message: Memory, _state: State): Promise<boolean> => {
    // This action is always valid for the LLM to call if it provides the parameters.
    return true;
  },

  handler: async (
    _runtime: IAgentRuntime,
    message: Memory,
    _state: State,
    options: any, // Options will contain the parsed parameters from the LLM
    callback: HandlerCallback,
    _responses: Memory[]
  ) => {
    try {
      logger.info('Handling GET_YIELD_STRATEGY action');

      // Validate the incoming parameters from the LLM using Zod
      const { risk } = GetYieldStrategyParamsSchema.parse(options);

      // Fetch the strategy from the KV store populated by agent.ts
      const strategyKey = `strategy:${risk}`;
      const storedStrategy = await kv.get(strategyKey);

      let responseText: string;
      if (storedStrategy) {
        const strategy = JSON.parse(storedStrategy);
        // Format the output clearly as JSON
        responseText = `Here is the current ${risk}-risk yield strategy:\n\`\`\`json\n${JSON.stringify(strategy, null, 2)}\n\`\`\``;
        logger.info(`Successfully retrieved ${risk}-risk strategy.`);
      } else {
        responseText = `I could not find a ${risk}-risk yield strategy at the moment. The data might not have been calculated yet or there was an issue. Please try again later.`;
        logger.warn(`No ${risk}-risk strategy found in KV.`);
      }

      const responseContent: Content = {
        text: responseText,
        actions: ['GET_YIELD_STRATEGY'], // Indicate which action produced this response
        source: message.content.source, // Maintain the source of the original message
      };

      await callback(responseContent); // Send the response back to the user

      return responseContent; // Return the content
    } catch (error) {
      logger.error('Error in GET_YIELD_STRATEGY action:', error);
      const errorMessage = error instanceof Error ? error.message : String(error);
      const errorContent: Content = {
        text: `An error occurred while fetching the yield strategy: ${errorMessage}. Please check the server logs for details.`,
        actions: ['GET_YIELD_STRATEGY'],
        source: message.content.source,
      };
      await callback(errorContent); // Inform the user about the error
      throw error; // Re-throw to propagate the error within ElizaOS
    }
  },

  // Add examples for the LLM to learn from (crucial for good action calling)
  examples: [
    [
      {
        name: 'user',
        content: {
          text: 'What is the low-risk strategy?',
        },
      },
      {
        name: 'YieldBot', // Make sure this matches your character's 'name' in character.json
        content: {
          // This is the XML format the LLM needs to generate
          text: '<call:GET_YIELD_STRATEGY><risk>low</risk></call:GET_YIELD_STRATEGY>',
          actions: ['GET_YIELD_STRATEGY'],
        },
      },
    ],
    [
      {
        name: 'user',
        content: {
          text: 'Tell me about the high-risk yield.',
        },
      },
      {
        name: 'YieldBot',
        content: {
          text: '<call:GET_YIELD_STRATEGY><risk>high</risk></call:GET_YIELD_STRATEGY>',
          actions: ['GET_YIELD_STRATEGY'],
        },
      },
    ],
    [
      {
        name: 'user',
        content: {
          text: 'I need a safe investment strategy.',
        },
      },
      {
        name: 'YieldBot',
        content: {
          text: '<call:GET_YIELD_STRATEGY><risk>low</risk></call:GET_YIELD_STRATEGY>',
          actions: ['GET_YIELD_STRATEGY'],
        },
      },
    ],
    [
      {
        name: 'user',
        content: {
          text: 'What are the current high return options?',
        },
      },
      {
        name: 'YieldBot',
        content: {
          text: '<call:GET_YIELD_STRATEGY><risk>high</risk></call:GET_YIELD_STRATEGY>',
          actions: ['GET_YIELD_STRATEGY'],
        },
      },
    ],
  ],
};


// ====== Example Components (Optional, can remove if not needed) ======
// Keeping these for now, as they were in your original provided plugin code.
// You can remove these if you only want the YieldBot functionality.
const helloWorldAction: Action = {
  name: 'HELLO_WORLD',
  similes: ['GREET', 'SAY_HELLO'],
  description: 'Responds with a simple hello world message',
  validate: async (_runtime: IAgentRuntime, _message: Memory, _state: State): Promise<boolean> => true,
  handler: async ( _runtime: IAgentRuntime, message: Memory, _state: State, _options: any, callback: HandlerCallback, _responses: Memory[] ) => {
    try {
      logger.info('Handling HELLO_WORLD action');
      const responseContent: Content = { text: 'hello world!', actions: ['HELLO_WORLD'], source: message.content.source, };
      await callback(responseContent);
      return responseContent;
    } catch (error) { logger.error('Error in HELLO_WORLD action:', error); throw error; }
  },
  examples: [
    [{ name: '{{name1}}', content: { text: 'Can you say hello?', }, },
     { name: '{{name2}}', content: { text: 'hello world!', actions: ['HELLO_WORLD'], }, },
    ],
  ],
};

const helloWorldProvider: Provider = {
  name: 'HELLO_WORLD_PROVIDER',
  description: 'A simple example provider',
  get: async ( _runtime: IAgentRuntime, _message: Memory, _state: State ): Promise<ProviderResult> => {
    return { text: 'I am a provider', values: {}, data: {}, };
  },
};

export class StarterService extends Service {
  static serviceType = 'starter';
  capabilityDescription = 'This is a starter service which is attached to the agent through the starter plugin.';
  constructor(runtime: IAgentRuntime) { super(runtime); }
  static async start(runtime: IAgentRuntime) {
    logger.info('*** Starting starter service ***');
    const service = new StarterService(runtime);
    return service;
  }
  static async stop(runtime: IAgentRuntime) {
    logger.info('*** Stopping starter service ***');
    const service = runtime.getService(StarterService.serviceType);
    if (!service) { throw new Error('Starter service not found'); }
    service.stop();
  }
  async stop() { logger.info('*** Stopping starter service instance ***'); }
}


// ====== ElizaOS Plugin Definition ======
const plugin: Plugin = {
  name: 'yield-bot-plugin', // Giving your plugin a more specific name
  description: 'Plugin for the YieldBot agent, managing yield strategy calculations and fetching.',
  // Set a default priority. Adjust if you have other plugins that might conflict.
  priority: 0,
  config: {
    EXAMPLE_PLUGIN_VARIABLE: process.env.EXAMPLE_PLUGIN_VARIABLE,
  },
  async init(config: Record<string, string>) {
    logger.info('*** Initializing YieldBot plugin ***');
    try {
      const validatedConfig = await configSchema.parseAsync(config);
      for (const [key, value] of Object.entries(validatedConfig)) {
        if (value) process.env[key] = value;
      }
    } catch (error) {
      if (error instanceof z.ZodError) {
        throw new Error(
          `Invalid plugin configuration: ${error.errors.map((e) => e.message).join(', ')}`
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
      name: 'helloworld',
      path: '/helloworld',
      type: 'GET',
      handler: async (_req: any, res: any) => {
        res.json({ message: 'Hello World from YieldBot Plugin!', });
      },
    },
  ],
  events: {
    MESSAGE_RECEIVED: [
      async (params) => {
        logger.info('YieldBot Plugin: MESSAGE_RECEIVED event received');
        logger.debug(Object.keys(params)); // Use debug for less critical logs
      },
    ],
    // You can keep or remove other event handlers as needed
  },
  services: [StarterService], // If you don't need StarterService, you can remove it.
  actions: [helloWorldAction, getYieldStrategyAction], // IMPORTANT: Added your new action here!
  providers: [helloWorldProvider], // If you don't need helloWorldProvider, you can remove it.
};

export default plugin;