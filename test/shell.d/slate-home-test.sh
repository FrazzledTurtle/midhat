#!/bin/bash

set -euo pipefail

source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/base-test.sh"

TMPDIR=$(mktemp -d)
trap 'rm -rf "$TMPDIR"' EXIT

H=$TMPDIR/home
mkdir -p "$H/.config/koreader" "$H/.local/share" "$H/Books/Lear.sdr" "$H/My PDFs" "$H/Notes"
touch "$H/Books/Lear.epub" "$H/My PDFs/Map of Berat.pdf" "$H/Books/old.pdf" "$H/Notes/Berat sketch.xopp" "$H/Notes/older.xopp"

cat >"$H/.config/koreader/history.lua" <<LUA
return {
    [1] = {
        ["file"] = "$H/.config/koreader/help/quickstart.html",
        ["time"] = 1800000300,
    },
    [2] = {
        ["file"] = "$H/Books/Lear.epub",
        ["time"] = 1800000200,
    },
    [3] = {
        ["file"] = "$H/Books/old.pdf",
        ["time"] = 1700000000,
    },
    [4] = {
        ["file"] = "$H/Books/gone.pdf",
        ["time"] = 1800000250,
    },
}
LUA

cat >"$H/Books/Lear.sdr/metadata.epub.lua" <<'LUA'
return {
    ["doc_pages"] = 428,
    ["doc_props"] = {
        ["authors"] = "Edward Lear",
        ["title"] = "Journals of a Landscape Painter in Albania",
    },
    ["last_page"] = 112,
    ["percent_finished"] = 0.26,
}
LUA

cat >"$H/.local/share/recently-used.xbel" <<XML
<xbel>
  <bookmark href="file://$H/My%20PDFs/Map%20of%20Berat.pdf" added="2027-01-01T00:00:00Z" modified="2027-01-15T08:00:00Z" visited="2027-01-15T08:00:00Z">
  <bookmark href="file://$H/Notes/older.xopp" added="2027-01-01T00:00:00Z" modified="2027-01-02T08:00:00Z" visited="2027-01-02T08:00:00Z">
  <bookmark href="file://$H/Notes/Berat%20sketch.xopp" added="2027-01-01T00:00:00Z" modified="2027-01-14T08:00:00Z" visited="2027-01-14T08:00:00Z">
</xbel>
XML

mkdir -p "$TMPDIR/bin"
printf '#!/bin/bash\nexit 1\n' >"$TMPDIR/bin/midhat-cmd-present"
chmod +x "$TMPDIR/bin/midhat-cmd-present"

json=$(HOME=$H XDG_DATA_DIRS="$TMPDIR/share" PATH="$TMPDIR/bin:$PATH" "$ROOT/bin/midhat-slate-home")

check() {
  local -a args=()
  while [[ $1 == --arg ]]; do
    args+=("$1" "$2" "$3")
    shift 3
  done
  jq -e "${args[@]}" "$1" <<<"$json" >/dev/null || fail "$2" "$json"
  pass "$2"
}

check '.book.title == "Journals of a Landscape Painter in Albania" and .book.author == "Edward Lear"' "home reads the book's title and author from its KOReader sidecar"
check '.book.page == 112 and .book.pages == 428 and .book.percent == 0.26' "home reads the book's progress"
check '.today.name == "Berat sketch"' "home picks the newest Xournal++ file as today's page"
check '[.pdfs[].name] == ["Map of Berat.pdf", "old.pdf"]' "home lists existing PDFs newest first, decoding file URLs and skipping missing files"

mkdir -p "$TMPDIR/share/applications"
touch "$TMPDIR/share/applications/org.midhat.Blloku.desktop"
json=$(HOME=$H XDG_DATA_DIRS="$TMPDIR/share" PATH="$TMPDIR/bin:$PATH" "$ROOT/bin/midhat-slate-home")
check --arg day "$(date +%F)" '.today.app == "blloku" and (.today.file | endswith("/Blloku/Ditari/" + $day + ".md")) and .today.time == null' \
  "with Blloku installed, today's page is Blloku's daily page, not started yet"
