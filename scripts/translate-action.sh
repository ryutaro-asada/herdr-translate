#!/bin/sh
# Collects the text to translate and opens the result popup.
set -u

herdr=${HERDR_BIN_PATH:-herdr}
input="$HERDR_PLUGIN_STATE_DIR/input.txt"

# selected_text is only set while a selection is still retained when the key
# is pressed. With ui.copy_on_select = true (the default) herdr copies and
# clears the selection on mouse release, so fall back to the clipboard.
text=$(printf '%s' "${HERDR_PLUGIN_CONTEXT_JSON:-}" | /usr/bin/jq -r '.selected_text // empty' 2>/dev/null)
if [ -z "$text" ]; then
  text=$(/usr/bin/pbpaste)
fi

umask 077
printf '%s\n' "$text" > "$input"

if ! "$herdr" plugin pane open --plugin "$HERDR_PLUGIN_ID" --entrypoint result \
  --env "HERDR_TRANSLATE_INPUT=$input" >/dev/null 2>&1; then
  # Popups are refused (ui_busy) while Settings, Copy mode, or another modal is open.
  "$herdr" notification show "herdr-translate" \
    --body "翻訳結果を表示できませんでした。Copy mode などを閉じてから再実行してください。" >/dev/null 2>&1
  exit 1
fi
