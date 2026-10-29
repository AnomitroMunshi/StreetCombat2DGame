"""Encode generated gameplay captures; requires imageio-ffmpeg."""
from pathlib import Path
import subprocess
import imageio_ffmpeg

review = Path(__file__).resolve().parents[1] / "docs/reviews/capoeira-jkd"
(review / "clips").mkdir(exist_ok=True)
ffmpeg = imageio_ffmpeg.get_ffmpeg_exe()
for side in ("right", "left"):
    subprocess.run([
        ffmpeg, "-y", "-loglevel", "error", "-i", str(review / f"gameplay_{side}.avi"),
        "-c:v", "libx264", "-crf", "21", "-pix_fmt", "yuv420p", "-c:a", "aac",
        str(review / "clips" / f"gameplay_{side}.mp4"),
    ], check=True)
