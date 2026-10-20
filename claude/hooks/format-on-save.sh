#!/usr/bin/env bash
set -euo pipefail
. "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/config/hook-utils.sh"
is_hook_disabled "disableFormatOnSave" && exit 0

f=$(jq -r '.tool_response.filePath // .tool_input.file_path')
[ -z "$f" ] || [ "$f" = "null" ] && exit 0
[ -f "$f" ] || exit 0

# Delegate to the standalone formatter (shared with external worker harnesses)
_hooks_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
_fmt="$_hooks_dir/../bin/format-file"
[[ -x "$_fmt" ]] && exec "$_fmt" "$f"
exit 0
