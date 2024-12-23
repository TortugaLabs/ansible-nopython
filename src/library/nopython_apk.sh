#!/bin/sh
# Copyright (c) 2017 Markus Weippert
# GNU General Public License v3.0 (see https://www.gnu.org/licenses/gpl-3.0.txt)

PARAMS="
    name=pkg/str/r
    state/str//present
    update_cache/bool
"

query_package() {
  grep -q "^$1\$" /etc/apk/world
}

install_packages() {
  local pkg
  set -- $name
  for pkg; do
    ! query_package "$pkg" || continue
    [ -n "$_ansible_check_mode" ] || {
      try apk add "$pkg"
      query_package "$pkg" || fail "failed to install $pkg: $_result"
    }
    changed
  done
}

remove_packages() {
  local pkg
  set -- $name
  for pkg; do
    query_package "$pkg" || continue
    [ -n "$_ansible_check_mode" ] || {
      try apk del "$pkg"
      ! query_package "$pkg" || fail "failed to remove $pkg: $_result"
    }
    changed
  done
}

main() {
    set +euf

    case "$state" in
        present|installed|absent|removed) :;;
        *) fail "state must be present or absent";;
    esac

    [ -z "$update_cache" -o -n "$_ansible_check_mode" ] || try apk update

    name=$(echo "$name" | tr  \'',[]' '    ')

    case "$state" in
        present|installed) install_packages;;
        absent|removed) remove_packages;;
    esac
}
