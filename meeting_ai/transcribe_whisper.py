import gc
import json
import os
import shutil
from contextlib import contextmanager

import pandas as pd
import torch
import whisper
from nemo.collections.asr.models.msdd_models import NeuralDiarizer
from omegaconf import OmegaConf
from pydub import AudioSegment
import tempfile

# Set the device based on availability
device = "cuda" if torch.cuda.is_available() else "cpu"

# Global variable to store singleton instances
MODEL_REGISTRY = {}


@contextmanager
def torch_cleanup():
    """Context manager to handle GPU memory cleanup and garbage collection."""
    try:
        yield
    finally:
        if torch.cuda.is_available():
            torch.cuda.empty_cache()
        gc.collect()


# Function to initialize and return the Whisper model (singleton pattern)
def get_whisper_model(model_name="medium.en"):
    """Initialize and return the Whisper model (singleton)."""
    global MODEL_REGISTRY
    if "whisper_model" not in MODEL_REGISTRY:
        print("Loading Whisper model...")
        model_dir = "/root/.cache/torch/NeMo"
        if not os.path.exists(model_dir):
            os.makedirs(model_dir)
        whisper_model = whisper.load_model(model_name, download_root=model_dir).to(
            device
        )
        MODEL_REGISTRY["whisper_model"] = whisper_model
    else:
        print("Using cached Whisper model...")
    return MODEL_REGISTRY["whisper_model"]


# Function to initialize and return the Neural Diarizer model (singleton pattern)
def get_diarizer_model(cfg):
    """Initialize and return the Neural Diarizer model (singleton pattern)."""
    diarizer_model = NeuralDiarizer(cfg=cfg).to(device)
    return diarizer_model


# Function to create the diarization configuration file and setup the environment
def create_diarization_config(audio_filepath, output_dir, domain_type="telephonic"):
    """
    Create the configuration and manifest for NeMo's Neural Diarizer.

    Args:
        audio_filepath (str): Path to the input audio file.
        output_dir (str): Directory to store config and manifest files.
        domain_type (str): Domain type for diarization ("telephonic", "meeting", or "general").

    Returns:
        OmegaConf object: Configuration for NeMo's Neural Diarizer.
    """
    config_filename = os.path.join("/config/", f"diar_infer_{domain_type}.yaml")
    config_path = os.path.join(output_dir, config_filename)

    if not os.path.exists(config_path):
        shutil.copy(config_filename, config_path)

    # Load the configuration file
    config = OmegaConf.load(config_path)
    # Setup directories and create manifest
    data_dir = os.path.join(output_dir, "data")
    os.makedirs(data_dir, exist_ok=True)

    # Create the manifest for diarization
    manifest = {
        "audio_filepath": audio_filepath,
        "offset": 0,
        "duration": None,
        "label": "infer",
        "text": "-",
        "rttm_filepath": None,
        "uem_filepath": None,
    }

    manifest_path = os.path.join(data_dir, "input_manifest.json")
    with open(manifest_path, "w") as manifest_file:
        json.dump(manifest, manifest_file)

    # Configure diarization paths and models
    config.diarizer.manifest_filepath = manifest_path
    config.diarizer.out_dir = output_dir
    config.diarizer.speaker_embeddings.model_path = "titanet_large"
    config.diarizer.vad.model_path = "vad_multilingual_marblenet"
    config.diarizer.msdd_model.model_path = "diar_msdd_telephonic"

    return config


# Function to merge consecutive speaker segments if they are within a specified gap
def merge_consecutive_speaker_segments(df, gap_threshold=2.0):
    """Merge consecutive speaker segments if they are within the specified gap."""
    merged_segments = []
    prev_row = None

    for _, row in df.iterrows():
        if prev_row is None:
            prev_row = row
        else:
            if (
                row["SpeakerID"] == prev_row["SpeakerID"]
                and (row["Start"] - prev_row["End"]) <= gap_threshold
            ):
                prev_row["End"] = row[
                    "End"
                ]  # Extend the End Time of the previous segment
            else:
                merged_segments.append(prev_row)
                prev_row = row

    if prev_row is not None:
        merged_segments.append(prev_row)

    return pd.DataFrame(merged_segments)


# Main function to handle diarization and transcription using Whisper
def diarize_split_transcribe(
    audio_file,
    csv_file,
    output_dir,
    domain_type="telephonic",
    merge_gap_threshold=2.0,
    progress_bar=None,
):
    """
    Perform diarization and Whisper transcription in a single pipeline.

    Args:
    - audio_file (str): Path to the input audio file (WAV or MP3).
    - domain_type (str): Diarization domain type ("telephonic", "meeting", or "general").
    - output_dir (str): Directory to store intermediate and output files.
    - merge_gap_threshold (float): Time gap (in seconds) to merge consecutive speaker segments.

    Returns:
    - pd.DataFrame: DataFrame containing Speaker, Start Time, End Time, and Whisper Transcription.
    """
    try:
        if os.path.exists(csv_file):
            df = pd.read_csv(csv_file)
            if progress_bar is not None:
                progress_bar.write("CSV file loaded successfully.")
            return df
        if progress_bar is not None:
            progress_bar.write("Performing speaker diarization...")
        # Ensure output directory exists
        os.makedirs(output_dir, exist_ok=True)

        # Step 1: Create diarization config and manifest
        config = create_diarization_config(audio_file, output_dir, domain_type)

        # Step 2: Diarize using NeMo's Neural Diarizer with torch cleanup context
        with torch_cleanup():
            diarizer_model = get_diarizer_model(config)
            diarizer_model.diarize()
            del diarizer_model

        # Step 3: Load RTTM file and generate segmentation boundaries
        rttm_file = os.path.join(
            output_dir,
            "pred_rttms",
            f"{os.path.splitext(os.path.basename(audio_file))[0]}.rttm",
        )
        if not os.path.exists(rttm_file):
            raise FileNotFoundError(f"RTTM file not found: {rttm_file}")
        if progress_bar is not None:
            progress_bar.write("Diarization completed. Checking speaker segments...")
        rttm_df = pd.read_csv(
            rttm_file,
            delim_whitespace=True,
            header=None,
            names=[
                "Type",
                "FileID",
                "ChannelID",
                "Start",
                "Duration",
                "NA1",
                "NA2",
                "SpeakerID",
                "NA3",
                "NA4",
            ],
        )
        rttm_df["End"] = rttm_df["Start"] + rttm_df["Duration"]

        # Step 4: Merge consecutive speaker segments within the specified gap
        rttm_df = merge_consecutive_speaker_segments(
            rttm_df, gap_threshold=merge_gap_threshold
        )
        if progress_bar is not None:
            progress_bar.write("Collating speaker segments for transcription...")
        # Step 5: Transcribe each speaker segment using Whisper within context
        transcriptions = []
        with torch_cleanup():
            whisper_model = get_whisper_model()
            audio = AudioSegment.from_file(audio_file)
            sub_progress = (
                progress_bar.progress(0) if progress_bar is not None else None
            )

            # Iterate over the rows and adjust segment boundaries
            for n, (index, row) in enumerate(rttm_df.iterrows()):
                speaker = row["SpeakerID"]
                start_time = row["Start"] * 1000  # Convert start time to milliseconds

                # Determine the end time: either the start time of the next segment or the end of the file
                if n < len(rttm_df) - 1:
                    end_time = rttm_df.iloc[n + 1]["Start"] * 1000
                else:
                    end_time = len(audio)  # Last segment: go till the end of the audio

                # Update progress bar with speaker and segment information
                if sub_progress is not None:
                    sub_progress.progress(
                        n / len(rttm_df),
                        text=f"""Transcribing `{speaker}` `{int(n)}` out of {len(rttm_df)} segments 
                                between `{row["Start"]:.3f}s` to `{end_time / 1000.0:.3f}s`...""",
                    )

                # Extract the audio segment for transcription
                segment = audio[start_time:end_time]

                # Save segment temporarily and transcribe
                with tempfile.NamedTemporaryFile(
                    suffix=".wav", delete=False
                ) as temp_audio:
                    segment.export(temp_audio.name, format="wav")
                    result = whisper_model.transcribe(temp_audio.name, language="en")
                    os.remove(temp_audio.name)

                # Store the transcription result
                transcriptions.append(
                    {
                        "Speaker": speaker,
                        "Start Time": row["Start"],
                        "End Time": end_time
                        / 1000.0,  # Convert back to seconds for consistency
                        "Whisper Transcription": result["text"],
                    }
                )

            if sub_progress is not None:
                sub_progress.progress(1.0, text="Transcription completed.")
        if progress_bar is not None:
            progress_bar.write("Transcription completed.")
        transcriptions_df = pd.DataFrame.from_records(transcriptions)
        transcriptions_df.to_csv(csv_file, index=False)
        return transcriptions_df
    except Exception as e:
        if progress_bar is not None:
            progress_bar.write(f"Error: {e}")
        else:
            raise e
