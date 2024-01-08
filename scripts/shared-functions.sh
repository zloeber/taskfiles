#!/bin/bash

[[ "$BASH_SOURCE" == "$0" ]] &&
    echo "This file is meant to be sourced, not executed" &&
    exit 30

## Common/Helper functions
function info() {
    printf "\033[2K[ \033[00;34mINFO\033[0m ] $1\n"
}

function debug() {
    if [ $DEBUG_ENABLED ]; then
        info "${1}"
    fi
}

function eecho() {
    printf "\033[2K[ \033[00;34mINFO\033[0m ] $1\n"
}

function success() {
    printf "\r\033[2K[ \033[00;32mOK\033[0m ] $1\n"
}

function error() {
    local message=${1:-"Script Failure"}
    local errorcode=${2:-1}
    printf "\r\033[2K[\033[0;31mERROR\033[0m] $message\n"
    exit $errorcode
    # if [[ "${CI}" == "true"  ]]; then
    #     exit $errorcode
    # else
    #     return $errorcode
    # fi
}

function warn() {
    printf "\r\033[2K[\033[0;33mWARNING\033[0m] $1\n"
}

# Ensures that a required binary exists in current $PATH
# Usage: require <command name>
function require() {
    local commandname=$1
    local not_found

    for commandname; do
        if ! command -v -- "${commandname}" >/dev/null 2>&1; then
            warn "Required binary check: ${commandname}"
            ((not_found++))
        else
            success "Required binary check: ${commandname}"
        fi
    done

    if ((not_found > 0)); then
        error "Missing requirements: ${not_found}"
    fi
}

vault_token_exists() {
    echo $VAULT_CLIENT_TOKEN
    echo $VAULT_ACCESSOR
    if [ -z "$VAULT_CLIENT_TOKEN" ] || [ -z "$VAULT_ACCESSOR" ]; then
        echo "$0 - Token or accessor does not exist"
        return 1
    else
        echo 0
    fi
}

vault_token_is_valid() {
    echo "Checking token validity"
    token_lookup=$(curl -X POST \
        -H "X-Vault-Token: $VAULT_CLIENT_TOKEN" \
        -w %{http_code} \
        --silent \
        --output /dev/null \
        -d '{"accessor":"'"$VAULT_ACCESSOR"'"}' \
        $VAULT_ADDR/v1/auth/token/lookup-accessor)
    if [ "$token_lookup" == "200" ]; then
        echo "$0 - Valid token found, exiting"
        return 0
    else
        echo "$0 - Invalid token found"
        return 1
    fi
}

vault_fetch_token_and_accessor() {
    curl -X POST \
        --silent \
        -d '{"role_id":"'"$VAULT_ROLE_ID"'","secret_id":"'"$VAULT_SECRET_ID"'"}' \
        $VAULT_ADDR/v1/auth/approle/login |
        tee >(jq --raw-output '.auth.accessor' >/tmp/accessor) >(jq --raw-output '.auth.VAULT_CLIENT_TOKEN' >/tmp/VAULT_CLIENT_TOKEN)
}

vault_renew_token() {
    echo "Renewing token"
    curl -X POST \
        --silent \
        -H "X-Vault-Token: $VAULT_CLIENT_TOKEN" \
        $VAULT_ADDR/v1/auth/token/renew-self | jq
}

# Scrapes the Hashicorp release endpoint for valid versions
# Usage: get_hashicorp_version <app>
function get_hashicorp_version() {
    local vendorapp="${1?"Usage: $0 app"}"
    local IGNORED_EXT='(tar\.gz\.asc|\.txt|\.tar\.xz|\.asc|\.MD|\.hsm|\+ent\.hsm|\.rpm|\.deb|\.sha256|\.src\.tar\.gz|\.sig|SHA256SUM|\.log|homebrew|alpha|beta|\.fips.*)'

    # Scrape HTML from release page for binary versions, which are
    # given as ${binary}_<version>. We just use sed to extract.
    curl -s "https://releases.hashicorp.com/${vendorapp}/" | grep -v -E "${IGNORED_EXT}" | sed -n "s/.*${vendorapp}_\([0-9][^<]*\)<.*/\1/p" | sed -n 1p
}

# Scrapes the Hashicorp release endpoint for valid versions
# Usage: get_hashicorp_version <app>
function get_hashicorp_versions() {
    require jq
    require curl

    local vendorapp="${1?"Usage: $0 app"}"
    local IGNORED_EXT='(tar\.gz\.asc|\.txt|\.tar\.xz|\.asc|\.MD|\.hsm|\+ent\.hsm|\.rpm|\.deb|\.sha256|\.src\.tar\.gz|\.sig|SHA256SUM|\.log|homebrew|alpha|beta|\.fips.*)'

    # Scrape HTML from release page for binary versions, which are
    # given as ${binary}_<version>. We just use sed to extract.
    curl -s "https://releases.hashicorp.com/${vendorapp}/" | grep -v -E "${IGNORED_EXT}" | sed -n "s/.*${vendorapp}_\([0-9][^<]*\)<.*/\1/p"
}

# Usage: get_hashicorp_release_url <app>
# Usage: get_hashicorp_release_url <app> <version>
# Usage: ENT=true _platform=darwin get_hashicorp_release_url <app>
function get_hashicorp_release_url() {
    require jq
    require curl

    local _vendorapp
    local _version
    _vendorapp="${1?"Usage: $0 app"}"
    _version="${2:-"latest"}"
    _is_ent="${ENT:-false}"
    _arch="${ARCH:-"amd64"}"
    _platform="${PLATFORM:-"linux"}"
    _suffix=""
    if [ "$_is_ent" = "true" ]; then
        _suffix="+ent"
    fi
    _vendor_lookup_name="${_vendorapp}"
    if [ "$_version" = "latest" ]; then
        echo "${_vendor_lookup_name}"
        _version=$(get_hashicorp_version "${_vendor_lookup_name}")
    fi

    echo "https://releases.hashicorp.com/${_vendorapp}/${_version}${_suffix}/${_vendorapp}_${_version}${_suffix}_${_platform}_${_arch}.zip"
}

# Scrapes the Hashicorp release endpoint for valid apps
# Usage: get_hashicorp_apps <app>
function get_hashicorp_apps() {
    # Scrape HTML from release page for binary app names
    require jq
    require curl

    curl -s "https://api.releases.hashicorp.com/v1/products" | jq -r '.[]'
}

function get_github_project_description {
    # Description: Scrape github project for its description
    local vendorapp="${1?"Usage: $0 vendor/app"}"
    curl -s "https://api.github.com/repos/${vendorapp}" | jq -r '.description'
}

function get_github_project_license {
    # Description: Scrape github project for its license
    local vendorapp="${1?"Usage: $0 vendor/app"}"
    curl -s "https://api.github.com/repos/${vendorapp}" | jq -r '.license.spdx_id'
}

function get_github_version_by_tag {
    # Attempt to get the latest version of a release by release tag
    local vendorapp="${1?"Usage: $0 vendor/app"}"
    curl -s "https://api.github.com/repos/${vendorapp}/releases/latest" |
        grep -oP '"tag_name": "\K(.*)(?=")' |
        grep -o '[[:digit:]].[[:digit:]].[[:digit:]]'
}

## VAULT_ENVIRONMENT handling
function vault_cluster_address() {
    if [[ "$VAULT_ADDR" == "" ]]; then
        warn "VAULT_ADDR not set, looking up address based on VAULT_ENVIRONMENT"
        # Uses VAULT_ENVIRONMENT to export the proper VAULT_ADDR
        # If neither are passed then nothing is exported.
        info "VAULT_ENVIRONMENT: ${VAULT_ENVIRONMENT}"
        local TARGET_VAULT_ENV=${VAULT_ENVIRONMENT:-"local"}

        # Our current environment targets
        local local=http://127.0.0.1:8200
        local poc=https://vault-poc.domain.local
        local dev=https://vault-dev.domain.local
        local int=https://vault-int.domain.local
        local prod=https://vault.domain.local
        local target_venv=""

        # Lowercase the target environment
        if [[ -n "$TARGET_VAULT_ENV" ]]; then
            target_venv=$(echo $TARGET_VAULT_ENV | tr '[:upper:]' '[:lower:]')
        fi

        case $target_venv in
        local)
            export VAULT_ADDR=$local
            ;;
        poc)
            export VAULT_ADDR=$poc
            ;;
        dev)
            export VAULT_ADDR=$dev
            ;;
        int | non | nonprod | nprd | nonprd | stage | stg)
            export VAULT_ADDR=$int
            ;;
        prod | production | prd)
            export VAULT_ADDR=$prod
            ;;
        *)
            export VAULT_ADDR=$local
            ;;
        esac
    else
        success "VAULT_ADDR already set!"
    fi
    info "VAULT_ADDR: ${VAULT_ADDR}"
}

## Vault Auth Functions
# These should emit 'VAULT_TOKEN' for further access into vault

## Gitlab authentication
function vault_auth_gitlab() {
    # Attempt to use gitlab JWT based auth to get a VAULT_TOKEN
    local gitlab_auth_mount=${VAULT_GITLAB_AUTH_MOUNT:-"jwt_gitlab"}
    local gitlab_role=${VAULT_GITLAB_ROLE:-$(echo $CI_PROJECT_PATH | tr "/" "_")}
    local exit_status
    local vault_cmd_output
    info "gitlab_role=${gitlab_role}"
    info "gitlab_auth_mount=${gitlab_auth_mount}"

    if [[ -n "$VAULT_ADDR" && -n "$CI_JOB_JWT" && -n "$gitlab_role" ]]; then
        info "Attempting Vault authentication via Gitlab JWT role..."
        vault_cmd_output=$(curl \
            -s --header "Accept: application/json" \
            --request POST \
            --data "{\"jwt\":\"${CI_JOB_JWT_V1}\",\"role\":\"${gitlab_role}\"}" "${VAULT_ADDR}/v1/auth/${gitlab_auth_mount}/login" 2>&1) && exit_status=$? || exit_status=$?
        #local vault_cmd_output=$(vault write -field=token auth/${gitlab_auth_mount}/login role=${gitlab_role} jwt=$CI_JOB_JWT 2>&1) && local exit_status=$? || local exit_status=$?
        if [ "$exit_status" = 0 ]; then
            info "Gitlab vault JWT auth success! Exporting VAULT_TOKEN"
            export VAULT_TOKEN="$(echo ${vault_cmd_output} | jq -r .auth.client_token)"
        else
            error "Gitlab vault JWT auth failure - ${vault_cmd_output}" $exit_status
        fi
    else
        error "Requires the following environment variables: VAULT_ADDR, CI_JOB_JWT_V1, and VAULT_GITLAB_ROLE"
    fi
}

function vault_auth_approle() {
    # Attempt to use gitlab JWT based auth to get a VAULT_TOKEN
    local vault_approle_mount=${VAULT_APPROLE_MOUNT:-"approle"}
    info "vault_approle_mount: ${vault_approle_mount}"
    info "VAULT_APPROLE_ROLE: ${VAULT_APPROLE_ROLE}"

    if [[ -n "$VAULT_ADDR" && -n "$VAULT_APPROLE_ROLE" ]]; then
        info "Attempting Vault authentication via AppRole"

        # If VAULT_APPROLE_ID is not defined then attempt to get it from vault
        if [ -z "$VAULT_APPROLE_ID" ]; then
            info "VAULT_APPROLE_ID missing, attempting to pull from vault"
            local vault_cmd_output=$(vault read "auth/${vault_approle_mount}/role/${VAULT_APPROLE_ROLE}/role-id" -format=json | jq -r '.data.role_id' 2>&1) && local exit_status=$? || local exit_status=$?
            if [ "$exit_status" = 0 ]; then
                info "Attained the VAULT_APPROLE_ID"
                export VAULT_APPROLE_ID="${vault_cmd_output}"
            else
                error "Unable to attain the VAULT_APPROLE_ID - ${vault_cmd_output}" $exit_status
            fi
        fi
        # If VAULT_APPROLE_SECRET is not defined then attempt to get it from vault
        if [ ! -n "$VAULT_APPROLE_SECRET" ]; then
            info "VAULT_APPROLE_SECRET missing, attempting to pull from vault"
            local vault_cmd_output=$(vault write -f "auth/${vault_approle_mount}/role/${VAULT_APPROLE_ROLE}/secret-id" -format=json | jq -r '.data.secret_id' 2>&1) && local exit_status=$? || local exit_status=$?
            if [ "$exit_status" = 0 ]; then
                info "Attained the VAULT_APPROLE_SECRET"
                export VAULT_APPROLE_SECRET="${vault_cmd_output}"
            else
                error "Unable to attain the VAULT_APPROLE_SECRET - ${vault_cmd_output}" $exit_status
            fi
        fi
        if [[ -n "$VAULT_APPROLE_ID" && -n "$VAULT_APPROLE_SECRET" ]]; then
            local vault_cmd_output=$(vault write auth/${vault_approle_mount}/login role_id="${VAULT_APPROLE_ID}" secret_id="${VAULT_APPROLE_SECRET}" -format=json | jq -r '.auth.client_token' 2>&1) && local exit_status=$? || local exit_status=$?
            if [ "$exit_status" = 0 ]; then
                info "Attained the VAULT_TOKEN"
                export VAULT_TOKEN="${vault_cmd_output}"
            else
                error "Unable to attain the VAULT_TOKEN - ${vault_cmd_output}" $exit_status
            fi
        fi
    else
        error "Requires the following environment variables: VAULT_ADDR and VAULT_APPROLE_ROLE"
    fi
}

function vault_auth_aws() {
    # If our variables are in place then attempt to assume an AWS role defined in vault
    local vault_aws_mount=${VAULT_AWS_MOUNT:-"aws"}
    local vault_uri="${VAULT_ADDR/'https:\/\/'/""}"
    info "vault_uri: ${vault_uri}"
    info "VAULT_AWS_ROLE: ${VAULT_AWS_ROLE}"
    info "vault_aws_mount: ${vault_aws_mount}"

    # Login to vault
    if [[ -n "$VAULT_ADDR" && -n "$VAULT_AWS_ROLE" && -n "$vault_aws_mount" ]]; then
        info "Attempting Vault authentication via AWS IAM role..."
        local vault_cmd_output=$(vault login \
            -method=aws \
            -path="${vault_aws_mount}" \
            -field=token \
            header_value="${vault_uri}" \
            role=${VAULT_AWS_ROLE} 2>&1) && local exit_status=$? || local exit_status=$?
        if [ "$exit_status" = 0 ]; then
            info "AWS IAM vault auth success! Exporting VAULT_TOKEN"
            export VAULT_TOKEN="${vault_cmd_output}"
        else
            error "AWS IAM vault auth failure - ${vault_cmd_output}" $exit_status
        fi
    else
        error "Requires the following environment variables: VAULT_ADDR, VAULT_AWS_MOUNT, and VAULT_AWS_ROLE"
    fi
}

function vault_auth_token() {
    # If our variables are in place then attempt to assume an AWS role defined in vault
    if [[ -n "$VAULT_ADDR" && -n "$VAULT_TOKEN" ]]; then
        info "Attempting Vault authentication via token..."
        local exit_status
        local vault_cmd_output
        vault_cmd_output=$(curl -s \
            -H "X-Vault-Token: ${VAULT_TOKEN}" \
            "${VAULT_ADDR}/v1/auth/token/lookup-self" 2>&1) && exit_status=$? || exit_status=$?

        if [ "$exit_status" = 0 ]; then
            # Technically this is just informational as VAULT_TOKEN should already be set prior to calling this function
            info "Vault token auth success!"
        else
            error "Vault token authentication failure - ${vault_cmd_output}" $exit_status
        fi
    else
        error "Requires the following environment variables: VAULT_ADDR and VAULT_TOKEN"
    fi
}

function vault_auth_oidc() {
    require vault

    if [[ -n "$VAULT_ADDR" ]]; then
        info "Attempting Vault authentication via oidc..."
        local exit_status
        local vault_cmd_output
        #    require openssl
        # require open
        # local client_nonce
        # client_nonce=$(openssl rand -base64 12)
        # vault_cmd_output=$(curl -s -X PUT \
        #     -H "X-Vault-Request: true" \
        #     -d '{"client_nonce":"'${client_nonce}'","redirect_uri":"http://localhost:8250/oidc/callback","role":""}' \
        #     "${VAULT_ADDR}/v1/auth/oidc/oidc/auth_url"  2>&1 | jq -r '.data.auth_url') && exit_status=$? || exit_status=$?

        vault_cmd_output=$(vault login -method=oidc -token-only -no-store 2>&1 | tail -n 1) && exit_status=$? || exit_status=$?
        if [[ "$exit_status" = "0" && ("${vault_cmd_ouput}" != "") ]]; then
            success "Vault oidc authenticated, exporting VAULT_TOKEN"
            export VAULT_TOKEN="${vault_cmd_output}"
        else
            error "Vault oidc auth failure - ${vault_cmd_output}" $exit_status
        fi
    else
        error "Requires the following environment variables: VAULT_ADDR"
    fi
}

function seed_vault_aws_sts() {
    require vault

    info "Seeding an AWS STS credential to KV"
    VAULT_KV_PATH=${VAULT_KV_PATH:-"controller/kv"}
    AWS_DEFAULT_REGION=${AWS_DEFAULT_REGION:-"us-east-1"}
    AWS_ACCESS_KEY_ID=${AWS_ACCESS_KEY_ID:-""}
    AWS_SECRET_ACCESS_KEY=${AWS_SECRET_ACCESS_KEY:-""}
    AWS_SESSION_TOKEN=${AWS_SESSION_TOKEN:-""}
    TOKEN_LEASE_ID=${TOKEN_LEASE_ID:-""}
    info "VAULT_ADDR: ${VAULT_ADDR}"
    info "VAULT_KV_PATH: ${VAULT_KV_PATH}"
    info "VAULT_KV_SECRET: ${VAULT_KV_SECRET}"
    info "TOKEN_LEASE_ID: ${TOKEN_LEASE_ID}"
    if [[ -n "$VAULT_TOKEN" ]]; then
        if [[ -n "$VAULT_KV_SECRET" ]]; then
            local vault_cmd_output=$(vault kv \
                put "${VAULT_KV_PATH}/${VAULT_KV_SECRET}" \
                AWS_DEFAULT_REGION="${AWS_DEFAULT_REGION}" \
                AWS_ACCESS_KEY_ID="${AWS_ACCESS_KEY_ID}" \
                AWS_SECRET_ACCESS_KEY="${AWS_SECRET_ACCESS_KEY}" \
                AWS_SESSION_TOKEN="${AWS_SESSION_TOKEN}" \
                TOKEN_LEASE_ID="${TOKEN_LEASE_ID}" 2>&1) && local exit_status=$? || local exit_status=$?
            if [ "$exit_status" = 0 ]; then
                success "Seeding succeeded!"
            else
                error "Unable to seed kv secrets - ${vault_cmd_output}" $exit_status
            fi
        else
            error "Seeding requires the following environment variables: VAULT_KV_SECRET"
        fi
    else
        error "Seeding requires the following environment variables: VAULT_ADDR"
    fi
}

function vault_auth() {
    local vault_auth_method=${VAULT_AUTH_METHOD:-"token"}
    info "vault_auth_method: ${vault_auth_method}"

    # Perform vault authentication first
    case $vault_auth_method in
    token)
        vault_auth_token
        ;;
    approle)
        vault_auth_approle
        ;;
    oidc)
        vault_auth_oidc
        ;;
    gitlab)
        vault_auth_gitlab
        ;;
    aws)
        vault_auth_aws
        ;;
    *)
        vault_auth_token
        ;;
    esac
}

function vault_token_lookup() {
    # A safer to display version of vault token lookup
    require vault
    vault token lookup -format yml | grep -vxE '[[:blank:]]*(id:.*)?' | grep -vxE '[[:blank:]]*(accessor:.*)?'

    ## Non-safe way to do this without vault binary
    # curl -s \
    #     -H "X-Vault-Token: ${VAULT_TOKEN}" \
    #     -H "X-Vault-Request: true" \
    #     ${VAULT_ADDR}/v1/auth/token/lookup-self | jq
}

function vault_kv_copy_recursive() {
    require vault
    local tmpfile
    tmpfile=$(mktemp /tmp/vault-json-data.XXXXXXXXXX) || {
        echo "Failed to create temp file"
        exit 1
    }

    local FOLDER_RE='^.*/$'

    local VAULT_SOURCE_ADDR="${VAULT_SOURCE_ADDR:-${VAULT_ADDR:-""}}"
    local VAULT_TARGET_ADDR="${VAULT_TARGET_ADDR:-${VAULT_ADDR:-""}}"

    # Arguments:
    # $1: source_store
    # $2: target_store
    # $3: path
    function copy_recursive() {
        local source_store="${1}"
        local target_store="${2}"
        local source_base_path="${source_store}${3}"
        local target_base_path="${target_store}${3}"

        local entries=($(vault kv list -format=json "${source_base_path}" | jq -r '.[]'))
        for entry in "${entries[@]}"; do
            local source_full_path="${source_base_path}${entry}"
            info -n "Processing entry ${source_full_path} ... "
            if [[ "${entry}" =~ ${FOLDER_RE} ]]; then
                copy_recursive "${1}" "${2}" "${3}${entry}"
            else
                local target_full_path="${target_base_path}${entry}"
                info "${source_store}${source_full_path} -> ${target_store}${source_full_path}"
                VAULT_ADDR="${VAULT_SOURCE_ADDR}" vault kv get -format=json "${source_full_path}" | jq -r '.data.data' >"${tmpfile}"
                VAULT_ADDR="${VAULT_TARGET_ADDR}" vault kv put "${target_full_path}" @"${tmpfile}"
            fi
        done
    }

    copy_recursive "$@"

    if [[ -f "${tmpfile}" ]]; then
        rm -f "${tmpfile}" || echo "Unable to delete tmpfile (${tmpfile}). Manual clean up necessary."
    fi
}

## Vault KV seeding functions
function seed_vault_kv_secret() {
    require vault

    local kv_secret_value=${VAULT_KV_SECRET_VALUE:-""}
    local kv_secret_name=${VAULT_KV_SECRET_NAME:-"value"}
    local kv_path="${VAULT_KV_PATH}/${VAULT_KV_SECRET}"
    info "kv_path: ${kv_path}"
    info "kv_secret_name: ${kv_secret_name}"
    info "Attempting KV Secret update to path - ${kv_path}"
    if [[ "$kv_secret_value" =~ ^@ ]]; then
        info "Secret is defined as a file, loading"
        local src=$(echo "${kv_secret_value}" | cut -c 2-)
        if file -b --mime-encoding $src | grep -s binary >/dev/null; then
            info "Secret data is binary, encoding"
            local vault_cmd_output=$(cat $src | base64 | vault kv put $kv_path \
                ${kv_secret_name}=- format="base64" 2>&1) &&
                local exit_status=$? || local exit_status=$?
        else
            info "Secret data is plain text, NOT encoding"
            local vault_cmd_output=$(cat $src | vault kv put $kv_path ${kv_secret_name}=- format="text" 2>&1) &&
                local exit_status=$? || local exit_status=$?
        fi
    else
        info "Secret data is NOT a file, seeding as plain text"
        local vault_cmd_output=$(vault kv put $kv_path \
            ${kv_secret_name}="${kv_secret_value}" format="text" 2>&1) &&
            local exit_status=$? || local exit_status=$?
    fi
    if [ "$exit_status" = 0 ]; then
        info "Vault kube secret seeding succeeded!"
    else
        error "Unable to seed kv secret - ${vault_cmd_output}" $exit_status
    fi
}

function seed_vault_kube_provider() {
    require vault

    info "Seeding Kube terraform provider secrets"
    local VAULT_KV_PATH=${VAULT_KV_PATH:-"controller/kv"}
    local KUBE_OWNER=${KUBE_OWNER:-"caas"}
    local KUBE_CLUSTER=${KUBE_CLUSTER:-"kind"}
    local KUBE_TOKEN=${KUBE_TOKEN:-$(cat /var/run/secrets/kubernetes.io/serviceaccount/token 2>/dev/null)}
    local KUBE_CERT=${KUBE_CERT:-$(cat /var/run/secrets/kubernetes.io/serviceaccount/ca.crt 2>/dev/null)}
    local VAULT_KV_SECRET=${VAULT_KV_SECRET:-"${KUBE_OWNER}/${KUBE_CLUSTER}/provider"}
    info "VAULT_ADDR: ${VAULT_ADDR}"
    info "VAULT_KV_PATH: ${VAULT_KV_PATH}"
    info "VAULT_KV_SECRET: ${VAULT_KV_SECRET}"
    info "KUBE_URL: ${KUBE_URL}"
    info "KUBE_CERT: ${KUBE_CERT}"
    info "KUBE_CLUSTER: ${KUBE_CLUSTER}"
    info "KUBE_USERNAME: ${KUBE_USERNAME}"
    info "KUBE_PASSWORD: ${KUBE_PASSWORD}"
    info "KUBE_CLIENT_CERTIFICATE: ${KUBE_CLIENT_CERTIFICATE}"
    info "KUBE_CLIENT_KEY: ${KUBE_CLIENT_KEY}"
    if [[ -n "$VAULT_ADDR" && -n "$VAULT_TOKEN" && -n "$KUBE_TOKEN" && -n "$KUBE_URL" && -n "$KUBE_CERT" ]]; then
        local vault_cmd_output=$(vault kv \
            put "${VAULT_KV_PATH}/${VAULT_KV_SECRET}" \
            url="${KUBE_URL}" \
            username="${KUBE_CLIENT_USERNAME}" \
            password="${KUBE_CLIENT_PASSWORD}" \
            client_certificate="${KUBE_CLIENT_CERTIFICATE}" \
            client_key="${KUBE_CLIENT_KEY}" \
            certificate="${KUBE_CERT}" 2>&1) && local exit_status=$? || local exit_status=$?
        if [ "$exit_status" = 0 ]; then
            info "Vault kube provider seeding succeeded!"
        else
            error "Unable to seed kube kv provider secrets - ${vault_cmd_output}" $exit_status
        fi
    else
        error "Vault kube provider secret seeding requires the following environment variables: VAULT_ADDR, KUBE_TOKEN, KUBE_CERT, and KUBE_URL"
    fi
}

function seed_vault_kube_authmount() {
    require vault

    info "Seeding a kube auth mount secret"
    local VAULT_KV_PATH=${VAULT_KV_PATH:-"controller/kv"}
    local KUBE_OWNER=${KUBE_OWNER:-"caas"}
    local KUBE_CLUSTER=${KUBE_CLUSTER:-"kind"}
    local KUBE_TOKEN=${KUBE_TOKEN:-$(cat /var/run/secrets/kubernetes.io/serviceaccount/token 2>/dev/null)}
    local KUBE_CERT=${KUBE_CERT:-$(cat /var/run/secrets/kubernetes.io/serviceaccount/ca.crt 2>/dev/null)}
    local VAULT_KV_SECRET=${VAULT_KV_SECRET:-"${KUBE_OWNER}/${KUBE_CLUSTER}/vault_auth"}
    info "VAULT_ADDR: ${VAULT_ADDR}"
    info "VAULT_KV_PATH: ${VAULT_KV_PATH}"
    info "VAULT_KV_SECRET: ${VAULT_KV_SECRET}"
    info "KUBE_URL: ${KUBE_URL}"
    info "KUBE_CERT: ${KUBE_CERT}"
    info "KUBE_CLUSTER: ${KUBE_CLUSTER}"
    info "KUBE_OWNER: ${KUBE_OWNER}"
    if [[ -n "$VAULT_TOKEN" ]]; then
        if [[ -n "$VAULT_ADDR" && -n "$KUBE_TOKEN" && -n "$KUBE_URL" && -n "$KUBE_CERT" ]]; then
            local vault_cmd_output=$(vault kv \
                put "${VAULT_KV_PATH}/${VAULT_KV_SECRET}" \
                token="${KUBE_TOKEN}" \
                name="${KUBE_URL}" \
                certificate="${KUBE_CERT}" 2>&1) && local exit_status=$? || local exit_status=$?
            if [ "$exit_status" = 0 ]; then
                info "Vault kube secret seeding succeeded!"
            else
                error "Unable to seed kube kv secrets - ${vault_cmd_output}" $exit_status
            fi
        else
            error "Unable to seed kube kv secrets - ${vault_cmd_output}" $exit_status
        fi
    else
        error "Vault kube auth secret seeding requires the following environment variables: VAULT_ADDR, KUBE_TOKEN, KUBE_CERT, and KUBE_URL"
    fi
}

function vault_assume_aws_sts {
    ## Depreciated alias
    lease_aws_sts_account
}

## Leasing functions for vault secrets engines
function lease_aws_sts_account() {
    # If our variables are in place then attempt to attain temporary AWS credentials via an AWS STS role defined in vault
    local vault_aws_sts_mount
    local vault_cmd_output

    vault_aws_sts_mount=${VAULT_AWS_STS_MOUNT:-"aws_sts"}
    VAULT_AWS_STS_ROLE=${VAULT_AWS_STS_ROLE:-${VAULT_STS_ROLE:-""}}
    if [[ -n "$VAULT_ADDR" && -n "$VAULT_TOKEN" ]]; then
        if [[ -n "$VAULT_AWS_STS_ROLE" && -n "$vault_aws_sts_mount" ]]; then
            info "VAULT_AWS_STS_ROLE: ${VAULT_AWS_STS_ROLE}"
            info "vault_aws_sts_mount: ${vault_aws_sts_mount}"
            info "Attempting Vault AWS STS role token generation..."
            vault_cmd_output=$(curl -s \
                -H "X-Vault-Token: ${VAULT_TOKEN}" \
                -H "Accept: application/json" \
                "${VAULT_ADDR}/v1/${vault_aws_sts_mount}/creds/${VAULT_AWS_STS_ROLE}" 2>&1) && exit_status=$? || exit_status=$?
            # vault_cmd_output=$( vault read \
            #     -format=json \
            #     ${vault_aws_sts_mount}/creds/${VAULT_AWS_STS_ROLE} 2>&1 ) \
            #     && local exit_status=$? || local exit_status=$?
            if [ "$exit_status" = 0 ]; then
                export AWS_DEFAULT_REGION=${AWS_DEFAULT_REGION:-"us-east-1"}
                export AWS_PAGER=${AWS_PAGER:-""}
                export AWS_ACCESS_KEY_ID="$(echo $vault_cmd_output | jq -r '.data.access_key')"
                export AWS_SECRET_ACCESS_KEY="$(echo $vault_cmd_output | jq -r '.data.secret_key')"
                export AWS_SESSION_TOKEN="$(echo $vault_cmd_output | jq -r '.data.security_token')"
                export TOKEN_LEASE_ID="$(echo $vault_cmd_output | jq -r '.lease_id')"
                success "Vault AWS STS credentials exported!"
            else
                error "Vault AWS STS account generation failure - ${vault_cmd_output}" $exit_status
            fi
        else
            error "AWS STS credential sourcing required variables missing: VAULT_AWS_STS_MOUNT, VAULT_AWS_STS_ROLE"
        fi
    else
        error "AWS STS credential sourcing required variables missing: VAULT_ADDR, VAULT_TOKEN"
    fi
}

function lease_ad_svc_account() {
    require vault
    # svc account name as defined in your manifest
    local vault_ad_role=${VAULT_AD_ROLE:-""}
    local vault_ad_domain=${VAULT_AD_DOMAIN:-"nmtest"}
    if [[ -n "$VAULT_ADDR" && -n "$VAULT_TOKEN" && -n "$vault_ad_role" && -n "$vault_ad_domain" ]]; then
        local vault_cmd_output=""
        vault_cmd_output=$(vault read ad/${vault_ad_domain}/creds/${vault_ad_role} -format=json 2>&1) && local exit_status=$? || local exit_status=$?
        if [ "$exit_status" = 0 ]; then
            info "Vault ad svc account leased!"
            AD_USERNAME=$(echo $vault_cmd_output | jq -r '.data.username')
            AD_PASSWORD=$(echo $vault_cmd_output | jq -r '.data.current_password')
            AD_LAST_PASSWORD=$(echo $vault_cmd_output | jq -r '.data.last_password')
            info "AD_USERNAME=${AD_USERNAME}"
            info "AD_LAST_PASSWORD=${AD_LAST_PASSWORD}"
            export AD_USERNAME
            export AD_PASSWORD
            export AD_LAST_PASSWORD
        else
            error "Unable to lease ad service account from vault - ${vault_cmd_output}" $exit_status
        fi
    else
        error "Leasing a vault managed AD service account requires VAULT_ADDR, VAULT_TOKEN, VAULT_AD_ROLE, and VAULT_AD_DOMAIN"
    fi
}

function checkout_ad_library_account() {
    # library name as defined in your manifest
    require vault

    local exit_status=""
    local vault_cmd_output=""
    local available_accounts=""
    local vault_ad_role=${VAULT_AD_ROLE:-""}
    local vault_ad_domain=${VAULT_AD_DOMAIN:-"nmtest"}
    local vault_ad_account_ttl=${VAULT_AD_ACCOUNT_TTL:-"300"}
    info "vault_ad_role: ${vault_ad_role}"
    info "vault_ad_domain: ${vault_ad_domain}"
    info "vault_ad_account_ttl: ${vault_ad_account_ttl}"

    if [[ -n "$VAULT_ADDR" && -n "$VAULT_TOKEN" && -n "$vault_ad_role" && -n "$vault_ad_domain" ]]; then
        vault_cmd_output=$(vault read "ad/${vault_ad_domain}/library/${vault_ad_role}/status" 2>&1) && exit_status=$? || exit_status=$?
        if [ "$exit_status" = 0 ]; then
            info "Vault ad library available accounts:"
            info "${vault_cmd_output}"
            available_accounts=$(echo "${vault_cmd_output}" | grep 'available:true')
            if [ -n "${available_accounts}" ]; then
                vault_cmd_output=""
                vault_cmd_output=$(vault write "ad/${vault_ad_domain}/library/${vault_ad_role}/check-out" \
                    -format=json ttl="${vault_ad_account_ttl}" 2>&1) && exit_status=$? || exit_status=$?
                if [ "$exit_status" = 0 ]; then
                    info "Vault ad svc account leased!"
                    export AD_USERNAME=$(echo "${vault_cmd_output}" | jq -r '.data.service_account_name')
                    info "AD_USERNAME=${AD_USERNAME}"
                    export AD_PASSWORD=$(echo "${vault_cmd_output}" | jq -r '.data.password')
                    export AD_LEASE_ID=$(echo "${vault_cmd_output}" | jq -r '.lease_id')
                else
                    error "Unable to lease ad library service account from vault - ${vault_cmd_output}" $exit_status
                fi
            else
                error "Unable to lease ad service account from vault as none are available to lease!" 1
            fi
        else
            error "Unable to check ad library service account availability - ${vault_cmd_output}" $exit_status
        fi
    else
        error "Leasing a vault managed AD service account requires VAULT_ADDR, VAULT_TOKEN, VAULT_AD_ROLE, and VAULT_AD_DOMAIN" 1
    fi
}

function checkin_ad_library_account() {
    require vault

    local exit_status=""
    local vault_cmd_output=""
    local vault_ad_role=${VAULT_AD_ROLE:-""}
    local vault_ad_domain=${VAULT_AD_DOMAIN:-"nmtest"}
    local ad_username=${AD_USERNAME:-""}
    info "vault_ad_role: ${vault_ad_role}"
    info "vault_ad_domain: ${vault_ad_domain}"
    info "ad_username: ${ad_username}"

    if [[ -n "$VAULT_ADDR" && -n "$VAULT_TOKEN" && -n "$vault_ad_role" && -n "$vault_ad_domain" && -n "$ad_username" ]]; then
        vault_cmd_output=$(vault write \
            "ad/${vault_ad_domain}/library/${vault_ad_role}/check-in" \
            --force \
            service_account_names="${ad_username}" 2>&1) && exit_status=$? || exit_status=$?
        if [ "$exit_status" = 0 ]; then
            success "Vault ad library service account checked in!"
        else
            warn "Unable to checkin ad service account from vault - ${vault_cmd_output}"
        fi
    else
        warn "Checking in a vault managed AD library service account requires VAULT_ADDR, VAULT_TOKEN, VAULT_AD_ROLE, AD_USERNAME, and VAULT_AD_DOMAIN" 1
    fi
}

function vault_sign_ssh_key() {
    require vault
    require ssh-keygen

    local VAULT_SSH_PREFIX=${VAULT_SSH_PREFIX:-"sshsigner_"}
    local VAULT_SSH_USER=${VAULT_SSH_USER:-"centos"}
    local VAULT_SSH_PRIVATE_KEY=${VAULT_SSH_PRIVATE_KEY:-"./.ssh/vault_id_rsa"}
    local VAULT_SSH_KEY=${VAULT_SSH_KEY:-"${VAULT_SSH_PRIVATE_KEY}.pub"}
    local VAULT_SSH_SIGNED=${VAULT_SSH_SIGNED:-"./.ssh/vault_id_rsa_signed"}
    local VAULT_SSH_TTL=${VAULT_SSH_TTL:-"28800"}
    local vault_ssh_role
    vault_ssh_role="${VAULT_SSH_ROLE:-""}"
    local SSH_KEY_PATH=$(basename $VAULT_SSH_KEY)

    info "VAULT_SSH_KEY: ${VAULT_SSH_KEY}"
    info "VAULT_SSH_SIGNED: ${VAULT_SSH_SIGNED}"
    info "VAULT_SSH_TTL: ${VAULT_SSH_TTL}"
    info "VAULT_SSH_PREFIX: ${VAULT_SSH_PREFIX}"
    info "vault_ssh_role: ${vault_ssh_role}"
    info "VAULT_SSH_USER: ${VAULT_SSH_USER}"

    # Ensure that if a key does not exist that we create one...
    if [ ! -f $VAULT_SSH_KEY ]; then
        warn "VAULT_SSH_KEY (${VAULT_SSH_KEY} - does not exist): Creating..."
        mkdir -p $(dirname $VAULT_SSH_KEY)
        chmod 700 $(dirname $VAULT_SSH_KEY)
        ssh-keygen -q -N "" -f ${VAULT_SSH_PRIVATE_KEY}
    fi

    local vault_cmd_output=$(vault write sshsigner_${VAULT_SSH_ROLE}/sign/${vault_ssh_role} public_key=@${VAULT_SSH_KEY} valid_principals=${VAULT_SSH_USER} ttl=${VAULT_SSH_TTL} -format=json 2>&1) && local exit_status=$? || local exit_status=$?

    if [ "$exit_status" = 0 ]; then
        success "Vault signed ssh key: ${VAULT_SSH_KEY}"
        echo $vault_cmd_output | jq -r .data.signed_key >${VAULT_SSH_SIGNED}
    else
        error "Unable to sign ssh key using vault - ${vault_cmd_output}" $exit_status
    fi
}

function seed_vault_kv_privatekey() {
    require vault
    require ssh_keygen

    local vault_cmd_output
    local exit_status

    local kv_ssh_key=${VAULT_KV_SSH_KEY:-"ssh1"}
    local kv_namespace=${VAULT_NAMESPACE:-"controller"}
    local kv_secret=${VAULT_KV_SECRET:-"private/${kv_ssh_key}"}
    local kv_secret_value=${VAULT_KV_SECRET_VALUE:-""}
    local kv_secret_name=${VAULT_KV_SECRET_NAME:-"id_rsa"}
    local kv_path=${VAULT_KV_PATH:-"${kv_namespace}/kv"}
    local kv_full_path="${kv_path}/${kv_secret}"
    info "kv_full_path: ${kv_path}"
    info "kv_secret_name: ${kv_secret_name}"

    if [[ "$kv_secret_value" =~ ^@ ]]; then
        info "kv_secret_value is defined as a file, loading"
        local src=$(echo "${kv_secret_value}" | cut -c 2-)
        vault_cmd_output=$(cat $src | vault kv put ${kv_full_path} ${kv_secret_name}=- format="text" 2>&1) && exit_status=$? || exit_status=$?
    fi

    if [[ "$kv_secret_value" == "" ]]; then
        info "kv_secret_value is empty, creating a new ssh private key."
        vault_cmd_output="$($(mkfifo key && $(
            cat key
            rm key
        ) &) && (echo y | ssh-keygen -N '' -q -f key >/dev/null) | vault kv put ${kv_full_path} ${kv_secret_name}=- format="text" 2>&1) && exit_status=$? || exit_status=$?"
    else
        info "kv_secret_value passed in as a value, seeding directly."
        vault_cmd_output=$(vault kv put ${kv_full_path} \
            ${kv_secret_name}="${kv_secret_value}" format="text" 2>&1) &&
            exit_status=$? || exit_status=$?
    fi

    if [[ "$exit_status" == "0" ]]; then
        info "Vault kube secret seeding succeeded!"
    else
        error "Unable to seed kv secret - ${vault_cmd_output}" $exit_status
    fi
}

function gitlab_ssh_config() {
    require ssh-agent
    require git
    require ssh-keyscan

    eval $(ssh-agent -s)
    info "$CICD_PRIVATE_KEY" | tr -d '\r' | ssh-add -
    mkdir -p ~/.ssh
    chmod 700 ~/.ssh
    git config --global user.email "hvault-cicd@domain.local"
    git config --global user.name "CICD User"
    git config --global url."git@github.com".insteadOf = https://www.github.com/
    ssh-keyscan github.com >>~/.ssh/known_hosts
    chmod 644 ~/.ssh/known_hosts
}

function gitlab_runner_config() {
    require vault

    export VAULT_ENVIRONMENT=${VAULT_ENVIRONMENT:-"poc"}
    export VAULT_ADDR=${VAULT_ADDR:-"http://127.0.0.1:8200"}
    export TF_VAR_vault_environment=${VAULT_ENVIRONMENT}
    if [[ $CI_RUNNER_TAGS == *"admin"* ]]; then
        info "Role is set as admin, setting the aws vault role to admin too"
        local VAULT_AUTH_ROLE=admin
        ## Used later in dynamic pipeline generation to add gitlab runner tags to apply task
        GITLAB_TAG=${GITLAB_TAG:-"vault-admin-${VAULT_ENVIRONMENT}"}
        info "GITLAB_TAG: ${GITLAB_TAG}"
        info "VAULT_AUTH_ROLE: ${VAULT_AUTH_ROLE}"
        local vault_cmd_output=$(vault login -method=aws -path=runners -field=token role=$VAULT_AUTH_ROLE 2>&1) && local exit_status=$? || local exit_status=$?
        if [ "$exit_status" = 0 ]; then
            info "Vault aws auth success! Exporting VAULT_TOKEN..."
            export VAULT_TOKEN=$vault_cmd_output
        else
            warn "Unable to login with vault: $vault_cmd_output"
        fi
    else
        if [ -f /scripts/vault-gitlab-sts.sh ]; then
            source /scripts/vault-gitlab-sts.sh
        fi
    fi

    TERRAFORM_PATH=${TERRAFORM_PATH:-"./deploy/${VAULT_ENVIRONMENT}"}
    TERRAFORM_STATE_BUCKET=${TERRAFORM_STATE_BUCKET:-"nwm-vault-${VAULT_ENVIRONMENT}-terraform-state"}
    TERRAFORM_LOCKING_DB=${TERRAFORM_LOCKING_DB:-"vault-${VAULT_ENVIRONMENT}-terraform-state"}
    TF_PLAN=${TF_PLAN:-"plan.tfplan"}
    TF_PLAN_JSON=${TF_PLAN_JSON:-"plan.json"}
    TF_PLAN_SUMMARY=${TF_PLAN_SUMMARY:-"${TF_ARTIFACT_PREFIX}plan_summary.json"}
    GITLAB_CACHE=${CI_PIPELINE_ID}-${VAULT_ENVIRONMENT}-${TF_ARTIFACT_PREFIX}
    BUILD_IMAGE=${BUILD_IMAGE:-"${CI_REGISTRY_IMAGE}"}
    CODEGEN_SOURCE_PATH=${CODEGEN_SOURCE_PATH:-"./state/${VAULT_ENVIRONMENT}"}
    AWS_ACCOUNTS_SCRIPT=${AWS_ACCOUNTS_SCRIPT:-"./scripts/get_account_ids.py"}
    ACCOUNTS_OUTPUT_FILE=${ACCOUNTS_OUTPUT_FILE:-"./deploy/${VAULT_ENVIRONMENT}/accounts.txt"}
    export TF_DATA_DIR=${TERRAFORM_PATH}/.terraform
    export TF_LOG=${TF_LOG}
    info "--------------Vault--------------"
    info "VAULT_ENVIRONMENT: ${VAULT_ENVIRONMENT}"
    info "VAULT_GITLAB_ROLE: ${VAULT_GITLAB_ROLE}"
    info "VAULT_STS_ROLE (AWS): ${VAULT_STS_ROLE}"
    info "VAULT_AUTH_ROLE: ${VAULT_AUTH_ROLE}"
    info "VAULT_ADDR: ${VAULT_ADDR}"
    info "ROLE: ${ROLE}"
    info "TOKEN_LEASE_ID: ${TOKEN_LEASE_ID}"
    info "AWS_DEFAULT_REGION: ${AWS_DEFAULT_REGION}"
    info "AWS_PAGER: ${AWS_PAGER}"
    info "AWS_ACCESS_KEY_ID: ${AWS_ACCESS_KEY_ID}"
    info "vault token lookup:"
    vault token lookup -format yml | grep -vxE '[[:blank:]]*(id:.*)?' | grep -vxE '[[:blank:]]*(accessor:.*)?'
    info ""
    info "--------------Terraform--------------"
    info "TERRAFORM_PATH: ${TERRAFORM_PATH}"
    info "TERRAFORM_STATE_BUCKET: ${TERRAFORM_STATE_BUCKET}"
    info "TERRAFORM_LOCKING_DB: ${TERRAFORM_LOCKING_DB}"
    info "TF_ARTIFACT_PREFIX: ${TF_ARTIFACT_PREFIX}"
    info "TF_PLAN: ${TF_PLAN}"
    info "TF_PLAN_JSON: ${TF_PLAN_JSON}"
    info "TF_PLAN_SUMMARY: ${TF_PLAN_SUMMARY}"
    info "TF_DATA_DIR: ${TF_DATA_DIR}"
    info "TF_LOG: ${TF_LOG}"
    info "TF_VARFILES: ${TF_VARFILES}"
    info "TF_PARALLELISM: ${TF_PARALLELISM}"
    info "TF_VAR_vault_environment: ${TF_VAR_vault_environment}"
    info "--------------Pipeline Variables--------------"
    info "CI_REGISTRY_IMAGE: ${CI_REGISTRY_IMAGE}"
    info "CI_COMMIT_BRANCH: ${CI_COMMIT_BRANCH}"
    info "CI_PIPELINE_SOURCE: ${CI_PIPELINE_SOURCE}"
    info "CI_COMMIT_REF_NAME: ${CI_COMMIT_REF_NAME}"
    info "CI_DEFAULT_BRANCH: ${CI_DEFAULT_BRANCH}"
    info "BUILD_IMAGE: ${BUILD_IMAGE}"
    info "BUILD_IMAGE_TAG: ${BUILD_IMAGE_TAG}"
    info "UPSTREAM_BRANCH: ${UPSTREAM_BRANCH}"
    info "CODEGEN_SOURCE_PATH: ${CODEGEN_SOURCE_PATH}"
    info "AWS_BASECONFIG: ${AWS_BASECONFIG}"
    info "IAM_ROLE_ARN: ${IAM_ROLE_ARN}"
    info "AWS_ACCOUNTS_SCRIPT: ${AWS_ACCOUNTS_SCRIPT}"
    info "ACCOUNTS_OUTPUT_FILE: ${ACCOUNTS_OUTPUT_FILE}"
    info "OU_ID: ${OU_ID}"
    info "GITLAB_CACHE: ${GITLAB_CACHE}"
    info "GITLAB_TAG: ${GITLAB_TAG}"
    info "---------------------------------------------"
}

function terraform_stage_manifests() {
    # Show what would be copied in a staging task
    local vault_env=${VAULT_ENVIRONMENT:-"local"}
    local source_path=${CODEGEN_SOURCE_PATH:-"./state/${vault_env}"}
    local dest_path=${TERRAFORM_PATH:-"./deploy/${vault_env}"}
    local manifest_types=(${MANIFEST_TYPES})
    local manifest_ext="${MANIFEST_EXT:-"tf"}"
    info "source_path: ${source_path}"
    info "dest_path: ${dest_path}"

    if [ ${#manifest_types[@]} -gt 0 ]; then
        info "Manifest filter count: ${#manifest_types[@]}"
        for manifesttype in "${manifest_types[@]}"; do
            info "filter: ${manifesttype}"
            find "${source_path}" -name "${manifesttype}.${manifest_ext}" -exec cp -rf {} "${dest_path}" \; 2>/dev/null
        done
    fi
}

function terraform_show_manifests() {
    # Show what would be copied in a staging task
    local vault_env=${VAULT_ENVIRONMENT:-"local"}
    local source_path=${CODEGEN_SOURCE_PATH:-"./state/${vault_env}"}
    local manifest_types=(${MANIFEST_TYPES:-""})
    local manifest_ext="${MANIFEST_EXT:-"tf"}"
    info "manifest_types: ${manifest_types}"
    info "source_path: ${source_path}"

    if [ ${#manifest_types[@]} -gt 0 ]; then
        info "Manifest filter count: ${#manifest_types[@]}"
        for manifesttype in "${manifest_types[@]}"; do
            info "filter: ${manifesttype}"
            find "${source_path}" -name "${manifesttype}.${manifest_ext}" -exec echo {} \; 2>/dev/null
        done
    fi
}

function lint-gitlab-pipeline() {
    local result
    local result_status
    local pipeline_file=${PIPELINE_FILE:-".gitlab-ci.yml"}
    #local gitlab_token=${CI_JOB_TOKEN:-"${GITLAB_TOKEN:-""}"}
    local gitlab_url="https://gitlab.com"
    info "pipeline_file: ${pipeline_file}"
    info "gitlab_url: ${gitlab_url}"

    result=$(jq --null-input --arg yaml "$(<${pipeline_file})" '.content=$yaml' |
        curl \
            --silent \
            --header "Content-Type: application/json" \
            --data @- \
            "${gitlab_url}/api/v4/ci/lint") || error "Unable to check pipeline at ${gitlab_url}/api/v4/ci/lint"

    result_status=$(echo "${result}" | jq -r '.status')

    info "result: ${result}"
    info "result_status: ${result_status}"
    if [[ "${result_status}" != "" ]]; then
        case $result_status in
        null) ;;
        valid)
            success "Gitlab CI Linting Succeeded: ${pipeline_file}"
            ;;
        *)
            info "warnings:"
            echo "${result}" | jq -r '.warnings'
            info "errors:"
            echo "${result}" | jq -r '.errors'
            error "Gitlab CI Linting Failed: ${pipeline_file}"
            ;;
        esac
    fi
}

function terraform_pre_apply() {
    local APPLY_ENABLED="true"
    local APPLY_ON_EMPTY=${TF_EMPTY_APPLY_ENABLED:-"false"}
    local APPLY_METHOD=${APPLY_METHOD:-"manual"}
    local generated_pipeline="$(pwd)/tf_apply_pipeline.yml"
    local CICD_BRANCH=${CICD_BRANCH:-"master"}
    local target_vault_env=${VAULT_ENVIRONMENT:-"local"}
    local default_branch=${CI_DEFAULT_BRANCH:-"master"}
    local ci_commit=${CI_COMMIT_REF_NAME:-$(git branch --show-current)}
    local is_prod="false"
    local upstream_branch=${UPSTREAM_BRANCH:-"master"}
    local terraform_path=${TERRAFORM_PATH:-"deploy/${target_vault_env}"}
    local tf_plan_summary=${TF_PLAN_SUMMARY:-"./scripts/tf_plan_summary_default.json"}

    if [[ "${target_vault_env}" == "prod" || "${target_vault_env}" == "int" ]]; then
        debug "This is a prod environment!"
        is_prod="true"
    fi

    # Start out without CM enabled
    local CHG_ENABLED="false"
    if [[ $FORCE_CM && "${FORCE_CM}" != "false" ]]; then
        debug "FORCE_CM set to true, enabling apply and apply on empty as well"
        APPLY_ENABLED="true"
        APPLY_ON_EMPTY="true"
        CHG_ENABLED="true"
    fi

    # Are we in a prod pipeline? If so determine if we are to disable the apply stage
    if [[ "$is_prod" == "true" ]]; then
        debug "We are in a prod level pipeline (VAULT_ENVIRONMENT=${target_vault_env})"
        debug " checking to see if we need to disable the apply stage."
        if [[ ("${ci_commit}" != "${default_branch}") ]]; then
            info "Task was run against a non-master provisioner branch (${ci_commit}), disabling apply in prod environments.."
            APPLY_ENABLED="false"
            CHG_ENABLED="false"
        ## Is this task triggered from an upstream non-master branch? -> Apply disabled
        elif [[ "$upstream_branch" != "master" ]]; then
            debug "Task triggered from an upstream non-master controller branch ($UPSTREAM_BRANCH), disabling apply"
            APPLY_ENABLED="false"
            CHG_ENABLED="false"
        fi
    fi

    debug "APPLY_ENABLED: ${APPLY_ENABLED}"
    debug "APPLY_ON_EMPTY: ${APPLY_ON_EMPTY}"
    debug "CICD_BRANCH: ${CICD_BRANCH}"
    debug "CHG_ENABLED: ${CHG_ENABLED}"
    debug "APPLY_METHOD: ${APPLY_METHOD}"
    debug "generated_pipeline: ${generated_pipeline}"
    debug "FORCE_CM: ${FORCE_CM}"
    debug "tf_plan_summary: ${tf_plan_summary}"

    local plan_summary=$(cat ${tf_plan_summary})
    debug "Current plan_summary: ${plan_summary}"
    debug ""
    local to_create=$(echo "${plan_summary}" | jq -r '.create')
    local to_delete=$(echo "${plan_summary}" | jq -r '.delete')
    local to_update=$(echo "${plan_summary}" | jq -r '.update')
    local total_plan_changes=$(($to_create + $to_delete + $to_update))
    debug "to_create: ${to_create}"
    debug "to_delete: ${to_delete}"
    debug "to_update: ${to_update}"
    debug "total_plan_changes: ${total_plan_changes}"

    if [[ ($total_plan_changes -eq 0) && ("$total_plan_changes" == "false") ]]; then
        local apply_task="
stages:
  - Complete

No Updates:
  stage: Complete
  image: ${BUILD_IMAGE}:${BUILD_IMAGE_TAG}
  script: |
    echo 'No Updates To Process!'
"
        echo "${apply_task}" >${generated_pipeline}

    ## If apply stage is not enabled then drop a 'Complete' task
    elif [[ ("$APPLY_ENABLED" == "false") && ("$APPLY_ON_EMPTY" == "false") ]]; then
        echo "As apply is NOT enabled, just complete the pipeline..."
        apply_task="
    stages:
      - Complete
    
    Apply Disabled:
      stage: Complete
      image: ${BUILD_IMAGE}:${BUILD_IMAGE_TAG}
      script: |
        echo 'There were updates to process but apply is not enabled on this pipeline'
    "
        echo "${apply_task}" >${generated_pipeline}

    ## Otherwise create the Apply stage that use the prior cached terraform init and plan files
    else
        info "There are detected changes, creating dynamic pipeline for apply jobs"

        ### Dynamic pipeline creation of the Apply stages
        if [[ "${target_vault_env}" == "prod" ]]; then
            echo "We are in prod, enabling the change management and gate tasks..."
            CHG_ENABLED=true
        fi
        cat <<EOF >${generated_pipeline}
variables:
    VAULT_ENVIRONMENT: "${target_vault_env}"
    VAULT_GITLAB_ROLE: "${VAULT_GITLAB_ROLE}"
    VAULT_STS_ROLE: "${VAULT_STS_ROLE}"
    VAULT_AUTH_ROLE: "${VAULT_AUTH_ROLE}"
    TF_PARALLELISM: "${TF_PARALLELISM}"
    SOURCE_BRANCH: "${SOURCE_BRANCH}"
    TF_LOG: "${TF_LOG}"
    ROLE: "${ROLE}"
    BUILD_IMAGE: ${BUILD_IMAGE}
    BUILD_IMAGE_TAG: "${BUILD_IMAGE_TAG}"
    TERRAFORM_PATH: ${terraform_path}
    TF_ARTIFACT_PREFIX: ${TF_ARTIFACT_PREFIX:-"${ROLE}-"}
    APPLY_ENABLED: "${APPLY_ENABLED}"
    APPLY_ON_EMPTY: "${APPLY_ON_EMPTY}"
    GITLAB_TAG: "${GITLAB_TAG}"
    GITLAB_CACHE: "${GITLAB_CACHE}"
    CHG_REQUESTED_BY: "${GITLAB_USER_LOGIN}"
    CHG_ASSIGNED_TO: "${GITLAB_USER_LOGIN}"
    CHG_CONFIGURATION_ITEM: "${CHG_CONFIGURATION_ITEM}"
    CHG_DESCRIPTION: "${CHG_DESCRIPTION}"
    CHG_STANDARD_TEMPLATE: "${CHG_STANDARD_TEMPLATE}"
    CHG_CREATE_ON_BRANCH: "${CHG_CREATE_ON_BRANCH}"
    CHG_JOBS_AUTO: "${CHG_JOBS_AUTO}"
    CHG_ENABLED: "${CHG_ENABLED}"

stages:
  - CM Create
  - Apply
  - CM Review

include:
  - project: idam-pxm/tools/hvault-cicd
    file: pipeline/shared/vault-env.yml
    ref: ${CICD_BRANCH}
  - project: idam-pxm/tools/hvault-cicd
    file: pipeline/build/terraform.vault.yml
    ref: ${CICD_BRANCH}
  - project: cicd/servicemanagement
    ref: 1.2.1
    file: templates/change-management-extendable.yml

.vaulttarget:
  extends:
    - .vault:${target_vault_env}

EOF

        # Insert the shared CM tasks
        cat <<'EOF' >>${generated_pipeline}
.change:ticket:create:
    extends: .Create Change Ticket
    rules:
    - if: $CHG_ENABLED == "true" && $APPLY_ENABLED == "true"
      when: manual
    - when: never

.change:ticket:review:
    extends: .Update Change to Review
    rules:
    - if: $CHG_ENABLED == "true" && $APPLY_ENABLED == "true"
      when: manual
    - when: never
EOF

        cat <<EOF >>${generated_pipeline}
CM Create:
  stage: CM Create
  extends:
    - .change:ticket:create

Apply:
  stage: Apply
  image: ${BUILD_IMAGE}:${BUILD_IMAGE_TAG}
EOF
        cat <<'EOF' >>${generated_pipeline}
extends:
  - .vaulttarget
script: |
    if [[ $CI_RUNNER_TAGS == *"admin"* ]]; then
        echo "Role is set as admin, setting the aws vault role to admin too"
        VAULT_AUTH_ROLE=admin
        ## Used later in dynamic pipeline generation to add gitlab runner tags to apply task
        GITLAB_TAG=${GITLAB_TAG:-"vault-admin-${VAULT_ENVIRONMENT}"}
        echo "GITLAB_TAG: ${GITLAB_TAG}"
        
        echo "VAULT_AUTH_ROLE: ${VAULT_AUTH_ROLE}"
        vault_cmd_output=$(vault login -method=aws -path=runners -field=token role=$VAULT_AUTH_ROLE 2>&1 ) && exit_status=$? || exit_status=$?
        if [ "$exit_status" = 0 ]; then
          echo "Vault aws auth success! Exporting VAULT_TOKEN..."
          export VAULT_TOKEN=$vault_cmd_output
        else
          echo "Unable to login with vault: $vault_cmd_output"
        fi
    else 
        if [ -f /scripts/vault-gitlab-sts.sh ]; then 
          source /scripts/vault-gitlab-sts.sh
        fi
    fi
    echo "AWS_DEFAULT_REGION: ${AWS_DEFAULT_REGION}"
    echo "AWS_PAGER: ${AWS_PAGER}"
    echo "AWS_ACCESS_KEY_ID: ${AWS_ACCESS_KEY_ID}"
    echo "CI_REGISTRY_IMAGE: ${CI_REGISTRY_IMAGE}"
    echo "CI_COMMIT_BRANCH: ${CI_COMMIT_BRANCH}"
    echo "BUILD_IMAGE: ${BUILD_IMAGE}"
    echo "BUILD_IMAGE_TAG: ${BUILD_IMAGE_TAG}"

    export TF_LOG=$TF_LOG
    export TF_DATA_DIR=${TERRAFORM_PATH}/.terraform
    cd ${TERRAFORM_PATH}
    if [ -n "$TF_PARALLELISM" ]; then
        terraform apply -auto-approve -parallelism=${TF_PARALLELISM} ${TF_PLAN}
    else
        terraform apply -auto-approve ${TF_PLAN}
    fi
cache:
  key: ${GITLAB_CACHE}
  paths:
    - ${TERRAFORM_PATH}/**
  policy: pull
timeout: 2h
rules:
  - if: '$APPLY_ENABLED == "true"'
EOF
        echo "    when: ${APPLY_METHOD}" >>${generated_pipeline}
        echo '  - if: $APPLY_ON_EMPTY != "false"' >>${generated_pipeline}
        echo "    when: ${APPLY_METHOD}" >>${generated_pipeline}

        # If is change management enabled then ensure that this job depends upon it creating the ticket
        if [[ "$CHG_ENABLED" == "true" ]]; then
            echo 'needs:' >>${generated_pipeline}
            echo '  - CM Create' >>${generated_pipeline}
        fi

        # If this is using standard gitlab token auth instead of vault gitlab role auth then add in a tag for the custom runner
        if [ -n "$GITLAB_TAG" ]; then
            echo '  tags:' >>${generated_pipeline}
            echo "    - ${GITLAB_TAG}" >>${generated_pipeline}
        fi

        cat <<EOF >>${generated_pipeline}
CM Review:
  stage: CM Review
  extends:
    - .change:ticket:review
  needs:
    - Apply
EOF

    fi

    cat ${generated_pipeline}
}

function reset_aws_vault_role() {
    require fzf
    require vault

    vault_role=$(vault list "auth/aws/roles" | sort | fzf)
    vault_role_arn=$(vault read -field=bound_iam_principal_arn -format=json "auth/aws/role/${vault_role}" | jq ".[0]" -r)
    before_bound_iam_principal_id=$(vault read -field=bound_iam_principal_id -format=json "auth/aws/role/${vault_role}" | jq ".[0]" -r)
    echo "vault_role_arn: ${vault_role_arn}"
    echo ""
    echo "before_bound_iam_principal_id: ${before_bound_iam_principal_id}"
    vault write "auth/aws/role/${vault_role}" bound_iam_principal_arn="${vault_role_arn}"
    after_bound_iam_principal_id=$(vault read -field=bound_iam_principal_id -format=json "auth/aws/role/${vault_role}" | jq ".[0]" -r)
    echo "after_bound_iam_principal_id: ${after_bound_iam_principal_id}"
}

# DESC: Validate we have superuser access as root (via sudo if requested)
# ARGS: $1 (optional): Set to any value to not attempt root access via sudo
# OUTS: None
function check_superuser() {
    local superuser
    if [[ $EUID -eq 0 ]]; then
        superuser=true
    elif [[ -z ${1-} ]]; then
        if check_binary sudo; then
            info 'Sudo: Updating cached credentials ...'
            if ! sudo -v; then
                error "Sudo: Couldn't acquire credentials ..." 1
            else
                local test_euid
                test_euid="$(sudo -H -- "$BASH" -c 'printf "%s" "$EUID"')"
                if [[ $test_euid -eq 0 ]]; then
                    superuser=true
                fi
            fi
        fi
    fi

    if [[ -z ${superuser-} ]]; then
        error 'Unable to acquire superuser credentials.' 1
        return 1
    fi

    info 'Successfully acquired superuser credentials.'
    return 0
}

# DESC: Run the requested command as root (via sudo if requested)
# ARGS: $1 (optional): Set to zero to not attempt execution via sudo
#       $@ (required): Passed through for execution as root user
# OUTS: None
function run_as_root() {
    if [[ $# -eq 0 ]]; then
        error 'Missing required argument to run_as_root()!' 2
    fi

    if [[ ${1-} =~ ^0$ ]]; then
        local skip_sudo=true
        shift
    fi

    if [[ $EUID -eq 0 ]]; then
        "$@"
    elif [[ -z ${skip_sudo-} ]]; then
        sudo -H -- "$@"
    else
        error "Unable to run requested command as root: $*" 1
    fi
}

# DESC: Combines two path variables and removes any duplicates
# ARGS: $1 (required): Path(s) to join with the second argument
#       $2 (optional): Path(s) to join with the first argument
# OUTS: $build_path: The constructed path
# NOTE: Heavily inspired by: https://unix.stackexchange.com/a/40973
function build_path() {
    if [[ $# -lt 1 ]]; then
        error 'Missing required argument to build_path()!' 2
    fi

    local new_path path_entry temp_path

    temp_path="$1:"
    if [[ -n ${2-} ]]; then
        temp_path="$temp_path$2:"
    fi

    new_path=
    while [[ -n $temp_path ]]; do
        path_entry="${temp_path%%:*}"
        case "$new_path:" in
        *:"$path_entry":*) ;;
        *)
            new_path="$new_path:$path_entry"
            ;;
        esac
        temp_path="${temp_path#*:}"
    done

    # shellcheck disable=SC2034
    build_path="${new_path#:}"
}

function rawurlencode() {
    local string="${1}"
    local strlen=${#string}
    local encoded=""
    local pos c o

    for (( pos=0 ; pos<strlen ; pos++ )); do
        c=${string:$pos:1}
        case "$c" in
        [-_.~a-zA-Z0-9] ) o="${c}" ;;
        * )               printf -v o '%%%02x' "'$c"
        esac
        encoded+="${o}"
    done
    echo "${encoded}"    # You can either set a return variable (FASTER) 
    REPLY="${encoded}"   #+or echo the result (EASIER)... or both... :p
}

require jq
require curl
