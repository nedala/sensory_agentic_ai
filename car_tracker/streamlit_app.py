import streamlit as st
import cv2
import numpy as np
from ultralytics import YOLO
from pathlib import Path
import tempfile
import subprocess
import shutil
import os
import hashlib
import json

st.set_page_config(layout="wide")
st.title("Car Tracking Demo")

@st.cache_resource
def load_model():
    return YOLO("yolo11s-seg.pt")

def process_video(input_path, output_path, tracker_yaml, conf=0.15, iou=0.15):
    model = load_model()
    cap = cv2.VideoCapture(input_path)

    fourcc = cv2.VideoWriter_fourcc(*"mp4v")
    fps = cap.get(cv2.CAP_PROP_FPS)
    W = int(cap.get(cv2.CAP_PROP_FRAME_WIDTH))
    H = int(cap.get(cv2.CAP_PROP_FRAME_HEIGHT))

    # Use a persistent cache directory so processed outputs can be reused
    cache_dir = Path.home() / ".cache" / "car_tracker"
    cache_dir.mkdir(parents=True, exist_ok=True)

    # Compute a cache key based on input file content and processing parameters
    def _file_hash(path):
        h = hashlib.sha256()
        with open(path, "rb") as fh:
            for chunk in iter(lambda: fh.read(8192), b""):
                h.update(chunk)
        return h.hexdigest()

    input_hash = _file_hash(input_path)
    # include processing params in the key so different options produce different outputs
    key_info = {
        "input_hash": input_hash,
        "tracker": str(tracker_yaml),
        "conf": float(conf),
        "iou": float(iou),
        "session_id": str(id(st.session_state))  # to avoid cross-session cache sharing
    }
    key = hashlib.sha256(json.dumps(key_info, sort_keys=True).encode("utf-8")).hexdigest()
    cached_path = cache_dir / f"processed_{key}.mp4"

    # If we already processed this exact input + params, return cached file
    if cached_path.exists():
        return str(cached_path)

    out = cv2.VideoWriter(output_path, fourcc, fps, (W, H))

    total_frames = int(cap.get(cv2.CAP_PROP_FRAME_COUNT))
    cap.release()

    progress = st.progress(0)
    processed = 0

    for res in model.track(
        source=input_path,
        stream=True,
        conf=conf,
        iou=iou,
        tracker=tracker_yaml,
        classes=[2],   # car only
        verbose=False
    ):
        frame = res.orig_img.copy()
        Hf, Wf = frame.shape[:2]

        if hasattr(res, "masks") and res.masks is not None:
            raw_masks = res.masks.data.cpu().numpy()   # shape: (N, mask_h, mask_w)
            overlay = frame.copy()
            N = raw_masks.shape[0]

            # Extract track IDs (aligned with masks by index)
            track_ids = None
            if hasattr(res, "boxes") and res.boxes is not None:
                if hasattr(res.boxes, "id") and res.boxes.id is not None:
                    track_ids = res.boxes.id.cpu().numpy().astype(int).tolist()
                else:
                    # fall back to last column of boxes.data
                    bdata = res.boxes.data.cpu().numpy()
                    if bdata.shape[1] >= 7:
                        track_ids = bdata[:, -1].astype(int).tolist()

            # fallback if tracker ids missing
            if track_ids is None:
                track_ids = [None] * N

            # Extract bounding boxes for label placement
            if hasattr(res.boxes, "xyxy") and res.boxes.xyxy is not None:
                boxes_xyxy = res.boxes.xyxy.cpu().numpy()
            else:
                boxes_xyxy = res.boxes.data.cpu().numpy()[:, :4]

            # color for masks
            mask_color = np.array([0, 255, 0], dtype=np.uint8)

            for i in range(N):
                m = raw_masks[i]  # (mask_h, mask_w)

                # Resize mask to full video resolution
                mask_resized = cv2.resize(
                    m.astype(np.uint8),
                    (Wf, Hf),
                    interpolation=cv2.INTER_NEAREST
                ).astype(bool)

                # Apply overlay
                overlay[mask_resized] = (
                    overlay[mask_resized] * 0.3 + mask_color * 0.7
                ).astype(np.uint8)

                # ---- LABEL DRAWING ----
                track_id = track_ids[i]

                # Prefer bounding box top-left for label
                try:
                    x1 = int(boxes_xyxy[i, 0])
                    y1 = int(boxes_xyxy[i, 1])
                except:
                    # fallback to mask centroid
                    ys, xs = np.where(mask_resized)
                    if len(xs):
                        x1 = int(xs.mean())
                        y1 = int(ys.min())
                    else:
                        x1, y1 = 10, 30

                if track_id is not None:
                    label = f"ID {track_id}"
                    font = cv2.FONT_HERSHEY_SIMPLEX
                    font_scale = 0.6
                    thickness = 2

                    (tw, th), bl = cv2.getTextSize(label, font, font_scale, thickness)

                    # background box
                    rx1 = max(x1, 0)
                    ry1 = max(y1 - th - 6, 0)
                    rx2 = rx1 + tw + 6
                    ry2 = ry1 + th + 6

                    cv2.rectangle(overlay, (rx1, ry1), (rx2, ry2), (0, 0, 0), -1)
                    cv2.putText(overlay, label,
                                (rx1 + 3, ry2 - 3),
                                font, font_scale,
                                (255, 255, 255), thickness, cv2.LINE_AA)

            frame = overlay

        out.write(frame)
        processed += 1
        progress.progress(min(processed / total_frames, 1.0))

    out.release()
    # Re-encode to H.264 using ffmpeg and place final file into the cache
    tmp_fp = tempfile.NamedTemporaryFile(delete=False, suffix=".mp4")
    tmp_path = tmp_fp.name
    tmp_fp.close()

    # Try to copy the audio track from the original input into the re-encoded
    # video. The `out` file written by OpenCV typically has no audio, so we
    # re-encode video from that file and map audio from the original input.
    cmd_with_audio = [
        "ffmpeg", "-y",
        "-i", output_path,  # video-only file produced by OpenCV
        "-i", input_path,   # original file, may contain audio
        "-map", "0:v:0",
        "-map", "1:a:0",
        "-vcodec", "libx264",
        "-preset", "fast",
        "-crf", "23",
        "-c:a", "copy",
        tmp_path
    ]

    # Fallback command that does not attempt to copy audio (for audio-less inputs)
    cmd_no_audio = [
        "ffmpeg", "-y",
        "-i", output_path,
        "-vcodec", "libx264",
        "-preset", "fast",
        "-crf", "23",
        tmp_path
    ]

    try:
        try:
            subprocess.run(cmd_with_audio, check=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        except subprocess.CalledProcessError:
            # input likely has no audio stream or mapping failed; try without audio
            subprocess.run(cmd_no_audio, check=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        # move final encoded file into cache for future reuse
        shutil.move(tmp_path, str(cached_path))
        # ensure the requested output_path also exists for backward compatibility
        try:
            shutil.copyfile(str(cached_path), output_path)
        except Exception:
            pass
    except subprocess.CalledProcessError as e:
        err = e.stderr.decode("utf-8", errors="ignore") if e.stderr else str(e)
        st.error(f"ffmpeg re-encode failed: {err}")
        if os.path.exists(tmp_path):
            os.remove(tmp_path)
    progress.progress(1.0)
    return str(cached_path)



uploaded = st.columns([1,3,1])[1].file_uploader("Upload a traffic video", type=["mp4", "mov", "avi"])
tracker_yaml = "custom_tracker.yaml"

if uploaded:
    temp_input = tempfile.NamedTemporaryFile(delete=False, suffix=".mp4")
    temp_input.write(uploaded.read())
    input_video_path = temp_input.name
    two_cols = st.columns(3)
    with two_cols[0]:
        st.subheader("Input Video")
        st.video(input_video_path)
    with two_cols[2]:
        output_slot = st.container()

    with two_cols[1]:
        st.markdown("<div style='padding-top:150px;display:block;'></div>", unsafe_allow_html=True)
        st.info("Running YOLO mask tracking. Please wait...")

    temp_output = tempfile.NamedTemporaryFile(delete=False, suffix=".mp4")
    output_video_path = temp_output.name

    with two_cols[1]:
        processed_path = process_video(
            input_video_path,
            output_video_path,
            tracker_yaml
        )

    with output_slot:
        st.subheader(f"Processed Output Video")
        st.video(processed_path)
        download_name = f"{Path(getattr(uploaded, 'name', 'processed')).stem}_processed.mp4"
        with open(processed_path, "rb") as f:
            video_bytes = f.read()

        st.download_button(
            label="Download Processed Video",
            data=video_bytes,
            file_name=download_name,
            mime="video/mp4"
        )
