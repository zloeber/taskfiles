#!/bin/bash
# Install taskfiles templates to current path.
# This script will download vendir.yml from the GitHub repository and sync the vendir dependencies.
# It will also create symlinks to the taskfiles templates.

set -pipefail -euo errexit

# Check if taskfiles is installed
task_ver=$(task --version 2>/dev/null)
vendir_ver=$(vendir --version 2>/dev/null)
if [[ ! $task_ver =~ "Task version:" ]]; then
  echo "Task is not installed. Exiting..."
  echo "(tip: curl -sL https://taskfile.dev/install.sh | sh)"
  exit 1
fi

if [[ ! -f vendir.yml ]]; then
  # Download vendir.yml from GitHub repository
  curl -sLJO https://raw.githubusercontent.com/zloeber/taskfile/main/scripts/config/vendir.yml

  # Check if the download was successful
  if [[ ! -f vendir.yml ]]; then
    echo "Failed to download vendir.yml. Exiting..."
    exit 1
  fi
fi

if [[ ! $vendir_ver =~ "vendir version" ]]; then
  echo "Vendir is not installed. Exiting..."
  echo "(tip: install via mise, 'mise use vendir@latest')"
  exit 1
else
  vendir sync
fi

# Create symlinks to taskfiles templates
ln -s ./.tasks/tasks ./
ln -s ./.tasks/Taskfile.yml ./
cp ./.tasks/Taskfile.vars.yml ./

echo "Taskfiles templates installed successfully.
Run 'task --list' to see available tasks.
Run 'task <task-name>' to execute a task.

Don't want to sully your git projects with this task crap?

In a subfolder you can run 'task -t ../Taskfile.yml --list' 
to use the taskfiles templates in the parent folder locally!
"
