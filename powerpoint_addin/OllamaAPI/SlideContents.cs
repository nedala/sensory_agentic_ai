using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace OllamaAPI
{
    using System.Collections.Generic;
    using System.Text.Json.Serialization;

    public class PresentationContent
    {
        [JsonPropertyName("title")]
        public string Title { get; set; }

        [JsonPropertyName("slide_count")]
        public int SlideCount => Slides?.Count ?? 0;

        [JsonPropertyName("slides")]
        public List<SlideContent> Slides { get; set; }
    }

    public class SlideContent
    {
        [JsonPropertyName("slide_number")]
        public int SlideNumber { get; set; }

        [JsonPropertyName("heading")]
        public string Heading { get; set; }

        [JsonPropertyName("content")]
        public string Content { get; set; }

        [JsonPropertyName("should_programming_code_be_included")]
        public bool ShouldProgrammingCodeBeIncluded { get; set; }

        [JsonPropertyName("recommended_visual_heading")]
        public string RecommendedVisualHeading { get; set; }
    }
}
