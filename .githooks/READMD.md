# Git Hooks

Project git hooks are stored here.

### Installing

[yarn](https://yarnpkg.com/en/) or [npm](https://www.npmjs.com/get-npm), depending on what is used to install nodecliac, will link the hook scripts in this directory with git by running the `preinstall` `package.json` script.

```json
{
  "scripts": {
    "preinstall": "git config core.hooksPath .githooks"
  }
}
```

### Git Hook Resources:

- https://githooks.com/
- https://hackernoon.com/how-to-use-git-hooks-in-your-development-workflow-a94e66a0f3eb
- https://www.atlassian.com/git/tutorials/git-hooks
- https://stackoverflow.com/a/55958779
- https://www.viget.com/articles/two-ways-to-share-git-hooks-with-your-team/
- https://stackoverflow.com/questions/2293498/applying-a-git-post-commit-hook-to-all-current-and-future-repos
- https://sigmoidal.io/automatic-code-quality-checks-with-git-hooks/
- https://rock-it.pl/automatic-code-quality-checks-with-git-hooks/
