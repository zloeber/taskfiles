#!/usr/bin/env bash

while read -r line
do
    output=$(kubectl get "$line" --all-namespaces -o yaml 2>/dev/null | grep '^items:')
    if ! grep -q "\[\]" <<< $output; then
        echo -e "\n======== "$line" manifests ========\n"
        kubectl get "$line" --all-namespaces -o yaml
    fi
done < <(kubectl api-resources -o name)
