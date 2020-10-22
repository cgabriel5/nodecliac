# Creating Completion Package

_This guide uses [Sublime Text 3](https://www.sublimetext.com/3)'s `subl` program to document completion package creation._

## Summary

The process is straightforward:

- Scaffold package.
- Write `.acmap` file and compile to `.acdef` (_repeat this until `.acmap` is complete_).
- Once finished, add completion package to registry.
- Source `.bashrc` file to apply changes and start using.

## Steps

<details><summary><b>1.</b> Scaffold package</summary>

<br>

First let's scaffold the completion package. Navigate to `~/Desktop` and run:

```sh
$ nodecliac init
```

It will start the builtin completion package generator — which asks a series of questions to scaffold your program's base completion package. After running `nodecliac init` a folder with the provided `<command>` name will be created. Inside it are `4` files:

```
<command>/
  ├── package.ini
  ├── <command>.acmap
  ├── <command>.acdef
  └── .<command>.config.acdef
```

**Note**: This is the simplest a completion package needs to be to work. Packages of more complexity may have a `/placeholders` and or a `/hooks` directory. The `/placeholders` directory is made and used internally by nodecliac after compiling. Therefore, _never_ create this directory manually or store anything in this directory as it gets overwritten after every compile run. The `/hooks` directory is created manually and stores [hook scripts](https://github.com/cgabriel5/nodecliac#hooks). Outside of that, the manner in which additional files/folders are structured is up to you.

</details>

<details><summary><b>2.</b> Write acmap file</summary>

<br>

**Tip**: _Syntax grammar packages for [Sublime Text 3](https://www.sublimetext.com/3), [VSCode](https://code.visualstudio.com/), and [Atom](https://atom.io/) are [available](/resources/editors)._

Here is Sublime Text's CLI interface as of `v3211`:

```
Sublime Text build 3211

Usage: subl [arguments] [files]         Edit the given files
   or: subl [arguments] [directories]   Open the given directories

Arguments:
  --project <project>: Load the given project
  --command <command>: Run the given command
  -n or --new-window:  Open a new window
  -a or --add:         Add folders to the current window
  -w or --wait:        Wait for the files to be closed before returning
  -b or --background:  Don't activate the application
  -h or --help:        Show help (this message) and exit
  -v or --version:     Show version and exit

Filenames may be given a :line or :line:column suffix to open at a specific
location.
```

Now it's time to write the program's `acmap`. This is done by using [acmap](https://github.com/cgabriel5/nodecliac/new/master#syntax) markup. Breaking it down, Sublime Text's `subl` command is very simple. There is only one command — the program (main/root) command `subl` and it has a few flags. As shown, each flag takes up its own line. Switches (flags representing either `true` or `false`) are appended a `?`.

Open the generated acmap file, `~/Desktop/subl.acmap`, and place the following acmap inside:

```acmap
subl = [
    --project
    --command
    --new-window?
    --add?
    --wait?
    --background?
    --stay?
    --help?
    --version?
]
```


</details>

<details><summary><b>3.</b> Compile <code>.acdef</code></summary>

<br>

With the `.acmap` ready, the next thing to do is generate the `.acdef` file. To do so run:

```sh
$ nodecliac make --source ~/Desktop/subl/subl.acmap
```

This will parse `subl.acmap` to generate the program's `acdef` and config file: `subl.acdef` and `.subl.config.acdef`.

`subl`'s completion package should look like:

```
subl/
  ├── package.ini
  ├── subl.acmap
  ├── subl.acdef
  └── .subl.config.acdef
```

</details>

<details><summary><b>4.</b> Add to registry</summary>

<br>

This package is now complete. Let's add it to the registry so nodecliac can use it. In the package root run:

```sh
$ nodecliac add
```

**Note**: When developing a package the [`link`](./docs/packages/adding.md#linking) and [`unlink`](./docs/packages/removing.md#removingunlinking) commands should be used, which use symlinks instead of copying the folder every time there is change. Once package development is complete the [`add`](./docs/packages/adding.md#adding) command should be used to copy package to the registry instead of using a symlink.

**Tip**: Run `$ nodecliac registry` to confirm package is in the registry. Output should list the name of the package.

</details>

<details><summary><b>5.</b> Reload rcfile</summary>

<br>

Open a Terminal or `$ source ~/.bashrc` current one then type <code>\$ subl --<kbd>Tab</kbd><kbd>Tab</kbd></code> to see completions.

<!-- [https://superuser.com/a/836349] -->

<p align="center"><img src="../../resources/images/subl-completion.gif?raw=true" alt="subl completion" title="subl completion" width="auto"></p>

</details>

### What's Next

That was it for the `subl` command. Admittedly, the command is extremely simple and for that reason it's used in this guide. However, as should go without saying, the more complex a CLI program is the more its `.acmap` will require. Existing completion packages of varying degrees of complexity can be found [here](resources/packages). Take a look at the [yarn completion package](https://github.com/cgabriel5/nodecliac/tree/master/resources/packages/yarn) which make use of a [hook](https://github.com/cgabriel5/nodecliac/tree/docs#hooks) and `Perl` scripts.
