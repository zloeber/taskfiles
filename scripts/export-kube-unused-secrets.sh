#!/bin/bash
volumeSecrets=$(kubectl get pods --all-namespaces -o jsonpath='{.items[*].spec.volumes[*].secret.secretName}' | xargs -n1)
envSecrets=$(kubectl get pods --all-namespaces -o jsonpath='{.items[*].spec.containers[*].env[*].valueFrom.secretKeyRef.name}' | xargs -n1)
envSecrets2=$(kubectl get pods --all-namespaces -o jsonpath='{.items[*].spec.containers[*].envFrom[*].secretRef.name}' | xargs -n1)
pullSecrets=$(kubectl get pods --all-namespaces -o jsonpath='{.items[*].spec.imagePullSecrets[*].name}' | xargs -n1)
tlsSecrets=$(kubectl get ingress --all-namespaces -o jsonpath='{.items[*].spec.tls[*].secretName}' | xargs -n1)

echo $("$envSecrets\n$envSecrets2\n$volumeSecrets\n$pullSecrets\n$tlsSecrets" | sort | uniq)
#<(kubectl get secrets --all-namespaces -o jsonpath='{.items[*].metadata.name}' | xargs -n1 | sort | uniq)
