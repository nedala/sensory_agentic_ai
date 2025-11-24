using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Net.Http;
using System.Text;
using System.Text.Json;
using System.Text.Json.Serialization;
using System.Threading;
using System.Threading.Tasks;

namespace OllamaAPI
{
    public interface IResponseStreamer<T>
    {
        void Stream(T stream);
    }

    public class ConversationContext
    {
        public long[] Context { get; }

        public ConversationContext(long[] context)
        {
            Context = context.ToArray(); // Defensive copying to ensure immutability
        }

        // Override Equals and GetHashCode for value equality
        public override bool Equals(object obj)
        {
            if (obj == null || GetType() != obj.GetType())
                return false;

            ConversationContext other = (ConversationContext)obj;
            return Context.SequenceEqual(other.Context);
        }

        public override int GetHashCode()
        {
            unchecked // Overflow is fine, just wrap
            {
                int hash = 17;
                foreach (var item in Context)
                    hash = hash * 23 + item.GetHashCode();
                return hash;
            }
        }
    }

    public class GenerateCompletionRequest
    {
        [JsonPropertyName("model")]
        public string Model { get; set; }

        [JsonPropertyName("prompt")]
        public string Prompt { get; set; }

        [JsonPropertyName("stream")]
        public bool Stream { get; set; } = true;

        [JsonPropertyName("raw")]
        public bool Raw { get; set; }

        [JsonPropertyName("options")]
        public OptionsRequest Options { get; set; }
    }

    public class OptionsRequest
    {
        [JsonPropertyName("seed")]
        public int seed { get; set; } = 42;

        [JsonPropertyName("temperature")]
        public double temperature { get; set; } = 0.01;

        [JsonPropertyName("repeat_penalty")]
        public double repeat_penalty { get; set; } = 1.2;

        [JsonPropertyName("stop")]
        public List<String> stop { get; set; } = new List<string>() { "```", "\n\n" };
    }

    public class GenerateCompletionResponseStream
    {
        [JsonPropertyName("model")]
        public string Model { get; set; }

        [JsonPropertyName("created_at")]
        public string CreatedAt { get; set; }

        [JsonPropertyName("response")]
        public string Response { get; set; }

        [JsonPropertyName("done")]
        public bool Done { get; set; }
    }

    public class GenerateCompletionDoneResponseStream : GenerateCompletionResponseStream
    {
        [JsonPropertyName("context")]
        public long[] Context { get; set; }

        [JsonPropertyName("total_duration")]
        public long TotalDuration { get; set; }

        [JsonPropertyName("load_duration")]
        public long LoadDuration { get; set; }

        [JsonPropertyName("prompt_eval_count")]
        public int PromptEvalCount { get; set; }

        [JsonPropertyName("prompt_eval_duration")]
        public long PromptEvalDuration { get; set; }

        [JsonPropertyName("eval_count")]
        public int EvalCount { get; set; }

        [JsonPropertyName("eval_duration")]
        public long EvalDuration { get; set; }
    }

    public class Client
    {
        private readonly HttpClient _client;

        public Client()
        {
            _client = new HttpClient();
        }

        public async Task<ConversationContext> StreamCompletion(GenerateCompletionRequest request, IResponseStreamer<GenerateCompletionResponseStream> streamer, int timeoutInSeconds, CancellationToken cancellationToken = default)
        {
            var cts = new CancellationTokenSource(TimeSpan.FromSeconds(timeoutInSeconds));
            return await GenerateCompletion(request, streamer, cts.Token);
        }

        private async Task<ConversationContext> GenerateCompletion(GenerateCompletionRequest generateRequest, IResponseStreamer<GenerateCompletionResponseStream> streamer, CancellationToken cancellationToken)
        {
            var request = new HttpRequestMessage(HttpMethod.Post, "/api/generate")
            {
                Content = new StringContent(JsonSerializer.Serialize(generateRequest), Encoding.UTF8, "application/json")
            };

            var completion = generateRequest.Stream ? HttpCompletionOption.ResponseHeadersRead : HttpCompletionOption.ResponseContentRead;

            var response = await _client.SendAsync(request, completion, cancellationToken);
            response.EnsureSuccessStatusCode();

            return await ProcessStreamedCompletionResponseAsync(response, streamer, cancellationToken);
        }

        private async Task<Stream> ReadAsStreamAsyncWithCancellation(HttpContent content, CancellationToken cancellationToken)
        {
            var stream = await content.ReadAsStreamAsync();
            cancellationToken.Register(() => stream.Dispose());
            return stream;
        }

        private async Task<ConversationContext> ProcessStreamedCompletionResponseAsync(HttpResponseMessage response, IResponseStreamer<GenerateCompletionResponseStream> streamer, CancellationToken cancellationToken)
        {
            var stream = await ReadAsStreamAsyncWithCancellation(response.Content, cancellationToken);
            var reader = new StreamReader(stream);

            while (!reader.EndOfStream && !cancellationToken.IsCancellationRequested)
            {
                string line = await reader.ReadLineAsync();
                var streamedResponse = JsonSerializer.Deserialize<GenerateCompletionResponseStream>(line);
                streamer.Stream(streamedResponse);

                if (streamedResponse?.Done ?? false)
                {
                    var doneResponse = JsonSerializer.Deserialize<GenerateCompletionDoneResponseStream>(line);
                    return new ConversationContext(Array.Empty<long>());
                }
            }

            return new ConversationContext(Array.Empty<long>());
        }

        public class ResponseImplementation : OllamaAPI.IResponseStreamer<OllamaAPI.GenerateCompletionResponseStream>
        {
            // StringBuilder to accumulate output
            private readonly StringBuilder stringBuilder = new StringBuilder();

            // Event handler to notify subscribers when a new response is streamed
            public event EventHandler<string> ResponseStreamed;

            public void Stream(OllamaAPI.GenerateCompletionResponseStream stream)
            {
                // Append the streamed response to the StringBuilder
                stringBuilder.Append(stream.Response);

                // Raise the event to notify subscribers
                OnResponseStreamed(stream.Response);
            }

            // Method to raise the ResponseStreamed event
            protected virtual void OnResponseStreamed(string response)
            {
                ResponseStreamed?.Invoke(this, response);
            }

            // Property to get the accumulated output
            public string AccumulatedOutput => stringBuilder.ToString();
        }

        public async Task<String> Call_LLM(string baseurl, string model_name, string prompt, List<String> stop, ResponseImplementation istreamer, int timeout = 120)
        {
            // Create an instance of HttpClient
            _client.BaseAddress = new Uri(baseurl);

            var streamer = istreamer ?? new ResponseImplementation();
            try
            {

                var request = new OllamaAPI.GenerateCompletionRequest
                {
                    Model = model_name,
                    Prompt = prompt,
                    Stream = true,
                    Raw = false,
                    Options = new OllamaAPI.OptionsRequest { stop = stop }
                };

                // Create a response streamer implementation
                // You need to implement the IResponseStreamer interface to handle the streamed response


                // Create a CancellationToken if needed
                var cancellationToken = new System.Threading.CancellationToken();

                // Call the StreamCompletion method
                var conversationContext = await this.StreamCompletion(request, streamer, timeout, cancellationToken);
            } catch (Exception ex)
            {
                return streamer.AccumulatedOutput;
            }

            // Use the conversationContext if needed
            return streamer.AccumulatedOutput;
        }
    }
}
