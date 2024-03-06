#!/bin/sh
# Copyright (c) 2017 Markus Weippert
# GNU General Public License v3.0 (see https://www.gnu.org/licenses/gpl-3.0.txt)

PARAMS="
    args/str
    enabled/bool
    name/str/r
    pattern/str
    runlevel/str//default
    sleep/int
    state/str
"
RESPONSE_VARS="name enabled state"

is_running() {
    [ -z "${pattern:-}" ] || { pgrep -f "$pattern" >/dev/null 2>&1; return $?; }
    "$init_script" running >/dev/null 2>&1
}

is_enabled() {
    ! "$init_script" enabled >/dev/null 2>&1 || echo 1
}

set_enabled() {
    local status result
    status="$(is_enabled)"
    [ "${enabled:-}" = "$status" ] || {
        changed
        [ -n "${_ansible_check_mode:-}" ] || {
            [ -n "${enabled:-}" ] && action="enable" || action="disable"
            result="$("$init_script" "$action" 2>&1)"
            status="$(is_enabled)"
            [ "${enabled:-}" = "$status" ] ||
                fail "Unable to $action service $name: $result"
        }
    }
    case "$status" in
        1) enabled="yes";;
        *) enabled="no";;
    esac
}

set_state() {
    local action result running
    is_running && running="y" || running=""
    case "$state" in
        started) [ -n "$running" ] || action="start";;
        stopped) [ -z "$running" ] || action="stop";;
        restarted|reloaded) action="${state%ed}";;
        *) fail "Unknown action $action";;
    esac
    [ -z "$action" ] || {
        changed
        [ -n "$_ansible_check_mode" ] ||
            result="$("$init_script" "$action" 2>&1)" ||
            fail "Unable to $action service $name: $result"
    }
}

#
# Apline Linux implementations
#
apk_set_state() {
  local action='' result running

  rc-service "$name" status && running=y || running=''
  case "$state" in
    started) [ -n "$running" ] || action="start";;
    stopped) [ -z "$running" ] || action="stop";;
    restarted)
      if [ -n "$sleep" ] ; then
	changed
	[ -n "$_ansible_check_mode" ] && return
	result="$(rc-service "$name" "stop" 2>&1)" ||
	  fail "Unable to stop service $name: $result"
	sleep "$sleep"
	result="$result$N$(rc-service "$name" "start" 2>&1)" ||
	  fail "Unable to start service $name: $result"
	return
      fi
      action="restart"
      ;;
    reloaded) fail "Unsupported state $state";;
    *) fail "Unknown action $action";;
  esac
  [ -z "$action" ] && return
  changed
  [ -n "$_ansible_check_mode" ] && return

  result="$(rc-service "$name" "$action" 2>&1)" ||
	fail "Unable to $action service $name: $result"
}




apk_is_enabled() {
  rc-update | awk '$1 == "'"$name"'" { $1 = ""; $2 = "" ; print }' | xargs echo
}

apk_set_enabled() {
  if (echo "$args" | grep -wq flex) ; then
    # If args=flex is specified, services can be enabled/disabled on
    # multiple runlevels
    apk_set_enabled_flex
  else
    apk_set_enabled_basic
  fi
}

apk_set_enabled_flex() {
  local status result

  status="$(apk_is_enabled)"
  if [ -n "${enabled:-}" ] ; then
    # enable requested
    if (echo "$status" | grep -qw "$runlevel") ; then
      # OK, already enabled in the given runlevel
      enabled=yes
      return
    fi
    # Must enable it for the selected run level
    changed
    [ -n "${_ansible_check_mode:-}" ] && return
    result=$(rc-update add "$name" "$runlevel" 2>&1 || :)
    status="$(apk_is_enabled)"
    if (echo "$status" | grep -qw "$runlevel") ; then
      enabled=yes
    else
      enabled=no
      fail "Unable to enable service $name on $runlevel: $result"
    fi
  else
    # disable requested
    if (echo "$status" | grep -qw "$runlevel") ; then
      # Currently enabled...
      changed
      [ -n "${_ansible_check_mode:-}" ] && return
      result=$(rc-update del "$name" "$runlevel" 2>&1 || :)
      status="$(apk_is_enabled)"
      if (echo "$status" | grep -qw "$runlevel") ; then
	enabled=yes
	fail "Unable to disable service $name on $runlevel: $result"
      else
	enabled=no
      fi
      return
    fi
    # Already disabled
    enabled=no
  fi
}

apk_set_enabled_basic() {
  local status result= i

  status="$(apk_is_enabled)"
  if [ -n "${enabled:-}" ] ; then
    # enable requested
    if [ x"$status" = x"$runlevel" ] ; then
      # OK, already enabled in the given runlevel
      enabled=yes
      return
    fi
    # Must enable it for the selected run level
    changed
    [ -n "${_ansible_check_mode:-}" ] && return
    if [ -n "$status" ] ; then
      # Currently enabled in different runlevel(s)
      for i in $status
      do
	[ x"$i" = x"$runlevel" ] && continue
        result="$result$N$(rc-update del "$name" "$i" 2>&1 || :)"
      done
    fi
    result="$result$N$(rc-update add "$name" "$runlevel" 2>&1 || :)"
    status="$(apk_is_enabled)"
    if [ x"$status" = x"$runlevel" ] ; then
      enabled=yes
    else
      enabled=no
      fail "Unable to enable service $name on $runlevel: $result"
    fi
  else
    # disable requested
    if [ -z "$status" ] ; then
      enabled=no
      return
    fi

    # Currently enabled...
    changed
    [ -n "${_ansible_check_mode:-}" ] && return
    for i in $status
    do
      result="$result$N$(rc-update del "$name" "$i" 2>&1 || :)"
    done
    status="$(apk_is_enabled)"
    if [ -z "$status" ] ; then
      enabled=no
    else
      enabled=yes
      fail "Unable to disable service $name on $runlevel: $result"
    fi
  fi
}


main() {
  if [ -f "/etc/openwrt_release" ] ; then
    #
    # OpenWRT implementation
    #
    init_script="/etc/init.d/$name"
    [ -f "$init_script" ] || fail "service $name does not exist"
    [ -z "${_orig_enabled:-}" ] || set_enabled
    [ -z "${state:-}" ] || set_state
  elif [ -f "/etc/alpine-release" ] ; then
    #
    # Alpine Linux implementation
    #
    [ ! -f "/etc/init.d/$name" ] && fail "service $name does not exist"
    # test if enabled was specified, if so, call apk_set_enabled
    [ -z "${_orig_enabled:-}" ] || apk_set_enabled
    [ -z "${state:-}" ] || apk_set_state
  fi
}
