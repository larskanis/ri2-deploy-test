#!/bin/bash

# Enable colors
normal=$(tput sgr0)
red=$(tput setaf 1)
green=$(tput setaf 2)
cyan=$(tput setaf 6)

# Deployment is enabled
deploy_enabled() {
    [[ -n "${GPGPASSWD}" ]] && [[ -n "${APPVEYOR_REPO_TAG_NAME}" ]]
}

# Basic status function
_status() {
    local type="${1}"
    local status="${package:+${package}: }${2}"
    local items=("${@:3}")
    case "${type}" in
        failure) local -n nameref_color='red';   title='[RI2 CI] FAILURE:' ;;
        success) local -n nameref_color='green'; title='[RI2 CI] SUCCESS:' ;;
        message) local -n nameref_color='cyan';  title='[RI2 CI]'
    esac
    printf "\n${nameref_color}${title}${normal} ${status}\n\n"
    printf "${items:+\t%s\n}" "${items:+${items[@]}}"
}

# Status functions
failure() { local status="${1}"; local items=("${@:2}"); _status failure "${status}." "${items[@]}"; exit 1; }
success() { local status="${1}"; local items=("${@:2}"); _status success "${status}." "${items[@]}"; exit 0; }
message() { local status="${1}"; local items=("${@:2}"); _status message "${status}"  "${items[@]}"; }

# Run command with status
execute(){
    local status="${1}"
    local command="${2}"
    local arguments=("${@:3}")
    cd "${package:-.}"
    message "${status}"
    if [[ "${command}" != *:* ]]
        then ${command} ${arguments[@]}
        else ${command%%:*} | ${command#*:} ${arguments[@]}
    fi || failure "${status} failed"
    cd - > /dev/null
}

# go to project dir
cd "$(dirname "$0")"

ruby --version
gem install rest-client uri_template --no-document

# Decrypt and import private sigature key
deploy_enabled && (gpg --passphrase $GPGPASSWD --decrypt appveyor-key.asc.asc | gpg --import)

# Deploy
deploy_enabled || success 'All packages built successfully'
execute 'SHA-256 checksums' sha256sum *
execute 'Sign artefacts' gpg --detach-sign --armor appveyor.yml
execute 'Upload artefacts' ruby deploy.rb create_release appveyor.yml*
success 'All artifacts uloaded successfully'
