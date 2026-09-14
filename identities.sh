# shellcheck shell=sh
# The personal GitHub identity for git/credential-helper.sh, which sources every
# file in ~/.config/git/identities.d/ (this one is linked there as personal.sh).
# Three fields, each read once per file:
#   URL_PREFIX  org or user segment of github.com/<prefix>/... repo URLs
#   GH_LOGIN    the gh CLI account whose token those URLs get (`gh auth status`)
#   TREE        filesystem root whose repos default to this account when the
#               URL prefix matches no identity
# The email is not here: git/identity owns it, included by git/config for
# every repo under TREE.
URL_PREFIX="yossidoctor"
GH_LOGIN="yossidoctor"
TREE="$HOME/dotfiles"
