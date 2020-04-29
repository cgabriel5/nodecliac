<h1 align="center">nodecliac</h1>
<p align="center">
  <img src="https://github.com/cgabriel5/nodecliac/blob/gh-pages/website/media/logo.png?raw=true" alt="nodecliac logo" title="nodecliac logo" width="125px">
</p>

<div align="center">Easy Bash completion for CLI programs</div>
<br>

<!-- ##### Table of Contents

- [Install](#install-normal)
- [How It Works](#how-it-works)
- [Syntax](#syntax)
- [CLI](#cli)
- [Registry](#registry)
- [Hooks](#hooks)
- [Packages](#packages)
- [Support](#support)
- [Contributing](#contributing)
- [License](#license)
 -->

<a name="install-normal"></a>

## Install

<!-- Using `bash -s`: [https://stackoverflow.com/a/51854728] -->

```sh
$ sudo curl -Ls https://raw.githubusercontent.com/cgabriel5/nodecliac/master/install | bash -s && source ~/.bashrc
```

<!-- [https://stackoverflow.com/questions/17341122/link-and-execute-external-javascript-file-hosted-on-github] -->

<details><summary>More installation methods</summary>

<br>

**With** `curl` (_explicit defaults_):

```sh
$ sudo curl -Ls https://raw.githubusercontent.com/cgabriel5/nodecliac/master/install | bash -s -- --installer= --branch=master --rcfilepath=~/.bashrc && source ~/.bashrc
```

**With** `wget` (_defaults_):

```sh
$ sudo wget -qO- https://raw.githubusercontent.com/cgabriel5/nodecliac/master/install | bash -s && source ~/.bashrc
```

</details>

<details><summary>Installation options</summary>

<br>

- `--installer`: The installer to use. (default: `yarn` > `npm` > `binary`)
  - `yarn`: Uses [yarn](https://yarnpkg.com/en/) to install.
  - `npm`: Uses [Node.js](https://nodejs.org/en/)'s [npm](https://www.npmjs.com/get-npm) to install.
  - `binary`: Uses nodecliac's [Nim](https://nim-lang.org/) Linux/macOS CLI tools.
- `--branch`: An _existing_ nodecliac branch name to install. (default: `master`)
- `--rcfilepath`: `bashrc` file to install nodecliac to. (default: `~/.bashrc`)

</details>

<details>
  <summary>Requirements</summary>

<br>

- [Perl](https://www.perl.org/get.html) `v5+`.
- [Node.js](https://nodejs.org/en/) `v8+` if installing via `npm` or `yarn`.
- [bash-completion](https://github.com/scop/bash-completion) `v2.1+`.
- [Bash](https://www.gnu.org/software/bash/) `v4.3+`.
  - `macOS`: Stock Bash is outdated (`v3.2`). Update via [Homebrew](https://brew.sh/) to [`v4.3+`](https://akrabat.com/upgrading-to-bash-4-on-macos/).

</details>

<details><summary>Uninstall</summary>

<br>

```sh
$ nodecliac uninstall
```

If a custom rcfile path was used during install provide it again during uninstall.

```sh
$ nodecliac uninstall --rcfilepath=path/to/.bashrc
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

<a name="what-is-nodecliac"></a>

## What Is nodecliac?

[`bash-completion`](https://www.gnu.org/software/bash/manual/html_node/Programmable-Completion.html) is awesome. It enhances the user experience by completing paths, file names, commands, flags, etc. Ironically enough, having to use [`Bash`](https://www.gnu.org/software/bash/) to implement it puts some off from using it.

nodecliac's approach is different. Rather than _directly_ using Bash, nodecliac lets one easily _map_ a program's commands with their flags in an **a**uto-**c**ompletion **map** (`.acmap`) file. Merely write the program's `.acmap`, compile to `.acdef`, and let nodecliac handle the rest. That's it.

If Bash _is_ needed, `.acmap` files are flexible enough to run Bash commands. Better yet, write necessary completion logic in a familiar language like [`Perl`](https://www.perl.org/), [`Python`](https://www.python.org/), [`Ruby`](https://www.ruby-lang.org/en/), etc., and use Bash as [glue code](https://en.wikipedia.org/wiki/Scripting_language#Glue_languages) to tie it all together.

In all, this project aims to `1` minimize the effort needed to add bash-completion so more programs support it, `2` provide a uniform bash-completion experience, and `3` to ultimately build a collection of community made completion packages for all to enjoy.

_Why the name nodecliac?_ Originally it was made in mind for [Node.js](https://nodejs.org/en/) programs. However, as development continued it proved useful for non Node.js programs as well.

<a name="how-it-works"></a>

## How It Works

The idea is simple. nodecliac uses two file types: **a**uto-**c**ompletion **map** (`.acmap`) and **a**uto-**c**ompletion **def**inition (`.acdef`). Those familiar with CSS preprocessors will quickly understand. Similar to how `.sass` and `.less` files are compiled to `.css` &mdash; `.acmap` files must be compiled to `.acdef`.

Therefore, an `.acmap` is a user generated file that uses a simple syntax to _map_ a program's commands with their flags. While an `.acdef` is a nodecliac generated _definition_ file. It's this file nodecliac uses to provide completions.

Ok, `1` but where do these files go? `2` How does nodecliac use them? Good questions. `1` **Files** will end up in the command's [completion package](./docs/packages/creating.md); a _folder_ containing the necessary files needed to provide completions for a command. `2` **Completion packages** will end up in nodecliac's [registry](#registry) (nodecliac's _collection_ of completion packages).

With that, nodecliac can provide Bash completions for programs by using their respective completion package stored in the registry.

<details><summary>Expand section</summary>

<p align="center"><img src="./docs/diagrams/nodecliac_diagram.png?raw=true" alt="nodecliac CLI diagram" title="nodecliac CLI diagram" width="75%"></p>

With the program's [completion package created](https://github.com/cgabriel5/nodecliac/blob/docs/docs/packages/creating.md) and stored in the [registry](#registry) the following is possible:

1. **<kbd>Tab</kbd> key pressed**: Bash completion invokes nodecliac's completion function for the program.

2. **CLI input analysis**: Input is parsed for commands, flags, positional arguments, etc.

3. `.acdef` **lookup**: The program's `.acdef` is compared against the CLI input to return possible completions.

_Complete details/events are oversimplified and condensed to get the main points across._

</details>

<a name="cli"></a>

## CLI

<details>
  <summary>CLI options</summary>

###### Commands:

- Main:
  - [`make`](#cli-command-make)
  - [`format`](#cli-command-format)
- Helper:
  - [`cache`](#cli-command-cache)
  - [`setup`](#cli-command-setup)
  - [`status`](#cli-command-status)
  - [`uninstall`](#cli-command-uninstall)
  - [`print`](#cli-command-print)
  - [`registry`](#cli-command-registry)
- Package:
  - [`add`](#cli-command-add)
  - [`remove`](#cli-command-remove)
  - [`link`](#cli-command-link)
  - [`unlink`](#cli-command-unlink)
  - [`enable`](#cli-command-enable)
  - [`disable`](#cli-command-disable)

---

<a name="cli-command-make"></a>

<b><i>make</i></b>

> Compile `.acdef`.

- `--source=`: (**required**): Path to `.acmap` file.
- `--print`: Log output to console.

###### Usage

```sh
$ nodecliac make --source path/to/program.acmap # Compile .acmap file to .acdef.
```

<details><summary>Test/debugging flags (internal)</summary>

- `--trace`: Trace parsers (_for debugging_).
- `--test`: Log output without file headers (_for tests_).

</details>

---

<a name="cli-command-format"></a>

<b><i>format</i></b>

> Format (prettify) `.acmap` file.

- `--source=`: (**required**): Path to `.acmap` file.
- `--strip-comments`: Remove comments when formatting.
- `--indent="(s|t):Number"`: Formatting indentation string:
  - `s` for spaces or `t` for tabs followed by amount-per-indentation level.
    - `t:1`: Use 1 tab per indentation level (_default_).
    - `s:2`: Use 2 spaces per indentation level.
- `--print`: Log output to console.

###### Usage

```sh
# Prettify using 2 spaces per indentation level and print output.
$ nodecliac format --source path/to/program.acmap --print --indent "s:2"
```

<details><summary>Test/debugging flags (internal)</summary>

- `--trace`: Trace parsers (_for debugging_).
- `--test`: Log output without file headers (_for tests_).

</details>

---

<a name="cli-command-cache"></a>

<b><i>cache</i></b>

> Interact with nodecliac's [cache system](#caching).

- `--clear`: Clears cache.
- `--level=<level>`:
  - _Without_ argument it prints the current cache level.
  - _With_ argument it sets cache level to provide level.
    - Levels: `0`, `1`, `2`

###### Usage

```sh
$ nodecliac cache --clear # Clear cache.
$ nodecliac cache --level # Print cache level.
$ nodecliac cache --level 1 # Set cache level to 1.
```

---

<a name="cli-command-setup"></a>

<b><i>setup</i></b>

> Setup nodecliac.

- `--force`: (**required** _if nodecliac is already setup)_: Overwrites old nodecliac setup and installs anew.
- `--rcfilepath`: By default `~/.bashrc` is used. If another rcfile should be used provide its path.
- **Note**: Setup appends `ncliac=~/.nodecliac/src/main/init.sh; [ -f "$ncliac" ] && . "$ncliac";` to rcfile.

###### Usage

```sh
$ nodecliac setup # Setup nodecliac.
```

---

<a name="cli-command-status"></a>

<b><i>status</i></b>

> Returns status of nodecliac (enabled or disabled).

- `--enable`: Enables nodecliac.
- `--disable`: Disables nodecliac.

###### Usage

```sh
$ nodecliac status # Get nodecliac's status.
$ nodecliac status --enable # Enable nodecliac.
$ nodecliac status --disable # Disable nodecliac.
```

---

<a name="cli-command-uninstall"></a>

<b><i>uninstall</i></b>

> Uninstalls nodecliac.

- `--rcfilepath`: Path of rcfile used in setup to remove changes from.

###### Usage

```sh
$ nodecliac uninstall # Remove nodecliac.
```

---

<a name="cli-command-print"></a>

<b><i>print</i></b>

> Print acmap/def file contents for files in registry.

- `--command=`: Name of command (uses available packages in registry).
- **Note**: Command is rather pointless and is primarily used to showcase `command-string`s.

###### Usage

```sh
$ nodecliac print --command=<command> # Print .acdef for given command.
```

---

<a name="cli-command-registry"></a>

<b><i>registry</i></b>

> Lists packages in [registry](#registry).

- _No arguments_

###### Usage

```sh
$ nodecliac registry # Print packages in registry.
```

---

<a name="cli-command-add"></a>

<b><i>add</i></b>

> Adds package to registry.

- _No arguments_
- **Note**: Must be run in package root.

###### Usage

```sh
$ nodecliac add # Copies cwd folder (completion package) to registry.
```

---

<a name="cli-command-remove"></a>

<b><i>remove</i></b>

> Removes package(s) from registry.

- Takes n-amount of package names as arguments.
- `--all`: Removes all packages in registry.

###### Usage

```sh
$ nodecliac remove # Removes cwd folder (completion package) from registry.
$ nodecliac remove --all # Removes all packages from registry.
```

---

<a name="cli-command-link"></a>

<b><i>link</i></b>

> Creates soft [symbolic](https://linuxize.com/post/how-to-create-symbolic-links-in-linux-using-the-ln-command/) link of package in registry.

- _No arguments_
- **Note**: Must be run in package root.
- For use when developing a completion package.

###### Usage

```sh
$ nodecliac link # Symlinks cwd folder (completion package) to registry.
```

---

<a name="cli-command-unlink"></a>

<b><i>unlink</i></b>

> Alias to [`remove`](#cli-command-remove) command.

- See [`remove`](#cli-command-remove) command.

###### Usage

```sh
$ nodecliac unlink # Removes cwd folder (completion package) from registry.
$ nodecliac unlink --all # Removes all packages from registry.
```

---

<a name="cli-command-enable"></a>

<b><i>enable</i></b>

> Enables completions for package(s).

- Takes n-amount of package names as arguments.
- `--all`: Enables all packages in registry.

###### Usage

```sh
$ nodecliac enable # Enables disabled package(s).
$ nodecliac enable --all # Enables all disabled packages.
```

---

<a name="cli-command-disable"></a>

<b><i>disable</i></b>

> Disables completions for package(s).

- Takes n-amount of package names as arguments.
- `--all`: Disables all packages in registry.

###### Usage

```sh
$ nodecliac disable # Disables enabled package(s).
$ nodecliac disable --all # Disables all enabled packages.
```

---

</details>

<details><summary>CLI quick usage</summary>

#### Compile `.acmap` files to `.acdef`.

```sh
$ nodecliac make --source path/to/program.acmap
```

#### Prettify `.acmap` file

```sh
# Prettify using 2 spaces per indentation level and print output.
$ nodecliac format --source path/to/program.acmap --print --indent "s:2"
```

</details>

<details><summary>CLI anatomy breakdown</summary>

<br>

nodecliac assumes following CLI program [design](http://programmingpractices.blogspot.com/2008/04/anatomy-of-command-line.html) pathway:

- `program-name` → [`subcommands`](https://github.com/mosop/cli/wiki/Defining-Subcommands) → `short-flags`/`long-flags` → `positional-parameters`

```
$ program [subcommand ...] [-a | -b] [--a-opt <Number> | --b-opt <String>] [file ...]
  ^^^^^^^  ^^^^^^^^^^^^^^   ^^^^^^^   ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^   ^^^^^^^^
     |            \             \                      |                   /
  CLI program's   Program        Program          Program long     Program's (flag-less)
  command.        subcommands.   short flags.     flags.           positional parameters.
```

</details>

<a name="syntax"></a>

## Syntax

<details>
  <summary><code>acmap</code> (<b>a</b>uto-<b>c</b>ompletion <b>map</b>) is a purposefully simple syntax which <i>maps</i> a program's commands to their flags in <code>.acmap</code> files.</summary>

###### Constructs:

- [Comments](#syntax-comments)
- [Settings](#syntax-settings)
- [Variables](#syntax-variables)
- [Command Chains](#syntax-cc)
- [Flags](#syntax-flags)

<a name="syntax-comments"></a>

#### Comments

- Comments begin with a number-sign (<code>#</code>) and continue to the end of the line.
- Whitespace indentation can precede a comment.
- Comments _must_ be on their _own_ line.
- Multi-line and trailing comments are _not_ supported.

```acmap
# This is a comment.
    # Whitespace can precede comment.
```

<a name="syntax-settings"></a>

#### Settings

- Settings begin with an at-sign (`@`) followed by the setting name.
- Setting values are assigned with `=` followed by the setting value.
- Any amount of whitespace before and after `=` is allowed.
- Whitespace indentation can precede a setting declaration.
- **Note**: Settings can be declared _anywhere_ within your `.acmap` file.
  - However, it's best if declared at the start of file to quickly spot them.

```acmap
# Available settings.
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
  - **Note**: Used only when compiling `.acdef` files.

<a name="syntax-variables"></a>

#### Variables

- Variables begin with a dollar-sign (`$`) followed by the variable name.
- Variable name _must_ start with an underscore (`_`) or a letter (`a-zA-Z`).
- Variable values are assigned with `=` followed by the variable value.
- A variable's value must be enclosed with quotes.
- Any amount of whitespace before and after `=` is allowed.
- Whitespace indentation can precede a variable declaration.
- **Note**: Variables can be declared _anywhere_ within your `.acmap`.

```acmap
$scriptpath = "~/path/to/script1.sh"
$scriptpath="~/path/to/script2.sh"
$scriptpath    =   "~/path/to/script3.sh"

# Note: `$scriptpath` gets declared 3 times.
# It's final value is: "~/path/to/script3.sh"
```

<details>
  <summary>Variable Interpolation</summary>

#### Variable Interpolation

- Variables are intended to be used inside quoted strings.
- Interpolation has the following structure:
  - Start with `${` and close with `}`.
  - Any amount of space between opening/closing syntax is allowed.
  - The string between the closing/starting syntax is the variable name.

```acmap
$mainscript = "~/.nodecliac/registry/yarn/init.sh"

yarn.remove = default $("${mainscript} remove")
yarn.run = default $("${mainscript} run")
```

</details>

<a name="syntax-cc"></a>

#### Command Chains

- Commands/subcommands should be viewed as chains which read from left to right.
- They start with the CLI program's name, are followed by any commands/subcommands, and are dot (`.`) delimited.
- If a (sub)command happens to use a dot then simply escape the dot. Non escaped dots will be used as delimiters.
- Whitespace indentation can precede a command chain.

**Example**: Say the CLI program `program` has two commands `install` and `uninstall`. It's `.acmap` will be:

```acmap
program.install
program.uninstall
```

<details>
  <summary>Command default documentation</summary>

#### Command Chain Default

A command chain's `default` `command-string` (a runable shell command string) can be used to dynamically generate auto-completion items. This `command-string` is run when no completion items (commands/flags) are returned. Think of it as a fallback.

- Start by using the keyword `default` followed by a whitespace character.
- Follow that with the `command-string`:
  - A command string is denoted with starting `$(` and closing `)`.
  - The string between the closing/starting syntax is the `command-string`.
  - **Example**: `default $("./path/to/script.sh arg1 arg2")`

<details><summary>Command-string example</summary>

<br>

For example, say we are implementing an `.acmap` file for the dependency manager [yarn](https://yarnpkg.com/en/) and would like to return the names of installed packages when removing a package (i.e.`$ yarn remove...`). Essentially, we want to extract the `package.json`'s `dependency` and `devDependency` entries and supply them to nodecliac. Using a `command-string` one can run a script/shell command to do just that.

```acmap
yarn.remove = [
  # The command will run on '$ yarn remove [TAB]'. The script 'script.sh' should contain the
  # logic needed to parse package.json to return the installed (dev)dependency package names.
  default $("~/.nodecliac/registry/yarn/script.sh")
]
```

</details>

<details>
  <summary>Command-string escaping</summary>

<hr></hr>

#### Varying Levels Of Escaping.

- **Level 0**: Hypothetical `script.sh` with the following contents. _No extra escaping when running a script._

```sh
for f in ~/.nodecliac/registry/yarn/hooks/*.*; do
  [[ "${f##*/}" =~ ^(pre-parse)\.[a-zA-Z]+$ ]] && echo "$f"
done
```

- **Code Breakdown**

  - The code will loop over the `~/.nodecliac/registry/yarn/hooks` directory.
  - File names matching the pattern (`^(pre-parse).[a-zA-Z]+$`) will print to console.

- **Level 1**: If `bash` is one's default shell, copy/paste and run this one-liner in a Terminal:

```bash
for f in ~/.nodecliac/registry/yarn/hooks/*.*; do [[ "${f##*/}" =~ ^(pre-parse)\.[a-zA-Z]+$ ]] && echo "$f"; done
```

- **Level 2**: Now say we want to run the same line of code via `bash -c`. Run the following in a Terminal:

```bash
bash -c "for f in ~/.nodecliac/registry/yarn/hooks/*.*; do [[ \"\${f##*/}\" =~ ^(pre-parse)\\.[a-zA-Z]+$ ]] && echo \"\$f\"; done;"
```

- **Level 3**: How about using `Perl` to run `bash -c` to execute the command?

```bash
perl -e 'print `bash -c "for f in ~/.nodecliac/registry/yarn/hooks/*.*; do [[ \\\"\\\${f##*/}\\\" =~ ^(pre-parse)\\.[a-zA-Z]+\$ ]] && echo \"\\\$f\"; done;"`';
```

As shown, the more programs involved the more escaping required due to the string being passed from program to program. Escaping can get cumbersome. If so, running the code from a file will be the easiest alternative.

**Example**: Command-string escaping.

Now let's make a `command-string` to print all `.acdef` file names (without extension) in the nodecliac registry:

```bash
$ s="";for f in ~/.nodecliac/registry/*/*.acdef; do s="$s$f\n"; done; echo -e "$s" | LC_ALL=C perl -ne "print \"\$1\n\" while /(?! \/)([^\/]*)\.acdef$/g"
```

Using the following `.acmap` contents the `command-string` would be the following:

- **Note**: Ensure the `|` and `\` characters are escaped.

```acmap
# The escaped command-string.
$cmdstr = 's="";for f in ~/.nodecliac/registry/*/*.acdef; do s="$s$f\\n"; done; echo -e "$s" \| LC_ALL=C perl -ne "print \"\$1\\n\" while /(?! \\/)([^\\/]*)\\.acdef$/g"'

nodecliac.print = --command=$('${cmdstr}')
```

Compiling to `.acdef`, an `.acdef` file with the following contents will be generated:

```acdef
# DON'T EDIT FILE —— GENERATED: Mon Mar 02 2020 14:15:13 (1583187313)

 --
.print --command=|--command=$('s="";for f in ~/.nodecliac/registry/*/*.acdef; do s="$s$f\\n"; done; echo -e "$s" \| LC_ALL=C perl -ne "print \"\$1\\n\" while /(?! \\/)([^\\/]*)\\.acdef$/g"')
```

<hr></hr>

</details>

#### Ignoring Options

Letting the completion engine know an option should be ignored (not displayed) is simple. Merely prefix the option with an exclamation-mark (`!`). This is meant to be used when an option has already been used and therefore doesn't need to be shown again as a possible completion item.

**Note**: For more information about `command-string`s take a look at `acmap Syntax > Flags > Flag Variants > Flags (dynamic values)`. The section contains more details for `command-string`s like special character escaping caveats, dynamic/static arguments, and examples with their breakdowns. Keep in mind that the section uses the term `command-flag` due it being used for flags but `command-flag` and `command-string` are effectively the same thing — _just a runable shell command string_. The naming (`command-{string|flag}`) is based on its application (i.e. for command-chains or flags).

</details>

<a name="syntax-flags"></a>

#### Flags

To define flags we need to extend the [command chain](#command-chains) syntax.

- Flags are wrapped with `= [` and a closing `]`.
- The `= [` must be on the same line of the command chain.
- The closing `]` must be on its own line and man have any amount of indentation.

Building on the [command chain](#command-chains) section example, say the `install` command has the flags: `destination/d` and `force/f`. Code can be updated to:

```acmap
program.install = [
  --destination
  -d
  --force
  -f
]
program.uninstall
```

<details>
  <summary>Flag variants</summary>

#### Flags (user input)

- If flag requires user input append `=` to the flag.

```acmap
program.command = [
  --flag=
]
```

#### Flags (boolean)

- If flag is a switch (boolean) append a `?` to the flag to let the completion engine know the flag doesn't require value completion.

```acmap
program.command = [
  --flag?
]
```

#### Flags (multi-flag)

- Sometimes a flag can be supplied multiple times.
- Let the completion engine know this by using the multi-flag indicator `*`.

```acmap
program.command = [
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
program.command = [
  # Supply 1, "2", false, 4 as hard-coded values.
  --flag=(1 "2" false 4)

  # If multiple values can be supplied to program use the multi-flag indicator '*'.
  # This allows --flag to be used multiple times until all values have been used.
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
program.command = [
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
program.uninstall
```

#### Flags (dynamic values)

Sometimes static values are not enough so a `command-flag` can be used. A `command-flag` is just a runnable shell command.

`command-flag` syntax:

- Begins with starting `$(`, followed by command, and ends with closing `)`.
- Output: a newline (`\n`) delimited list is expected.
  - Each completion item should be on its own line.
- Example: `$("cat ~/colors.text")`
- **Note**: Command must be quoted (double or single).

_static_ or _dynamic_ arguments may be provided.

- Example: `$("cat ~/colors.text", "!red", $"cat ~/names.text")`:
  - This provides the _static_ `!red` and _dynamic_ `cat ~/names.text` arguments.
  - `!red` will be argument `0` and the output of `cat ~/names.text` will be argument `1`.
- **Note**: _dynamic_ arguments must be dollar-sign prefixed (`$`).

**Escaping**: `$` and `|` are used internally so require escaping when used.

- `--flag=$("echo \$0-\$1", $"echo 'john'", "doe")`:
  - The `$`s in the command are escaped.
- `--flag=$("nodecliac registry \| grep -oP \"(?<=─ )([-a-z]*)\"")`:
  - The `|` gets escaped here.
  - **Note**: Inner quotes are also escaped like one would on the command-line.

**Example**: Showcases _dynamic_ and _static_ values.

```acmap
program.command = [
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
    - $("cat ~/values.text")
  )
]
program.uninstall
```

</details>

</details>

<details>
  <summary><code>acdef</code> (<b>a</b>uto-<b>c</b>ompletion <b>def</b>inition) uses a stripped down and condensed version of <code>acmap</code> syntax. It's devoid of unnecessary comments, newlines, etc. using only relevant information from an <code>.acmap</code> file.</summary>

###### Constructs:

- [Header](#syntax-header)
- [Command/Flags](#syntax-command-flags)
- [Command Fallbacks](#syntax-command-fallbacks)
- [Placeholders](#syntax-placeholders)

#### `.acdef` Anatomy

The following example `.acdef` will be used to explain how to read `.acdef` files.

```acdef
# DON'T EDIT FILE —— GENERATED: Mon Mar 02 2020 14:15:13 (1583187313)

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

.upgrade default $("~/.nodecliac/registry/command/scripts/init.sh upgrade")
.why default $("command list --depth=0 \| perl -wln -e \"/(?! ─ )([-\/_.@(?)a-zA-Z0-9]*)(?=\@)/ and print $&;\"")
.workspace default $("~/.nodecliac/registry/command/scripts/init.sh workspace")
.workspaces.run default $("~/.nodecliac/registry/command/scripts/init.sh run")
```

<a name="syntax-header"></a>

#### Header

- The first line is the file's header.
- It is the only comment in the document.
- It contains a warning to not modify the file and the file's creation information.

```acdef
# DON'T EDIT FILE —— GENERATED: Mon Mar 02 2020 14:15:13 (1583187313)

...
```

<a name="syntax-command-flags"></a>

#### Commands/Flags

- The following section contains the command-chains and their respective flags.
- Each line represents a _row_ which starts with the command chain and is followed by a single space.
- Whatever comes after the single space are the command's flags.
  - Flags are delimited by pipe (`|`) characters.
- Rows that do not have flags will contain two hyphens (`--`) after the single space character.

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
For example, the line `.workspaces.run --` can be viewed as `command.workspaces.run --`.

<a name="syntax-command-fallbacks"></a>

#### Command Fallbacks

- The bottom section of an `.acdef` file will contain any command chain fallbacks.

```acdef
...

.upgrade default $("~/.nodecliac/registry/command/scripts/init.sh upgrade")
.why default $("command list --depth=0 \| perl -wln -e \"/(?! ─ )([-\/_.@(?)a-zA-Z0-9]*)(?=\@)/ and print $&;\"")
.workspace default $("~/.nodecliac/registry/command/scripts/init.sh workspace")
.workspaces.run default $("~/.nodecliac/registry/command/scripts/init.sh run")
```

<a name="syntax-placeholders"></a>

#### Placeholders

- Depending how complex an `.acmap` is sometimes placeholders are needed. They are used internally to speed up reading, what would otherwise be large, `.acdef` files.
- Placeholder syntax:
  - Begin with `--p#` and are followed by a fixed number of hexadecimal characters.
  - **Example**: `--p#d2eef1`

The following example `.acdef` showcase placeholders.

```acdef
# DON'T EDIT FILE —— GENERATED: Thu Apr 09 2020 10:4:22 (1586451862)

 --help|--version
.buildIndex --p#07d43e
.c --p#07d43e
.cc --p#07d43e
.check --p#07d43e
.compile --p#07d43e
.compileToC --p#07d43e
.compileToCpp --p#07d43e
.compileToOC --p#07d43e
.cpp --p#07d43e
.ctags --p#07d43e
.doc --p#07d43e
.doc2 --p#07d43e
.dump --p#07d43e
.e --p#07d43e
.genDepend --p#07d43e
.js --p#07d43e
.jsondoc --p#07d43e
.objc --p#07d43e
.rst2html --p#07d43e
.rst2tex --p#07d43e
```

</details>

<a name="registry"></a>

## Registry

Simply put, the registry (`~/.nodecliac/registry`) is where completion packages are stored. Completion packages are stored in the form: `~/.nodecliac/registry/<command>`.

<a name="packages"></a>

## Packages

Package documentation is divided into their own sections.

<!-- Table formatting hack: [https://stackoverflow.com/a/51701842] -->

| <img width=220/> <br /> [Create](/docs/packages/creating.md) <img width=220/> | <img width=220/> <br /> [Add / Link](/docs/packages/adding.md) <img width=220/> | <img width=220/> <br /> [Remove / Unlink](/docs/packages/removing.md) <img width=220/> | <img width=220/> <br /> [Enable / Disable](/docs/packages/state.md) <img width=220/> |
| ----------------------------------------------------------------------------- | ------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------ |


<a name="hooks"></a>

## Hooks

Hooks are _just regular executable shell scripts_ that run at specific points along a completion cycle when a completion is attempted. They let one modify internal aspects of nodecliac's completion logic and behavior.

<details><summary>Expand hook section</summary>

#### Available Hooks

1. `hooks/pre-parse.sh`: Modifies select initialization variables before running [completion script](/src/scripts/ac).

#### `hooks/` Directory

In the command's completion package create a `hooks/` directory. All hook scripts will be stored here.

```sh
<command>/
  ├── <command>.acmap
  ├── <command>.acdef
  ├── .<command>.config.acdef
  └── hooks/
```

#### Environment Variables

Hook scripts are provided parsing information via environment variables.

<details><summary>Bash provided variables but exposed by nodecliac</summary>

<br>

- `NODECLIAC_COMP_LINE`: Original (unmodified) CLI input.
- `NODECLIAC_COMP_POINT`: Caret index when <kbd>Tab</kbd> key was pressed.

</details>

<details><summary>nodecliac provided variables</summary>

<br>

- `NODECLIAC_MAIN_COMMAND`: The command auto completion is being performed for.
- `NODECLIAC_COMMAND_CHAIN`: The parsed command chain.
- `NODECLIAC_LAST`: The last parsed word item.
  - **Note**: Last word item could be a _partial_ word item.
    - This happens when the <kbd>Tab</kbd> key gets pressed _within_ a word item. For example, take the following input:`$ program command`. If the<kbd>Tab</kbd> key was pressed like so: <code>\$ program comm<kbd>Tab</kbd>and</code>, the last word item is `comm`. Thus a _partial_ word with a remainder string of `and`. Resulting in finding completions for `comm`.
- `NODECLIAC_PREV`: The word item preceding the last word item.
- `NODECLIAC_INPUT`: CLI input from start to caret (<kbd>Tab</kbd> key press) index.
- `NODECLIAC_INPUT_ORIGINAL`: Original unmodified CLI input.
- `NODECLIAC_INPUT_REMAINDER`: CLI input from start to caret index.
- `NODECLIAC_LAST_CHAR`: Character before caret.
- `NODECLIAC_NEXT_CHAR`: Character after caret.
  - **Note**: If char is _not_ `''` (empty) then the last word item (`NODECLIAC_LAST`) is a _partial_ word.
- `NODECLIAC_COMP_LINE_LENGTH`: Original CLI input's length.
- `NODECLIAC_INPUT_LINE_LENGTH`: CLI input length from string beginning to caret position.
- `NODECLIAC_ARG_COUNT`: Amount of arguments parsed in `NODECLIAC_INPUT` string.
- `NODECLIAC_ARG_N`: Parsed arguments can be individually accessed with this variable.
  - First argument is `NODECLIAC_ARG_0` and will _always_ be the program's command.
  - Because input is variable all other arguments can be retrieved with a loop.
    - Use `NODECLIAC_ARG_COUNT` as max loop iteration.
  - **Example**: Given the CLI input: `$ yarn remove chalk prettier`
    - Arguments would be:
      - `NODECLIAC_ARG_0`: `yarn`
      - `NODECLIAC_ARG_1`: `remove`
      - `NODECLIAC_ARG_2`: `chalk`
      - `NODECLIAC_ARG_3`: `prettier`
- `NODECLIAC_USED_DEFAULT_POSITIONAL_ARGS`: Collected positional arguments.

</details>

#### Writing Hook Script

Take yarn's [`pre-parse.sh`](/resources/packages/yarn/hooks/pre-parse.sh) script as an example:

```sh
#!/bin/bash

# Initialization variables:
#
# cline    # CLI input.
# cpoint   # Index of caret position when [TAB] key was pressed.
# command  # Program for which completions are for.
# acdef    # The command's .acdef file contents.

output="$("$HOME/.nodecliac/registry/$command/hooks/pre-parse.pl" "$cline")"

# 1st line is the modified CLI (workspace) input.
read -r firstline <<< "$output"
[[ -n "$firstline" ]] && cline="$firstline"

# Remaining lines are package.json's script entries.
len="${#firstline}"; [[ ! "$len" ]] || len=1
addon="${output:$len}"; [[ -n "$addon" ]] && acdef+=$'\n'"$addon"
```

- The Bash script is [glue code](https://en.wikipedia.org/wiki/Scripting_language#Glue_languages). It runs the Perl script [`pre-parse.pl`](/resources/packages/yarn/hooks/pre-parse.pl) to retrieve the cwd `package.json` `scripts` and determine whether yarn is being used in a workspace.
- Using the Perl script's output the Bash script overwrites the `cline` variable and appends the `package.json` `scripts` to the `acdef` variable. Adding them as their [own commands](https://yarnpkg.com/en/docs/cli/run#toc-yarn-run).
- nodecliac uses the new values to determine completions.

</details>

<a name="caching"></a>

## Caching

To return quicker results completions are cached.

<details><summary>Expand cache section</summary>

##### Cache Levels:

- `0`: No caching.
- `1`: Cache all but `command-string` (dynamic) completions. (`default`)
- `2`: Cache everything.

```sh
$ nodecliac cache --clear # Clear cache.
$ nodecliac cache --level 0 # Turn cache off.
```

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

- nodecliac only works with Bash.
- Support for other shells (Zsh, Fish, etc.) may be added with increased usage.

</details>

<details><summary>Editor Support</summary>

<!-- #### Editor Support (Syntax Highlighting) -->

- `.acmap`/`.acdef` [grammar packages](/resources/editors) available for [Sublime Text 3](https://www.sublimetext.com/3), [VSCode](https://code.visualstudio.com/), and [Atom](https://atom.io/) text editors.
- **Note**: `README.md` files are found next to each package explaining how to install it.
- Packages are stored under [`resources/editors`](/resources/editors).

</details>

<a name="contributing"></a>

## Contributing

Contributions are welcome! Found a bug, feel like documentation is lacking/confusing and needs an update, have performance/feature suggestions or simply found a typo? Let me know! :)

See how to contribute [here](/CONTRIBUTING.md).

<a name="license"></a>

## License

This project uses the [MIT License](/LICENSE.txt).
