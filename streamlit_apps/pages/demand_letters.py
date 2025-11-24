import streamlit as st
import pymupdf as fitz
import os
import uuid
import json
import pandas as pd

from llama_index.llms.ollama import Ollama
from llama_index.core.llms import (
    ChatMessage,
    TextBlock,
    ImageBlock,
    MessageRole,
)
from llama_index.core.bridge.pydantic import BaseModel, Field

# --------------------------------------------------------------------
# STREAMLIT SETUP
# --------------------------------------------------------------------
st.set_page_config(page_title="Demand Letter Analyzer", layout="wide", initial_sidebar_state="collapsed")

# --------------------------------------------------------------------
# LLM SETUP – Qwen2.5-VL
# --------------------------------------------------------------------
MODEL_NAME = os.environ.get("MODEL_NAME", "qwen2.5vl:7b")
BASE_URL = os.environ.get("BASE_URL", "http://localhost:11434")

vision_llm = Ollama(
    model=MODEL_NAME,
    base_url=BASE_URL,
    request_timeout=120,
    context_window=3072,
    temperature=0.0
)

# --------------------------------------------------------------------
# SCHEMA (unchanged)
# --------------------------------------------------------------------
class DemandLetterExtract(BaseModel):
    is_demand_letter: bool | None = None
    claim_number: str | None = None
    claimant_name: str | None = None
    claimant_address: str | None = None
    claimant_contact_phone: str | None = None
    claimant_contact_email: str | None = None
    claimant_contact_facsimile: str | None = None
    claimant_legal_office_information: str | None = None
    insurance_company_representative: str | None = None
    claim_amount: str | None = None
    demand_letter_date: str | None = None
    response_deadline_date: str | None = None
    evidence_attached: list = Field(default_factory=list)
    date_of_loss: str | None = None
    insured_property_address: str | None = None
    insured_asset_description: str | None = None
    policy_number: str | None = None
    referenced_policy_language: str | None = None
    threats_of_legal_action: str | None = None
    requested_resolution: str | None = None
    tone_of_letter: str | None = None
    claimant_stated_cause_of_loss: str | None = None
    letter_response_markdown: str

sllm = vision_llm.as_structured_llm(DemandLetterExtract)

# --------------------------------------------------------------------
# DO NOT CHANGE THE USER'S PROMPT
# --------------------------------------------------------------------
MASTER_PROMPT = f"""
You are the insurance claims adjuster reviewing a demand letter. Extract structured information strictly grounded in the provided content.

Return ONLY a JSON object matching the exact schema below:

{{
    "is_demand_letter": boolean | false,
    "claim_number": string | null,
    "claimant_name": string | null,
    "claimant_address": string | null,
    "claimant_contact_phone": string | null,
    "claimant_contact_email": string | null,
    "claimant_contact_facsimile": string | null,
    "claimant_legal_office_information": string | null,
    "insurance_company_representative": string | null,
    "claim_amount": string | null,
    "demand_letter_date": string | null,
    "response_deadline_date": string | null,
    "evidence_attached": array,
    "date_of_loss": string | null,
    "insured_property_address": string | null,
    "insured_asset_description": string | null,
    "policy_number": string | null,
    "referenced_policy_language": string | null,
    "threats_of_legal_action": string | null,
    "requested_resolution": string | null,
    "tone_of_letter": string | null,
    "claimant_stated_cause_of_loss": string | null,
    "letter_response_markdown": string | null
}}

Rules:

1. First determine if the document **is** a demand letter.  
   - If NOT a demand letter, set `"is_demand_letter": false` and set **all** other fields (including `letter_response_markdown`) to null.

2. If it IS a demand letter, set `"is_demand_letter": true` and extract all fields.  
   - Use null for any field not explicitly present.

3. The field `letter_response_markdown` must contain a **professional acknowledgement letter** from the insurance adjuster to the claimant (or their legal office).  
   Requirements for the letter:
   - It must **only** acknowledge receipt of the demand.  
   - It must state that the claim is under review.  
   - It must summarize factual items found in the provided content (no fabrications).  
   - It must state a **proposed 30-day response timeline**.  
   - **No salutation** (do not use “Dear…”).  
   - **No adjuster names**.  
   - The claimant or their legal office is the implicit addressee.

4. You must **not hallucinate** or fabricate any facts.

5. All extracted information must be grounded ONLY in the provided text and images.

6. Use both the visual page images and any extracted text.  
   Treat visual content as authoritative.

7. Clearly separate insured information from insurer/adjuster information.  
   Do not confuse claimant/insured roles.

Output must be **only** the JSON object, with no surrounding commentary.

"""

# --------------------------------------------------------------------
# FILE → PAGE OBJECTS
# --------------------------------------------------------------------
def extract_pages(upload):
    filename = upload.name.lower()
    raw = upload.read()
    pages = []

    if filename.endswith(".pdf"):
        pdf = fitz.open(stream=raw, filetype="pdf")
        for i, page in enumerate(pdf):
            text = page.get_text()

            pix = page.get_pixmap(dpi=240)
            img_path = f"/tmp/dl_page_{uuid.uuid4()}.png"
            pix.save(img_path)
            abs_path = os.path.abspath(img_path)

            pages.append({
                "index": i + 1,
                "text": text,
                "image_path": abs_path,
            })
        return pages

    if filename.endswith((".png", ".jpg", ".jpeg")):
        img_path = f"/tmp/dl_page_{uuid.uuid4()}.png"
        with open(img_path, "wb") as f:
            f.write(raw)

        pages.append({
            "index": 1,
            "text": "",
            "image_path": os.path.abspath(img_path),
        })
        return pages

    if filename.endswith((".txt", ".rtf")):
        pages.append({
            "index": 1,
            "text": raw.decode("utf-8", errors="ignore"),
            "image_path": None,
        })
        return pages

    return []


# --------------------------------------------------------------------
# PROCESS A SINGLE PAGE VIA STRUCTURED LLM
# --------------------------------------------------------------------
def run_llm(text, image_path):
    blocks = []

    if text:
        blocks.append(TextBlock(text=text))
    if image_path:
        blocks.append(ImageBlock(path=image_path))

    msg = ChatMessage(
        role=MessageRole.USER,
        blocks=[TextBlock(text=MASTER_PROMPT)] + blocks,
    )

    return sllm.chat([msg]).raw


# --------------------------------------------------------------------
# UI
# --------------------------------------------------------------------
def show():
    st.title("Demand Letter Analyzer")

    upload = st.file_uploader(
        "Upload Demand Letter (PDF, PNG, JPG, TXT, RTF)",
        type=["pdf", "png", "jpg", "jpeg", "txt", "rtf"],
    )

    if not upload:
        return

    pages = extract_pages(upload)
    if not pages:
        st.write("Unable to read file.")
        return

    if st.columns(7)[3].button("Analyze"):
        results = []
        with st.spinner("Processing pages..."):
            for page in pages:
                result = run_llm(page["text"], page["image_path"])
                results.append({
                    "page": page["index"],
                    "json": json.loads(result.json()),
                    "letter": result.letter_response_markdown,
                    "image_path": page["image_path"]
                })
                
        dfs = []
        for page_num, page_result in enumerate(results, start=1):
            cols = st.columns([3, 1, 3])
            df = pd.DataFrame(
                {
                    "field": list(page_result["json"].keys()),
                    "value": list(page_result["json"].values()),
                    "page": page_num
                }
            )
            if not df.empty:
                dfs.append(df)
            with cols[0]:
                st.markdown(f"Page {page_result['page']}")
                if page_result["image_path"]:
                    st.image(page_result["image_path"], caption="Page Image")
            with cols[2]:
                st.markdown("Rebuttal Letter")
                st.markdown(page_result["letter"] or "")
        st.markdown("Extracted Fields")
        st.dataframe(pd.concat(dfs, ignore_index=True).reset_index(), use_container_width=True)


if __name__ == "__main__":
    show()
