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
source_lang=$(config_value source_lang)
source_lang=${source_lang:-EN}
target_lang=$(config_value target_lang)
target_lang=${target_lang:-JA}

show() {
  printf '%s\n' "$1" > "$page"
  LESSCHARSET=utf-8 less -c -P'q to close' "$page"
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
    show "DEEPL_API_KEY is not set.

Plugins inherit the environment of the herdr server.
Export DEEPL_API_KEY (for example in ~/.zshrc), then start
the herdr server, or restart it if it is already running."
  fi
  case $DEEPL_API_KEY in
    *:fx) url="https://api-free.deepl.com/v2/translate" ;;
    *) url="https://api.deepl.com/v2/translate" ;;
  esac

  printf 'Translating...\n'
  request="$HERDR_PLUGIN_STATE_DIR/request.json"
  response="$HERDR_PLUGIN_STATE_DIR/response.json"
  curl_err="$HERDR_PLUGIN_STATE_DIR/curl-error.txt"
  rm -f "$output" "$response"
  umask 077
  # source_lang "auto" omits the field so DeepL detects the language.
  /usr/bin/jq -n --rawfile text "$input" --arg source "$source_lang" --arg target "$target_lang" \
    '{text: [$text], target_lang: $target} + (if $source == "auto" then {} else {source_lang: $source} end)' \
    > "$request"
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
    show "Could not connect to DeepL (curl exit code ${status}).

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
        show "DeepL returned an empty translation."
      fi
      ;;
    403)
      show "DeepL rejected the API key (HTTP 403).

Check the value of DEEPL_API_KEY.
DeepL API Free keys end with :fx."
      ;;
    456)
      show "DeepL character quota exceeded (HTTP 456).

Check your usage in your DeepL account."
      ;;
    429)
      show "Too many requests to DeepL (HTTP 429).

Wait a moment and try again."
      ;;
    *)
      show "DeepL translation failed (HTTP ${http_code}).

${message}"
      ;;
  esac
}

case $engine in
  shortcuts | deepl) ;;
  *)
    show "Unknown engine \"${engine}\".

Set engine in
$config
to \"shortcuts\" or \"deepl\"."
    ;;
esac

if [ -z "$input" ] || ! grep -q '[^[:space:]]' "$input" 2>/dev/null; then
  show "No text to translate.

Select text in a pane with the mouse, then try again."
fi

if [ "$engine" = deepl ]; then
  translate_deepl
  show_result
fi

if ! /usr/bin/shortcuts list | grep -Fqx -- "$shortcut"; then
  show "Shortcut \"${shortcut}\" not found.

Create it as described in the README, or set shortcut in
$config
to the name of an existing shortcut."
fi

printf 'Translating...\n'
rm -f "$output"
umask 077
# public.utf8-plain-text makes `shortcuts run` crash with SIGBUS on macOS 26;
# public.plain-text is written as UTF-8.
err=$(/usr/bin/shortcuts run "$shortcut" -i "$input" -o "$output" \
  --output-type public.plain-text 2>&1)
status=$?
if [ "$status" -ne 0 ]; then
  show "Translation failed (shortcut \"${shortcut}\", exit code ${status}).

${err}"
fi
if ! grep -q '[^[:space:]]' "$output" 2>/dev/null; then
  show "The translation was empty (shortcut \"${shortcut}\").

Check that the shortcut's Translate Text action uses
Shortcut Input, and that it ends with Stop and Output
returning the translated text."
fi

show_result
