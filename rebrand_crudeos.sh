#!/usr/bin/env bash
# CrudeOS branding upgrade for Project14
# Run this from the root of the Project14 repository.
#
# IMPORTANT:
# - Changes user-facing branding from "Alpine" to "CrudeOS".
# - Keeps Alpine technical identifiers (mirror URLs, apk, package names,
#   and ID_LIKE=alpine) because CrudeOS still uses Alpine as its base.
# - Creates backups before editing tracked text files.

set -euo pipefail

ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
cd "$ROOT"

STAMP="$(date +%Y%m%d-%H%M%S)"
BACKUP="$ROOT/.crudeos-backup-$STAMP"

echo "== CrudeOS branding upgrade =="
echo "Repository: $ROOT"
echo "Backup:     $BACKUP"
mkdir -p "$BACKUP"

# Files that are safe/appropriate to rewrite as branding/configuration.
FILES=(
  "README.md"
  "about.txt"
  "build_crude_os.sh"
  "build_crude_os_unprivileged.sh"
  "crude-os/README.md"
  "crude-os/scripts/build_crude_os.sh"
  "crude_os_build/setup_crude.sh"
)

for f in "${FILES[@]}"; do
  [[ -f "$f" ]] || continue
  mkdir -p "$BACKUP/$(dirname "$f")"
  cp -a "$f" "$BACKUP/$f"
done

# Generic human-facing wording.
# Deliberately NOT global-replacing URLs, package names, apk, or compatibility IDs.
python3 - "$ROOT" <<'PY'
from pathlib import Path
import re, sys

root = Path(sys.argv[1])

targets = [
    root / "README.md",
    root / "about.txt",
    root / "build_crude_os.sh",
    root / "build_crude_os_unprivileged.sh",
    root / "crude-os" / "README.md",
    root / "crude-os" / "scripts" / "build_crude_os.sh",
    root / "crude_os_build" / "setup_crude.sh",
]

replacements = [
    (r"Alpine Linux with XFCE4", "CrudeOS XFCE"),
    (r"Based on Alpine Linux", "CrudeOS Linux desktop"),
    (r"based on Alpine Linux", "based on the Alpine Linux base"),
    (r"Alpine-based XFCE ISO rebranded as [\"“]Crude OS[\"”]", "CrudeOS XFCE ISO"),
    (r"Download Alpine Linux miniroot", "Download CrudeOS base rootfs"),
    (r"Downloading Alpine Linux minirootfs", "Downloading CrudeOS base rootfs"),
    (r"Extracting Alpine base system", "Extracting CrudeOS base system"),
    (r"Base: Alpine Linux", "Base runtime: CrudeOS"),
    (r"Built with ❤️ using Alpine Linux as base", "Built with ❤️ as CrudeOS, using Alpine Linux as the upstream base"),
]

for path in targets:
    if not path.exists():
        continue
    text = path.read_text(encoding="utf-8")
    old = text
    for pattern, repl in replacements:
        text = re.sub(pattern, repl, text, flags=re.IGNORECASE)
    if text != old:
        path.write_text(text, encoding="utf-8")

# Improve the two main build scripts with consistent CrudeOS metadata.
for name in ("build_crude_os.sh", "build_crude_os_unprivileged.sh"):
    p = root / name
    if not p.exists():
        continue
    text = p.read_text(encoding="utf-8")
    text = text.replace('ISO_LABEL="CRUDE_OS"', 'ISO_LABEL="CRUDEOS"')
    text = text.replace('ISO_NAME="crude-os-xfce.iso"', 'ISO_NAME="crudeos-xfce.iso"')
    text = text.replace('echo "   Starting Crude OS Build Process"',
                        'echo "   Starting CrudeOS Build Process"')
    text = text.replace('echo "Starting Crude OS Build Process..."',
                        'echo "Starting CrudeOS Build Process..."')
    text = text.replace('echo "Crude OS system configured inside chroot."',
                        'echo "CrudeOS system configured inside chroot."')
    p.write_text(text, encoding="utf-8")

# Add a small machine-readable branding file so the OS has a single source
# of truth for its public identity.
branding = root / "crude-os" / "config" / "branding"
branding.mkdir(parents=True, exist_ok=True)
(branding / "crudeos-branding.conf").write_text(
    """# CrudeOS public branding
DISTRO_NAME="CrudeOS"
DISTRO_ID="crudeos"
DISTRO_CODENAME="Forge"
DISTRO_VERSION="1.0.0"
DISTRO_DESCRIPTION="A lightweight desktop Linux distribution built on the Alpine base."
DISTRO_URL="https://github.com/Dev-Mehraj/Project14"
""",
    encoding="utf-8",
)

# Add a consistent os-release fragment. Keep ID_LIKE=alpine for compatibility.
release_dir = root / "crude-os" / "config" / "branding"
(release_dir / "os-release.crudeos").write_text(
    """NAME="CrudeOS"
ID=crudeos
ID_LIKE=alpine
PRETTY_NAME="CrudeOS 1.0.0"
VERSION_ID="1.0"
VERSION="1.0.0 (Forge)"
HOME_URL="https://github.com/Dev-Mehraj/Project14"
BUG_REPORT_URL="https://github.com/Dev-Mehraj/Project14/issues"
SUPPORT_URL="https://github.com/Dev-Mehraj/Project14/issues"
""",
    encoding="utf-8",
)

print("Branding files updated.")
print("Technical Alpine references were intentionally preserved.")
PY

chmod +x build_crude_os.sh build_crude_os_unprivileged.sh 2>/dev/null || true
chmod +x crude-os/scripts/build_crude_os.sh 2>/dev/null || true
chmod +x crude_os_build/setup_crude.sh 2>/dev/null || true

echo
echo "Done."
echo "Review with:"
echo "  git diff -- . ':!build_log.txt'"
echo
echo "To restore the previous files:"
echo "  cp -a \"$BACKUP\"/. \"$ROOT\"/"
