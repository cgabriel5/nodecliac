# Adding/Linking Completion Package

### Adding

This copies the folder to the registry, `~/.nodecliac/registry`.

```sh
$ nodecliac add # Run in package root.
```

### Linking

During development symlink package to registry.

```sh
$ nodecliac link # Run in package root.

# Once development is complete remove symlink and add to registry.
$ nodecliac unlink && nodecliac add # Run in package root.
```

**Tip**: Run `$ nodecliac registry`. Package should appear in output.

Finally, open a Terminal or `$ source ~/.bashrc` current one and start using it.
