#!/bin/sh
# Copyright (c) 2017 Markus Weippert
# GNU General Public License v3.0 (see https://www.gnu.org/licenses/gpl-3.0.txt)

NO_EXIT_JSON="1"

main() {
    seperator=","
    echo '{"changed":false,"ansible_facts":'


    json_set_namespace facts
    json_init
    json_add_string ansible_hostname "$(cat /proc/sys/kernel/hostname)"

    if [ -f /etc/openwrt_release ] ; then
      json_add_string ansible_distribution "OpenWRT"
      json_add_string ansible_os_family "OpenWRT"
      . /etc/openwrt_release
      dist_version="${DISTRIB_RELEASE:-NA}"
      dist_release="${DISTRIB_CODENAME:-NA}"
      dist_major="${dist_version%%.*}"
      json_add_string ansible_distribution_major_version "$dist_major"
      json_add_string ansible_distribution_release "$dist_release"
      json_add_string ansible_distribution_version "$dist_version"
    elif [ -f /etc/os-release ] ; then
      . /etc/os-release
      json_add_string ansible_distribution "${NAME:-Linux}"
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
	alpine) json_add_string ansible_os_family "Alpine" ;;
	*) json_add_string ansible_os_family "$(uname -o)" ;;
      esac
    else
      json_add_string ansible_os_family "$(uname -o)"
    fi
    json_add_string ansible_kernel "$(uname -rm)"
    json_add_string ansible_system "$(uname -s)"

    json_add_boolean ansible_is_chroot "$([ -r /proc/1/root/. ] &&
        { [ / -ef /proc/1/root/. ]; echo $?; } ||
        { [ "$(ls -di / | awk '{print $1}')" -eq 2 ]; echo $?; }
        )"
    dist_facts="$(json_dump)"
    json_cleanup
    json_set_namespace result
    echo "${dist_facts%\}*}"
    #~ for fact in \
            #~ info!system!info \
            #~ devices!network.device!status \
            #~ services!service!list \
            #~ board!system!board \
            #~ wireless!network.wireless!status \
            #~ ; do
        #~ add_ubus_fact "openwrt_$fact"
    #~ done
    #~ echo "$seperator"'"openwrt_interfaces":{'
    #~ seperator=""
    #~ for net in $($ubus list); do
        #~ [ "${net#network.interface.}" = "$net" ] ||
            #~ add_ubus_fact "${net##*.}!$net!status"
    #~ done
    echo '}}'
}

[ -n "$_ANSIBLE_PARAMS" ] || main
