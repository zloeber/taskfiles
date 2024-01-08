## General script to get a fairly full cli environment up on a default windows powershell prompt
# (no WSL)

Set-ExecutionPolicy RemoteSigned -scope CurrentUser
iwr -useb get.scoop.sh | iex
scoop install unzip 7zip git openssh grep curl aws aws-vault clink bind docker gawk gomplate go gnupg jq vault consul terraform tar wget yq python concfg

# back-up current console settings
concfg export console-backup.json

# use solarized color theme
concfg import solarized-dark

# Use fancy powershell prompt
scoop install pshazz

# generate a new key for things like gitlab
ssh-kegen

# Enable git to use windows cred manager
git config --global credential.helper manager

# Need this for the self signed cert in some envs.
git config --global http.sslVerify false

# Allow different versions of apps to be installed
scoop bucket add versions

scoop install nodejs10
set NODE_TLS_REJECT_UNAUTHORIZED=0
npm set strict-ssl false

