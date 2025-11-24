using OllamaAPI;
using System.IO;
using System.Text.Json;
using static OllamaAPI.Client;

namespace CustomOllamaConsoleApp
{
    class Program
    {
        static async Task Main(string[] args)
        {
            var client = new Client();
            var streamer = new ResponseImplementation(); 
            var modelUrl = "http://192.168.27.10:11434";
            var modelName = "neural-chat";
            string userInput = "USCBP's mission";
            var PromptInput = $@"You are a technical writer that must draft ~10 slides about `{userInput}`. Please create an outline of the presentation. Respond in JSON with fields of title (presentation title) and slides (list of strings).
Please use professional, respectful language. Do not output any foul or biased content.
For example, your response must look like -- 
```{{
    ""title"": ""{{ PRESENTATION TITLE }}"",
    ""slide_count"": {{ NUMBER OF SLIDES }},
    ""slides"": [
        {{
            ""slide_number"": {{ SLIDE_NUMBER }},
            ""heading"": ""{{ SLIDE HEADING }}"",
            ""content"": ""{{ SLIDE CONTENT OVERVIEW }}"",
            ""should_programming_code_be_included"": {{true|false}},
            ""recommended_visual_heading"": ""{{ OPTIONAL RELEVANT IMAGE CAPTION IN THE SLIDE }}""
        }},
        ...
    ]
}}```

Response: ```";
            var stopMarkers = new List<string>() { "```", "\n\n" };

            var result = await client.Call_LLM(modelUrl, modelName, PromptInput, stopMarkers, streamer, 60);
            Console.WriteLine(result);
            PresentationContent content = JsonSerializer.Deserialize<PresentationContent>(result);
            Console.WriteLine(content.Slides[0].Heading);
        }

        private static void Streamer_ResponseStreamed(object? sender, string e)
        {
            Console.WriteLine(e);
        }
    }
}
