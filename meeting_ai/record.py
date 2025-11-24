import shutil
from summarizer import generate_summary
import streamlit as st
import streamlit.components.v1 as components
import tempfile, os, json
from pydub import AudioSegment
from transcribe_whisper import diarize_split_transcribe
from utils import (
    convert_video_to_audio,
    convert_audio_to_mono_wav_file,
    cleanup_temp_files,
    generate_html_download_link,
    stage_file_for_download,
)
import base64
import pandas as pd
# Set up the page
st.set_page_config(
    page_title="Meeting AI",
    page_icon=":studio_microphone:",
    layout="wide",
    initial_sidebar_state="collapsed",
    menu_items={
        "Report a bug": "mailto: nedala@gmail.com",
        "About": "#### Meeting AI is your private meeting notetaker.\n It records your screen and audio during meetings. It provides a summary of the meeting content later.",
    },
)
# Directory to temporarily store files for upload
UPLOAD_FOLDER = os.path.join("/tmp", "uploads")
if not os.path.exists(UPLOAD_FOLDER):
    os.makedirs(UPLOAD_FOLDER, exist_ok=True)

st.markdown("""
<style>
/* Global Typography */
html, body, [class*="css"]  {
    font-family: Inter, -apple-system, BlinkMacSystemFont, Segoe UI, Roboto, Helvetica Neue, sans-serif;
}

/* Card container */
.ui-card {
    background: #ffffff;
    padding: 24px 28px;
    border-radius: 14px;
    border: 1px solid rgba(0,0,0,0.06);
    box-shadow: 0 2px 6px rgba(0,0,0,0.04);
    margin-bottom: 25px;
}

/* Section titles */
.section-title {
    font-size: 20px;
    font-weight: 600;
    margin-bottom: 14px;
    margin-top: 6px;
}

/* Minimal Step Indicator */
.step-indicator {
    display: flex;
    justify-content: center;
    margin: 20px 0 35px 0;
    gap: 40px;
}

.step-item {
    font-size: 15px;
    letter-spacing: .4px;
    padding-bottom: 6px;
    border-bottom: 2px solid transparent;
    color: #6b7280;
}

.step-active {
    color: #111827 !important;
    border-color: #4F46E5 !important;
}

/* Download button styling */
.download-btn button {
    background-color: #4F46E5 !important;
    color: white !important;
    padding: 10px 18px !important;
    border-radius: 10px !important;
    border: none !important;
    font-size: 15px !important;
    transition: 0.15s ease-in-out;
}

.download-btn button:hover {
    background-color: #6366F1 !important;
    transform: translateY(-2px);
}

/* Pill buttons for samples */
.sample-btn button {
    background-color: #f3f4f6 !important;
    color: #374151 !important;
    padding: 8px 14px !important;
    border-radius: 8px !important;
    font-size: 14px !important;
    border: 1px solid #e5e7eb !important;
}

.sample-btn button:hover {
    background-color: #e5e7eb !important;
}

/* Summary sections */
.summary-section {
    background-color: #f9fafb;
    padding: 18px 20px;
    border-radius: 10px;
    margin-bottom: 18px;
    border: 1px solid #e5e7eb;
}
</style>
""", unsafe_allow_html=True)


# JavaScript to toggle the help popup visibility
components.html(
    """
    <script>
        const helpButton = window.parent.document.querySelector('.help-button');
        const windowButton = window.parent.document.querySelector('.window-button');
        const closeButton = window.parent.document.querySelector('.close-help');
        
        function closeHelpPopup() {
            const helpPopup = window.parent.document.getElementById('help-popup');
            helpButton.innerHTML = helpPopup.style.display === 'block' ? '?' : '×';
            helpPopup.style.display = helpPopup.style.display === 'block' ? 'none' : 'block';
        }
        
        function openDummyTab() {
            const newTab = window.open("", "_blank");  // Specify _blank for new tab
            if (newTab) {
                newTab.document.write("<h1>Empty Tab - No Content</h1>");
                newTab.document.write("<p>This is a dummy tab to avoid recording any real content.</p>");
                newTab.document.title = "Empty Tab -- To Be Used as Dummy Target for Recording";
                window.focus();
            } else {
                console.log("Popup blocked by the browser.");
            }
        }
        
        function startRecording() {
            window.parent.document.getElementById('MainMenu').click();
            setTimeout(() => {
                const spans = window.parent.document.querySelectorAll('span');
                const targetSpan = Array.from(spans).find(span => span.textContent.trim() === 'Record a screencast');
                if (targetSpan) {
                    console.log('Found the span:', targetSpan);
                    targetSpan.click();
                    setTimeout(() => { 
                        window.parent.document.querySelector('input[name="recordAudio"]').click();
                        const recordingButtons = window.parent.document.querySelectorAll('button');
                        const targetButton = Array.from(recordingButtons).find(button => button.textContent.trim() === 'Start recording!');
                        if (targetButton) {
                            openDummyTab();
                            targetButton.click();
                        }
                    }, 1000);
                } else {
                    console.log('Span with text "Record a screencast" not found');
                }
                }, 1000);
        };

        helpButton.addEventListener('click', closeHelpPopup);
        windowButton.addEventListener('click', openDummyTab);
        closeButton.addEventListener('click', closeHelpPopup);
        const recordButton = window.parent.document.querySelector('.record-button');
        recordButton.addEventListener('click', startRecording);
    </script>
    """,
    height=0,
)

# Initialize session state to store transcription data
if "transcription_text" not in st.session_state:
    st.session_state["transcription_text"] = None
    st.session_state["audio_path"] = ""
    st.session_state["csv_path"] = ""
    st.session_state["namespace"] = ""


# Define the pages (Main and Visual Guide)
def main_page():
    st.markdown("<h1 style='text-align:center;'>Meeting AI</h1>", unsafe_allow_html=True)

    # ---------------------------------------------------------------------
    #  TABS
    # ---------------------------------------------------------------------
    tab1, tab2, tab3 = st.tabs(["① Record Meeting", "② Transcribe Audio", "③ Summarize Meeting"])

    # ---------------------------------------------------------------------
    #  TAB 1 — RECORD
    # ---------------------------------------------------------------------
    with tab1:
        cols = st.columns([5, 5])
        cols[0].write("""
        This is the first step in Meeting AI.  
        The recording begins when you **Record a Screencast** from your hamburger menu.  
        Also **record audio** from your microphone.
        """)

        with cols[0]:
            st.markdown(
                """<button class="record-button" title="Start Recording">Start Recording</button>""",
                unsafe_allow_html=True,
            )

        cols[1].container(border=1).write("""
        1. Open the Streamlit menu (‘≡’).
        2. Select *Record a screencast*, enable *Record audio*.
        3. Press Escape (Esc) to stop.
        4. Upload the recording in Step 2.
        5. Use the ‘?’ button for help.
        6. Use the Dummy Window button to record a blank tab.
        """)

    # ---------------------------------------------------------------------
    #  TAB 2 — TRANSCRIBE
    # ---------------------------------------------------------------------
    with tab2:
        upload_cols = st.columns([6, 2])
        progress_review = st.empty()

        with upload_cols[0]:
            st.write("Upload your meeting recording and let the system transcribe the audio.")

            uploaded_file = st.file_uploader(
                "Upload your meeting recording",
                type=["webm", "mp4", "wav", "ogg", "aac", "mp3", "wma", "flac"],
            )

            col4 = st.columns(4)

            # --- TRANSCRIBE ---
            if uploaded_file and col4[1].button("Transcribe", key="TranscribeBtn"):
                st.session_state["transcription_text"] = None
                st.session_state["audio_path"] = ""

                with progress_review.status("Transcribing...", expanded=True) as progress_bar:
                    try:
                        bytes_data = uploaded_file.read()
                        bytes_len = len(bytes_data)

                        prefix_path = f"f{abs(hash(os.path.splitext(os.path.basename(uploaded_file.name))[0]))}_{bytes_len}"
                        output_dir = os.path.join(UPLOAD_FOLDER, prefix_path)
                        os.makedirs(output_dir, exist_ok=True)
                        st.session_state["namespace"] = output_dir

                        input_video_name = os.path.join(output_dir, f"input{os.path.splitext(uploaded_file.name)[1]}")
                        output_mp3_name = os.path.join(output_dir, "output.mp3")
                        output_wav_name = os.path.join(output_dir, "output.wav")
                        output_csv_name = os.path.join(output_dir, "output.csv")

                        with open(input_video_name, "wb") as tmp_video:
                            tmp_video.write(bytes_data)

                        progress_bar.write(f"Extracting mp3... `{input_video_name}`")
                        output_mp3_name = convert_video_to_audio(input_video_name, output_mp3_name, "mp3")

                        progress_bar.write(f"Extracting wav... `{output_mp3_name}`")
                        output_wav_name = convert_audio_to_mono_wav_file(output_mp3_name, output_wav_name)

                        audio_filename = output_wav_name
                        st.session_state["audio_path"] = output_mp3_name
                        st.session_state["csv_path"] = output_csv_name

                        transcription_frame = diarize_split_transcribe(
                            audio_filename,
                            output_csv_name,
                            output_dir=output_dir,
                            progress_bar=progress_bar
                        )

                        st.session_state["transcription_text"] = transcription_frame
                        progress_bar.update(label="Transcription Complete", state="complete", expanded=False)

                    except Exception as e:
                        progress_bar.code(f"Error: {e}")
                        progress_bar.update(label="Errored", state="error", expanded=True)

            # --- CLEAR ---
            if uploaded_file and col4[2].button("Clear", key="ResetBtn"):
                st.session_state["transcription_text"] = None
                st.session_state["audio_path"] = ""
                st.session_state["csv_path"] = ""
                st.session_state["namespace"] = ""

        # --- Show Transcription ---
        if st.session_state["transcription_text"] is not None:
            st.dataframe(
                st.session_state["transcription_text"],
                use_container_width=True,
                height=250,
            )

        # --- Download Buttons ---
        if st.session_state.get("namespace") and os.path.exists(st.session_state["namespace"]):
            four_columns = st.columns(4)

            # AUDIO
            if "audio_path" in st.session_state and st.session_state["audio_path"]:
                try:
                    with open(st.session_state["audio_path"], "rb") as fh:
                        four_columns[1].markdown('<div class="download-btn">', unsafe_allow_html=True)
                        four_columns[1].download_button(
                            "Download MP3",
                            fh.read(),
                            file_name=os.path.basename(st.session_state["audio_path"]),
                            mime="audio/mpeg",
                        )
                        four_columns[1].markdown('</div>', unsafe_allow_html=True)
                except:
                    pass

            # TRANSCRIPT CSV
            if st.session_state["transcription_text"] is not None:
                csv_filename = f"{os.path.splitext(os.path.basename(st.session_state['audio_path']))[0]}_transcript.csv"
                st.session_state["transcription_text"].to_csv(csv_filename, index=False)

                try:
                    with open(csv_filename, "rb") as fh:
                        four_columns[2].markdown('<div class="download-btn">', unsafe_allow_html=True)
                        four_columns[2].download_button(
                            "Download Transcript",
                            fh.read(),
                            file_name=csv_filename,
                            mime="text/csv",
                        )
                        four_columns[2].markdown('</div>', unsafe_allow_html=True)
                except:
                    pass

        # --- Samples (unchanged) ---
        with upload_cols[1].container(border=1):
            st.write("##### Samples")

            from pathlib import Path
            static_dir = Path(__file__).parent / "static"

            samples = [
                ("Teresa", "Teresa.webm", "video/webm"),
                ("Goodall", "Goodall.webm", "video/webm"),
                ("DeGrasse", "DeGrasse.webm", "video/webm"),
                ("Meeting (Long)", "Meeting.mp3", "audio/mpeg"),
                ("Taunt (Short)", "taunt.wav", "audio/wav"),
            ]

            for label, fname, mime in samples:
                file_path = static_dir / fname
                if file_path.exists():
                    with open(file_path, "rb") as fh:
                        st.download_button(
                            label=label,
                            data=fh.read(),
                            file_name=fname,
                            mime=mime,
                            key=f"download_{fname}",
                        )

    # ---------------------------------------------------------------------
    #  TAB 3 — SUMMARIZE
    # ---------------------------------------------------------------------
    with tab3:
        analysis_cols = st.columns([5, 2])
        summary_div = st.container()
        progress_result = st.container()

        with analysis_cols[0]:
            if (
                st.session_state["transcription_text"] is not None
                and st.session_state["transcription_text"].shape[0] > 0
            ):
                st.dataframe(st.session_state["transcription_text"], height=250)
            else:
                uploaded_transcription = st.file_uploader("Upload transcript", type=["csv"])
                if uploaded_transcription:
                    st.session_state["transcription_text"] = pd.read_csv(uploaded_transcription)
                    st.dataframe(st.session_state["transcription_text"], height=250)

            if st.session_state["transcription_text"] is not None:
                cols4 = st.columns(3)
                if cols4[1].button("Extract Summary"):
                    ps = progress_result.empty().status("Analyzing...", expanded=True)
                    summary_payload = generate_summary(
                        st.session_state["transcription_text"].head(200),
                        progress_status=ps,
                    )

                    if ps:
                        ps.update(label="AI Summarization Complete", state="complete", expanded=False)

                    if summary_payload and "final_summary" in summary_payload:
                        meeting_summary = summary_payload["final_summary"]
                        with summary_div:
                            st.markdown("## Final Summary")
                            st.caption(meeting_summary.overall_summary)
                            if hasattr(meeting_summary, "speaker_identities") and meeting_summary.speaker_identities:
                                st.markdown("### Participants")

                                # Sort speaker0, speaker1, speaker2 ... properly
                                ordered_keys = sorted(
                                    meeting_summary.speaker_identities.keys(),
                                    key=lambda k: int(''.join(filter(str.isdigit, k))) if any(ch.isdigit() for ch in k) else 999
                                )

                                for spk in ordered_keys:
                                    identity = meeting_summary.speaker_identities[spk]
                                    st.caption(f"- **{spk}** → {identity}")

                            if meeting_summary.topics:
                                st.markdown("### Topics")
                                for t in meeting_summary.topics:
                                    st.caption(f" - {t}")

                            if meeting_summary.decisions:
                                st.markdown("### Decisions")
                                for d in meeting_summary.decisions:
                                    st.caption(f" - {d}")

                            if meeting_summary.action_items:
                                st.markdown("### Action Items")
                                for a in meeting_summary.action_items:
                                    st.caption(f" - {a}")

                            if meeting_summary.risks:
                                st.markdown("### Risks")
                                for r in meeting_summary.risks:
                                    st.caption(f" - {r}")

                            if meeting_summary.follow_ups:
                                st.markdown("### Follow-ups")
                                for f in meeting_summary.follow_ups:
                                    st.caption(f" - {f}")

        analysis_cols[1].container(border=1).write("""
        1. AI will analyze your transcript.  
        2. The final meeting summary will appear here.
        """)



def include_help():
    # Get Streamlit's theme colors from the session state
    primary_color = (
        st.get_option("theme.primaryColor") or "#ff4b4b"
    )  # Default red color
    background_color = (
        st.get_option("theme.backgroundColor") or "#f0f0f0"
    )  # Default white color
    text_color = st.get_option("theme.textColor") or "#000000"  # Default black color
    secondary_background_color = (
        st.get_option("theme.secondaryBackgroundColor") or "#f0f0f0"
    )  # Default light gray color

    # Inject dynamic CSS based on the theme colors
    st.markdown(
        f"""
        <style>
        .help-button-container {{
            position: fixed;
            bottom: 20px;
            right: 20px;
            z-index: 100;
        }}
        .help-button {{
            background-color: {background_color};
            color: {text_color};
            border-radius: 50%;
            width: 50px;
            height: 50px;
            font-size: 25px;
            text-align: center;
            line-height: 50px;
            border: none;
            cursor: pointer;
        }}
        .window-button {{
            background-color: {background_color};
            color: {text_color};
            border-radius: 50%;
            width: 50px;
            height: 50px;
            font-size: 25px;
            text-align: center;
            line-height: 50px;
            border: none;
            cursor: pointer;
        }}
        .help-popup {{

            position: fixed;
            bottom: 90px;
            right: 20px;
            width: 50%;
            max-width: 800px;
            background-color: {background_color};
            color: {text_color};
            padding: 30px;
            border-radius: 10px;
            box-shadow: 0 4px 8px rgba(0,0,0,0.2);
            z-index: 101;
            max-height: 80%; /* Set max-height to restrict the height */
            overflow-y: auto; /* Enable vertical scrolling */
        }}
        .help-popup h3 {{
            color: {text_color};
        }}
        .h4 {{
            color: {text_color};
        }}
        .help-button:hover {{
            background-color: #f0f0f0;
        }}

        .help-popup::-webkit-scrollbar {{
            width: 12px; /* Set width of the scrollbar */
        }}
        .help-popup::-webkit-scrollbar-track {{
            background: {secondary_background_color}; /* Scrollbar track color */
        }}
        .help-popup::-webkit-scrollbar-thumb {{
            background-color: {primary_color}; /* Scrollbar thumb (draggable part) */
            border-radius: 10px;
            border: 3px solid {secondary_background_color}; /* Adds space around the thumb */
        }}

        /* Firefox scrollbar customization */
        .help-popup {{
            scrollbar-width: thin;
            scrollbar-color: {primary_color} {secondary_background_color}; /* Thumb and track color */
        }}
        </style>
        """,
        unsafe_allow_html=True,
    )

    # Help popup content, initially hidden
    st.markdown(
        f"""
    <style>
    img {{
        border-radius: 8px;
        box-shadow: 0px 4px 8px rgba(0, 0, 0, 0.2);
        margin-bottom: 10px;
        margin-top: 10px;
    }}
    </style>
    <div id="help-popup" class="help-popup" style="display:none; text-align:center;">
    <!-- Close Button for the Help Popup -->
        <button aria-label="Close" id="close-help" class="close-help" style="position: absolute; top: 10px; right: 10px; background-color: transparent; color: {text_color}; border: none; font-size: 18px; cursor: pointer;">
            &times;
        </button>
        <h4><div class='h4'>Visual Guide for Meeting AI</div></h4>
        <p>
            <strong>Step 1: Open the hamburger menu.</strong><br/>
            <img src="/app/static/app-menu-developer.png" alt="Step 1: Open the hamburger menu." width="80%"/>
        </p>
        <hr/>
        <p>
            <strong>Step 2: Select 'Record a screencast' and choose 'Also record audio'.</strong><br/>
            <img src="/app/static/app-menu-record-2.png" alt="Step 2: Select 'Record a screencast' and choose 'Also record audio'." width="80%"/>
        </p>
        <hr/>
        <p>
            <strong>Step 3: Click 'Share' to begin.</strong><br/>
            <img src="/app/static/app-menu-record-3.png" alt="Step 3: Click 'Share' to begin." width="80%"/>
        </p>
        <hr/>
        <p>
            <strong>Step 4: Stop the recording by pressing 'ESC' or clicking 'Stop recording'.</strong><br/>
            <img src="/app/static/app-menu-record-6.png" alt="Step 4: Stop the recording by pressing 'ESC' or clicking 'Stop recording'." width="80%"/>
        </p>
        <hr/>
        <p>
            For more help, email <a href="mailto:nedala@gmail.com">Edala</a>.
        </p>
    </div>
    """,
        unsafe_allow_html=True,
    )

    # Help button positioned in the bottom-right corner
    st.markdown(
        """
        <div class="help-button-container">
            <button class="help-button" title="Click for help">?</button>
            <button class="window-button" title="Click to open a dummy target for recording">▞</button>
        </div>
        """,
        unsafe_allow_html=True,
    )


main_page()
include_help()
