import tempfile, os, json
from pydub import AudioSegment
import shutil
import base64
import streamlit as st

DOWNLOAD_FOLDER = os.path.join("static", "downloads")

# Function to convert video to audio (MP3) if needed
def convert_video_to_audio(video_file, output_file, output_format="mp3"):
    audio = AudioSegment.from_file(video_file)
    audio.export(output_file, format=output_format, bitrate="192k").close()
    return output_file


# Function to convert audio to mono WAV file
def convert_audio_to_mono_wav_file(audio_file, output_file):
    audio = AudioSegment.from_file(audio_file)
    audio = audio.set_channels(1)
    audio.export(output_file, format="wav").close()
    return output_file


# Function to clean up temporary directories and files
def cleanup_temp_files(output_dir):
    """Clean up temporary directories and files after processing."""
    if os.path.exists(output_dir):
        shutil.rmtree(output_dir)


def generate_html_download_link(file_path, link_label, file_type):
    """
    Generates an HTML anchor tag for downloading files using base64 encoding.

    Args:
    - file_path (str): Path to the file to be downloaded.
    - link_label (str): The label to display on the download link.
    - file_type (str): MIME type for the file ("audio/mpeg" or "text/csv").

    Returns:
    - str: HTML anchor tag for downloading the specified file.
    """
    # Read the file and encode it in base64
    with open(file_path, "rb") as file:
        file_data = file.read()
        b64_encoded = base64.b64encode(file_data).decode()

    # Generate appropriate download MIME types
    if file_type == "audio/mpeg":
        mime = "audio/mpeg"
    elif file_type == "text/csv":
        mime = "text/csv"
    else:
        mime = "application/octet-stream"  # Fallback MIME type for unknown files

    # Create a downloadable HTML link
    return f'<a href="data:{mime};base64,{b64_encoded}" download="{os.path.basename(file_path)}">{link_label}</a>'


# Function to create staged download links
def stage_file_for_download(file_path, output_file, link_label):
    """
    Stage the file for download by saving it in the DOWNLOAD_FOLDER and creating a link.

    Args:
    - file_path (str): Path to the file to be staged for download.
    - link_label (str): The label to display on the download link.
    - file_type (str): MIME type for the file ("audio/mpeg" or "text/csv").

    Returns:
    - str: HTML anchor tag for downloading the specified file.
    """
    # If the file doesn't exist, return a disabled link
    if not os.path.exists(file_path):
        return f'<span style="color: #888">{link_label} (missing)</span>'

    # For reliability across deployments, create a data-URI based download link
    # This avoids depending on the app's static file serving path which can
    # vary between environments (and was producing small/invalid downloads).
    # For very large files this will embed the file in the page; if that's
    # a concern, consider using `st.download_button` directly in Streamlit.
    with open(file_path, "rb") as f:
        b64_encoded = base64.b64encode(f.read()).decode()

    # Guess MIME type from extension
    ext = os.path.splitext(file_path)[1].lower()
    if ext in (".mp3", ".mpeg"):
        mime = "audio/mpeg"
    elif ext in (".wav",):
        mime = "audio/wav"
    elif ext in (".csv",):
        mime = "text/csv"
    else:
        mime = "application/octet-stream"

    return f'<a href="data:{mime};base64,{b64_encoded}" download="{os.path.basename(file_path)}">{link_label}</a>'
