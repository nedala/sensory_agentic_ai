import streamlit as st
import os
import json
import uuid
import pandas as pd

from llama_index.llms.ollama import Ollama
from llama_index.core.llms import (
    ChatMessage,
    TextBlock,
    MessageRole,
)
from llama_index.core.bridge.pydantic import BaseModel, Field

# --------------------------------------------------------------------
# STREAMLIT SETUP
# --------------------------------------------------------------------
st.set_page_config(
    page_title="Claim Notes Entity Graph",
    layout="wide",
    initial_sidebar_state="collapsed",
)

# --------------------------------------------------------------------
# LLM SETUP – text model (Ollama)
# --------------------------------------------------------------------
MODEL_NAME = os.environ.get("MODEL_NAME", "qwen2.5vl:7b")
BASE_URL = os.environ.get("BASE_URL", "http://localhost:11434")

llm = Ollama(
    model=MODEL_NAME,
    base_url=BASE_URL,
    request_timeout=120,
    context_window=4096,
    temperature=0.0,
)

# --------------------------------------------------------------------
# SPATIO–TEMPORAL ENTITY GRAPH DSL / DATA MODEL
# --------------------------------------------------------------------

class TimeExpression(BaseModel):
    # Raw phrase in the note
    text: str | None = None
    # Normalized ISO8601 date/time if it can be inferred (e.g. "2025-07-01T15:00:00")
    normalized_iso: str | None = None
    # How this time is used (e.g. "date_of_contact", "inspection_date", "promised_callback_date")
    role: str | None = None


class LocationMention(BaseModel):
    location_id: str | None = None  # arbitrary id like "loc_1"
    label: str | None = None        # e.g. "loss_location", "insured_property", "mailing_address", "other"
    # Freeform address / place from the note
    address_text: str | None = None
    city: str | None = None
    state: str | None = None
    postal_code: str | None = None
    # Any additional description (e.g. "rear of property", "kitchen ceiling")
    description: str | None = None


class Participant(BaseModel):
    entity_id: str | None = None  # arbitrary id like "ent_1"
    name: str | None = None
    entity_type: str | None = None  # e.g. "insured", "claimant", "adjuster", "contractor", "vendor", "attorney", "other"
    roles_in_claim: list[str] = Field(default_factory=list)  # e.g. ["policyholder", "spouse", "public_adjuster"]
    phone: str | None = None
    email: str | None = None
    organization: str | None = None  # company / firm / employer if mentioned
    address: str | None = None       # freeform address text if given


class MoneyMention(BaseModel):
    raw_text: str | None = None      # e.g. "$3,500 estimate"
    amount: float | None = None      # numeric if it can be parsed
    currency: str | None = None      # e.g. "USD"
    role: str | None = None          # e.g. "estimate", "payment", "deductible", "policy_limit", "reserve"
    coverage_type: str | None = None # e.g. "Coverage A", "Coverage C", "ALE", "other"


class RelationshipEdge(BaseModel):
    from_entity_id: str | None = None  # should match a Participant.entity_id
    to_entity_id: str | None = None    # should match a Participant.entity_id
    relationship_type: str | None = None  # e.g. "insured_of", "attorney_for", "employer_of", "vendor_for"
    evidence_snippet: str | None = None   # short text span supporting this relation from the note


class NoteEvent(BaseModel):
    event_id: str | None = None               # arbitrary id like "evt_1"
    event_type: str | None = None             # e.g. "phone_call", "site_inspection", "email_sent", "status_update",
                                              #      "payment_issued", "estimate_received", "coverage_discussion"
    main_time: TimeExpression | None = None   # primary time the event refers to (use note date if nothing else)
    other_times: list[TimeExpression] = Field(default_factory=list)
    participants: list[str] = Field(default_factory=list)  # list of Participant.entity_id involved in this event
    locations: list[str] = Field(default_factory=list)     # list of LocationMention.location_id used in this event
    money: list[MoneyMention] = Field(default_factory=list)
    summary: str | None = None               # concise plain language summary of the event
    status_after_event: str | None = None    # e.g. "awaiting documents", "inspection scheduled", "paid in full",
                                             #      "coverage denied", "no contact", "other"


class ClaimNoteEntityGraph(BaseModel):
    # Basic claim / note context (mirrors CSV columns when present)
    claim_number: str | None = None
    date_of_loss: str | None = None            # raw string from DATE_OF_LOSS column
    report_date: str | None = None             # raw string from REPORT_DATE column
    note_date: str | None = None               # raw string from NOTE_DATE column
    jurisdiction_state: str | None = None
    policy_state: str | None = None
    topic_type: str | None = None
    adjuster_name: str | None = None
    adjuster_job_title: str | None = None
    adjuster_branch: str | None = None

    # High-level categorization for this note
    high_level_tags: list[str] = Field(
        default_factory=list,
        description=(
            "List of standardized tags such as: 'CONTACTED_INSURED', 'LEFT_VOICEMAIL', "
            "'COVERAGE_DISCUSSION', 'PAYMENT_ISSUED', 'RESERVE_CHANGE', "
            "'DELAY_EXPLAINED', 'THIRD_PARTY_CONTACT', 'LITIGATION', 'SUBRO', 'SALVAGE', 'OTHER'."
        ),
    )

    # Extracted entities and graph structure
    participants: list[Participant] = Field(default_factory=list)
    spatial_mentions: list[LocationMention] = Field(default_factory=list)
    temporal_mentions: list[TimeExpression] = Field(default_factory=list)
    money_mentions: list[MoneyMention] = Field(default_factory=list)
    events: list[NoteEvent] = Field(default_factory=list)
    relationships: list[RelationshipEdge] = Field(default_factory=list)

    # A single normalized status label for downstream use
    canonical_status_after_note: str | None = None  # e.g. "open_investigation", "waiting_on_insured",
                                                    #      "awaiting_vendor", "paid_and_closed", "other"

# Structured LLM wrapper
sllm = llm.as_structured_llm(ClaimNoteEntityGraph)

# --------------------------------------------------------------------
# EXTRACTION PROMPT
# --------------------------------------------------------------------

MASTER_PROMPT = """
You are an insurance claims analyst building a spatio-temporal entity graph for a single claim note.

You will receive one JSON object representing a row from a claim notes CSV file.
Columns may include, for example:
- CLAIM_NUMBER
- DATE_OF_LOSS
- REPORT_DATE
- JURISDICTION_STATE
- POLICY_STATE
- NOTE_DATE
- ADJUSTER_NAME
- ADJUSTER_JOB_TITLE
- ADJUSTER_BRANCH
- TOPIC_TYPE
- NOTE_DESC (the free-text note body)
and possibly other columns.

Your task:

1. Read the row json carefully.
2. Treat the CSV columns as authoritative metadata when present.
3. Treat the NOTE_DESC field as the primary free-text source.
4. From this single row, populate the ClaimNoteEntityGraph schema.

Guidelines:

- All extracted information must be grounded ONLY in the given row json.
- Do not hallucinate specific facts such as names, addresses, dates, dollar amounts, or roles.
- When unsure, use null or an empty list.
- Use the CLAIM_NUMBER, DATE_OF_LOSS, REPORT_DATE, NOTE_DATE, JURISDICTION_STATE,
  POLICY_STATE, TOPIC_TYPE, ADJUSTER_NAME, ADJUSTER_JOB_TITLE, and ADJUSTER_BRANCH
  directly from the row if present.
- The 'high_level_tags' field should be a small list of standardized tags summarizing the main intent of the note.
- Participants:
  - Capture people or organizations mentioned explicitly in the NOTE_DESC.
  - Use 'entity_type' and 'roles_in_claim' to distinguish insured, claimant, contractor, adjuster, attorney, vendor, etc.
- Spatial mentions:
  - Capture any addresses or location references (e.g. property address, city, state, vendor location).
  - If JURISDICTION_STATE or POLICY_STATE appear to be relevant to a location, they may be referenced as state values.
- Temporal mentions:
  - Capture dates and time phrases in NOTE_DESC (e.g. "on 7/1/25", "tomorrow", "next week").
  - Normalize into ISO strings when possible (YYYY-MM-DD or YYYY-MM-DDThh:mm:ss).
- Money mentions:
  - Capture dollar amounts, deductibles, limits, estimates, reserves, and payments when explicitly present.
- Events:
  - Build a small list of NoteEvent objects that summarize key actions such as calls, inspections, payments,
    status updates, estimate receipt, or coverage discussions.
  - Each event should link to participants, locations, times, and money mentions via their IDs where appropriate.
- Relationships:
  - Use RelationshipEdge objects to connect participants (e.g. attorney_for, insured_of, employer_of, vendor_for),
    when explicitly supported by the text.
  - Always include an evidence_snippet from the note that supports the relationship.

- The field 'canonical_status_after_note' should contain a single label describing the overall status after this note,
  using a simple vocabulary such as:
  - "open_investigation"
  - "waiting_on_insured"
  - "waiting_on_third_party"
  - "inspection_scheduled"
  - "inspection_completed"
  - "payment_issued"
  - "paid_and_closed"
  - "coverage_denied"
  - "no_contact"
  - "other"

Output must be ONLY a JSON object matching the ClaimNoteEntityGraph schema defined above,
with no extra keys and no surrounding commentary.
"""

# --------------------------------------------------------------------
# LLM RUNNER FOR ONE ROW
# --------------------------------------------------------------------
def run_llm_on_row(row: pd.Series):
    """
    Convert a pandas row to a JSON string and send it plus the MASTER_PROMPT
    to the structured LLM. Returns the raw Pydantic model instance.
    """
    row_dict = row.to_dict()
    row_json = json.dumps(row_dict, ensure_ascii=False)

    msg = ChatMessage(
        role=MessageRole.USER,
        blocks=[
            TextBlock(text=MASTER_PROMPT),
            TextBlock(text=row_json),
        ],
    )

    # sllm.chat returns a wrapper; .raw is the underlying pydantic model
    result = sllm.chat([msg]).raw
    return result

# --------------------------------------------------------------------
# STREAMLIT UI
# --------------------------------------------------------------------
def show():
    st.title("Claim Notes Entity Graph")

    upload = st.file_uploader(
        "Upload Claim Notes CSV",
        type=["csv"],
    )

    if not upload:
        return

    # Basic CSV load
    try:
        df = pd.read_csv(upload)
    except Exception as e:
        st.error(f"Unable to read CSV: {e}")
        return

    if df.empty:
        st.write("CSV appears to be empty.")
        return

    # Optional selection / filtering
    with st.expander("Preview CSV"):
        st.dataframe(df.head(50), use_container_width=True)

    st.write("Configure extraction scope")

    # Let user pick a subset of rows (by index)
    two_cols = st.columns(2)
    max_rows = int(two_cols[0].number_input("Number of rows to process", min_value=1, max_value=min(100, len(df)), value=5))
    start_index = int(two_cols[1].number_input("Start index (0-based)", min_value=0, max_value=max(0, len(df) - 1), value=0))
    end_index = min(start_index + max_rows, len(df))

    subset = df.iloc[start_index:end_index].reset_index(drop=True)

    st.write(f"Processing rows {start_index} to {end_index - 1} (total {len(subset)})")

    if st.button("Analyze selected rows"):
        results = []
        with st.spinner("Running entity extraction on selected rows..."):
            for idx, row in subset.iterrows():
                try:
                    result_model = run_llm_on_row(row)
                    result_json = json.loads(result_model.json())
                except Exception as e:
                    # If something fails on this row, record an error result
                    result_json = {
                        "error": str(e),
                        "claim_number": row.to_dict().get("CLAIM_NUMBER"),
                        "row_index": int(idx),
                    }

                results.append(
                    {
                        "row_index": int(idx),
                        "claim_number": row.to_dict().get("CLAIM_NUMBER"),
                        "graph": result_json,
                        "note_text": row.to_dict().get("NOTE_DESC", ""),
                    }
                )

        # ----------------------------------------------------------------
        # DISPLAY RESULTS
        # ----------------------------------------------------------------
        st.subheader("Row-level entity graphs")

        flat_rows = []

        for r in results:
            cols = st.columns([2, 3, 3])
            with cols[0]:
                st.markdown(f"**Row {r['row_index']}**")
                st.markdown(f"Claim: `{r.get('claim_number')}`")

            with cols[1]:
                st.markdown("Note text")
                st.write(r.get("note_text", ""))

            with cols[2]:
                st.markdown("Extracted ClaimNoteEntityGraph (JSON)")
                st.json(r["graph"])

            # For a simple flat view / overview table
            graph = r["graph"]
            if "error" not in graph:
                flat_rows.append(
                    {
                        "row_index": r["row_index"],
                        "claim_number": graph.get("claim_number"),
                        "canonical_status_after_note": graph.get("canonical_status_after_note"),
                        "num_participants": len(graph.get("participants", [])),
                        "num_events": len(graph.get("events", [])),
                        "high_level_tags": ", ".join(graph.get("high_level_tags", [])),
                    }
                )
            else:
                flat_rows.append(
                    {
                        "row_index": r["row_index"],
                        "claim_number": r.get("claim_number"),
                        "canonical_status_after_note": None,
                        "num_participants": None,
                        "num_events": None,
                        "high_level_tags": f"ERROR: {graph['error']}",
                    }
                )

        if flat_rows:
            st.subheader("Summary table")
            flat_df = pd.DataFrame(flat_rows)
            st.dataframe(flat_df, use_container_width=True)


if __name__ == "__main__":
    show()
