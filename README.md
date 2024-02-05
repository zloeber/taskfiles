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

Additional Python specific tools get dropped in a local binary path called `.local`.

## Variables

You can overwrite most variables by including a `Taskfile.vars.yml` file with the variables you wish to overwrite.

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

## Development

Fork this repo, make updates, send a PR for approval. If you update this readme ensure to run `task toc` to update the table of contents.
