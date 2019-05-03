# nodecliac

##### Table of Contents

- [Overview](#overview)
- [Install](#install)
- [How It Works](#how-it-works)
- [ACMAP Format/Syntax](#acmap-format-syntax)
- [Examples](#examples)
- [API](#API)
- [CLI](#cli)
- [CLI Usage](#cli-usage-examples)
- [Support](#support)
- [Contributing](#contributing)
- [License](#license)

<a name="overview"></a>

### Overview

nodecliac is a simple definition based bash auto-completion tool originally made in mind for node (Node.js) apps. However, as development continued it proved useful for non-node CLI apps as well.

<a name="install"></a>

### Install

Download/clone the repo somewhere on your machine. Preferably to your desktop. Once download, `cd` into the project directory and setup the project with `yarn` or `npm` to download project dependencies. Finally, while in the project root, run `nodecliac setup` to setup nodecliac. The following commands shows how to install nodecliac.

<details>
  <summary>Requirements</summary>

- Node.js `8+`
- Perl `5+`
- Bash `4.3+`
  - `macOS`, by default, comes with with Bash `3.2` so please update it.
    - [Homebrew](https://brew.sh/) can be used to [update bash](https://akrabat.com/upgrading-to-bash-4-on-macos/).
      </details>

```sh
# Go to desktop.
$ cd ~/Desktop

# Clone repo to desktop.
$ git clone https://github.com/cgabriel5/nodecliac.git

# cd into project directory.
$ cd nodecliac

# Setup repo with yarn...
$ yarn install
# ...or with npm.
$ npm install

# Finally, install nodecliac.
$ nodecliac setup
```

<a name="how-it-works"></a>

### How It Works

nodecliac uses 2 custom file formats: `auto-completion definition` (`.acdef`) and `auto-completion map` (`.acmap`). The idea here is you create an `.acmap` file to map your app's CLI commands/subcommands with their respective flags. You then pass your `mycommand.acmap` file to nodecliac to generate an `.acdef` file all from the command line. This auto-completion definition file (i.e. `mycommand.acdef`) can then be used by nodecliac to provide CLI tab auto-completion for your app.

<a name="acmap-format-syntax"></a>

### ACMAP Format/Syntax

<details>
  <summary>ACMAP files are text files with a simple language structure and relatively few language constructs.</summary>

#### Comments

- Comments are identified by a number-sign followed by a single whitespace character (tab or space) (<code># </code>).
- Any amount of whitespace indentation can precede the comment.
- Comments must be on their own line.
- Multi-line comments do not exist and trailing comments are invalid.

```acmap
# The space after '#' is required.
  # Starting white space is perfectly fine.
```

#### Settings

- Settings start off with an at-sign (`@`) followed by the setting name.
- Setting values are assigned with `=` followed by the setting value.
- Any amount of whitespace before and after `=` is fine, but keep things tidy.
- No amount of indentation can precede a setting declaration.
- To be clear, settings can be declared _anywhere_ within your `.acmap` file but to quickly see what settings are being declared they should be placed at the top of the file.

```acmap
# It is ok to have comments before settings.
@default = "default"
@filedir=true
@disable    =   false
```

#### Command Chains

- Your program's commands/subcommands should be thought of as a chain which reads from left to right.
- It starts with your CLI program's name, is followed by any commands/subcommands, and is dot (`.`) delimited.
- If a subcommand happens to use a dot then simply escape the dot.
- Non escaped dots will be used as delimiters.
- No amount of indentation can precede a command chain.

Say your app's CLI program name is `mycliprogram` and it has 2 commands `install` and `uninstall`. Your `mycliprogram.acmap` file will look like:

```acmap
mycliprogram.install
mycliprogram.uninstall
```

#### Flags

To define flags we need to add to the [command chain](#command-chains) syntax.

- Flags are wrapped with `= [` and a closing `]`.
- The `= [` must be on the same line of the command chain.
- The closing `]` must be on its own line and can have any amount of indentation.

Using the example from the [command chain](#command-chains) section, say the `install` command has the flags: `destination/d` and `force/f`. ACMAP can be updated to:

```acmap
mycliprogram.install = [
  --destination
  -d
  --force
  -f
]
mycliprogram.uninstall
```

<details>
  <summary>Show flag variations</summary>

#### Flags (user input)

- If flag requires user input append `=` to the flag.

```acmap
mycliprogram.command = [
  --flag=
]
```

#### Flags (boolean)

- If flag does not require input and is more a switch (yes/no boolean) then append `?` to the flag.
- Though not required, doing so will let the auto-completion engine know the flag does not require value auto-completion.

```acmap
mycliprogram.command = [
  --flag?
]
```

#### Flags (multi-flag)

- Sometimes a flag can be supplied multiple times.
- Let the auto-completion engine know this by using the multi-flag indicator `*`.

```acmap
mycliprogram.command = [
  # Allow user to provide multiple file paths.
  --file=*

  # Hard-coded values.
  --colors=*(red green yellow)
]
```

#### Flags Values (one liner)

- This method should be used when the flag value list is short.
- Otherwise the long form method should be used.
- **Note**: Values must be delimited with spaces.
- **Note**: When a flag has many values a [long form list](#flags-values-long-form) should be used for clarities sake.

```acmap
mycliprogram.command = [
  # Supplied 1, "2", false, 4 as hard-coded values.
  --flag=(1 "2" false 4)

  # If multiple values can be supplied to program use the multi-flag indicator '*'.
  # This will allow --flag to be used multiple times until all values have been used.
  --flag=*(1 "2" false 4)
]
```

<a name="flags-values-long-form"></a>

#### Flags Values (long form)

- Flag long form list are wrapped with `=(` and a closing `)`.
- The `=(` must be on the same line as the flag.
- The closing `)` must be on its own line and can have any amount of indentation.
- A flag value option starts with <code>- </code> (a hyphen + a space) followed by the value.
- Any amount of whitespace indentation can precede the flag value option <code>- </code> sequence.

```acmap
mycliprogram.command = [
  --flag=(
    - 1
    - "2"
    - false
    - 4
  )

  # Allow flag to be used multiple times.
  --flag=*(
    - 1
    - "2"
    - false
    - 4
  )
]
mycliprogram.uninstall
```

#### Flags (dynamic values)

Sometimes hard-coded values are not enough so a `command-flag` can be used. A `command-flag` runs a command that expects output. By default the returned command's output expects each completion item to be on its own line (newline delimited list). However, if you need to change the delimiter character to a space, hyphen, etc. then simply add the delimiter character to the command flag. The syntax for a `command-flag` is as follows:

- `$("cat ~/colors.text")`: Will run command and split output on newlines to get individual options.
- `$("cat ~/colors.text", " ")`: Will run command and split output on spaces to get individual options.

If the command requires arguments they can be hard-coded or dynamically supplied.

- `$("cat ~/colors.text", "!red", $"cat ~/names.text", "-")`: This will provide the hard-coded `!red` value and run the `cat ~/names.text` flag command argument. Once all dynamic arguments are ran their outputs along with the hard-coded values are passed to the command `cat ~/colors.text` in the order they were provided. So `!red` will be argument `0` and the output of `cat ~/names.text` will be argument `1`.
- Once `cat ~/colors.text` is ran the output will be split by hyphens and will finally get passed to the auto-completion engine.
- **Note**: Arguments prefixed with the `$` character denotes it's a dynamic flag command argument.

**Escaping**: Internally the following characters have special uses: `$` and `|`. This means that when using these characters inside a command they will have to be escaped. Take the following examples:

- `--flag=$("echo \$0-\$1", $"echo 'john'", "doe", "-")`: The `$`s in the command are escaped.
- `--flag=$("nodecliac list \| grep -oP \"(?<=─ )([-a-z]*)\"")`: Here the `|` gets escaped as well.

```acmap
mycliprogram.command = [
  # The '*' denotes the flag is a multi-flag meaning it can be used/supplied to program multiple times.
  --flag=*
  --flag=(
    # The flag-command's output will be used as option values.
    - $("cat ~/values.text")

    # Hard coded and dynamically generated values will be supplied to auto-completion script.
    - index.js
    - ':task:js'
    - "some-thing"
  )

  # flag above can be shortened to:
  --flag=*(
    - index.js
    - ':task:js'
    - "some-thing"
    - $("cat ~/file.text")
  )
]
mycliprogram.uninstall
```

</details>

### Miscellaneous

#### Blank Lines

Blank lines (empty lines) are allowed and ignored when generating `.acdef` file.

#### Duplicate Command Chains/Flags/Settings

Though allowed the parser will warn when duplicate command chains/flags/settings are detected.

#### Indentation

Indentation is all allowed but when declaring command chains and settings.

</details>

<a name="examples"></a>

### Examples

<details><summary>Show examples</summary>

#### Sublime Text ACMAP

The following represents `subl.acmap`, the Sublime Text nodecliac auto-completion map file.

```acmap
subl = [
  --project
  --command
  --new-window?
  --add
  --wait?
  --background?
  --help?
  --version?
]
```

#### nodecliac ACMAP

**One liner**: The following represents `nodecliac.acmap`, the nodecliac auto-completion map file.

```acmap
nodecliac = --version?
nodecliac.setup = --rcfilepath|--force?
nodecliac.uninstall = --rcfilepath
nodecliac.list
nodecliac.make = --add?|--force?|--source|--save?|--print?|--highlight?|--trace?|--nowarn?
nodecliac.status = --enable?|--disable?
nodecliac.format = --indent|--source|--save?|--print?|--highlight?|--strip-comments?|--trace?|--nowarn?
nodecliac.print = --command=|--command=$("for f in ~/.nodecliac/defs/*; do echo \"\${f##*/}\"; done;")
```

**Long form**: Verbose `nodecliac.acmap` alternative. Although verbose this is effectively the same as above. You can pick which to use or settle on a mixture of both.

```acmap
nodecliac = [
  --version?
]
nodecliac.setup = [
  --rcfilepath
  --force?
]
nodecliac.uninstall = [
  --rcfilepath
]
nodecliac.list
nodecliac.make = [
  --add?
  --force?
  --source
  --save?
  --print?
  --highlight?
  --trace?
  --nowarn?
]
nodecliac.status = [
  --enable?
  --disable?
]
nodecliac.format = [
  --indent
  --source
  --save?
  --print?
  --highlight?
  --strip-comments?
  --trace?
  --nowarn?
]
nodecliac.print = [
  --command=
  --command=$("for f in ~/.nodecliac/defs/*; do echo \"\${f##*/}\"; done;")
]
```

</details>

<a name="API"></a>

### API

Currently nodecliac is only a CLI tool.

<a name="cli"></a>

### CLI

<details>
  <summary>Show commands/flags.</summary>

- `format`: Prettifies `.acmap` file.
  - `--highlight`: Syntax highlight output.
  - `--nowarn`: Don't print parser warnings.
  - `--save`: Overwrite source file with prettified output
  - `--strip-comments`: Remove all comments from final output.
  - `--indent` (**required**): Formatting indentation information can be provided like:
    - `s` for spaces or `t` for tabs followed by `:<NUMBER>`.
    - `t:1`: Use 1 tab per indentation level.
    - `s:2`: Use 2 spaces per indentation level.
  - `--print`: Print output to console.
  - `--source` (**required**): The `.acmap` file path.
  - `--trace`: Used for debugging purposes only.
- `list`: Lists installed auto-completion definition files (`.acdef`).
- `make`: Generate `.acdef` file from an `.acmap` file.
  - `--add`: Add generated `.acdef` file to nodecliac auto-completion registry.
  - `--highlight`: Syntax highlight output.
  - `--print`: Print output to console.
  - `--source` (**required**): The `.acmap` file path.
  - `--force`: If an `.acdef` file exists for the command then this flag is needed to overwrite old `.acdef` file.
  - `--nowarn`: Don't print parser warnings.
  - `--save`: Will save generated `.acdef` file to source location.
  - `--trace`: Used for debugging purposes only.
- `print`: Simple command used to showcase nodecliac's ability to generate dynamic flag option values on-the-fly.
  - `--command=`: The file to print (list dynamically generated based on available files in registry).
- `setup`: Installs and setups nodecliac.
  - `--force`: If nodecliac is already installed this flag is needed for overwrite old install.
  - `--rcfilepath`: By default setup will look for `~/.bashrc` to add modifications to. Supply the path to another rc file if you don't want changes to be made to `~/.bashrc`.
  - To be transparent this is what gets added the your rc file:
    - `ncliac=~/.nodecliac/src/main.sh;if [ -f "$ncliac" ];then source "$ncliac";fi;`
    - The line will load the file `~/.nodecliac/src/main.sh` if it exists. `main.sh` registers all `~/.nodecliac/defs/*.acdef` files with the auto-completion script to work with bash-completion.
- `status`: Checks whether nodecliac is enabled/disabled.
  - `--enable`: Enables nodecliac if disabled.
  - `--disable`: Disables nodecliac if enabled.
- `uninstall`: Uninstalls nodecliac/reverts rc file changes.
  - `--rcfilepath`: rc file used in setup to remove changes from.
    </details>

<a name="cli-usage-examples"></a>

### CLI Usage Examples

#### Generate ACDEF file

```sh
# Generate mycliprogram.acdef file and add it to registry.
$ nodecliac make --source path/to/mycliprogram.acmap --add

# Generate mycliprogram.acdef contents but only print to terminal and add syntax highlighting for clarity.
$ nodecliac make --source path/to/mycliprogram.acmap --print --highlight
```

#### Prettify ACMAP file

```sh
# Prettify mycliprogram.acmap file using 2 spaces per indentation level and log/highlight output.
$ nodecliac format --source path/to/mycliprogram.acmap --print --highlight --indent "s:2"

# As above but overwrite source file with prettified output.
$ nodecliac format --source path/to/mycliprogram.acmap --print --highlight --indent "s:2" --save
```

<a name="support"></a>

### Support

#### OS Support

- Made using Node.js `v8.16.0` on a Linux machine running `Ubuntu 16.04.5 LTS`.
- Tested and working on:
  - `macOS Mojave (v10.14.4)`.
  - `Windows 10 - Untested`.

#### Shell Support

- nodecliac only works with Bash, seeing that it is the only shell I use. However, if the project grows support for other shells (Zsh, Fish, etc.) could be added.

#### Editor Support (Syntax Highlighting)

- I use Sublime Text and have created a language syntax file (`acmap.sublime-syntax`) for it. It can be accessed in the `resources/sublime-text/Auto Completion Map (acmap)` folder. Download the folder and place it in the `User/` folder for Sublime Text to pickup. Personally, I have it stored like so: `/User/Languages/Auto Completion Map (acmap)`.
- Support for other editors can also be added if the project grows.

<a name="contributing"></a>

### Contributing

Contributions are welcome! Found a bug, feel like documentation is lacking/confusing and needs an update, have performance/feature suggestions or simply found a typo? Let me know! :)

See how to contribute [here](/CONTRIBUTING.md).

<a name="license"></a>

### License

This project uses the [MIT License](/LICENSE.txt).
