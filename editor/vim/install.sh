#!/bin/bash
# Install the PLUM vim files into ~/.vim (or $1).
set -e

DEST="${1:-$HOME/.vim}"
HERE="$(cd "$(dirname "$0")" && pwd)"

mkdir -p "$DEST/syntax" "$DEST/ftdetect" "$DEST/ftplugin"

install -m 644 "$HERE/plum.vim"     "$DEST/syntax/plum.vim"
install -m 644 "$HERE/ftdetect.vim" "$DEST/ftdetect/plum.vim"
install -m 644 "$HERE/ftplugin.vim" "$DEST/ftplugin/plum.vim"

echo "installed into $DEST:"
echo "  syntax/plum.vim"
echo "  ftdetect/plum.vim"
echo "  ftplugin/plum.vim"
echo
echo "*.pl is shared with Perl, so PLUM is detected by content."
echo "To claim every *.pl unconditionally, add to your .vimrc:"
echo "    let g:plum_claim_pl = 1"
