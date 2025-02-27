<!---toc start-->

* [Taskfiles Collection](#taskfiles-collection)
* [Configuration](#configuration)
  * [Additional Software](#additional-software)
  * [Variables](#variables)
* [Notes](#notes)
    * [Docker Image](#docker-image)
  * [Usage](#usage)
  * [Development](#development)

<!---toc end-->

# Taskfiles Collection

This is a library of [taskfile.dev](https://taskfile.dev) definitions for things you may do at a cli once in a while or maybe multiple times a day.

# Configuration

You can install [mise](https://mise.jdx.dev) and other requirements via `./.configure.sh`.

## Additional Software

Mise handles a good deal of software you might use in a taskfile. Check if whatever binary you are looking for with `mise install <binary>`. If it is not installed then you can use cargo, go, or python packages as well. One example of this is in this project's `.mise.toml` file for [eget](https://github.com/zyedidia/eget) (which is a last ditch method to automatically install binary releases from github). You can use eget to install binaries into your user local bin path like so `eget canop/broot --to ~/.local/bin`

## Variables

You can overwrite most variables by including a `Taskfile.vars.yml` file with the variables you wish to overwrite. Or you can include the variable name assignment prior to calling task in most cases.

# Notes

### Docker Image

This includes a rudimentary docker image you can use to run most tasks. Simply build it with the task

```bash
task docker:build docker:shell
```

Then when you are in the running container start up zsh for a better shell experience. Then you can run task or any other binaries included in `.mise.toml`

```bash
/bin/zsh
```

## Usage

To use this in a project you need only copy the `tasks` folder and `Taskfile.yml`/`Taskfile.vars.yml` to your project root. Keep files in the `tasks` folder that you plan on using. Ensure `tasks` is in your `.gitignore` file.

> **TIP** Monorepo project? To use the tasks within subfolders simply soft link the Taskfile.yml and tasks folder into it. Then create a per-folder Taskfile.vars.yml file if needed.

You can use vendir to sync versions of this repo into your own if you like. Create a vendir.yml file with contents like the following:

```yaml
apiVersion: vendir.k14s.io/v1alpha1
kind: Config
directories:
  - path: ./.tasks
    contents:
      - path: ./
        git:
          url: https://github.com/zloeber/taskfiles.git
          ref: main
        includePaths:
          - tasks/**/*
          - Taskfile.yml
          - Taskfile.vars.yml
```

Then at the root of your project run:

```bash
vendir sync
ln -s ./.tasks/tasks ./
ln -s ./.tasks/Taskfile.yml ./
cp ./.tasks/Taskfile.vars.yml ./
```

Finish off by adding `.tasks` to your `./.gitignore`

> **NOTE** You can keep any custom tasks in `./Taskfile.custom.yml` but you cannot use dotenv sourcing within them. Use `.mise.toml` to do this instead!

> **NOTE** You can change variables in Taskfile.vars.yml as you see fit. If you softlink the base Taskfile.yml to subdirectories (for monorepos perhaps) adding another local var file to customize the targets may make sense.

##

## Development

Fork this repo, make updates, send a PR for approval. If you update this readme ensure to run `task toc` to update the table of contents.
