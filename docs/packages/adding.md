# Adding/Linking Completion Package

### The Registry

In short, the registry is where all completion packages are kept. It is located at `~/.nodecliac/registry`. Complete information about the registry can be found [here](https://github.com/cgabriel5/nodecliac#registry).

### Adding

```sh
$ nodecliac add # run in package root
```

### Linking

During development, instead of constantly adding/removing to see changes, its best symlink the package:

```sh
$ nodecliac link # run in package root
```

**Note**: Once development is complete simply [remove](./removing.md) the symlink.

That's it. Once added, run `$ nodecliac registry`. The name of the package should be included in the output.

### Using It

Open a new Terminal (or run `$ source ~/.bashrc` in current one) and start using it.
