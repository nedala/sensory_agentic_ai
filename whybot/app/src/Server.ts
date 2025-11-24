import { NextApiRequest, NextApiResponse } from "next";
import { createParser, ParsedEvent, ReconnectInterval } from "eventsource-parser";

export const config = {
  runtime: "edge",
};

const handler = async (req: NextApiRequest, res: NextApiResponse) => {
  if (req.method !== "POST") {
    return res.status(405).json({ error: "Method not allowed" });
  }

  const data = await req.body;

  const encoder = new TextEncoder();
  const decoder = new TextDecoder();

  const body = JSON.stringify({
    model: data.model.replace(/^ollama\//, ""), // Use model sent from frontend, strip 'ollama/'
    prompt: data.prompt,
    stream: true,
    options: {
      temperature: data.temperature,
      num_predict: 1024,
    },
  });

  const response = await fetch("https://api.ollama.com/v1/complete", {
    headers: {
      "Content-Type": "application/json",
      Authorization: `Bearer ${process.env.OLLAMA_API_KEY}`,
    },
    method: "POST",
    body,
  });

  if (!response.ok) {
    return res.status(response.status).json({ error: response.statusText });
  }

  const stream = new ReadableStream({
    async start(controller) {
      function onParse(event: ParsedEvent | ReconnectInterval) {
        if (event.type === "event") {
          const data = event.data;
          if (data === "[DONE]") {
            controller.close();
            return;
          }
          const queue = encoder.encode(data);
          controller.enqueue(queue);
        }
      }

      const parser = createParser(onParse);
      for await (const chunk of response.body as any) {
        parser.feed(decoder.decode(chunk));
      }
    },
  });

  return new Response(stream);
};

export default handler;