from pydantic import BaseModel, Field
from typing import List, Optional, Dict


class DiarizationSegment(BaseModel):
    id: str = Field(..., description="Unique segment id")
    speaker: str = Field(..., description="Speaker label or ID")
    start: float = Field(..., description="Start time in seconds")
    end: float = Field(..., description="End time in seconds")


class TranscriptSegment(BaseModel):
    id: str = Field(..., description="Unique segment id")
    speaker: str = Field(..., description="Speaker label or ID")
    start: float = Field(..., description="Start time in seconds")
    end: float = Field(..., description="End time in seconds")
    text: str = Field(..., description="Transcribed text for the segment")
    confidence: Optional[float] = Field(None, description="Optional confidence score")
    extras: Optional[Dict] = Field(None, description="Optional free-form metadata")


class Transcript(BaseModel):
    segments: List[TranscriptSegment] = Field(..., description="Ordered transcript segments")
    language: Optional[str] = Field(None, description="Detected or selected language code")
    duration: Optional[float] = Field(None, description="Total audio duration in seconds")
    metadata: Optional[Dict] = Field(None, description="Optional metadata about the recording")


class SummarySegment(BaseModel):
    id: str = Field(..., description="Segment id this summary refers to")
    summary: str = Field(..., description="Short summary for the segment")
    highlights: Optional[List[str]] = Field(None, description="Key highlights extracted from the segment")


class FinalSummary(BaseModel):
    title: Optional[str] = Field(None, description="Optional short title for the meeting summary")
    summary: str = Field(..., description="Final, human-readable meeting summary")
    collapsed: List[SummarySegment] = Field([], description="Collapsed per-segment summaries")
    action_items: Optional[List[str]] = Field(None, description="Extracted action items")
    key_takeaways: Optional[List[str]] = Field(None, description="Short list of key takeaways")
    metadata: Optional[Dict] = Field(None, description="Optional additional metadata")
