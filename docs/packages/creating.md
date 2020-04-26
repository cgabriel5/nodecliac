# Creating Completion Package

_This guide uses [Sublime Text 3](https://www.sublimetext.com/3)'s `subl` program to document completion package creation._

## Summary

The process is straightforward:

1. Setup package and create `.acmap` file.
2. Write `.acmap` file and compile to `.acdef`.

- **Note**: Repeat step until `.acmap` is complete.

4. Once finished, add completion package to registry.
5. Source `.bashrc` file to apply changes and start using.

## Steps

<details><summary><b>1.</b> Setup package</summary>

<br>

Let's create the completion package folder and the program's `.acmap` file, `subl.acmap`:

```sh
$ cd ~/Desktop && mkdir subl && cd subl && touch subl.acmap
```

A folder named `subl` containing the single file `subl.acmap` should now exist on the desktop. The name of the completion package and `.acmap` file will _always_ be the name of the program.

**Completion package structure**: At the moment the completion package (`~/Desktop/subl`) should only contain an empty `subl.acmap` file. This guide will produce a completion package with the most basic of structure &mdash; _a folder containing `3` files_. This is the simplest a completion package needs to be to work.

```
<command>/
  ├── <command>.acmap
  ├── <command>.acdef
  └── .<command>.config.acdef
```

Packages of more complexity may have a `/placeholders` and or a `/hooks` directory. The `/placeholders` directory is made and used internally by nodecliac after compiling. Therefore, _never_ create this directory manually or store anything in this directory as it gets overwritten after every compile. The `/hooks` directory is created manually and stores [hook scripts](https://github.com/cgabriel5/nodecliac#hooks). Outside of that, the manner in which additional files/folders are structured is up to you.

</details>

<details><summary><b>2.</b> Write acmap file</summary>

<br>

**Tip**: _Grammar packages for [Sublime Text 3](https://www.sublimetext.com/3), [VSCode](https://code.visualstudio.com/), and [Atom](https://atom.io/) are [available](/resources/editors)._

With `~/Desktop/subl/subl.acmap` created open it and add the following:

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

[acmap](https://github.com/cgabriel5/nodecliac/new/master#syntax) syntax is used to map the commands with their flags. There is only one command in this case. The program command `subl`. The command's flags each take up their own line. Switches (flags representing either `true` or `false`) are appended a `?`.

</details>

<details><summary><b>3.</b> Compile <code>.acdef</code></summary>

<br>

With the `.acmap` ready, the next thing to do is generate the `.acdef` file. Run:

```sh
$ nodecliac make --source ~/Desktop/subl/subl.acmap
```

The package should now contain two new files: `subl.acdef` and `.subl.config.acdef`.

```
subl/
  ├── subl.acmap
  ├── subl.acdef
  └── .subl.config.acdef
```

</details>

<details><summary><b>4.</b> Add to registry</summary>

<br>

This package is now complete. Let's add it to the registry for use with nodecliac. In the package root run:

```sh
$ nodecliac add
```

**Note**: When developing a package the [`link`](./docs/packages/adding.md#linking) and [`unlink`](./docs/packages/removing.md#removingunlinking) commands should be used. Once package development is complete the [`add`](./docs/packages/adding.md#adding) command should be used to copy package to the registry instead of using a symlink.

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
