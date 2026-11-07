#!/bin/sh
# Translates $HERDR_TRANSLATE_INPUT with a macOS Shortcut or DeepL and shows the result.
set -u

default_shortcut="herdr-translate"
config="$HERDR_PLUGIN_CONFIG_DIR/config.toml"
output="$HERDR_PLUGIN_STATE_DIR/output.txt"
page="$HERDR_PLUGIN_STATE_DIR/page.txt"
input=${HERDR_TRANSLATE_INPUT:-}

config_value() {
  if [ -f "$config" ]; then
    sed -n "s/^[[:space:]]*$1[[:space:]]*=[[:space:]]*\"\(.*\)\"[[:space:]]*\$/\1/p" "$config" | head -n 1
  fi
}

shortcut=$(config_value shortcut)
shortcut=${shortcut:-$default_shortcut}
engine=$(config_value engine)
engine=${engine:-shortcuts}

show() {
  printf '%s\n' "$1" > "$page"
  LESSCHARSET=utf-8 less -c -P'q で閉じる' "$page"
  rm -f "$page"
  exit 0
}

show_result() {
  show "$(cat "$output")

────────────────────────────────
$(cat "$input")"
}

translate_deepl() {
  if [ -z "${DEEPL_API_KEY:-}" ]; then
    show "環境変数 DEEPL_API_KEY が設定されていません。

プラグインは herdr サーバーの環境変数を引き継ぎます。
~/.zshrc などで export DEEPL_API_KEY=... を設定してから
herdr サーバーを起動 (起動中なら再起動) してください。"
  fi
  case $DEEPL_API_KEY in
    *:fx) url="https://api-free.deepl.com/v2/translate" ;;
    *) url="https://api.deepl.com/v2/translate" ;;
  esac

  printf '翻訳中...\n'
  request="$HERDR_PLUGIN_STATE_DIR/request.json"
  response="$HERDR_PLUGIN_STATE_DIR/response.json"
  curl_err="$HERDR_PLUGIN_STATE_DIR/curl-error.txt"
  rm -f "$output" "$response"
  umask 077
  /usr/bin/jq -n --rawfile text "$input" \
    '{text: [$text], source_lang: "EN", target_lang: "JA"}' > "$request"
  # The key goes through a curl config on stdin so it never appears in argv.
  http_code=$(printf 'header = "Authorization: DeepL-Auth-Key %s"\n' "$DEEPL_API_KEY" |
    /usr/bin/curl -sS -K - --max-time 30 -X POST \
      -H 'Content-Type: application/json' --data-binary "@$request" \
      -o "$response" -w '%{http_code}' "$url" 2>"$curl_err")
  status=$?
  err=$(cat "$curl_err" 2>/dev/null)
  rm -f "$request" "$curl_err"
  if [ "$status" -ne 0 ]; then
    rm -f "$response"
    show "DeepL に接続できませんでした (curl 終了コード ${status})。

${err}"
  fi

  message=$(/usr/bin/jq -r '.message // empty' "$response" 2>/dev/null)
  case $http_code in
    2??) /usr/bin/jq -r '.translations[0].text // empty' "$response" > "$output" 2>/dev/null ;;
  esac
  rm -f "$response"
  case $http_code in
    2??)
      if ! grep -q '[^[:space:]]' "$output" 2>/dev/null; then
        show "DeepL の翻訳結果が空でした。"
      fi
      ;;
    403)
      show "DeepL が API キーを拒否しました (HTTP 403)。

DEEPL_API_KEY の値を確認してください。
Free プランのキーは末尾が :fx です。"
      ;;
    456)
      show "DeepL の文字数上限に達しました (HTTP 456)。

DeepL のアカウントで使用量を確認してください。"
      ;;
    429)
      show "DeepL へのリクエストが多すぎます (HTTP 429)。

しばらく待ってから再実行してください。"
      ;;
    *)
      show "DeepL の翻訳に失敗しました (HTTP ${http_code})。

${message}"
      ;;
  esac
}

case $engine in
  shortcuts | deepl) ;;
  *)
    show "engine の値「${engine}」は使えません。

$config
の engine には \"shortcuts\" か \"deepl\" を設定してください。"
    ;;
esac

if [ -z "$input" ] || ! grep -q '[^[:space:]]' "$input" 2>/dev/null; then
  show "翻訳するテキストがありません。

ペインで英文をマウスで選択してから実行してください。"
fi

if [ "$engine" = deepl ]; then
  translate_deepl
  show_result
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

show_result
