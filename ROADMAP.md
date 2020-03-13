# Roadmap

_Document serves to give insight into project plans (i.e. possible features, improvements, etc.)._

### Features

- [ ] Build proper package manager to easily manage completion packages.
- [ ] _Syntax_: Look into expanding `.acmap` syntax to allow for conditional logic:
  - For example, to be able to show `x` command/flag only when `y` command/flag is/isn't already used.
- [ ] Look into building a GUI (maybe website) to help with `.acmap` file creation.
- [x] _Caching_: Look into supporting a cache system to provide quicker completions.

### Support

- [ ] Look into supporting Zsh/Fish shells.
- [ ] Look into supporting the Windows platform.

### Improvements

- [x] Look into porting `.acmap` JavaScript CLI tools (parser/formatter) to Nim to remove Node.js requirement when building completion packages.
