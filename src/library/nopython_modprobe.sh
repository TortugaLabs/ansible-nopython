#!/bin/sh
# Copyright (c) 2024 A Liu Ly
# GNU General Public License v3.0 (see https://www.gnu.org/licenses/gpl-3.0.txt)

PARAMS="
    name/str/r
    params/str
    persistent/str//disabled
    state/str//present
"
RESPONSE_VARS="name params state msg"

is_mod_loaded() {
  f=$(awk -vmodname="$1" '$1 == modname { print }' /proc/modules)
  # TODO: check also in /lib/modules/{RELEASE_VER}/modules.builtin
  [ -n "$f" ]
}

mod_options_file() {
  local p
  for p in ${params:-}
  do
    echo options $name $p
  done
}


init() {
  msg=""
  diff_mprev=""
  diff_mnext=""
}


main() {
  if [ x"$state" = x"present" ] ; then
    if ! is_mod_loaded "$name" ; then
      diff_mnext="$diff_mnext${N}modprobe $name $params"
      if [ ! -n "$_ansible_check_mode" ] ; then
	msg=$(modprobe "$name" $params) || fail "Error modprobe: $msg"
      fi
      changed
    fi
  elif [ x"$state" = x"absent" ] ; then
    if is_mod_loaded "$name" ; then
      diff_mprev="$diff_mprev${N}modprobe --remove $name"
      if [ ! -n "$_ansible_check_mode" ] ; then
	msg=$(modprobe -r "$name") || fail "Error modprobe remove: $msg"
      fi
      changed
    fi
  else
    fail "Unknown desired state: $state"
  fi

  # NOTE: This is fairly Alpine Linux specific...
  if [ x"$persistent" = x"present" ] ; then
    if [ ! -f "/etc/modules-load.d/mab-$name.conf" ] ; then
      diff_mnext="$diff_mnext${N}Create /etc/modules-load.d/mab-$name.conf"
      if [ ! -n "$_ansible_check_mode" ] ; then
	( echo "$name" | dd of=/etc/modules-load.d/mab-$name.conf ) \
	    || fail "Error creating /modules-load.d/mab-$name.conf"
      fi
      changed
    fi
    # Check if params has change
    options="$(mod_options_file)"
    opt_file=/etc/modprobe.d/mab-$name.conf
    if [ -z "$options" ] && [ -f "$opt_file" ] ; then
      diff_mprev="$diff_mprev${N}rm  $opt_file"
      if [ ! -n "$_ansible_check_mode" ] ; then
        rm -f "$opt_file" || fail "Error removing $opt_file"
      fi
      changed
    elif [ -n "$options"  ] && [ ! -f "$opt_file" ] ; then
      diff_mnext="$diff_mnext${N}Create $opt_file"
      if [ ! -n "$_ansible_check_mode" ] ; then
        echo "$options" | dd of="$opt_file" || fail "Error creating $opt_file"
      fi
      changed
    elif [ x"$options" != x"$(cat $opt_file)" ] ; then
      diff_mnext="$diff_mnext${N}Updating $opt_file${N}$options${N}"
      diff_mprev="$diff_mprev${N}Updating $opt_file${N}$(cat $opt_file)${N}"
      if [ ! -n "$_ansible_check_mode" ] ; then
        echo "$options" | dd of="$opt_file" || fail "Error modifying $opt_file"
      fi
      changed
    fi
  elif [ x"$persistent" = x"absent" ] ; then
    if [ -f "/etc/modules-load.d/mab-$name.conf" ] ; then
      diff_mprev="$diff_mprev${N}Remove /etc/modules-load.d/mab-$name.conf"
      if [ ! -n "$_ansible_check_mode" ] ; then
	rm -f /etc/modules-load.d/mab-$name.conf  \
	    || fail "Error removing /modules-load.d/mab-$name.conf"
      fi
      changed
    fi
    opt_file=/etc/modprobe.d/mab-$name.conf
    if [ -f "$opt_file" ] ; then
      diff_mprev="$diff_mprev${N}Remove $opt_file"
      if [ ! -n "$_ansible_check_mode" ] ; then
        rm -f "$opt_file" || fail "Error removing $opt_file"
      fi
      changed
    fi
  elif [ x"$persistent" = x"disabled" ] ; then
    msg="Not updating persistent state"
  else
    fail "Unknown desired persistency: $persistent"
  fi

  set_diff "$diff_mprev" "$diff_mnext" "" ""
}
