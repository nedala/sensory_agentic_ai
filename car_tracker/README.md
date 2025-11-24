# Car Tracking Demo (YOLO + Streamlit)

This demo shows how real-time computer vision can detect and track cars in video.
You upload a traffic clip, and the app automatically:

* Detects each car
* Segments the car shape (mask)
* Tracks each car across frames
* Assigns each car a **unique tracker ID**
* Overlays colored masks and labels onto the video
* Produces a clean, playable MP4 result

The interface displays both the **original video** and the **processed output** for easy comparison.

---

## What This Demo Shows

This project highlights modern vision capabilities:

**Segmentation**
Each car is outlined using a pixel-accurate mask, not just a bounding box.

**Tracking**
Cars maintain consistent IDs across the entire video, even when crossing paths.

**Labeling**
Every mask includes a readable ID label placed directly on the object.

**Efficient Processing**
The app uses GPU acceleration (optional) and optimized encoding to produce smooth results.

**Caching**
If the same video is uploaded again, the processed output can be reused.

---

## How to Use

1. Run the app (see instructions below).
2. Drag-and-drop or browse to upload a traffic video (MP4, MOV, AVI).
3. Wait for the progress indicator while the video is processed.
4. Watch the output video in the right-hand panel.
5. Download the processed video if desired.

Supported video formats:

* MP4
* MOV
* AVI
* MPEG4

Recommended input resolution: **720p or 1080p**.
