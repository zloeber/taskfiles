<!---toc start-->

* [Taskfiles Collection](#taskfiles-collection)
* [Configuration](#configuration)
  * [Notes](#notes)
    * [Docker Image](#docker-image)
    * [Applications](#applications)

<!---toc end-->

# Taskfiles Collection

This is a library of [taskfile.dev](https://taskfile.dev) definitions for things you may do at a cli once in a while or maybe multiple times a day.

# Configuration

This uses [asdf-vm](https://asdf-vm.com/) to manage binaries used by this application. You can install it and other requirements via `./.configure.sh`.

## Notes

### Docker Image

This includes a rudimentary docker image you can use to run most tasks. Simply build it with the task

```bash
task docker:build docker:shell
```

Then when you are in the running container start up zsh for a better shell experience
```bash
/bin/zsh
```

### Applications

I tend to lean on other, purpose built, application managers for installing higher level dependencies like python, golang, or nodejs. This can be done via asdf specifically if you are up for setting that up in your shell. Adding a .tool-versions file with your applications and their version works swimmingly most of the time. 

Another option for many applications would be aqua. Tasks have been included to install aqua and sync up application versions within a definition file in your repo easily enough. Otherwise, the local binary installs tend to get dropped in a local binary path. The default for this project is `.local` but you can update this to suit your needs in the root Taskfile.yml
