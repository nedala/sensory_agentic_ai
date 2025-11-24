import streamlit as st
import streamlit_antd_components as sac
from llama_index.llms.ollama import Ollama
from llama_index.core.llms import ChatMessage
from llama_index.core.bridge.pydantic import BaseModel
import os

# ---------- Pydantic Schemas ----------

class TranslationRequest(BaseModel):
    text: str
    source_language: str  # e.g. "English" or "Auto"
    target_language: str  # e.g. "Spanish"

class TranslationResponse(BaseModel):
    translated_text: str          # final translation only
    detected_language: str        # human-readable language name (e.g. "Hindi", "Japanese")

# ---------- Streamlit UI ----------

st.set_page_config(page_title="Ollama Translation Assistant", layout="wide", initial_sidebar_state="collapsed")
st.markdown("<h1 style='text-align: center;'>Ollama Translation Assistant</h1>", unsafe_allow_html=True)

btns = sac.segmented(
    [sac.SegmentedItem(label=idx) for idx in ['English', 'Global']],
    align='center'
)

# ---------- LLM Setup ----------

MODEL_NAME = os.environ.get("MODEL_NAME", "qwen2.5vl:7b")
BASE_URL = os.environ.get("BASE_URL", "http://localhost:11434")

llm = Ollama(
    model=MODEL_NAME,
    base_url=BASE_URL,
    request_timeout=30.0,
    context_window=2048,
    temperature=0.0
)

# Strong system prompt for structured translation
SYSTEM_MESSAGE = ChatMessage(
    role="system",
    content=(
        "You are a professional language translation engine.\n\n"
        f"You MUST always respond using the {TranslationResponse.schema()} schema:\n"
        "- translated_text: the input text translated into the requested target language, "
        "  written in fluent, natural, and contextually accurate language.\n"
        "- detected_language: your best guess of the source text's language as a human-readable name "
        "  (e.g. 'English', 'Hindi', 'Japanese').\n\n"
        "Guidelines:\n"
        "- Preserve the original meaning, tone, and register (formal/informal) as much as possible.\n"
        "- Use idiomatic expressions in the target language instead of literal word-by-word translations.\n"
        "- Do NOT include explanations, notes, or any text outside the TranslationResponse fields.\n"
        "- Do NOT wrap the translation in quotes.\n"
        "- It is important to NOT just do literal translations, but to make the text sound natural and correct to the target language in meaning, emotion, and form. For instance, `वंदे मातरम्!` should be translated to `Salutations to the Motherland!` in English, rather than a word-for-word translation like `Vande Mataram`.\n"
    )
)

# Convert to structured LLM that outputs TranslationResponse
sllm = llm.as_structured_llm(TranslationResponse)

# ---------- Helper to call structured LLM ----------

def call_translation_llm(request: TranslationRequest) -> TranslationResponse:
    """
    Call the structured LLM with a TranslationRequest and get a TranslationResponse.
    """
    # The user message is intentionally simple and machine-readable for reliability
    user_message = ChatMessage(
        role="user",
        content=(
            f"Source language: {request.source_language}\n"
            f"Target language: {request.target_language}\n"
            f"Text:\n{request.text}"
        )
    )

    # sllm.chat will return a TranslationResponse instance
    response: TranslationResponse = sllm.chat(
        messages=[SYSTEM_MESSAGE, user_message]
    )
    return response.raw

# ---------- UI Logic ----------

if btns == 'English':
    # English -> Global
    form1 = st.form(key="english_to_global")
    with form1:
        language = st.selectbox(
            label="Select Language",
            options=[
                "Mandarin Chinese", "Hindi", "Spanish", "French", "Standard Arabic",
                "Bengali", "Russian", "Portuguese", "Indonesian", "Urdu",
                "German", "Japanese", "Swahili", "Marathi", "Telugu", "Kannada",
                "Italian", "Dutch", "Greek", "Polish", "Ukrainian",
                "Turkish", "Tamil", "Vietnamese", "Korean"
            ],
            index=2,
        )
        text = st.text_area(
            "Enter text to translate",
            """MLK: I have a dream that one day this nation will rise up and live out the true meaning of its creed.""",
            height=200,
            max_chars=4096,
        )
        submit = st.columns(7)[3].form_submit_button("Translate")

    if submit:
        with st.spinner("Translating..."):
            request = TranslationRequest(
                text=text,
                source_language="English",
                target_language=language
            )
            response = call_translation_llm(request)

        # Use structured fields, not response.message.content
        st.subheader("Translation")
        st.code(response.translated_text, language="text")

        st.caption(f"Detected source language: {response.detected_language}")

elif btns == 'Global':
    # Global -> English
    form2 = st.form(key="global_to_english")
    with form2:
        text = st.text_area(
            "Enter text to translate to English",
            """
वन्दे मातरम्।
सुजलाम् सुफलाम्
मलयजशीतलाम्
शस्यश्यामलाम् मातरम्।
वन्दे मातरम्।

शुभ्रज्योत्स्नाम्
पुलकितयामिनीम्
फुल्लकुसुमित
द्रुमदलशोभिनीम्
सुहासिनीम्
सुमधुर भाषिणीम्
सुखदाम् वरदाम्
मातरम्॥
वन्दे मातरम्।""".strip(),
            height=400,
            max_chars=4096,
        )
        submit = st.columns(7)[3].form_submit_button("Translate")

    if submit:
        with st.spinner("Translating..."):
            request = TranslationRequest(
                text=text,
                source_language="Auto",
                target_language="English"
            )
            response = call_translation_llm(request)

        st.subheader("Translation")
        st.code(response.translated_text, language="text")

        st.caption(f"Detected source language: {response.detected_language}")
