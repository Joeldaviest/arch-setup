#!/bin/bash

find_limine_zen_entry() {
  awk '
    function finish_entry() {
      if (!found && entry_path != "" && entry_text ~ /(^|[^[:alnum:]])linux-zen([^[:alnum:]]|$)/ &&
          tolower(entry_path) !~ /fallback/) {
        found = 1
        print entry_path
        exit
      }
    }

    /^[[:space:]]*\/+[^\/]/ {
      finish_entry()

      line = $0
      sub(/^[[:space:]]*/, "", line)
      level = 0
      while (substr(line, level + 1, 1) == "/") level++

      title = substr(line, level + 1)
      sub(/^\+/, "", title)
      sub(/[[:space:]]+$/, "", title)
      titles[level] = title
      for (i = level + 1; i <= max_level; i++) delete titles[i]
      if (level > max_level) max_level = level

      entry_path = titles[1]
      for (i = 2; i <= level; i++) entry_path = entry_path "/" titles[i]
      entry_text = tolower(title)
      next
    }

    {
      if (entry_path != "") entry_text = entry_text "\n" tolower($0)
    }

    END { finish_entry() }
  ' "$1"
}

write_limine_zen_default() {
  local source=$1
  local destination=$2
  local entry=$3
  local has_default=false
  local has_remember=false

  grep -qiE '^[[:space:]]*default_entry[[:space:]]*:' "$source" && has_default=true
  grep -qiE '^[[:space:]]*remember_last_entry[[:space:]]*:' "$source" && has_remember=true

  awk -v entry="$entry" -v has_default="$has_default" -v has_remember="$has_remember" '
    BEGIN {
      if (has_default == "false") print "default_entry: " entry
      if (has_remember == "false") print "remember_last_entry: no"
    }
    /^[[:space:]]*default_entry[[:space:]]*:/ {
      if (!wrote_default++) print "default_entry: " entry
      next
    }
    /^[[:space:]]*remember_last_entry[[:space:]]*:/ {
      if (!wrote_remember++) print "remember_last_entry: no"
      next
    }
    { print }
  ' "$source" >"$destination"
}
