#!/bin/sh
# Translates $HERDR_TRANSLATE_INPUT with a macOS Shortcut and shows the result.
set -u

default_shortcut="herdr-translate"
config="$HERDR_PLUGIN_CONFIG_DIR/config.toml"
output="$HERDR_PLUGIN_STATE_DIR/output.txt"
page="$HERDR_PLUGIN_STATE_DIR/page.txt"
input=${HERDR_TRANSLATE_INPUT:-}

shortcut=""
if [ -f "$config" ]; then
  shortcut=$(sed -n 's/^[[:space:]]*shortcut[[:space:]]*=[[:space:]]*"\(.*\)"[[:space:]]*$/\1/p' "$config" | head -n 1)
fi
shortcut=${shortcut:-$default_shortcut}

show() {
  printf '%s\n' "$1" > "$page"
  LESSCHARSET=utf-8 less -c -P'q で閉じる' "$page"
  rm -f "$page"
  exit 0
}

if [ -z "$input" ] || ! grep -q '[^[:space:]]' "$input" 2>/dev/null; then
  show "翻訳するテキストがありません。

ペインで英文をマウスで選択してから実行してください。"
fi

if ! /usr/bin/shortcuts list | grep -Fqx -- "$shortcut"; then
  show "ショートカット「${shortcut}」が見つかりません。

README の手順でショートカットを作成するか、
$config
の shortcut に既存のショートカット名を設定してください。"
fi

printf '翻訳中...\n'
rm -f "$output"
umask 077
# public.utf8-plain-text makes `shortcuts run` crash with SIGBUS on macOS 26;
# public.plain-text is written as UTF-8.
err=$(/usr/bin/shortcuts run "$shortcut" -i "$input" -o "$output" \
  --output-type public.plain-text 2>&1)
status=$?
if [ "$status" -ne 0 ]; then
  show "翻訳に失敗しました (ショートカット「${shortcut}」、終了コード ${status})。

${err}"
fi
if ! grep -q '[^[:space:]]' "$output" 2>/dev/null; then
  show "翻訳結果が空でした (ショートカット「${shortcut}」)。

ショートカットが「テキストを翻訳」(Translate) の入力に
「ショートカットの入力」(Shortcut Input) を使い、最後に
「出力を停止して出力」(Stop and output) で翻訳結果を返しているか確認してください。"
fi

show "$(cat "$output")

────────────────────────────────
$(cat "$input")"
