#!/bin/bash

# Set the base folder
base_folder="./tasks"

# Initialize the YAML string
yaml_string="includes:
  variables:
    taskfile: ./Taskfile.vars.yml
    optional: true"

# Loop through Taskfile.*.yml files in the base folder
for taskfile in "$base_folder"/Taskfile.*.yml; do
  # Extract subfolder name from the file name
  subfolder_name=$(basename "$taskfile" | cut -d'.' -f2)

  # Add entry to the YAML string
  yaml_string+="
  $subfolder_name:
    taskfile: $taskfile
    optional: true"
done

# Print the final YAML string
echo "$yaml_string"
