using Microsoft.Office.Tools.Ribbon;
using System.Collections.Generic;
using System;
using System.Windows.Forms;
using OllamaAPI;
using System.IO;

namespace PoPilotAddin
{
    public partial class PromptRibbon
    {
        private void Ribbon1_Load(object sender, RibbonUIEventArgs e)
        {
        }

        private async void button1_Click(object sender, RibbonControlEventArgs e)
        {
            TextInputForm inputForm = new TextInputForm();
            if (inputForm.ShowDialog() == DialogResult.OK)
            {
                // User clicked OK, get the input text
                string userInput = inputForm.UserInput;
                string ollamaUrl = inputForm.OllamaURL;
                Client client = new Client();
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
                var result = await client.Call_LLM(ollamaUrl, "neural-chat", PromptInput, new List<String>() { "```", "\n\n" }, null, 120);
                try
                {
                    PresentationContent presentationContent = System.Text.Json.JsonSerializer.Deserialize<PresentationContent>(result);
                    AddSlidesToPowerPoint(presentationContent);
                }
                catch (Exception ex)
                {
                    AddSlidesToPowerPointException(ex);
                }
            }
        }

        private void AddSlidesToPowerPointException(Exception ex)
        {
            // Access PowerPoint application
            Microsoft.Office.Interop.PowerPoint.Application pptApp = Globals.ThisAddIn.Application;

            // Create a new presentation
            Microsoft.Office.Interop.PowerPoint.Presentation pptPresentation = pptApp.Presentations.Add();

            Microsoft.Office.Interop.PowerPoint.Slide pptSlide = pptPresentation.Slides.Add(1, Microsoft.Office.Interop.PowerPoint.PpSlideLayout.ppLayoutText);

            // Set slide title and content
            pptSlide.Shapes.Title.TextFrame.TextRange.Text = ex.Message;
            pptSlide.Shapes.Placeholders[2].TextFrame.TextRange.Text = ex.ToString();

            // Show PowerPoint application
            pptApp.Visible = Microsoft.Office.Core.MsoTriState.msoTrue;
        }

        private void AddSlidesToPowerPoint(PresentationContent presentationContent)
        {
            // Access PowerPoint application
            Microsoft.Office.Interop.PowerPoint.Application pptApp = Globals.ThisAddIn.Application;

            // Create a new presentation
            Microsoft.Office.Interop.PowerPoint.Presentation pptPresentation = pptApp.Presentations.Add();

            // Loop through each slide in the presentation content and add to PowerPoint
            foreach (var slide in presentationContent.Slides)
            {
                // Add a new slide
                Microsoft.Office.Interop.PowerPoint.Slide pptSlide = pptPresentation.Slides.Add(slide.SlideNumber, Microsoft.Office.Interop.PowerPoint.PpSlideLayout.ppLayoutText);

                // Set slide title and content
                pptSlide.Shapes.Title.TextFrame.TextRange.Text = slide.Heading;
                pptSlide.Shapes.Placeholders[2].TextFrame.TextRange.Text = slide.Content;
            }

            // Show PowerPoint application
            pptApp.Visible = Microsoft.Office.Core.MsoTriState.msoTrue;
        }
    }
}
