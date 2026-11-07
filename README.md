# herdr-translate

A [herdr](https://herdr.dev) plugin that translates English text you select in a
pane into Japanese with one key, and shows the result in a popup.

Translation runs through macOS's built-in Translate, called from a Shortcuts
shortcut (`/usr/bin/shortcuts run`). It is free, needs no API key, and works
offline once the language data is downloaded.

macOS only. Requires herdr 0.9.5 or later.

## How it works

1. Select text in a pane with the mouse. With herdr's default
   `ui.copy_on_select = true`, the selection is copied to the clipboard when you
   release the mouse.
2. Press the key bound to the plugin action (for example `prefix+t`).
3. A popup shows the Japanese translation, followed by the original text.
   Press `q` to close it.

The action uses herdr's `selected_text` when a selection is still active at the
time of the key press (for example with `ui.copy_on_select = false`), and
otherwise the clipboard contents.

## Setup

### 1. Create the shortcut (once)

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

To use a shortcut with a different name, create `config.toml` in the plugin
config directory (`herdr plugin config-dir ryutaroasada.translate`):

```toml
shortcut = "My Translate"
```

## Errors

The popup shows a message instead of a translation when:

- there is no selected text and the clipboard is empty,
- the shortcut does not exist,
- `shortcuts run` fails or returns no text.

If the popup cannot open at all (herdr returns `ui_busy` while Settings, Copy
mode, or another modal is open), a herdr notification is shown instead.

## License

Apache-2.0. See [LICENSE](LICENSE).
