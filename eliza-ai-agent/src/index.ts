// src/index.ts

// Import the 'main' function from your agent logic file (e.g., src/agent.ts)
import { main as agentMain } from './agent'; // Import it and rename it to 'agentMain' for clarity

// Define a local function to orchestrate the start-up
async function startApplication() { // Renamed from 'main' to avoid conflict
  try {
    // Call the imported agent's main function
    await agentMain(); // Use the renamed import
    // Or if you need to pass a risk level:
    // await agentMain("low");
    console.log("Agent started successfully!");
  } catch (error) {
    console.error("AI agent failed:", error);
  }
}

// Call the new start function
startApplication();