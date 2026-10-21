#!/usr/bin/env bash
set -euo pipefail

core_site="/opt/hadoop/etc/hadoop/core-site.xml"

case "$(hostname -s)" in
  team-16-en)
    allowed_hosts="127.0.0.1,::1,10.16.0.10"
    ;;
  team-16-nn)
    allowed_hosts="10.16.0.10"
    ;;
  *)
    echo "Run this script on team-16-en or team-16-nn" >&2
    exit 1
    ;;
esac

[[ -f "$core_site" ]] || { echo "File not found: $core_site" >&2; exit 1; }

if grep -Fq 'hadoop.proxyuser.team.hosts' "$core_site" ||
   grep -Fq 'hadoop.proxyuser.team.groups' "$core_site"; then
  if grep -Fq '<name>hadoop.proxyuser.team.hosts</name>' "$core_site" &&
     grep -Fq "<value>$allowed_hosts</value>" "$core_site" &&
     grep -Fq '<name>hadoop.proxyuser.team.groups</name>' "$core_site" &&
     grep -Fq '<value>team</value>' "$core_site"; then
    echo "Proxy-user settings already exist in $core_site"
    exit 0
  fi
  echo "Existing proxy-user settings differ; inspect $core_site" >&2
  exit 1
fi

[[ "$(grep -c '</configuration>' "$core_site")" -eq 1 ]] || {
  echo "Expected one closing configuration tag in $core_site" >&2
  exit 1
}

tmp_file="$(mktemp)"
trap 'rm -f "$tmp_file"' EXIT

awk -v hosts="$allowed_hosts" '
  /<\/configuration>/ {
    print "  <property>"
    print "    <name>hadoop.proxyuser.team.hosts</name>"
    print "    <value>" hosts "</value>"
    print "  </property>"
    print "  <property>"
    print "    <name>hadoop.proxyuser.team.groups</name>"
    print "    <value>team</value>"
    print "  </property>"
  }
  { print }
' "$core_site" >"$tmp_file"

sudo cp "$tmp_file" "$core_site"

if [[ "$(hostname -s)" == "team-16-nn" ]]; then
  /opt/hadoop/bin/hdfs dfsadmin -refreshSuperUserGroupsConfiguration
  /opt/hadoop/bin/yarn rmadmin -refreshSuperUserGroupsConfiguration
fi

echo "Proxy-user settings added to $core_site"
