# herdr-translate

A [herdr](https://herdr.dev) plugin that translates text you select in a pane
with one key, and shows the result in a popup. It translates English to
Japanese by default.

There are two translation engines:

- `shortcuts` (default): macOS's built-in Translate, called from a Shortcuts
  shortcut (`/usr/bin/shortcuts run`). It is free, needs no API key, and works
  offline once the language data is downloaded.
- `deepl`: the [DeepL API](https://www.deepl.com/pro-api). It needs an API key;
  see [Using DeepL](#using-deepl).

macOS only. Requires herdr 0.9.5 or later.

## How it works

1. Select text in a pane with the mouse. With herdr's default
   `ui.copy_on_select = true`, the selection is copied to the clipboard when you
   release the mouse.
2. Press the key bound to the plugin action (for example `prefix+t`).
3. A popup shows the translation, followed by the original text.
   Press `q` to close it.

The action uses herdr's `selected_text` when a selection is still active at the
time of the key press (for example with `ui.copy_on_select = false`), and
otherwise the clipboard contents.

## Setup

### 1. Create the shortcut (once)

This step is needed for the `shortcuts` engine only. If you use DeepL, skip it
and see [Using DeepL](#using-deepl).

In the Shortcuts app, create a shortcut named `herdr-translate`:

1. Click `+` to create a new shortcut and rename it to `herdr-translate`.
2. Add the **Translate Text** action (テキストを翻訳).
   - Click the `Text` placeholder and choose **Shortcut Input** (ショートカットの入力).
   - Set the languages to **English** → **Japanese**.
3. Add the **Stop and Output** action (出力を停止して出力) and set its value to
   **Translated Text** (翻訳されたテキスト).
   Optionally set "If there's nowhere to output" to **Do Nothing**.

The finished shortcut looks like this:

```
Receive [Any] input from [Nowhere]
Translate [Shortcut Input] from [English] to [Japanese]
Stop and output [Translated Text]
```

Check it from a terminal:

```sh
printf 'Hello, world.\n' > /tmp/in.txt
shortcuts run herdr-translate -i /tmp/in.txt
```

For offline use, download English and Japanese under System Settings →
General → Language & Region → Translation Languages.

### 2. Install the plugin

```sh
git clone https://github.com/ryutaro-asada/herdr-translate.git ~/repos/herdr-translate
herdr plugin link ~/repos/herdr-translate
herdr plugin action list --plugin ryutaroasada.translate
```

There is nothing to build; the plugin is two shell scripts.

### 3. Bind a key

Add to `~/.config/herdr/config.toml`, then reload with `prefix+shift+r`
(or `herdr server reload-config`):

```toml
[[keys.command]]
key = "prefix+t"
type = "plugin_action"
command = "ryutaroasada.translate.translate"
description = "translate selection"
```

`prefix+t` is not used by herdr's default keybindings.

## Configuration

Settings are read from `config.toml` in the plugin config directory
(`herdr plugin config-dir ryutaroasada.translate`). The file and every key are
optional. For example, to use a shortcut with a different name:

```toml
shortcut = "My Translate"
```

| Key           | Default             | Description                                                     |
|---------------|---------------------|-----------------------------------------------------------------|
| `engine`      | `"shortcuts"`       | `"shortcuts"` (macOS Shortcuts) or `"deepl"` (DeepL API)        |
| `shortcut`    | `"herdr-translate"` | Name of the shortcut used by the `shortcuts` engine             |
| `source_lang` | `"EN"`              | DeepL source language code, or `"auto"` to let DeepL detect it  |
| `target_lang` | `"JA"`              | DeepL target language code (for example `DE`, `ZH`, `EN-US`)    |

`source_lang` and `target_lang` apply only to the `deepl` engine. They are
passed to DeepL as given; see DeepL's
[supported languages](https://developers.deepl.com/docs/getting-started/supported-languages).
An unsupported code makes DeepL return HTTP 400, and the popup shows DeepL's
message. With the `shortcuts` engine, change the languages in the shortcut's
Translate Text action in the Shortcuts app.

## Using DeepL

Set `engine = "deepl"` in `config.toml`:

```toml
engine = "deepl"
```

The API key is read from the `DEEPL_API_KEY` environment variable. It is not
stored in a file and there is no config key for it. Get a key from the
"API Keys" tab of your DeepL account and export it, for example in `~/.zshrc`:

```sh
export DEEPL_API_KEY="..."
```

Plugin commands inherit the environment of the herdr server process, not of
the shell you press the key in. Export the variable before the herdr server
starts, or restart the server after setting it.

Keys ending in `:fx` (DeepL API Free) are sent to
`https://api-free.deepl.com/v2/translate`; other keys (DeepL API Pro) to
`https://api.deepl.com/v2/translate`. The key is passed to `curl` on stdin, so
it does not appear in process listings.

The languages are set with `source_lang` and `target_lang`; see
[Configuration](#configuration).

If DeepL fails, the popup shows the error. It does not fall back to the `shortcuts` engine.

## Errors

The popup shows a message instead of a translation when:

- there is no selected text and the clipboard is empty,
- `engine` has an unknown value,
- with the `shortcuts` engine: the shortcut does not exist, or `shortcuts run`
  fails or returns no text,
- with the `deepl` engine: `DEEPL_API_KEY` is not set, DeepL cannot be
  reached, DeepL rejects the key (403), the quota is exceeded (456), there are
  too many requests (429), another HTTP error occurs such as an unsupported
  language code (the status and DeepL's message are shown), or the result is
  empty.

If the popup cannot open at all (herdr returns `ui_busy` while Settings, Copy
mode, or another modal is open), a herdr notification is shown instead.

## License

Apache-2.0. See [LICENSE](LICENSE).
