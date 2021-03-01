import os, strformat, tables

let cwd = parentDir(parentDir(currentSourcePath()))
let homedir = os.getEnv("HOME")
const projectname = "nodecliac"
let ncliacdir = joinPath(homedir, fmt".{projectname}")
let bashrcpath = joinPath(homedir, ".bashrc")
const mainscriptname = "init.sh"
let registrypath = joinPath(homedir, fmt".{projectname}", "registry")
let acmapssource = joinPath(homedir, fmt".{projectname}", "src")
let setupfilepath = joinPath(ncliacdir, ".setup.db.json")
let resourcespath = joinPath(cwd, "resources", "packages")
let resourcessrcs = joinPath(cwd, "src", "scripts")
let testsrcpath = joinPath(cwd, "tests", "scripts")
let cachepath = joinPath(homedir, fmt".{projectname}", ".cache")

let paths* = {
    "cwd": cwd,
    "homedir": homedir,
    "ncliacdir": ncliacdir,
    "bashrcpath": bashrcpath,
    "mainscriptname": mainscriptname,
    "registrypath": registrypath,
    "acmapssource": acmapssource,
    "setupfilepath": setupfilepath,
    "resourcespath": resourcespath,
    "resourcessrcs": resourcessrcs,
    "testsrcpath": testsrcpath,
    "cachepath": cachepath
}.toTable
