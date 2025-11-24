console.log("SERVER STARTED");
import express, { Request, Response } from "express";
import { rateLimit, MemoryStore } from "express-rate-limit";
import { Configuration, OpenAIApi } from "openai";
import WebSocket from "ws";
import cors from "cors";
import { config } from "dotenv";
import fs from "fs";
import path from "path";

import { PrismaClient } from '@prisma/client';

config();

console.log(process.env.FIREBASE_PRIVATE_KEY, process.env.OPENAI_API_KEY);

const prisma = new PrismaClient();

const store = new MemoryStore();

const PROMPT_LIMITS = {
  "openai/gpt3.5": 5,
  "openai/gpt4": 0,
};
const PORT = process.env.PORT || 6823;

function rateLimiterKey(model: string, fingerprint: string) {
  return model + "/" + fingerprint;
}

const rateLimiters = {
  "openai/gpt3.5": rateLimit({
    windowMs: 24 * 60 * 60 * 1000, // 24 hours in milliseconds
    max: PROMPT_LIMITS["openai/gpt3.5"],
    message: "You have exceeded the 5 requests in 24 hours limit!", // message to send when a user has exceeded the limit
    keyGenerator: (req) => {
      return rateLimiterKey(req.query.model as string, req.query.fp as string);
    },
    store,
    legacyHeaders: false,
    standardHeaders: true,
  }),
  "openai/gpt4": rateLimit({
    windowMs: 24 * 60 * 60 * 1000, // 24 hours in milliseconds
    max: PROMPT_LIMITS["openai/gpt4"],
    message: "You have exceeded the 1 request per day limit!", // message to send when a user has exceeded the limit
    keyGenerator: (req) => {
      return req.query.fp + "";
    },
    store: store,
    legacyHeaders: false,
    standardHeaders: true,
  }),
};

const configuration = new Configuration({
  apiKey: process.env.OPENAI_API_KEY,
});
const openai = new OpenAIApi(configuration);

const app = express();
app.use(cors());

const OLLAMA_HOST = process.env.OLLAMA_HOST || "http://192.168.27.10:11434";
const OLLAMA_MODEL = process.env.OLLAMA_MODEL || "deepseek-r1:8b";

// Serve static files from the Vite build output
if (process.env.NODE_ENV === 'production') {
  app.use(express.static(path.join(__dirname, "../app/dist")));
  app.get(/^\/(?!api).*/, (req, res) => {
    res.sendFile(path.join(__dirname, "../app/dist/index.html"));
  });
}

// Create a WebSocket server
const wss = new WebSocket.Server({ noServer: true });

// Listen for WebSocket connections
wss.on("connection", (ws) => {
  // Handle incoming messages from the client
  ws.on("message", async (message) => {
    console.log("[WS MESSAGE RECEIVED]", message.toString());
    try {
      // Parse the message from the client
      const data = JSON.parse(message.toString());
      if (data.model && data.model.startsWith("ollama/")) {
        const ollamaPayload = {
          model: data.model.replace(/^ollama\//, ""), // Use model sent from frontend, strip 'ollama/'
          messages: [
            { role: "system", content: "You are a helpful assistant. Non-JSON answers should be short, with a _max_ of 300 words." },
            { role: "user", content: data.prompt },
          ],
          stream: true,
          options: { temperature: data.temperature, num_predict: 2048 },
        };
        console.log("[OLLAMA REQUEST]", JSON.stringify(ollamaPayload, null, 2));
        const response = await fetch(`${OLLAMA_HOST}/api/chat`, {
          method: "POST",
          headers: { "Content-Type": "application/json" },
          body: JSON.stringify(ollamaPayload),
        });
        console.log("[OLLAMA RESPONSE STATUS]", response.status);
        if (!response.ok) {
          const errorText = await response.text();
          console.error("[OLLAMA ERROR BODY]", errorText);
          ws.send(`[OLLAMA ERROR] ${response.status}: ${errorText}`);
          return;
        }
        if (!response.body) throw new Error("No response body from Ollama");
        const reader = response.body.getReader();
        let done = false;
        while (!done) {
          const { value, done: readerDone } = await reader.read();
          if (value) {
            const lines = Buffer.from(value).toString().split('\n').filter(line => line.trim() !== '');
            for (const line of lines) {
              try {
                const payload = JSON.parse(line);
                if (payload.message && payload.message.content) {
                  // Remove <think>...</think> from each chunk
                  const filtered = payload.message.content.replace(/<think>[\s\S]*?<\/think>/g, '');
                  if (filtered.trim()) {
                    ws.send(filtered);
                  }
                }
                if (payload.done) {
                  done = true;
                  ws.send('[DONE]');
                  break;
                }
              } catch (error) {
                console.error('Could not JSON parse Ollama stream message', line, error);
              }
            }
          }
          done = done || readerDone;
        }
        return;
      }

      try {
        const documentRef = await prisma.completion.create({
          data: { ...data, createdAt: new Date() },
        });
        console.log("Document added with ID:", documentRef.id);
      } catch (error) {
        console.error("Error while adding document:", error);
      }

      console.log("data", data);

    } catch (error) {
      // Handle any errors that occur during the API call
      // console.error("Error:", error);
      ws.send(error + "");
    }
  });
});

// Upgrade HTTP connections to WebSocket connections
app.use("/ws", (req, res, next) => {
  wss.handleUpgrade(req, req.socket, Buffer.alloc(0), (ws) => {
    wss.emit("connection", ws, req);
  });
});

app.get("/api/completion", async (req: Request, res: Response) => {
  const prompt = req.query.prompt as string;
  const model = req.query.model as string | undefined;
  const persona = req.query.persona as string | undefined;
  // Normalize the prompt for cache lookup
  const normalizedRoot = prompt?.toLowerCase().replace(/[^a-z0-9]+/g, "");
  if (normalizedRoot) {
    try {
      const cached = await prisma.example.findFirst({
        where: { normalizedRoot },
      });
      if (cached) {
        return res.json({
          cached: true,
          persona: cached.persona,
          model: cached.model,
          tree: cached.tree,
          rootQuestion: cached.rootQuestion,
        });
      }
    } catch (err) {
      console.error("Error checking cache:", err);
    }
  }
  // ...existing code for LLM/OpenAI...
  res.json({ receivedPrompt: prompt });
});

app.get("/api/prompts-remaining", (req: Request, res: Response) => {
  const key = rateLimiterKey(req.query.model as string, req.query.fp as string);
  console.log("KEY", key);

  const remaining = Math.max(
    (PROMPT_LIMITS[req.query.model as keyof typeof PROMPT_LIMITS] ?? 5) -
      (store.hits[key] ?? 0),
    0
  );

  res.json({
    remaining: remaining,
  });
});

app.get("/api/moar-prompts", (req: Request, res: Response) => {
  const key = rateLimiterKey(req.query.model as string, req.query.fp as string);
  store.hits[key] = (store.hits[key] ?? 0) - 3;
  console.log("Got moar prompts for", req.query.fp);
  res.json({
    message: "Decremented",
  });
});

app.get("/api/use-prompt", (req: Request, res: Response) => {
  const key = rateLimiterKey(req.query.model as string, req.query.fp as string);
  store.increment(key);
  res.json({
    message: `Used a token: ${key}`,
  });
});

app.get("/api/examples", async (req: Request, res: Response) => {
  try {
    // Fetch the latest 10 examples in reverse chronological order
    const examples = await prisma.example.findMany({
      orderBy: { createdAt: "desc" },
      take: 10,
    });
    res.json(
      examples.map((e: any) => ({
        persona: e.persona,
        model: e.model,
        tree: e.tree,
        rootQuestion: e.rootQuestion,
        createdAt: e.createdAt,
      }))
    );
  } catch (err) {
    console.error("Error fetching examples from database:", err);
    res.status(500).json({ error: "Failed to fetch examples from database." });
  }
});

// Add endpoint to save research example for caching and deduplication
app.post('/api/save-example', express.json(), async (req: Request, res: Response) => {
  try {
    const { persona, model, tree } = req.body;
    if (!tree || !tree['0'] || !tree['0'].question) {
      return res.status(400).json({ error: 'Missing root question in tree.' });
    }
    const rootQuestion = tree['0'].question;
    // Normalize: lowercase, remove non-alphanumeric
    const normalizedRoot = rootQuestion.toLowerCase().replace(/[^a-z0-9]+/g, '');
    // DISABLE SAVING FOR NOW: WE DO NOT WANT ROGUES TO ABUSE AND PERSIST BAD EXAMPLES
    // Upsert: overwrite if exists, else create new
    // await prisma.example.upsert({
    //   where: { normalizedRoot },
    //   update: {
    //     persona,
    //     model,
    //     tree,
    //     rootQuestion,
    //   },
    //   create: {
    //     persona,
    //     model,
    //     tree,
    //     rootQuestion,
    //     normalizedRoot,
    //   },
    // });
    res.status(201).json({ message: 'Example saved (created or updated).' });
  } catch (err) {
    console.error('Error saving example:', err);
    res.status(500).json({ error: 'Failed to save example.' });
  }
});

// Start the server
app.listen(PORT, () => {
  console.log(`Server is running on port ${PORT}`);
});
