#!/bin/sh
# Copyright (c) 2017 Markus Weippert
# Copyright (c) 2024 A Liu Ly
# GNU General Public License v3.0 (see https://www.gnu.org/licenses/gpl-3.0.txt)

NO_EXIT_JSON="1"
PARAMS="
  fact_path/str

"

add_ubus_fact() {
    set -- ${1//!/ }
    ubus list "$2" > /dev/null 2>&1 || return
    local json="$($ubus call "$2" "$3" 2>/dev/null)"
    echo -n "$seperator\"$1\":$json"
    seperator=","
}

openwrt_main() {
    ubus="/bin/ubus"
    seperator=","
    echo '{"changed":false,"ansible_facts":'
    dist="OpenWRT"
    dist_version="NA"
    dist_release="NA"

    . /etc/openwrt_release

    dist="${DISTRIB_ID:-$dist}"
    dist_version="${DISTRIB_RELEASE:-$dist_version}"
    dist_release="${DISTRIB_CODENAME:-$dist_release}"

    dist_major="${dist_version%%.*}"
    json_set_namespace facts
    json_init
    json_add_string ansible_hostname "$(cat /proc/sys/kernel/hostname)"
    json_add_string ansible_distribution "$dist"
    json_add_string ansible_distribution_major_version "$dist_major"
    json_add_string ansible_distribution_release "$dist_release"
    json_add_string ansible_distribution_version "$dist_version"
    json_add_string ansible_os_family OpenWRT
    json_add_boolean ansible_is_chroot "$([ -r /proc/1/root/. ] &&
        { [ / -ef /proc/1/root/. ]; echo $?; } ||
        { [ "$(ls -di / | awk '{print $1}')" -eq 2 ]; echo $?; }
        )"
    json_add_string nopython_setup OpenWRT
    dist_facts="$(json_dump)"
    json_cleanup
    json_set_namespace result
    echo "${dist_facts%\}*}"
    for fact in \
            info!system!info \
            devices!network.device!status \
            services!service!list \
            board!system!board \
            wireless!network.wireless!status \
            ; do
        add_ubus_fact "openwrt_$fact"
    done
    echo "$seperator"'"openwrt_interfaces":{'
    seperator=""
    for net in $($ubus list); do
        [ "${net#network.interface.}" = "$net" ] ||
            add_ubus_fact "${net##*.}!$net!status"
    done
    echo '}}}'
}

generic_facts() {
  json_add_string ansible_hostname "$(cut -d. -f1 /proc/sys/kernel/hostname)"
  json_add_string ansible_domain "$(cut -d. -f2- /proc/sys/kernel/hostname)"
  json_add_string ansible_fqdn "$(cat /proc/sys/kernel/hostname)"

  if [ -f /etc/os-release ] ; then
    . /etc/os-release
    json_add_string ansible_distribution "$(echo ${NAME:-Linux}|cut -d' ' -f1)"
    if [ -n ${VERSION_ID:-} ] ; then
      dist_major="${VERSION_ID%%.*}"
      json_add_string ansible_distribution_major_version "$dist_major"
      json_add_string ansible_distribution_version "${VERSION_ID}"
    fi
    if [ -n "${VERSION:-}" ] ; then
      json_add_string ansible_distribution_release "$VERSION"
    elif [ -n ${VERSION_ID:-} ] ; then
      json_add_string ansible_distribution_release "${VERSION_ID%.*}"
    fi
    case "${ID:-}" in
      alpine)
	json_add_string ansible_os_family "Alpine"
	json_add_string ansible_pkg_mgr "apk"
	;;
      *) json_add_string ansible_os_family "$(uname -o)" ;;
    esac
  else
    json_add_string ansible_os_family "$(uname -o)"
  fi

  json_add_string nopython_setup "Linux-generic"
  json_add_string ansible_kernel "$(uname -r)"
  json_add_string ansible_kernel_version "$(uname -v)"
  json_add_string ansible_machine "$(uname -m)"
  json_add_string ansible_system "$(uname -s)"

  json_add_boolean ansible_is_chroot "$([ -r /proc/1/root/. ] &&
      { [ / -ef /proc/1/root/. ]; echo $?; } ||
      { [ "$(ls -di / | awk '{print $1}')" -eq 2 ]; echo $?; }
      )"

  json_add_int ansible_uptime_seconds "$(cut -d. -f1 /proc/uptime)"
}

generic_ansible_date_time() {
  json_add_object ansible_date_time
    json_add_string date "$(date +'%Y-%m-%d')"
    json_add_string time "$(date +'%H:%M:%S')"
    json_add_string day "$(date +'%d')"
    json_add_string month "$(date +'%m')"
    json_add_string year "$(date +'%Y')"
    json_add_string hour "$(date +'%H')"
    json_add_string minute "$(date +'%M')"
    json_add_string second "$(date +'%S')"
    json_add_string epoch "$(date +'%s')"
    json_add_string epoch_int "$(date +'%s' | cut -d. -f 1)"
    json_add_string iso8601 "$(date -Is)"
  json_close_object # ansible_date_time

}

generic_main() {
  echo '{"changed":false,"ansible_facts":'
  json_set_namespace facts
  json_init

  generic_facts
  generic_ansible_date_time

  dist_facts="$(json_dump)"
  json_cleanup
  json_set_namespace result
  echo "${dist_facts%\}*}"
  echo '}}'
}

main() {
  if [ -f /etc/openwrt_release ] ; then
    openwrt_main
  else
    generic_main
  fi
}

[ -n "$_ANSIBLE_PARAMS" ] || main
