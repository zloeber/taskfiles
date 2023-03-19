# Taskfiles Collection

This is a library of taskfile.dev definitions for things you may do at a cli once in a while or maybe multiple times a day. These are categorized and then included in an ignored vendir synced location  project's root Taskfile.yaml file along with some supporting


## Notes

Taskfile uses golang templating and variable resolution that can be confusing. The gist is:

- `vars` blocks within included task files are global in scope. If defined multiple times the last defined variable 'wins' and will be the value for all tasks unless manually overwritten at the task level.

- `env` blocks are just available to your script tasks as env vars without taskfile interference.

So in general, you will want to not include additional variables in the included taskfiles that may be defined elsewhere. Just include them in the main Taskfile.yml to be safe in most cases.
