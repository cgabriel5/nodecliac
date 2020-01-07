# acmap README

This is the README for your extension "acmap". After writing up a brief description, we recommend including the following sections.

## Features

Describe specific features of your extension including screenshots of your extension in action. Image paths are relative to this README file.

For example if there is an image subfolder under your extension project workspace:

\!\[feature X\]\(images/feature-x.png\)

> Tip: Many popular extensions utilize animations. This is an excellent way to show off your extension! We recommend short, focused animations that are easy to follow.

## Requirements

If you have any requirements or dependencies, add a section describing those and how to install and configure them.

## Extension Settings

Include if your extension adds any VS Code settings through the `contributes.configuration` extension point.

For example:

This extension contributes the following settings:

* `myExtension.enable`: enable/disable this extension
* `myExtension.thing`: set to `blah` to do something

## Known Issues

Calling out known issues can help limit users opening duplicate issues against your extension.

## Release Notes

Users appreciate release notes as you update your extension.

### 1.0.0

Initial release of ...

### 1.0.1

Fixed issue #.

### 1.1.0

Added features X, Y, and Z.

-----------------------------------------------------------------------------------------------------------

## Working with Markdown

**Note:** You can author your README using Visual Studio Code.  Here are some useful editor keyboard shortcuts:

* Split the editor (`Cmd+\` on macOS or `Ctrl+\` on Windows and Linux)
* Toggle preview (`Shift+CMD+V` on macOS or `Shift+Ctrl+V` on Windows and Linux)
* Press `Ctrl+Space` (Windows, Linux) or `Cmd+Space` (macOS) to see a list of Markdown snippets

### For more information

* [Visual Studio Code's Markdown Support](http://code.visualstudio.com/docs/languages/markdown)
* [Markdown Syntax Reference](https://help.github.com/articles/markdown-basics/)

**Enjoy!**


# README
## This is the README for your extension "nucleus"
You can author your README using Visual Studio Code.  Here are some useful editor keyboard shortcuts:

* Split the editor (`Cmd+\` on macOS or `Ctrl+\` on Windows and Linux)
* Toggle preview (`Shift+CMD+V` on macOS or `Shift+Ctrl+V` on Windows and Linux)
* Press `Ctrl+Space` (Windows, Linux) or `Cmd+Space` (macOS) to see a list of Markdown snippets

### For more information
* [Visual Studio Code's Markdown Support](http://code.visualstudio.com/docs/languages/markdown)
* [Markdown Syntax Reference](https://help.github.com/articles/markdown-basics/)

**Enjoy!**


## Override scheme scopes/colors

For a better experience the following scheme scope overides should be applied. More information on customizing a color scheme [here](https://code.visualstudio.com/docs/getstarted/themes#_customizing-a-color-theme).

### Color Scheme override

**Basic example**

```js
"editor.tokenColorCustomizations": {
    "[Nucleus Theme]": {
        "comments": "#999999"
    }
},
```

**Advanced example**

```js
"editor.tokenColorCustomizations": {
  "[Nucleus Theme]": {
      "textMateRules": [
          {
              "scope": [
                  "source.acmap comment.line.number-sign.acmap",
              ],
              "settings": {
                  "foreground": "#999999"
              }
          },
          {
              "scope": [
                  "keyword.operator.assignment.multi-flag.acmap",
              ],
              "settings": {
                  "foreground": "#aa0c91"
              }
          }
      ]
  },
},

"workbench.colorCustomizations": {
  "[Nucleus Theme]": {
    "sideBar.background": "#ff0000",
  }
},
```

## Recommended settings for better experience

```js
{
    "editor.fontFamily": "ODejaVu Sans Mono", // Controls font family.
    "editor.lineHeight": 24, // Controls line height (use 0 to compute lineHeight using fontSize).
    "editor.fontLigatures": true, // Enables font ligatures.
    "explorer.decorations.badges": false // Controls whether decorations should use badges.
}
```



