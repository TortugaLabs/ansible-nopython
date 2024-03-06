#!/bin/sh
# Copyright (c) 2017 Markus Weippert
# Copyright (c) 2024 A Liu Ly
# GNU General Public License v3.0 (see https://www.gnu.org/licenses/gpl-3.0.txt)

NO_EXIT_JSON="1"
PARAMS="
  fact_path/str

"

alpine_service_facts() {
  echo '{"changed":false,"ansible_facts":'
  json_set_namespace facts
  json_init

  local rc_update=$(rc-update) sv
  json_add_object services
  for sv in $(find /etc/init.d -mindepth 1 -maxdepth 1)
  do
    sv=$(basename "$sv")
    [ $sv = functions.sh ] && continue
    json_add_object "$sv"
      json_add_string name "$sv"
      json_add_string source "openrc"
      json_add_string state "$(rc-service "$sv" status | awk '{ print $NF }')"
      local rls n
      rls=$(echo "$rc_update"|awk -vSRV="$sv" '$1 == SRV {$1="";$2="";print}')
      if [ -z "$rls" ] ; then
        n=null
      else
        local i c=''
        n='['
        for i in $rls
        do
          n="$n$c\"$i\""
          c=","
        done
        n="$n]"
      fi
      json_add_int runlevels "$n"
    json_close_object # $sv
  done  
  json_close_object # services
    
  dist_facts="$(json_dump)"
  json_cleanup
  json_set_namespace result
  echo "${dist_facts%\}*}"
  echo '}}'
}

main() {
  if [ -f "/etc/alpine-release" ] ; then
    #
    # Alpine Linux implementation
    #
    alpine_service_facts
  else
    echo 'Unimplmented, use the python module instead' 1>&2
    exit 1
  fi
}

[ -n "$_ANSIBLE_PARAMS" ] || main
