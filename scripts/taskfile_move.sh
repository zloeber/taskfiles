#!/bin/bash

# Set the base folder
base_folder="./tasks"

# Loop through subfolders
for subfolder in "$base_folder"/*/; do
    subfolder_name=$(basename "$subfolder")

    # Check if Taskfile.yml exists in the subfolder
    if [ -e "$subfolder/Taskfile.yml" ]; then
        # Copy Taskfile.yml to the base folder with the desired format
        cp "${subfolder}/Taskfile.yml" "${base_folder}/Taskfile.${subfolder_name}.yml"
        echo "Copied Taskfile.yml from ${subfolder_name} to Taskfile.${subfolder_name}.yml"
    fi
done
