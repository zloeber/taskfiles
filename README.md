# Taskfiles Collection

This is a library of taskfile.dev definitions for things you may do at a cli once in a while or maybe multiple times a day. These are categorized and then included in an ignored location synced via vendir (or similar solution).

## Notes

### Applications

I tend to lean on other, purpose built, application managers for installing higher level dependencies like python, golang, or nodejs. This can be done via asdf specifically if you are up for setting that up in your shell. Adding a .tool-versions file with your applications and their version works swimmingly most of the time. 

Another option for many applications would be aqua. Tasks have been included to install aqua and sync up application versions within a definition file in your repo easily enough. Otherwise, the local binary installs tend to get dropped in a local binary path. The default for this project is `.local` but you can update this to suit your needs in the root Taskfile.yml

### Variables
Taskfile uses golang templating and variable resolution that can be confusing. The gist is:

- `vars` blocks within included task files are global in scope. If defined multiple times the last defined variable 'wins' and will be the value for all tasks unless manually overwritten at the task level.

- `env` blocks are just available to your script tasks as env vars without taskfile interference.

So in general, you will want to NOT include additional variables in the included taskfiles that may be defined elsewhere. Just include them in the main Taskfile.yml to be safe.
