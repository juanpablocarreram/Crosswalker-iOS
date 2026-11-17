"""Export named UI captures and the summary from a successful XCTest run."""
import json
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile

root = Path(__file__).resolve().parents[1]
result = Path(sys.argv[1]).resolve()
kind = sys.argv[2]
if kind not in ("ios", "compact"):
    raise SystemExit("Use ios or compact as the destination.")
runtime = root / "Documentation/verification/runtime"
summary = json.loads(subprocess.check_output([
    "xcrun", "xcresulttool", "get", "test-results", "summary", "--path", str(result)
]))
if summary.get("failedTests", 0) or not summary.get("passedTests", 0):
    raise SystemExit("Refusing to label a failing or empty run as final evidence.")
folder = runtime / kind
folder.mkdir(parents=True, exist_ok=True)
(runtime / f"{kind}-summary.json").write_text(json.dumps(summary, indent=2) + "\n")
captures = []
with tempfile.TemporaryDirectory(prefix="crosswalker-captures-") as temporary:
    subprocess.run([
        "xcrun", "xcresulttool", "export", "attachments", "--path", str(result),
        "--output-path", temporary
    ], check=True, stdout=subprocess.DEVNULL)
    source = Path(temporary)
    for test in json.loads((source / "manifest.json").read_text()):
        for attachment in test["attachments"]:
            name = attachment["suggestedHumanReadableName"]
            key = name.split("_")[0]
            if name.endswith(".png") and key.startswith((
                "home", "tutorial-", "level-", "simulation-", "unsafe-", "collision-",
                "retry-", "persisted-", "credits-"
            )):
                shutil.copy(source / attachment["exportedFileName"], folder / f"{key}.png")
                captures.append({"file": f"{key}.png", "test": test["testIdentifier"]})
(folder / "captures.json").write_text(json.dumps(captures, indent=2) + "\n")
print(f"Exported {len(list(folder.glob('*.png')))} captures for {kind}.")
