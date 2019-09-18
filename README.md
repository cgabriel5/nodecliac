# nodecliac

Easily add Bash tab completion to CLI programs with nodecliac (**node**-**cli**-**a**uto-**c**ompletion).

<p align="center"><img src="./resources/images/nodecliac-tab-completion.gif?raw=true" alt="nodecliac tab completion" title="nodecliac tab completion" width="auto"></p>

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
  - [Hooks](#resources-hooks)
- [Support](#support)
- [Contributing](#contributing)
- [License](#license)

<a name="install-normal"></a>

## Install

```sh
$ sudo curl -Ls https://raw.githubusercontent.com/cgabriel5/nodecliac/master/install | bash -s
```

<!-- [https://stackoverflow.com/questions/17341122/link-and-execute-external-javascript-file-hosted-on-github] -->

**Note**: Don't forget to reload `.bashrc` by running `$ source ~/.bashrc`.

<details><summary>More installation methods</summary>

##### With `curl`:

```sh
# Tab-completion only:
$ sudo curl -Ls https://raw.githubusercontent.com/cgabriel5/nodecliac/master/install | bash -s
# ...same as above.
$ sudo curl -Ls https://raw.githubusercontent.com/cgabriel5/nodecliac/master/install | bash -s aconly master

# Tab-completion + nodecliac CLI tools:
# Install with Node.js's npm...
$ sudo curl -Ls https://raw.githubusercontent.com/cgabriel5/nodecliac/master/install | bash -s npm master
# ... or with yarn.
$ sudo curl -Ls https://raw.githubusercontent.com/cgabriel5/nodecliac/master/install | bash -s yarn master
```

##### With `wget`:

```sh
# Tab-completion only:
$ sudo wget -qO- https://raw.githubusercontent.com/cgabriel5/nodecliac/master/install | bash -s
# ...same as above.
$ sudo wget -qO- https://raw.githubusercontent.com/cgabriel5/nodecliac/master/install | bash -s aconly master

# Tab-completion + nodecliac CLI tools:
# Install with Node.js's npm...
$ sudo wget -qO- https://raw.githubusercontent.com/cgabriel5/nodecliac/master/install | bash -s npm master
# ... or with yarn.
$ sudo wget -qO- https://raw.githubusercontent.com/cgabriel5/nodecliac/master/install | bash -s yarn master
```

</details>

<details><summary>Installation arguments</summary>

- `arg: $1`: `INSTALLER`
  - Values: `aconly`, `npm`, `yarn`. (default: `aconly`)
    - `aconly`: At the moment, generating `.acdef` files from `.acmap` files requires Node.js as the parser and all nodecliac's core tools are written in JavaScript. However, if you already have the CLI program(s) registry package/files and only need tab-completion, (you aren't generating `.acdef` files, for example) install this way.
    - `npm`: Uses Node.js's npm to install.
    - `yarn`: Uses yarn to install.
- `arg: $2`: `BRANCH_NAME`
  - Value: A _valid_ nodecliac branch name. (default: `master`)

</details>

<details>
  <summary>Requirements</summary>

- Node.js `8+`
  - nodecliac and its CLI tools (`.acmap` to `.acdef` parser, formatter, etc.) are written in JavaScript.
  - **Note**: If only tab-completion is needed (i.e. you already have the CLI program's registry package/files and don't need nodecliac's core CLI tools (parser, formatter, etc.)) then Node.js is _not_ required. Simply follow the [tab-completion only setup](#tab-ac-only) section.
- Perl `5+`
  - Runs needed Perl tab-completion scripts.
  - Works in tandem with Bash shell scripts.
- Bash `4.3+`
  - Glues/setup/runs Perl and Shell tab-completion scripts.
  - Works in tandem with Perl scripts.
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

nodecliac uses 2 custom file types: **a**uto-**c**ompletion **def**inition (`.acdef`) and **a**uto-**c**ompletion **map** (`.acmap`) files. The idea here is to create an `.acmap` file to map the CLI app's (sub)commands with their respective flags. `mycliprogram.acmap` then gets passed to nodecliac via the command line to generate an `.acdef` file. This generated `mycliprogram.acdef` definitions file can now be used by nodecliac to provide CLI tab completions.

###### Bullet Breakdown:

1. [Create CLI app's](#cli-usage-examples) `mycliprogram.acmap` file.
2. Using nodecliac's `make` command, provide `mycliprogram.acmap` to generate app's `mycliprogram.acdef` file.
3. Add generated `mycliprogram.acdef` file to [nodecliac's registry](#cli-usage-examples) via `make`'s `--add` flag.
4. Open a new Terminal or `source ~/.bashrc` to start enjoying Bash tab completions!
5. See [CLI Usage](#cli-usage-examples) section for examples.

<a name="acmap-syntax"></a>

## ACMAP Syntax

<details>
  <summary>auto-completion map (<code>.acmap</code>) files are text files with a simple language structure and relatively few language constructs.</summary>

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

#### Variables

- Variables start off with a dollar-sign (`$`) followed by the variable name.
- Variable name can start with an underscore (`_`) or a letter (`a-zA-Z`).
- Variable values are assigned with `=` followed by the variable value.
- A variable's value must be enclosed with quotes.
- Any amount of whitespace before and after `=` is fine, but keep things tidy.
- No amount of indentation can precede a setting declaration.
- To be clear, variables can be declared _anywhere_ within your `.acmap` file but to quickly see what settings are being declared they should be placed at the top of the file.

```acmap
$scriptpath = "~/path/to/script1.sh"
$scriptpath="~/path/to/script2.sh"
$scriptpath    =   "~/path/to/script3.sh"
```

#### Variable Interpolation (template-string)

- Variables are meant to be used inside quoted strings.
- Template strings have following structure:
  - A template string is denoted with starting `${` and closing `}`.
  - Any amount of space between opening/closing syntax is fine, but keep things tidy.
  - The string in between the closing/starting syntax is the variable name.

```acmap
# Variables - paths.
$mainscript = "~/.nodecliac/registry/yarn/main.sh"

# Command chains.
yarn.remove = default $("${mainscript} remove")
yarn.run = default $("${mainscript} run")
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

<details>
  <summary>Show command default documentation</summary>

#### Command Chain Default

Command chains can have a default command-string (runable shell command(s)) be run to dynamically generate auto-completion items. For example, say we are implementing an `.acmap` file for the dependency manager [yarn](https://yarnpkg.com/en/) and would like to return the names of installed modules when removing a package (i.e.`$ yarn remove...`). Basically, we would like to return the `package.json`'s `dependency` and `devDependency` entries. This can be done with a default command-string.

- Start by using the keyword `default` followed by a space.
- Follow that with the command-string like so:
  - A command string is denoted with starting `$(` and closing `)`.
  - The string in between the closing/starting syntax is the command-string.

**Note**: For more information about `command-string`s please take a look at `ACMAP Syntax > Flags > Flag Variations > Flags (dynamic values)`. The section contains all details for command-strings like special character escaping caveats, dynamic/static arguments, and examples with their breakdowns. Please be aware that the section uses the term `command-flag` due it being used for flags but `command-flag` and `command-string` are effectively the same thing. Here we see it being used for command chains. The naming is based on what it's being used for (i.e. flags or command chains).

```acmap
yarn.remove = [
  # The default command will run on '$ yarn remove [TAB]'. The 'config.sh' script should
  # contain the logic needed to parse package.json to return the installed (dev)dependency
  # packages.
  default $("~/.nodecliac/registry/yarn/config.sh")

  # As shown the script resides within ~/.nodecliac/ in the registry/ sub-directory. Some
  # CLI programs are more complicated than others. This will require the need to make a folder
  # under the registry/ directory for the command. In this folder all relevant files should
  # reside.
]
```

</details>

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
- Though not required, doing so will let the completion engine know the flag does not require a value.

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
- Once `cat ~/colors.text` is run the output will be split by hyphens and will finally get passed to the completion engine.
- **Note**: Arguments prefixed with the `$` character denotes it's a dynamic flag command argument.

**Escaping**: Internally the following characters have special uses: `$` and `|`. This means that when using these characters inside a command they will have to be escaped. Take the following examples:

- `--flag=$("echo \$0-\$1", $"echo 'john'", "doe", "-")`: The `$`s in the command are escaped.
- `--flag=$("nodecliac registry \| grep -oP \"(?<=─ )([-a-z]*)\"")`: Here the `|` gets escaped as well.

```acmap
mycliprogram.command = [
  # The '*' denotes the flag is a multi-flag meaning it can be used/supplied to program multiple times.
  --flag=*
  --flag=(
    # The flag-command's output will be used as option values.
    - $("cat ~/values.text")

    # Hard coded and dynamically generated values will be supplied to completion script.
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

## Miscellaneous

#### Blank Lines

Blank lines (empty lines) are allowed and ignored when generating `.acdef` file.

#### Duplicate Command Chains/Flags/Settings

Though allowed the parser will warn when duplicate command chains/flags/settings are detected.

#### Indentation

Indentation is all allowed but when declaring command chains and settings.

</details>

<a name="acdef-syntax"></a>

## ACDEF Syntax

<details>
  <summary>auto-completion definition (<code>.acdef</code>) files are easy to read, look similar to <code>.acmap</code> files, and is what nodecliac references when providing tab-completion.</summary>

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

.upgrade default $("~/.nodecliac/registry/yarn/scripts/main.sh upgrade")
.why default $("yarn list --depth=0 \| perl -wln -e \"/(?! ─ )([-\/_.@(?)a-zA-Z0-9]*)(?=\@)/ and print $&;\"")
.workspace default $("~/.nodecliac/registry/yarn/scripts/main.sh workspace")
.workspaces.run default $("~/.nodecliac/registry/yarn/scripts/main.sh run")
```

#### ACDEF Header

- The first line in an `.acdef` file is the header.
- The header contains a warning to not modify the file as well as the file's creation time information.

```acdef
# DON'T EDIT FILE —— GENERATED: Fri Jun 21 2019 19:59:33 GMT-0700 (PDT)(1561172373941)

...
```

#### Commands/Flags

- The following section contains the command chains and their respective flags.
- Each line represents a row which starts with the command chain and is followed by single space.
- Whatever comes after the single space are the command's flags.
- Rows that do not have flags will contain `--` after the single space character.
- Flags are separated by pipe (`|`) characters.

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
For example, if the line is `.workspaces.run --` it can be thought of as `yarn.workspaces.run --`.

#### Command Fallbacks

- The bottom section of an `.acdef` file will contain any command chain fallbacks.

```acdef
...

.upgrade default $("~/.nodecliac/registry/yarn/scripts/main.sh upgrade")
.why default $("yarn list --depth=0 \| perl -wln -e \"/(?! ─ )([-\/_.@(?)a-zA-Z0-9]*)(?=\@)/ and print $&;\"")
.workspace default $("~/.nodecliac/registry/yarn/scripts/main.sh workspace")
.workspaces.run default $("~/.nodecliac/registry/yarn/scripts/main.sh run")
```

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
nodecliac.make = --add?|--force?|--source|--save?|--print?|--trace?|--nowarn?
nodecliac.status = --enable?|--disable?
nodecliac.format = --indent|--source|--save?|--print?|--strip-comments?|--trace?|--nowarn?
nodecliac.print = --command=|--command=$("for f in ~/.nodecliac/registry/*/*.acdef; do f=\"\${f##*/}\";c=\"\${f%%.*}\";echo \"\$c\"; done;")
```

**Long form**: Verbose `nodecliac.acmap` alternative (same as short form). Settle on one or mixture of both.

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
  --strip-comments?
  --trace?
  --nowarn?
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

- `format`: Prettifies .acmap files.
  - `--indent="(s|t):Number"`: (**required**): Formatting indentation information:
    - `s` for spaces or `t` for tabs followed by a number.
    - `t:1`: Use 1 tab per indentation level.
    - `s:2`: Use 2 spaces per indentation level.
  - `--nowarn` : Don't print parser warnings.
  - `--print` : Print output to console.
  - `--save` : Overwrite source file with prettified output
  - `--source`: (**required**): The `.acmap` file path.
  - `--strip-comments` : Remove all comments from final output.
  - `--trace` : Used for debugging purposes only.
- `make`: Generate `.acdef` file from an `.acmap` file.
  - `--add`: Add generated`.acdef` file to nodecliac registry.
  - `--print` : Print output to console.
  - `--source`: (**required**): The `.acmap` file path.
  - `--force`: If an `.acdef` file exists for the command then this flag is needed to overwrite old`.acdef` file.
  - `--nowarn` : Don't print parser warnings.
  - `--save`: Will save generated `.acdef` file to source location.
  - `--trace` : Used for debugging purposes only.
- `print`: Print acmap/def file contents for files in registry.
  - `--command=`: The file to print (list dynamically generated based on available files in registry).
- `registry`: Lists `.acdef` files in registry.
- `setup`: Installs and setups nodecliac.
  - `--force` : If nodecliac is already installed this flag is needed for overwrite old install.
  - `--rcfilepath`: By default setup will look for `~/.bashrc` to add modifications to. Supply the path to another rc file if you don't want changes to be made to `~/.bashrc`.
    - **Note**: To be transparent this is what gets added to your rc file:
    - `ncliac=~/.nodecliac/src/main.sh;if [ -f "$ncliac" ];then source "$ncliac";fi;`
    - The line will load `~/.nodecliac/src/main.sh` if it exists. `main.sh` registers all `~/.nodecliac/registry/*/*.acdef` files with the completion script to work with bash-completion.
- `status`: Checks whether nodecliac is enabled/disabled.
  - `--enable` : Enables nodecliac if disabled.
  - `--disable`: Disables nodecliac if enabled.
- `uninstall`: Uninstalls nodecliac/reverts rc file changes.
  - `--rcfilepath`: rc file used in setup to remove changes from.

</details>

<a name="cli-usage-examples"></a>

## CLI Usage Examples

#### Generate ACDEF file

```sh
# Generate mycliprogram.acdef file and add it to registry.
$ nodecliac make --source path/to/mycliprogram.acmap --add

# Generate mycliprogram.acdef contents but only print to terminal.
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

Some CLI programs are more complicated than others and will require the need of additional custom script files. If this is the case, a command folder should be made under the following path: `~/.nodecliac/registry/COMMAND-NAME/`. For example, say we are creating an `.acmap` file for [yarn](https://yarnpkg.com/en/) and we need to run custom script files for a better tab-completion experience. These files should reside at `~/.nodecliac/registry/yarn/`. [See directory structure/files here](/resources/nodecliac).

<details><summary>Show directory structures.</summary>

- Required directory base structure:

```
~/.nodecliac/
└── registry/
    └── COMMAND-NAME/
        ├── COMMAND-NAME.acdef
        ├── .COMMAND-NAME.config.acdef
        └── hooks/
```

- Directory structure with yarn as a registry command:

```
~/.nodecliac/
└── registry/
    └── yarn/
        ├── yarn.acdef
        ├── .yarn.config.acdef
        └── hooks/
```

**Note**: The manner in which script files are structured within `~/.nodecliac/registry/COMMAND-NAME/` is up to you. Just note that the above base structure is required.

</details>

<a name="resources-hooks"></a>

## Hooks

As stated in the resources files section some programs are more complicated than others. In the case of [yarn](https://yarnpkg.com/en/) its `yarn.acdef` file needed to be modified before parsing to [dynamically add the repos scripts as commands](https://yarnpkg.com/en/docs/cli/run#toc-yarn-run). One of the easier solutions for this was to use a pre-parsing hook. Basically, before nodecliac does anything
it is possible to use a hook script to modify the command's `.acdef` file and CLI input (in-memory) values.

Available hook scripts:

- `hooks/prehook.sh`
  - Allows the modification of the in-memory `acdef` contents before starting any parsing.
  - Allows the modification of the in-memory CLI input string before starting any parsing.

**Note**: Using a hook script might sound involved/off-putting but it's not. A hook script is just a regular shell script. The script just has special meaning in the sense that it can be used to **hook** into nodecliac to change some variables used for later tab-completion processing.

<details><summary>Expand hook section.</summary>

#### Making Hook Script

To use a hook script simply create the file in the command's resource `hooks/` directory: `~/.nodecliac/registry/COMMAND-NAME/hooks`. All hook scripts will reside in the `COMMAND-NAME/hooks` sub directory. For example, creating the `prehook` script for yarn would be: `~/.nodecliac/registry/yarn/hooks/prehook.sh`.

#### Using Hook Script

This section will use [yarn's prehook script](/resources/nodecliac/yarn) as an example. [`/yarn/hooks/prehook.sh`](/resources/nodecliac/yarn) runs custom Perl scripts to modify the `.acdef` and the CLI input. Since the prehook script is sourced into the main completion script nothing is echoed back to the main script. Instead, the `acdef` and `cline` variables are overwritten, rather. These new values will then be used by nodecliac to provide tab-completion.

**Note**: Perl is used here for quick text processing as doing it in Bash is slow and cumbersome. _However_, use what you _want/need_ to get the job done. Hook scripts just _need_ to be executable scripts stored in `~/.nodecliac/registry/COMMAND-NAME/hooks/`.

**Note**: As a reminder, the provided `.acmap` file gets parsed to generate an `.acdef` file. The created `.acdef` file is what nodecliac actually reads **a**uto-**c**ompletion **def**initions from. Therefore, modifying `.acdef` contents is a _slightly_ advanced topic as it requires knowing `.acdef` syntax.

</details>

<a name="support"></a>

## Support

#### OS Support

- Made using Node.js `v8.16.0` on a Linux machine running `Ubuntu 16.04.5 LTS`.
- Tested and working on:
  - `macOS Mojave (v10.14.4)`.
  - `Windows 10 - Untested`.

#### Shell Support

- nodecliac only works with Bash, seeing that it is the only shell I use. However, if the project grows support for other shells (Zsh, Fish, etc.) may be added.

#### Editor Support (Syntax Highlighting)

- I use Sublime Text (ST) and have created a language syntax file (`acmap.sublime-syntax`) for it. ST files can be accessed [here](/resources/sublime-text/). Download the folder and place it in the `User/` folder for ST to pickup. Personally, I have it stored like so: `/User/Languages/Auto Completion Map (acmap)`.
- Support for other editors can also be added if the project grows.

<a name="contributing"></a>

## Contributing

Contributions are welcome! Found a bug, feel like documentation is lacking/confusing and needs an update, have performance/feature suggestions or simply found a typo? Let me know! :)

See how to contribute [here](/CONTRIBUTING.md).

<a name="license"></a>

## License

This project uses the [MIT License](/LICENSE.txt).
