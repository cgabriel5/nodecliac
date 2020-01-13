# Removing/Unlinking Completion Package

### The Registry

In short, the registry is where all completion packages are kept. It is located at `~/.nodecliac/registry`. Complete information about the registry can be found [here](https://github.com/cgabriel5/nodecliac#registry).

### Removing/Unlinking

The `remove`/`unlink` commands take _n_ arguments (package names) and have the same function. Either can be used.

```sh
$ nodecliac remove <PACKAGE_NAME> # same as: '$ nodecliac unlink <PACKAGE_NAME>'
```

Once removed, run `$ nodecliac registry`. The name of the package should not be included in the output.

**Tip**: Remember to `$ source ~/.bashrc` any open Terminals to reflect changes.
