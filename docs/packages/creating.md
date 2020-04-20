# Creating Completion Package

_Guide shows how to create a completion package for [Sublime Text 3](https://www.sublimetext.com/3)'s `subl` command._

### Firsts Things First

If nodecliac is not already installed install it:

```sh
$ sudo curl -Ls https://raw.githubusercontent.com/cgabriel5/nodecliac/master/install | bash -s
```

_See complete installation methods [here](https://github.com/cgabriel5/nodecliac/new/master#install)._

### Creating acmap File

Let's create the completion package folder and the program's `.acmap` file, `subl.acmap`:

```sh
$ cd ~/Desktop && mkdir subl && cd subl && touch subl.acmap
```

A folder named `subl` containing the single file `subl.acmap` should now exist on the desktop.

**Note**: The name of the completion package and `.acmap` file will always be the name of the program.

### Writing acmap File

**Tip**: _Grammar packages for [Sublime Text 3](https://www.sublimetext.com/3), [VSCode](https://code.visualstudio.com/), and [Atom](https://atom.io/) are [available](/resources/editors). Install one for syntax highlighting._

With `subl.acmap` created, lets write to it. Open it in your editor of choice and add the following:

```acmap
subl = [
    --project
    --command
    --new-window?
    --add
    --wait?
    --background?
    --stay?
    --help?
    --version?
]
```

The [.acmap syntax](https://github.com/cgabriel5/nodecliac/new/master#syntax) here is simple. As shown, each flag take up their own line. Flags representing switches (`true` or `false`) are appended a `?`.

### Generating Completion Package

With the `.acmap` ready, the next thing to do is generate its `.acdef` file. Run:

```sh
$ nodecliac make --source ~/Desktop/subl/subl.acmap
```

This generates two files: `subl.acmap` and `.subl.config.acdef`.

### Adding To Registry

The package must now be added to the registry for nodecliac to use it. While in the package root run:

```sh
$ nodecliac add
```

**Note**: When developing a package the `link` and `unlink` commands should be used. Once package development is complete the `add` command should be used to copy package to the registry instead of using a symlink.

**Tip**: Confirm package is in registry by running: `$ nodecliac registry`. Output should include the name of your package.

### Using It

Open a new Terminal (or `$ source ~/.bashrc` current one), type `$ subl --`, and hit <kbd>Tab</kbd><kbd>Tab</kbd> to see completions.

<!-- [https://superuser.com/a/836349] -->

<p align="center"><img src="../../resources/images/subl-completion.gif?raw=true" alt="subl completion" title="subl completion" width="auto"></p>

### What's Next

That was it for the `subl` command. Admittedly, the command is relatively simple and for that reason it's used in this guide. However, as should go without saying, the more complex a CLI program is the more the fleshed out `.acmap` will become. `.acmap`s for various programs (of varying degrees of complexity) can be found [here](resources/packages).

For a more complex example which uses a `pre-hook` and `Perl` scripts take a look at the [yarn completion package](https://github.com/cgabriel5/nodecliac/tree/master/resources/nodecliac/yarn).
