# nodecliac

Easily add Bash completion to CLI programs with nodecliac (**node**-**cli**-**a**uto-**c**ompletion).

<p align="center"><img src="./resources/images/nodecliac-completion.gif?raw=true" alt="nodecliac completion" title="nodecliac completion" width="auto"></p>

##### Table of Contents

- [Install](#install-normal)
- [How It Works](#how-it-works)
- [ACMAP Syntax](#acmap-syntax)
- [ACDEF Syntax](#acdef-syntax)
- [Examples](#examples)
- [API](#api)
- [CLI](#cli)
- [CLI Usage](#cli-usage-examples)
- [Registry](#registry)
- [Hooks](#hooks)
- [Support](#support)
- [Contributing](#contributing)
- [License](#license)

<a name="install-normal"></a>

## Install

```sh
$ sudo curl -Ls https://raw.githubusercontent.com/cgabriel5/nodecliac/master/install | bash -s
```

<!-- [https://stackoverflow.com/questions/17341122/link-and-execute-external-javascript-file-hosted-on-github] -->

**Note**: After installing reload `.bashrc` (by running `$ source ~/.bashrc`) or open a new Terminal to start using.

<details><summary>More installation methods</summary>

##### With `curl`:

```sh
# Bash completion only:
$ sudo curl -Ls https://raw.githubusercontent.com/cgabriel5/nodecliac/master/install | bash -s
# ...same as above.
$ sudo curl -Ls https://raw.githubusercontent.com/cgabriel5/nodecliac/master/install | bash -s aconly master

# Bash completion + nodecliac CLI tools:
# Install with Node.js's npm...
$ sudo curl -Ls https://raw.githubusercontent.com/cgabriel5/nodecliac/master/install | bash -s npm master
# ...or with yarn.
$ sudo curl -Ls https://raw.githubusercontent.com/cgabriel5/nodecliac/master/install | bash -s yarn master
```

##### With `wget`:

```sh
# Bash completion only:
$ sudo wget -qO- https://raw.githubusercontent.com/cgabriel5/nodecliac/master/install | bash -s
# ...same as above.
$ sudo wget -qO- https://raw.githubusercontent.com/cgabriel5/nodecliac/master/install | bash -s aconly master

# Bash completion + nodecliac CLI tools:
# Install with Node.js's npm...
$ sudo wget -qO- https://raw.githubusercontent.com/cgabriel5/nodecliac/master/install | bash -s npm master
# ...or with yarn.
$ sudo wget -qO- https://raw.githubusercontent.com/cgabriel5/nodecliac/master/install | bash -s yarn master
```

</details>

<details><summary>Installation arguments</summary>

- `arg: $1`: `INSTALLER`
  - Values: `yarn`, `npm`, `aconly`. (default: `yarn` > `npm` > `aconly`)
    - `yarn`: Uses [yarn](https://yarnpkg.com/en/) to install.
    - `npm`: Uses [Node.js](https://nodejs.org/en/)'s [npm](https://www.npmjs.com/get-npm) to install.
    - `aconly`: _Only_ Bash completion (no nodecliac JavaScript CLI tools).
- `arg: $2`: `BRANCH_NAME`
  - Value: An _existing_ nodecliac branch name. (default: `master`)

</details>

<details>
  <summary>Requirements</summary>

- Node.js `8+`
  - nodecliac and its CLI tools (`.acmap` to `.acdef` parser, formatter, etc.) are written in JavaScript.
  - **Note**: If _only_ Bash completion is needed (i.e. one already has the CLI program's registry package/files and don't need nodecliac's core CLI tools (parser, formatter, etc.)) then Node.js is _not_ required. Simply install with `aconly` installer.
- Perl `5+`
  - Runs needed Perl Bash completion scripts.
  - Works in tandem with Bash shell scripts.
- Bash `4.3+`
  - Runs Bash completion scripts.
  - Works in tandem with Perl/Nim scripts.
  - `macOS`, by default, comes with with Bash `3.2` so please update it.
    - [Homebrew](https://brew.sh/) can be used to [update bash](https://akrabat.com/upgrading-to-bash-4-on-macos/).
      </details>

<details><summary>Uninstall</summary>

```sh
$ nodecliac uninstall
```

</details>

<!-- <details><summary>Download <a href="https://stackoverflow.com/a/4568323" target="_blank" rel="nofollow">specific branch</a></summary>

```sh
# yarn
$ yarn global add cgabriel5/nodecliac#BRANCH_NAME && nodecliac setup

# npm (requires sudo)
$ sudo npm i -g cgabriel5/nodecliac#BRANCH_NAME && nodecliac setup

# git
$ git clone -b BRANCH_NAME --single-branch https://github.com/cgabriel5/nodecliac.git
```

</details> -->

<a name="how-it-works"></a>

## How It Works

###### Text Summary:

nodecliac uses two custom file types: **a**uto-**c**ompletion **map** (`.acmap`) and **a**uto-**c**ompletion **def**inition (`.acdef`) files. The `.acmap` file is _user_ generated. It's where the program's commands get _mapped_ to their respective flags. The `.acdef` file is generated from the `.acmap` file with nodecliac. Bash completions get made by referencing the `.acdef` file.

###### Bullet Breakdown:

<details>
  <summary>Show breakdown</summary>

1. [Create CLI app's](#cli-usage-examples) `mycliprogram.acmap` file.
2. Generate app's completion-package from `mycliprogram.acmap` file and add to nodecliac's registry.
3. Finally, reload `.bashrc` or open a new Terminal to start using.

</details>

<a name="acmap-syntax"></a>

## ACMAP Syntax

<details>
  <summary>auto-completion map (<code>.acmap</code>) files are text files with a simple language structure and few language constructs.</summary>

#### Comments

- Comments begin with a number-sign (<code>#</code>) followed by a single whitespace character (tab or space): <code># </code>
- Any amount of whitespace indentation can precede a comment.
- Comments must be on their own line.
- For the time being, multi-line comments don't exist and trailing comments are invalid.

```acmap
# The space after '#' is required.
  # Starting white space is perfectly fine.
```

#### Settings

- Settings begin with an at-sign (`@`) followed by the setting name.
- Setting values are assigned with `=` followed by the setting value.
- Any amount of whitespace before and after `=` is fine, but keep things tidy.
- No amount of indentation can precede a setting declaration.
- **Note**: Settings can be declared _anywhere_ within your `.acmap` file.
  - However, it's best if declared at the start of file to quickly spot them.

```acmap
# Comments before settings are allowed.
@compopt   = "default"
@filedir   = ""
@disable   = false
@placehold = true
```

###### Available Settings:

- `@compopt`: The [`comp-option`](https://gerardnico.com/lang/bash/edition/complete#o_comp-option) ([`-o`](https://www.thegeekstuff.com/2013/12/bash-completion-complete/)) value to provide bash-completion's [`complete`](https://www.gnu.org/software/bash/manual/html_node/Programmable-Completion-Builtins.html#Programmable-Completion-Builtins) function.
  - Values: `false` (no value), `true` (default: `false`)
- `@filedir`: The pattern to provide bash-completion's [`_filedir`](https://github.com/gftg85/bash-completion/blob/bb0e3a1777e387e7fd77c3abcaa379744d0d87b3/bash_completion#L549) function.
  - Values: A string value (i.e. `"@(pdf)"`). (default: `""`)
  - `_filedir` resources: [\[1\]](https://unix.stackexchange.com/a/463342), [\[2\]](https://unix.stackexchange.com/a/463336), [\[3\]](https://github.com/scop/bash-completion/blob/master/completions/java), [\[4\]](https://stackoverflow.com/a/23999768), [\[5\]](https://unix.stackexchange.com/a/190004), [\[6\]](https://unix.stackexchange.com/a/198025)
- `@disable`: Disables bash-completion for command.
  - Values: `false`, `true` (default: `false`)
- `@placehold`: Placehold long `.acdef` rows to provide faster file lookups.
  - Values: `false`, `true` (default: `false`)
  - **Note**: Used only when generating `.acdef` files.

#### Variables

- Variables begin with a dollar-sign (`$`) followed by the variable name.
- Variable name _must_ start with an underscore (`_`) or a letter (`a-zA-Z`).
- Variable values are assigned with `=` followed by the variable value.
- A variable's value must be enclosed with quotes.
- Any amount of whitespace before and after `=` is fine, but keep things tidy.
- No amount of indentation can precede a setting declaration.
- **Note**: Variables can be declared _anywhere_ within your `.acmap`.

```acmap
$scriptpath = "~/path/to/script1.sh"
$scriptpath="~/path/to/script2.sh"
$scriptpath    =   "~/path/to/script3.sh"

# Note: `$scriptpath` gets declared 3 times.
# It's final value is: "~/path/to/script3.sh"
```

#### Variable Interpolation (template-string)

- Variables are intended to be used inside quoted strings.
- Template strings have the following structure:
  - A template string is denoted with starting `${` and closing `}`.
  - Any amount of space between opening/closing syntax is fine, but keep things tidy.
  - The string between the closing/starting syntax is the variable name.

```acmap
# Variables - paths.
$mainscript = "~/.nodecliac/registry/yarn/init.sh"

# Command chains.
yarn.remove = default $("${mainscript} remove")
yarn.run = default $("${mainscript} run")
```

#### Command Chains

- Commands/subcommands should seen as chains which read from left to right.
- They start with the CLI program's name, are followed by any commands/subcommands, and are dot (`.`) delimited.
- If a (sub)command happens to use a dot then simply escape the dot.
  - Non escaped dots will be used as delimiters.
- No amount of indentation can precede a command chain.

**Example**: Say the CLI program `mycliprogram` has two commands `install` and `uninstall`. It's `.acmap` file will be:

```acmap
mycliprogram.install
mycliprogram.uninstall
```

<details>
  <summary>Show command default documentation</summary>

#### Command Chain Default

A command chain's `default` `command-string` (a runable shell string) can be used to dynamically generate auto-completion items. This `command-string` is run when no completion items (commands/flags) are returned. Think of it as a fallback.

For example, say we are implementing an `.acmap` file for the dependency manager [yarn](https://yarnpkg.com/en/) and would like to return the names of installed modules when removing a package (i.e.`$ yarn remove...`). Essentially, we want to extract the `package.json`'s `dependency` and `devDependency` entries and supply them to nodecliac. Using a `command-string` one can run a script/shell command to do just that.

- Start by using the keyword `default` followed by a whitespace character.
- Follow that with the `command-string` like so:
  - A command string is denoted with starting `$(` and closing `)`.
  - The string between the closing/starting syntax is the `command-string`.
  - Example `command-string`: `default $("./path/to/custom/script.sh arg1 arg2")`
  - `yarn.remove` example:

```acmap
yarn.remove = [
  # The default command will run on '$ yarn remove [TAB]'. In this example, the shell script
  # 'script.sh' should contain the logic needed to parse package.json to return the installed
  # (dev)dependency package names.
  default $("~/.nodecliac/registry/yarn/script.sh")
]
```

<details>
  <summary>Show command-string escaping</summary>

<hr></hr>

_Keep in mind, if escaping gets to be too much, simply running the code from a file will be the easiest way._

**Example**: Varying levels of escaping.

Take the hypothetical `file.sh` with the following contents:

```sh
for f in ~/.nodecliac/registry/yarn/hooks/*.*; do
  [[ "${f##*/}" =~ ^(pre-parse)\.[a-zA-Z]+$ ]] && echo "$f"
done
```

- **Code Breakdown**
  - The code will loop over the `~/.nodecliac/registry/yarn/hooks` directory.
  - File names matching the pattern (`^(pre-parse).[a-zA-Z]+$`) will print to console.

**Level 1**: If `bash` is one's default shell then running this as a one-liner can be as simple as pasting the following into a Terminal:

```bash
for f in ~/.nodecliac/registry/yarn/hooks/*.*; do [[ "${f##*/}" =~ ^(pre-parse)\.[a-zA-Z]+$ ]] && echo "$f"; done
```

**Level 2**: Now say we want to run the same line of code via `bash -c`. Paste the following into a Terminal.

```bash
bash -c "for f in ~/.nodecliac/registry/yarn/hooks/*.*; do [[ \"\${f##*/}\" =~ ^(pre-parse)\\.[a-zA-Z]+$ ]] && echo \"\$f\"; done;"
```

**Level 3**: How about using `Perl` to run `bash -c` to execute the command?

```bash
perl -e 'print `bash -c "for f in ~/.nodecliac/registry/yarn/hooks/*.*; do [[ \\\"\\\${f##*/}\\\" =~ ^(pre-parse)\\.[a-zA-Z]+\$ ]] && echo \"\\\$f\"; done;"`';
```

**Note**: As seen, the more programs involved the more escaping required due to the string being passed from program to program.

**Example**: Command-string escaping.

Now let's make a `command-string` to print all `.acdef` file names (without extension) in the nodecliac registry:

```bash
$ s="";for f in ~/.nodecliac/registry/*/*.acdef; do s="$s$f\n"; done; echo -e "$s" | LC_ALL=C perl -ne "print \"\$1\n\" while /(?! \/)([^\/]*)\.acdef$/g"
```

Using the following `.acmap` contents the `command-string` would be the following:

- **Note**: Ensure the `|` is properly escaped.
- **Note**: Ensure `\` character(s) get escaped.

```acmap
# The escaped command-string.
$cmdstr = 's="";for f in ~/.nodecliac/registry/*/*.acdef; do s="$s$f\\n"; done; echo -e "$s" \| LC_ALL=C perl -ne "print \"\$1\\n\" while /(?! \\/)([^\\/]*)\\.acdef$/g"'

nodecliac.print = --command=$('${cmdstr}')
```

Will generate the following `.acdef` file:

```acdef
# DON'T EDIT FILE —— GENERATED: Thu Nov 14 2019 21:27:45 GMT-0800 (PST)(1573795665206)

 --
.print --command=|--command=$('s="";for f in ~/.nodecliac/registry/*/*.acdef; do s="$s$f\\n"; done; echo -e "$s" \| LC_ALL=C perl -ne "print \"\$1\\n\" while /(?! \\/)([^\\/]*)\\.acdef$/g"')
```

<hr></hr>

</details>

**Note**: For more information about `command-string`s please take a look at `ACMAP Syntax > Flags > Flag Variations > Flags (dynamic values)`. The section contains complete details for `command-string`s like special character escaping caveats, dynamic/static arguments, and examples with their breakdowns. Please be aware that the section uses the term `command-flag` due it being used for flags but `command-flag` and `command-string` are effectively the same thing — _just a runable shell command string_. The naming (`command-{string|flag}`) is based on its application (i.e. for command-chains or flags).

</details>

#### Flags

To define flags we need to extend the [command chain](#command-chains) syntax.

- Flags are wrapped with `= [` and a closing `]`.
- The `= [` must be on the same line of the command chain.
- The closing `]` must be on its own line and man have any amount of indentation.

Building on the [command chain](#command-chains) section example, say the `install` command has the flags: `destination/d` and `force/f`. ACMAP can be updated to:

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

- If flag is a switch (yes/no boolean) then append `?` to the flag.
  - This lets the completion engine know the flag does not require value completion.

```acmap
mycliprogram.command = [
  --flag?
]
```

#### Flags (multi-flag)

- Sometimes a flag can be supplied multiple times.
- Let the completion engine know this by using the multi-flag indicator `*`.

```acmap
mycliprogram.command = [
  # Allow user to provide multiple file paths.
  --file=*

  # Hard-coded values.
  --colors=*(red green yellow)
]
```

#### Flags Values (one liner)

- This method should be used when the flag value list can be kept to a single line.
- **Note**: Values must be delimited with spaces.
- **Note**: When a flag has many values a [long form list](#flags-values-long-form) should be used for clarities sake.

```acmap
mycliprogram.command = [
  # Supply 1, "2", false, 4 as hard-coded values.
  --flag=(1 "2" false 4)

  # If multiple values can be supplied to program use the multi-flag indicator '*'.
  # This will allow --flag to be used multiple times until all values have been used.
  --flag=*(1 "2" false 4)
]
```

<a name="flags-values-long-form"></a>

#### Flags Values (long form)

- Flag long form lists are wrapped with starting `=(` and a closing `)`.
- The `=(` must be on the same line as the flag.
- The closing `)` must be on its own line and man have any amount of indentation.
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

Sometimes hard-coded values are not enough so a `command-flag` can be used. A `command-flag` runs a shell command string. By default the returned command's output expects each completion item to be on its own line (newline (`\n`) delimited list). However, if you need to change the delimiter character to a space, hyphen, etc. then simply add the delimiter character to the `command-flag`. The syntax for a `command-flag` is as follows:

- `$("cat ~/colors.text")`: Will run command and split output on newlines to get individual options.
- `$("cat ~/colors.text", " ")`: Will run command and split output on spaces to get individual options.

If the command requires arguments they can be _hard-coded_ or _dynamically_ supplied.

- `$("cat ~/colors.text", "!red", $"cat ~/names.text", "-")`:
  - This will provide the hard-coded `!red` value and run the `cat ~/names.text` flag command argument.
  - Once all dynamic arguments are ran their outputs along with the hard-coded values are passed to the command `cat ~/colors.text` in the order they were provided.
  - So `!red` will be argument `0` and the output of `cat ~/names.text` will be argument `1`.
  - Once `cat ~/colors.text` is run, its output will be split by hyphens.
- **Note**: _dynamic_ flag command arguments must be prefixed with a dollar-sign (`$`) character.

**Escaping**: `$` and `|` are used internally by nodecliac so they have special meaning. Therefore, if used they need escaping. Take the following examples:

- `--flag=$("echo \$0-\$1", $"echo 'john'", "doe", "-")`:
  - The `$`s in the command are escaped.
- `--flag=$("nodecliac registry \| grep -oP \"(?<=─ )([-a-z]*)\"")`:
  - Here the `|` gets escaped as well.
  - **Note**: Inner quotes are also escaped for obvious reasons.

**Example**: Showcases dynamic and hard-coded values.

```acmap
mycliprogram.command = [
  # '*' denotes the flag is a multi-flag.
  --flag=*
  --flag=(
    - index.js
    - ':task:js'
    - "some-thing"
    # Dynamic values get combined with hard-coded values.
    - $("cat ~/values.text")
  )

  # Same as above.
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

## Miscellaneous

#### Blank Lines

Blank lines (empty lines) are allowed and ignored when generating an `.acdef` file.

<!-- #### Duplicate Command Chains/Flags/Settings

Though allowed the parser will warn when duplicate command-chains/flags/settings are detected. -->

#### Indentation

Indentation is allowed except when declaring command-chains and settings.

</details>

<a name="acdef-syntax"></a>

## ACDEF Syntax

<details>
  <summary>auto-completion definition (<code>.acdef</code>) files are easy to read and is what nodecliac references when providing completions.</summary>

#### ACDEF Anatomy

The following example `yarn.acdef` file will be used to explain how to read `.acdef` files.

```acdef
# DON'T EDIT FILE —— GENERATED: Fri Jun 21 2019 19:59:33 GMT-0700 (PDT)(1561172373941)

 --cache-folder|--check-files|--cwd|--disable-pnp
.access --
.add --audit|--dev|--exact|--ignore-workspace-root-check|--optional|--peer|--tilde
.autoclean --force|--init
.bin --
.cache --
.upgrade --caret|--exact|--latest|--pattern|--scope|--tilde
.why --
.workspace --
.workspaces --
.workspaces.info --
.workspaces.run --

.upgrade default $("~/.nodecliac/registry/yarn/scripts/init.sh upgrade")
.why default $("yarn list --depth=0 \| perl -wln -e \"/(?! ─ )([-\/_.@(?)a-zA-Z0-9]*)(?=\@)/ and print $&;\"")
.workspace default $("~/.nodecliac/registry/yarn/scripts/init.sh workspace")
.workspaces.run default $("~/.nodecliac/registry/yarn/scripts/init.sh run")
```

#### ACDEF Header

- The first line is the `.acdef` file's header.
  - Header contains a warning to not modify the file as well as the file's creation information.

```acdef
# DON'T EDIT FILE —— GENERATED: Fri Jun 21 2019 19:59:33 GMT-0700 (PDT)(1561172373941)

...
```

#### Commands/Flags

- The following section contains the command-chains and their respective flags.
- Each line represents a _row_ which starts with the command chain and is followed by single space.
- Whatever comes after the single space are the command's flags.
  - Flags are delimited by pipe (`|`) characters.
- Rows that do not have flags will contain `--` after the single space character.

```acdef
...

 --cache-folder|--check-files|--cwd|--disable-pnp
.access --
.add --audit|--dev|--exact|--ignore-workspace-root-check|--optional|--peer|--tilde
.autoclean --force|--init
.bin --
.cache --
.upgrade --caret|--exact|--latest|--pattern|--scope|--tilde
.why --
.workspace --
.workspaces --
.workspaces.info --
.workspaces.run --

...
```

**Note**: Command chain lines, lines starting with a single space or a dot (`.`) character, have the program's name removed.
For example, the line `.workspaces.run --` can be viewed as `yarn.workspaces.run --`.

#### Command Fallbacks

- The bottom section of an `.acdef` file will contain any command chain fallbacks.

```acdef
...

.upgrade default $("~/.nodecliac/registry/yarn/scripts/init.sh upgrade")
.why default $("yarn list --depth=0 \| perl -wln -e \"/(?! ─ )([-\/_.@(?)a-zA-Z0-9]*)(?=\@)/ and print $&;\"")
.workspace default $("~/.nodecliac/registry/yarn/scripts/init.sh workspace")
.workspaces.run default $("~/.nodecliac/registry/yarn/scripts/init.sh run")
```

#### Placeholders

- Depending how complex an `.acmap` is, sometimes placeholders are needed.
- Placeholder syntax:
  - Begin with `--p#` and are followed by a fixed number of hexadecimal characters.
  - **Example**: `--p#d2eef1`
- **Note**: They are used internally to speed up reading, what would be otherwise large, `.acdef` files.

</details>

<a name="examples"></a>

## Examples

ACMAPS for various CLI programs can be can be found [here](resources/nodecliac/__acmaps).

<details><summary>nodecliac ACMAP</summary>

**Short form**: The following represents `nodecliac.acmap`, the nodecliac auto-completion map file.

```acmap
nodecliac = --version?
nodecliac.setup = --rcfilepath?|--force?
nodecliac.uninstall = --rcfilepath?
nodecliac.registry
nodecliac.make = --add?|--force?|--source|--save?|--print?|--trace?
nodecliac.status = --enable?|--disable?
nodecliac.format = --indent|--source|--save?|--print?|--strip-comments?|--trace?
nodecliac.print = --command=|--command=$("for f in ~/.nodecliac/registry/*/*.acdef; do f=\"\${f##*/}\";c=\"\${f%%.*}\";echo \"\$c\"; done;")
```

**Long form**: Same as short form above. Settle on one or mixture of both.

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
nodecliac.registry
nodecliac.make = [
  --add?
  --force?
  --source
  --save?
  --print?
  --trace?
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
  --strip-comments?
  --trace?
]
nodecliac.print = [
  --command=
  --command=$("for f in ~/.nodecliac/registry/*/*.acdef; do f=\"\${f##*/}\";c=\"\${f%%.*}\";echo \"\$c\"; done;")
]
```

</details>

</details>

<a name="api"></a>

## API

nodecliac is currently only a CLI tool.

<a name="cli"></a>

## CLI

#### CLI Anatomy (Example)

nodecliac assumes following CLI program [design](http://programmingpractices.blogspot.com/2008/04/anatomy-of-command-line.html) pathway:

- `program-name` → [`subcommands`](https://github.com/mosop/cli/wiki/Defining-Subcommands) → `short-flags`/`long-flags` → `positional-parameters`

```
$ mycliprogram [subcommand ...] [-a | -b] [--a-opt <Number> | --b-opt <String>] [file ...]
  ^^^^^^^^^^^^  ^^^^^^^^^^^^^^   ^^^^^^^   ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^   ^^^^^^^^
        |              |            |                      /                    /
  CLI program's   Program        Program          Program long     Program's (flag-less)
  command.        subcommands.   short flags.     flags.           positional parameters.
```

<details>
  <summary>Show nodecliac's commands/flags.</summary>

- `format`: Format (prettify) `.acmap` file.
  - `--source=`: (**required**): Path to `.acmap` file.
  - `--save` : Overwrite source file with prettified output.
  - `--indent="(s|t):Number"`: Formatting indentation string:
    - `s` for spaces or `t` for tabs followed by a number.
      - `t:1`: Use 1 tab per indentation level (_default_).
      - `s:2`: Use 2 spaces per indentation level.
  - `--print` : Log output to console.
  - `--strip-comments` : Remove comments from final output.
  - `--trace` : Trace parsers (_for debugging_).
  - `--test`: Log output without file headers (_for tests_).
- `make`: Make completion-package for command.
  - `--source=`: (**required**): Path to `.acmap` file.
  - `--add`: Add generated completion-package nodecliac registry.
    - `--force`: Forces overwrite of existing registry completion-package.
  - `--save=` : Location where completion-package should be saved to.
    - **Note**: If path isn't provided current working directory is used.
    - `--force`: Forces overwrite of existing completion-package at directory.
  - `--print` : Log output to console.
  - `--trace` : Trace parsers (_for debugging_).
  - `--test`: Log output without file headers (_for tests_).
- `print`: Print acmap/def file contents for files in registry.
  - `--command=`: The file to print (list dynamically generated based on available files in registry).
- `registry`: Lists `.acdef` files in registry.
- `setup`: Installs and setups nodecliac.
  - `--force` : Forces install even if nodecliac is already installed.
  - `--rcfilepath`: By default `~/.bashrc` is used. If another rc file should be used provide its path.
    - **Note**: This gets appended to rc file:
      - `ncliac=~/.nodecliac/src/main/init.sh;if [ -f "$ncliac" ];then source "$ncliac";fi;`
- `status`: Checks whether nodecliac is enabled/disabled.
  - `--enable` : Enables nodecliac if disabled.
  - `--disable`: Disables nodecliac if enabled.
- `uninstall`: Uninstalls nodecliac/reverts rc file changes.
  - `--rcfilepath`: rc file used in setup to remove changes from.

</details>

<a name="cli-usage-examples"></a>

## CLI Usage Examples

#### Generate completion-package

```sh
# Generate completion-package for 'mycliprogram' and add it to registry.
$ nodecliac make --source path/to/mycliprogram.acmap --add

# Generate mycliprogram.acdef contents and log to terminal.
$ nodecliac make --source path/to/mycliprogram.acmap --print
```

#### Prettify ACMAP file

```sh
# Prettify mycliprogram.acmap file using 2 spaces per indentation level and log output.
$ nodecliac format --source path/to/mycliprogram.acmap --print --indent "s:2"

# As above but overwrite source file with prettified output.
$ nodecliac format --source path/to/mycliprogram.acmap --print --indent "s:2" --save
```

<a name="registry"></a>

## Registry

The registry (`~/.nodecliac/registry`) is where nodecliac's completion packages live. Completion packages follow this form: `~/.nodecliac/registry/COMMAND-NAME/`. For example, [yarn's](https://yarnpkg.com/en/) completion [package and its files](/resources/nodecliac) reside in `~/.nodecliac/registry/yarn/`.

<details><summary>Show directory structures.</summary>

- Required completion package directory base structure:

```
~/.nodecliac/
└── registry/
    └── COMMAND-NAME/
        ├── COMMAND-NAME.acdef
        ├── .COMMAND-NAME.config.acdef
        ├── hooks/
        └── placeholders/
```

- Yarn completion package directory structure:

```
~/.nodecliac/
└── registry/
    └── yarn/
        ├── yarn.acdef
        ├── .yarn.config.acdef
        ├── hooks/
        └── placeholders/
```

**Note**: The manner in which script files are structured within `~/.nodecliac/registry/COMMAND-NAME/` is up to you. Just note that the above base structure is required.

</details>

<a name="hooks"></a>

## Hooks

Some programs are more complicated than others. Take [yarn](https://yarnpkg.com/en/) as an example. Its `yarn.acdef` file needs to be modified before parsing to [dynamically add the repos scripts as commands](https://yarnpkg.com/en/docs/cli/run#toc-yarn-run). Doing so will require a pre-parsing hook. Essentially, before nodecliac does anything
it's possible to use a pre-hook script to modify the command's `acdef` and CLI input values.

<details><summary>Expand hook section.</summary>

#### Available hook scripts

- `hooks/pre-parse.sh`
  - Purpose: `pre-parse.sh` is _meant_ to modify `acdef` and `cline` variables before running [completion-script](/src/scripts/ac).
  - **Note**: However, since the hook script is `sourced` into [`connector.sh`](/src/scripts/main/connector.sh) it has _access_ to other [`connector.sh`](/src/scripts/main/connector.sh) variables.
  - Hook script should be seen as [glue code](https://en.wikipedia.org/wiki/Scripting_language#Glue_languages) intended to run actual logic.
    - For example, take yarn's [`pre-parse.sh`](/resources/nodecliac/yarn/hooks/pre-parse.sh) script. The [script](/resources/nodecliac/yarn/hooks/pre-parse.sh) actually runs a Perl script ([`pre-parse.pl`](/resources/nodecliac/yarn/hooks/pre-parse.pl)) which returns the repo's `package.json` `scripts` as well as modified CLI input.
    - The point here is to use the language _needed for the job_. Bash simply _glues_ it together.

**Note**: Using a hook script might sound involved/off-putting but it's not. A hook script is _just a regular executable shell script_. The script simply has special meaning in the sense that it is used to **hook** into nodecliac to change some variables used for later Bash completion processing.

#### Making Hook Script

First create the command's resource `hooks/` directory: `~/.nodecliac/registry/COMMAND-NAME/hooks`. All hook scripts reside in the `COMMAND-NAME/hooks` sub directory. For example, yarn's `pre-parse` script is located at `~/.nodecliac/registry/yarn/hooks/pre-parse.sh`.

#### Using Hook Script

This section will continue to use yarn's [`pre-parse.sh`](/resources/nodecliac/yarn/hooks/pre-parse.sh) script as an example.

- [`pre-parse.sh`](/resources/nodecliac/yarn/hooks/pre-parse.sh) runs a Perl script ([`pre-parse.pl`](/resources/nodecliac/yarn/hooks/pre-parse.pl)) which returns the repo's `package.json` `scripts` as well as modified CLI input.
- [`pre-parse.sh`](/resources/nodecliac/yarn/hooks/pre-parse.sh) then modifies the `acdef` and the CLI input.
- Since the pre-parse script is sourced into [`connector.sh`](/src/scripts/main/connector.sh) nothing is echoed to script.
- Instead, the `acdef` and `cline` variables are reset/overwritten.
- These new values are then used by nodecliac to provide Bash completions.

**Note**: Perl is used here for quick text processing as doing it in Bash is slow and cumbersome. _However_, use what you _want/need_ to get the job done. Hook scripts just _need_ to be executable scripts stored in `~/.nodecliac/registry/COMMAND-NAME/hooks/`.

**Note**: As a reminder, the provided `.acmap` file gets parsed to generate an `.acdef` file. The created `.acdef` file is what nodecliac actually reads **a**uto-**c**ompletion **def**initions from. Therefore, modifying `.acdef` contents requires knowing `.acdef` syntax.

#### Ignoring Options

Letting the completion engine know an option should be ignored (not used) is simple. Just prefix the option with an exclamation-mark (`!`). This is meant to be used when an option has already been used and therefore doesn't need to be shown again.

#### Environment Variables

Hook scripts are provided environment variables.

- Following environment variables are provided by `bash` but exposed by nodecliac.

  - `NODECLIAC_COMP_LINE`: Original (unmodified) CLI input.
  - `NODECLIAC_COMP_POINT`: Caret index when `[TAB]` key was pressed.

- Following environment variables are custom and exposed by nodecliac.
  - `NODECLIAC_MAIN_COMMAND`: The command auto completion is being performed for.
  - `NODECLIAC_COMMAND_CHAIN`: The parsed command chain.
  - `NODECLIAC_LAST`: The last parsed word item.
    - **Note**: Last word item could be a _partial_ word item.
      - This happens when the `[TAB]` key gets pressed _within_ a word item. For example, take the following input: `$ program command`. If the `[TAB]` key was pressed like so: `$ program comm[TAB]and`, the last word item is `comm`. Thus a _partial_ word with a remainder string of `and`. Resulting in finding completions for `comm`.
  - `NODECLIAC_PREV`: The word item preceding the last word item.
  - `NODECLIAC_INPUT`: CLI input from start to caret (`[TAB]` key press) index.
  - `NODECLIAC_INPUT_ORIGINAL`: Original unmodified CLI input.
  - `NODECLIAC_INPUT_REMAINDER`: CLI input from start to caret index.
  - `NODECLIAC_LAST_CHAR`: Character before caret.
  - `NODECLIAC_NEXT_CHAR`: Character after caret.
    - **Note**: If char is _not_ `''` (empty) then the last word item (`NODECLIAC_LAST`) is a _partial_ word.
  - `NODECLIAC_COMP_LINE_LENGTH`: Original CLI input's length.
  - `NODECLIAC_INPUT_LINE_LENGTH`: CLI input length from string beginning to caret position.
  - `NODECLIAC_ARG_COUNT`: Amount of arguments parsed in `NODECLIAC_INPUT` string.
  - `NODECLIAC_ARG_N`: Parsed arguments can be individually accessed with this variable.
    - Arguments are _zero-index_ based.
      - First argument is `NODECLIAC_ARG_0`.
        - Will _always_ be the program command.
    - Because input is variable all other arguments can be retrieved with a loop.
      - Use `NODECLIAC_ARG_COUNT` as max loop iteration.
    - **Example**: If the following was the CLI input: `$ yarn remove chalk prettier`
      - Arguments would be:
        - `NODECLIAC_ARG_0`: `yarn`
        - `NODECLIAC_ARG_1`: `remove`
        - `NODECLIAC_ARG_2`: `chalk`
        - `NODECLIAC_ARG_3`: `prettier`
  - `NODECLIAC_USED_DEFAULT_POSITIONAL_ARGS`: Collected positional arguments after validating the command-chain.

</details>

<a name="support"></a>

## Support

<details><summary>OS Support</summary>

<!-- #### OS Support -->

- Made using Node.js `v8.16.0` on a Linux machine running `Ubuntu 16.04.5 LTS`.
- Tested and working on:
  - `macOS Mojave (v10.14.4)`.
  - `Windows 10 - Untested`.

</details>

<details><summary>Shell Support</summary>

<!-- #### Shell Support -->

- nodecliac only works with Bash, seeing that it's the only shell I use. However, if the project grows support for other shells (Zsh, Fish, etc.) may be added.

</details>

<details><summary>Editor Support</summary>

<!-- #### Editor Support (Syntax Highlighting) -->

- I use Sublime Text (ST) and have created a language syntax file (`acmap.sublime-syntax`) for it. ST files can be accessed [here](/resources/sublime-text/). Download the folder and place it in the `User/` folder for ST to pickup. Personally, I have it stored like so: `/User/Languages/Auto Completion Map (acmap)`.
- Support for other editors can also be added if the project grows.

</details>

<a name="contributing"></a>

## Contributing

Contributions are welcome! Found a bug, feel like documentation is lacking/confusing and needs an update, have performance/feature suggestions or simply found a typo? Let me know! :)

See how to contribute [here](/CONTRIBUTING.md).

<a name="license"></a>

## License

This project uses the [MIT License](/LICENSE.txt).
