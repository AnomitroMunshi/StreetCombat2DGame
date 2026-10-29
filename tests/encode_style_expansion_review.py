"""Encode generated gameplay captures; requires imageio-ffmpeg."""
from pathlib import Path
import subprocess
import sys
import imageio_ffmpeg

review = Path(sys.argv[1]).resolve() if len(sys.argv) > 1 else Path(__file__).resolve().parents[1] / "docs/reviews/capoeira-jkd"
(review / "clips").mkdir(exist_ok=True)
ffmpeg = imageio_ffmpeg.get_ffmpeg_exe()
for source in review.glob("*.avi"):
    subprocess.run([
        ffmpeg, "-y", "-loglevel", "error", "-i", str(source),
        "-c:v", "libx264", "-crf", "21", "-pix_fmt", "yuv420p", "-c:a", "aac",
        str(review / "clips" / (source.stem + ".mp4")),
    ], check=True)
