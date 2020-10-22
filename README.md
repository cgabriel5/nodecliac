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

<!-- Shorten install script URL: -->
<!-- [https://saraford.net/2017/02/18/how-to-use-git-io-to-shorten-github-urls-and-create-vanity-urls-049/] -->
<!-- [https://stackoverflow.com/questions/44347129/delete-git-io-shortened-url] -->
<!-- [https://github.blog/2011-11-10-git-io-github-url-shortener/] -->
<!-- [https://stackoverflow.com/questions/39065921/what-do-raw-githubusercontent-com-urls-represent] -->

<!-- Using `bash -s`: [https://stackoverflow.com/a/51854728] -->
<!-- [https://unix.stackexchange.com/a/339238] -->
<!-- [https://unix.stackexchange.com/a/180826] -->

```sh
$ bash <(curl -Ls git.io/nodecliac) && source ~/.bashrc
```

<!-- [https://stackoverflow.com/questions/17341122/link-and-execute-external-javascript-file-hosted-on-github] -->

<details><summary>More installation methods</summary>

<br>

**curl Install** (_explicit defaults_):

```sh
$ bash <(curl -Ls git.io/nodecliac) --installer= --branch=master --rcfile=~/.bashrc && source ~/.bashrc
```

**wget Install** (_defaults_):

```sh
$ bash <(wget -qO- git.io/nodecliac) && source ~/.bashrc
```

**Manual Install**: One can also install manually.

<!-- [https://askubuntu.com/a/86850] -->

1. First download the GitHub nodecliac [repository](https://github.com/cgabriel5/nodecliac/archive/master.zip).
2. Next unzip the folder via `$ unzip nodecliac-*.zip` or by right-clicking and using the OS provided extractor utility.
3. `cd` into the repository and install: `$ sudo chmod +x install.sh && ./install.sh --manual && source ~/.bashrc`
4. Delete the downloaded `zip` folder, its extracted folder, and start using.

**Checksum Install**: If desired, the install script file's integrity can be verified before running.

[install.sh](https://raw.githubusercontent.com/cgabriel5/nodecliac/master/install.sh) `sha256sum` checksum: `37ed932882557fd0b910f7bb64622e53274ede49855eb5afa241bfb7d6f2da60`

Create an executable shell file called `install.sh`, add the following, and run it.

```sh
#!/bin/bash

# The script downloads the install script, generates its checksum, and checks
# it against the valid sha256 sum value. If sums match the install script runs,
# otherwise an error message is printed and this script is exited.

install() {
    url="git.io/nodecliac"
    is="$([[ "$(command -v curl)" ]] && sudo curl -Ls "$url" || sudo wget -qO- "$url")"
    x=($([[ "$OSTYPE" == "darwin"* ]] && shasum -a 256 <<< "$is" || sha256sum <<< "$is"))
    c="37ed932882557fd0b910f7bb64622e53274ede49855eb5afa241bfb7d6f2da60"
    err="\033[1;31mError\033[0m: Verification failed: checksums don't match."
    [[ "$c" == "$x" ]] && bash <(echo "$is") \
        --installer= \
        --branch=master \
        --rcfile=~/.bashrc \
        && source ~/.bashrc || echo -e "$err" && exit 1
} && install
```

<!-- [https://unix.stackexchange.com/a/538602] -->
<!-- [https://unix.stackexchange.com/a/426838] -->
<!-- [https://github.com/ESGF/esg-search/issues/84#issuecomment-214773499] -->
<!-- [https://apple.stackexchange.com/a/310245] -->
<!-- [https://explainshell.com/explain?cmd=%28curl%20-fsSL%20lsd.systemten.org%7C%7Cwget%20-q%20-O-%20lsd.systemten.org%29%7Cmksh.1#] -->
<!-- # l="$(sha256sum <<< "$is" | awk '$0=$1')" -->
<!-- # l="$(perl -ne 'print $1 if /^([^\s]+)/' <<< $(sha256sum <<< "$is"))" -->

</details>

<details><summary>Installation options</summary>

<br>

- `--installer`: The installer to use. (default: `yarn` > `npm` > `binary`)
  - `yarn`: Uses [yarn](https://yarnpkg.com/en/) to install.
  - `npm`: Uses [Node.js](https://nodejs.org/en/)'s [npm](https://www.npmjs.com/get-npm) to install.
  - `binary`: Uses nodecliac's [Nim](https://nim-lang.org/) Linux/macOS CLI tools.
- `--branch`: An _existing_ nodecliac branch name to install. (default: `master`)
- `--rcfile`: `bashrc` file to install nodecliac to. (default: `~/.bashrc`)
- `--yes`: Automate install by saying yes to any prompt(s).
- `--packages`: Install [collection](https://github.com/cgabriel5/nodecliac/tree/master/resources/packages) of pre-made completion packages.
- `--manual`: Let's install script to take manual install route.
- `--update`: Let's install script to take update router over fresh install route.

</details>

<details>
  <summary>Requirements</summary>

<br>

- [Perl](https://www.perl.org/get.html) `v5+`.
- [Node.js](https://nodejs.org/en/) `v8+` if installing via `npm` or `yarn`.
- [bash-completion](https://github.com/scop/bash-completion) `v1.3+`, preferably `v.2.1+`.
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
$ nodecliac uninstall --rcfile=path/to/.bashrc
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

[`bash-completion`](https://www.gnu.org/software/bash/manual/html_node/Programmable-Completion.html) is awesome. It enhances the user experience by completing paths, file names, commands, flags, etc. Ironically enough, having to use [`Bash`](https://www.gnu.org/software/bash/) to add it to one's program puts some off from using it.

nodecliac's approach is different. Rather than _directly_ using Bash, nodecliac provides a layer of abstraction. It lets one easily _map_ a program's commands with their flags in an **a**uto-**c**ompletion **map** (`.acmap`) file. Merely write the program's `.acmap`, compile to `.acdef`, and let nodecliac handle the rest. That's it.

If Bash _is_ needed, `.acmap` files are flexible enough to run shell code to generate matches. Better yet, write the necessary completion logic in a familiar language like [`Perl`](https://www.perl.org/), [`Python`](https://www.python.org/), [`Ruby`](https://www.ruby-lang.org/en/), etc., and use Bash as [glue code](https://en.wikipedia.org/wiki/Scripting_language#Glue_languages) to tie it all together.

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
  <summary>CLI commands/flags</summary>

###### Commands:

- Main:
  - [`make`](#cli-command-make)
  - [`format`](#cli-command-format)
- Helper:
  - [`init`](#cli-command-init)
  - [`bin`](#cli-command-bin)
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


<a name="cli-command-init"></a>

<b><i>init</i></b>

> Starts nodecliac's completion package generator to easily scaffold a completion package.

- `--force`: Overwrites existing folder of the same name.

###### Usage

```sh
$ nodecliac init
```

---

<a name="cli-command-bin"></a>

<b><i>bin</i></b>

> Prints nodecliac's bin location.

- _No arguments_

###### Usage

```sh
$ nodecliac bin # Binary location.
```

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
- `--yes`: Automate install by saying yes to any prompt(s).
- `--rcfile`: By default `~/.bashrc` is used. If another rcfile should be used provide its path.
- **Note**: Setup appends `ncliac=~/.nodecliac/src/main/init.sh; [ -f "$ncliac" ] && . "$ncliac";` to rcfile.

###### Usage

```sh
$ nodecliac setup # Setup nodecliac.
$ nodecliac setup --force # Force nodecliac setup.
$ nodecliac setup --force --yes # Force nodecliac setup and assume yes to any prompt(s).
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

- `--rcfile`: Path of rcfile used in setup to remove changes from.

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

- `--path`: Path to completion package.
- `--repo`: GitHub repo to install completion package from.
  -  Repo only: `<username>/<repo_name>`
  -  Repo sub-directory: `<username>/<repo_name>/trunk/<sub_directory_path>`
- `--skip-val`: Skips package validation (caution: not recommended, for dev purposes).
- `--force`: If local completion package is more than `10MB` this flag is needed to install.
  - Meant as a safeguard to prevent accidentally copying large folders.
 
###### Usage

```sh
$ nodecliac add # Copies cwd folder (completion package) to registry.
$ nodecliac add --force # Copies cwd folder and forces install if package is over 10MB.
$ nodecliac add --path ~/Desktop/subl # Installs completion package at specified path.
$ nodecliac add --repo cgabriel5/nodecliac # Install completion package from a GitHub repo.
# Install completion package from a specific directory in a GitHub repo.
$ nodecliac add --repo cgabriel5/nodecliac/trunk/resources/packages/yarn
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

- `--path`: Path to completion package.

###### Usage

```sh
$ nodecliac link # Symlinks cwd folder (completion package) to registry.
$ nodecliac link --path ~/Desktop/subl # Symlinks completion package at specified path.
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
- Trailing comments are allowed.
- Multi-line comments are _not_ supported.

```acmap
# This is a comment.
    # Whitespace can precede comment.
program.command = --flag # A trailing comment.
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

- `@compopt`: [`comp-option`](https://gerardnico.com/lang/bash/edition/complete#o_comp-option) ([`-o`](https://www.thegeekstuff.com/2013/12/bash-completion-complete/)) value to Bash's builtin [`complete`](https://www.gnu.org/software/bash/manual/html_node/Programmable-Completion-Builtins.html#Programmable-Completion-Builtins) function.
  - Values: `false` (no value), `true` (default: `false`)
- `@filedir`: [Pattern](https://unix.stackexchange.com/a/108646) to provide [bash-completion](https://github.com/scop/bash-completion/)'s `_filedir` function.
  - Values: A string value (i.e. `"@(acmap)`, `"-d"`) (default: `""`)
    <!-- - Values: To complete directories only provide `"-d"`. To complete specific file types provide a pattern like so: `"@(pdf)"`. (default: `""`) -->
    <!-- - `_filedir` resources: [\[1\]](https://unix.stackexchange.com/a/463342), [\[2\]](https://unix.stackexchange.com/a/463336), [\[3\]](https://github.com/scop/bash-completion/blob/master/completions/java), [\[4\]](https://stackoverflow.com/a/23999768), [\[5\]](https://unix.stackexchange.com/a/190004), [\[6\]](https://unix.stackexchange.com/a/198025) -->
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

<details>
  <summary>Variable Builtins</summary>

#### Variable Builtins

`acmap`s provide the following builtin variables:

- `$OS`: The user's platform: `linux`, `macosx`
- `$HOME`: The user's home directory.
- `$COMMAND`: The command being completed.
- `$PATH`: The command's nodecliac registry path:
  - For example: `~/.nodecliac/registry/<COMMAND>`

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

```acmap
program.command = [
  default $("./path/to/script.sh arg1 arg2")
]
```

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

<details>
  <summary>Command chain grouping</summary>

#### Command Chain Grouping

Command chains can be grouped. It is not necessary but doing may help condense acmaps.

- A command group is denoted with starting `{` and closing `}`.
- The commands are found in between the closing/starting syntax.
- Commands are comma delimited.

For example, take the following:

```acmap
program.deploy-keys.add
program.deploy-keys.list
program.deploy-keys.rm
```

Grouping can reduce it to:

```acmap
program.deploy-keys.{add,list,rm}
```

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

However, it can be cleaned up a bit by using the flag `alias` syntax:

```acmap
program.install = [
  --destination::d
  --force::f
]
program.uninstall
```

<details>
  <summary>Flag variants</summary>

###### Types:

- [Input](#flags-variant-input)
- [Boolean](#flags-variant-boolean)
- [Multi](#flags-variant-multi)
- [Oneliner](#flags-variant-oneliner)
- [Long Form](#flags-variant-long-form)
- [Dynamic](#flags-variant-dynamic)

###### Keywords:

- [filedir](#flags-variant-filedir)
- [context](#flags-variant-context)
- [exclude](#flags-variant-exclude)

<a name="flags-variant-input"></a>

#### Flags (input)

- If flag requires user input append `=` to the flag.

```acmap
program.command = [
  --flag=
]
```

<a name="flags-variant-boolean"></a>

#### Flags (boolean)

- If flag is a switch (boolean) append a `?` to the flag to let the completion engine know the flag doesn't require value completion.

```acmap
program.command = [
  --flag?
]
```

<a name="flags-variant-multi"></a>

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

<a name="flags-variant-oneliner"></a>

#### Flags (one liner)

- This method should be used when the flag value list can be kept to a single line.
- **Note**: Values must be delimited with spaces.
- **Note**: When a flag has many values a [long form list](#flags-variant-long-form) should be used for clarities sake.

```acmap
program.command = [
  # Supply 1, "2", false, 4 as hard-coded values.
  --flag=(1 "2" false 4)

  # If multiple values can be supplied to program use the multi-flag indicator '*'.
  # This allows --flag to be used multiple times until all values have been used.
  --flag=*(1 "2" false 4)
]
```

<a name="flags-variant-long-form"></a>

#### Flags (long form)

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

<a name="flags-variant-dynamic"></a>

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

<a name="flags-variant-filedir"></a>

#### Keyword (filedir)

When no completion items are found bash-completion's `_filedir` function is used as a fallback. `_filedir` performs file/directory completion. By default it returns both file and directory names. However, this can be controlled to only return directory names or files of certain types.

<!-- [https://www.nebulousresearch.org/other/bashcompletion] -->

- Start by using the keyword `filedir` followed by a whitespace character.
- Follow that with a string:
  - To only return directories use `"-d"`.
  - To filter file type extensions provide a [pattern](https://unix.stackexchange.com/a/108646) like `"@(acmap)"`.
  - **Example**: `filedir "@(acmap)"`

```acmap
program.command = [
  filedir "@(acmap)"
]
```

**Note**: This `filedir` usage is per command chain. If this is not needed, a global `filedir` value can be provided via the `@filedir` setting like so: `@filedir = "@(acmap)"`. Both can be used but precedence is as follows:

- If a command uses `filedir` use that.
- If not, look for `@filedir` setting.
- If neither are provided all files/directories are returned (_no filtering_).

<a name="flags-variant-context"></a>

#### Keyword (context)

The `context` keyword provides the ability to disable flags and deal with mutual flag exclusivity.

- Start by using the keyword `context` followed by a whitespace character.
- Follow that with a string:
  - **Conditional Example**: `context "!help: #fge0"`
  - **Mutual Exclusivity Example**: `context "{ json | yaml | csv }`

#### Context String (conditional):

Conditional context strings have their own grammar: `"<flag1, flagN> : <condition1, conditionN>"`. If each `<condition>` results in `true` the `<flags>` are enabled/disabled.

##### Flag grammar

- A flag is represented without the hyphens.
  - Example: For the flag `--help` it would just be `help`.
- If the flag needs to be disabled, prepend a `!`.
  - Example: `help` (If conditions are `true` flag will be _enabled_)
  - Example: `!help` (If conditions are `true` flag will be _disabled_)

##### Condition grammar

- Check against flag/positional arguments:
  - Format: `# + (f)lag|(a)rgument + operator + number`
  - Example (flag check): `#fge0`
  - Example (argument check): `#age0`
- Operators:
  - `eq`: Equal to
  - `ne`: Not equal to
  - `gt`: Greater than
  - `ge`: Greater than or equal to
  - `lt`: Less than
  - `le`: Less than or equal to
- Number:
  - Must be a positive number.
- Inversion: Tests can be _inverted_ by prepending a `!`.

###### Example 1

Disable `help` and `version` flags when used flag count is greater or equal to 0.

```acmap
program.command = [
  --help?
  --version?
  context "!help, !version: #fge0"
]
```

###### Example 2

Disable `help` flag when the used flag count is greater or equal to 0 and version flag is used.

```acmap
program.command = [
  --help?
  --version?
  context "!help: #fge0, version"
]
```

#### Context String (mutual exclusivity):

Mutual exclusivity is represented like so: `"{ flag1 | flagN }"`. Once a grouped flag is used the other(s) are disabled.

###### Example 1

For example, say the `--json`, `--csv`, and `--text` flags are allowed but the `--json` flag is used. The remaining flags `--text` and `--csv` won't be shown as completion items.

```acmap
program.command = [
  --json=,
  --csv=,
  --text=(false true)
  context "{ json | csv | text }"
]
```

###### Example 2

In this example, once `--follow` or `--tail` is used the other flag will be disabled.

```acmap
program.command = [
  --follow=,
  --tail=(false true)
  context "{follow | tail}"
]
```

This is equivalent to the previous example.

```acmap
program.command = [
  --follow=,
  --tail=(false true)
  context "!follow: tail"
  context "!tail: follow"
]
```

#### Combine Context Strings

Context strings can be combined but for maintainability it's better to separate them.

###### Example 1: Separate Context Strings

```acmap
program.command = [
  --help?
  --version?
  context "!help, !version: #fge0"

  --json=,
  --csv=,
  --text=(false true)
  context "{ json | csv | text }"

  --follow=,
  --tail=(false true)
  context "{follow | tail}"

  --hours=
  --minutes=
  --seconds=
  --service=

  --job-id=
  --target=
  context "{ job-id | target }"
]
```

###### Example 1: Combined Context Strings

Context strings can be combined by delimiting them with `;`.

```acmap
program.command = [
  --help?
  --version?

  --json=,
  --csv=,
  --text=(false true)

  --follow=,
  --tail=(false true)

  --hours=
  --minutes=
  --seconds=
  --service=

  --job-id=
  --target=

  context "!help, !version: #fge0; { json | csv | text }; { follow | tail }; { job-id | target }"
]
```

**Note**: Context strings are evaluated on every completion cycle. Therefore, using too many may slow down the 'perceived completion feel' as it takes time to evaluate all provided contexts.

<a name="flags-variant-exclude"></a>

#### Keyword (exclude)

The `exclude` keyword is only allowed in a _wildcard_ command block. It serves to easily give all command strings the same (universal/shared) flags. Although this can be done manually, this can help reduce the acmap and make it easier to maintain.

Let's look at an example. All command strings but `program.cache` share the `--help` flag.

```acmap
program = [
  --help?
  --version
]

program.make = [
  --help?
  --extensions=*(js html css)
]

program.format = [
  --help?
  --extensions=*(js html css)
  --indentation
]

program.cache = [
  --clear?
]
```

Now let's use a wildcard block and exclude the `program.cache` command string.

```acmap
* = [
  exclude "program.cache"
  --help?
]

program = [
  --version
]

program.make = [
  --extensions=*(js html css)
]

program.format = [
  --extensions=*(js html css)
  --indentation
]

program.cache = [
  --clear?
]
```

If desired it can even be condensed to.

```acmap
* = --help?|exclude "program.cache"
program = --version
program.make,
program.format = --extensions=*(js html css)
program.format = --indentation
program.cache = --clear?
```

<br>

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


Pre-made completion packages for several programs of varying complexity are [available](https://github.com/cgabriel5/nodecliac/tree/master/resources/packages) for reference.

<a name="hooks"></a>

## Hooks

Hooks are _just regular executable shell scripts_ that run at specific points along a completion cycle when a completion is attempted. They let one modify internal aspects of nodecliac's completion logic and behavior.

<details><summary>Expand hook section</summary>

#### Available Hooks

1. `hooks/pre-parse.sh`: Modifies select initialization variables before running [completion script](/src/scripts/ac).
1. `hooks/post-parse.sh`: Modifies final completions before terminating the completion cycle and printing suggestions.

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
- `NODECLIAC_COMP_INDEX`: The index where completion is being attempted.
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

#### Writing Pre Hook Script

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

# Remaining lines are package.json's script entries.
mapfile -ts1 lines < <(echo -e "$output")
printf -v output '%s\n' "${lines[@]}" && acdef+=$'\n'"$output"
```

- The Bash script is [glue code](https://en.wikipedia.org/wiki/Scripting_language#Glue_languages). It runs the Perl script [`pre-parse.pl`](/resources/packages/yarn/hooks/pre-parse.pl) to retrieve the cwd `package.json` `scripts` and determine whether yarn is being used in a workspace.
- Using the Perl script's output the Bash script overwrites the `cline` variable and appends the `package.json` `scripts` to the `acdef` variable. Adding them as their [own commands](https://yarnpkg.com/en/docs/cli/run#toc-yarn-run).
- nodecliac uses the new values to determine completions.

#### Writing Post Hook Script

Take m-cli's [`post-parse.sh`](/resources/packages/m-cli/hooks/post-parse.sh) script as an example:

```sh
#!/bin/bash

function completion_logic() {
  COMP_CWORD="$NODECLIAC_COMP_INDEX"
  prev="$NODECLIAC_PREV"
  cmd="$NODECLIAC_ARG_1"
  sub="$NODECLIAC_ARG_2"
  case "$cmd" in
    dir)
      case "$prev" in
        delete) echo -e "empty\ndsfiles"; return ;;
        dsfiles) echo -e "on\noff"; return ;;
      esac
      ;;
    disk)
      case "$sub" in
        # _m_disk
        verify|repair) [[ $COMP_CWORD == 3 ]] && echo -e "disk\nvolume"; return ;;
        format)
          case $COMP_CWORD in
            3) echo -e "ExFAT\nJHFS+\nMS-DOS\nvolume" ;;
            4) [[ "$NODECLIAC_ARG_3" == "volume" ]] && echo -e "ExFAT\nJHFS+\nMS-DOS" ;;
          esac
          return
        ;;
        rename) [[ $COMP_CWORD == 3 ]] && \
        echo -e "$(grep -oE '(disk[0-9s]+)' <<< "$(diskutil list)")"; return ;;

        # _m_dock
        autohide) [[ $COMP_CWORD == 3 ]] && echo -e "YES\nNO"; return ;;
        magnification) [[ $COMP_CWORD == 3 ]] && echo -e "YES\nNO"; return ;;
        position) [[ $COMP_CWORD == 3 ]] && echo -e "BOTTOM\nLEFT\nRIGHT"; return ;;
      esac
      ;;
    dock)
      case "$sub" in
        autohide) [[ $COMP_CWORD == 3 ]] && echo -e "YES\nNO"; return ;;
        magnification) [[ $COMP_CWORD == 3 ]] && echo -e "YES\nNO"; return ;;
        position) [[ $COMP_CWORD == 3 ]] && echo -e "BOTTOM\nLEFT\nRIGHT"; return ;;
      esac
      ;;
    finder) [[ $COMP_CWORD == 3 ]] && echo -e "YES\nNO"; return ;;
    screensaver) [[ $sub == "askforpassword" && $COMP_CWORD == 3 ]] && echo -e "YES\nNO"; return ;;
  esac
}
completion_logic
```

- The post hook script is written in Bash but any language may be used. As shown, the script makes use of the provided `NODECLIAC_*` environment variables to determine what completion items to add. Each completion item must be returned on its own line.

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

<a name="testing"></a>

## Testing

nodecliac provides a way to test completions for your program.

<details><summary>Expand testing section</summary>

#### Creating tests:

Creating tests is done directly from the program's acmap via `@test`. Start with `@test =` followed by the test string `"<completion string> ; <test1 ; testN>"`.

- Test entire completion output (including meta data):
  - _Does the output contain_ `format`_?_: `@test = "program --; *format*`
  - _Does the output omit_ `format`_?_: `@test = "program --; !*format*`
- Test individual completion items:
  - _Do any completion items contain_ `format`_?_: `@test = "program --; *:*format*`
  - _Does the first completion item contain_ `format`_?_: `@test = "program --; 1:*format*`
  - _Does the first completion item start with_ `--for`_?_: `@test = "program --; 1:--for*`
  - _Does the first completion item end with_ `format`_?_: `@test = "program --; 1:*format`
  - _Does the first completion item equal_ `--format`_?_: `@test = "program --; 1:--format`
- Test completion items count:
  - _Is there at least 1 completion item?_: `@test = "program --; #cgt0`
  - _Are there 3 completion items?_: `@test = "program --; #ceq3`
    - Format: `# + (c)ount + operator + number`
    - Operators:
      - `eq`: Equal to
      - `ne`: Not equal to
      - `gt`: Greater than
      - `ge`: Greater than or equal to
      - `lt`: Less than
      - `le`: Less than or equal to
    - Number:
      - Must be a positive number.
- Inversion: Any test can be _inverted_ by preceding the test with a `!`.

###### Example 1

Take the following example acmap. It contains a couple commands and their respective flags.

```acmap
program.make = --source
program.format = --source

@test = "program make --; *source*"
@test = "program format --for; *format*"
```

###### Example 2

Multiple tests can be provided to test a single completion string. Simply delimit them with `;`.

```acmap
program.make = --source
program.format = --source

@test = "program make --; *source* ; #ceq1"
@test = "program format --for; *format* ; #ceq1"
```

#### Running tests:

Running tests is done by running a built in command: `$ nodecliac test <command-name>`. As an example, try running nodecliac's tests. With nodecliac installed, enter `nodecliac test nodecliac` into a Terminal and press <kbd>Enter</kbd>. Note, for tests to run the program's completion package _must_ exist in the [registry](#registry) to be able to run tests. Running `$ nodecliac registry` will list installed completion packages.

</details>

<a name="debugging"></a>

## Debugging

Like with testing completion strings, nodecliac also provides a way to debug completions. This is useful when creating a completion package. To start debugging simply enable it. When enabled pressing the <kbd>Tab</kbd> key will output debugging information instead of providing bash completions.

<details><summary>Expand debugging section</summary>

#### Enabling debugging:

Run: `$ nodecliac debug --enable`

#### Disabling debugging:

Run: `$ nodecliac debug --disable`

#### Picking Debug Script

nodecliac's auto-completion script is written in `Nim` and `Perl`. The Nim version supports Linux/macOS while Perl is used as a fallback. When both versions are installed it's possible to use one over the other to debug. This is done with the `--script` flag like so:

- Explicitly use Nim script: `$ nodecliac debug --enable --script nim`
- Explicitly use Perl script: `$ nodecliac debug --enable --script perl`

#### Debug mode

To get the debug mode: `$ nodecliac debug`

- `0`: Disabled
- `1`: Enabled
- `2`: Enabled + use Perl script
- `3`: Enabled + use Nim script

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
