import os


# setCurrentDir(newDir="/home/speckr/.nodecliac/registry")
# echo "????"


# for kind, path in walkDirs("*"):
#     echo(path)



for kind, path in walkDir("/home/speckr/.nodecliac/registry"):
    # echo(path)
    # echo tailDir(path)
    # let name = splitPath(path, DirSep)[^1]
    let parts = splitPath(path)
    echo parts.tail
    # echo ""
