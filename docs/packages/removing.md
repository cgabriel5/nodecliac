# Removing Completion Package

### The Registry

In short, the registry is where all completion packages are kept. It is located at `~/.nodecliac/registry`. Complete information about the registry can be found [here](https://github.com/cgabriel5/nodecliac#registry).

### Removing Completion Package

The `remove` command can take as many arguments (package names):

```sh
$ nodecliac remove <PACKAGE_NAME>
```

Once removed, run `$ nodecliac registry`. The name of the package should not be included in the output.

**Tip**: Remember to `$ source ~/.bashrc` any open Terminals to reflect changes.
