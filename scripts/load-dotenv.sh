# shellcheck shell=sh
# Export KEY=VALUE lines from a dotenv file WITHOUT shell evaluation, so secret
# values containing $ ` & ; spaces or quotes are taken literally.
#
# Usage:  . scripts/load-dotenv.sh && ptl_load_dotenv <file>
#
# Rules: one variable per line (no multi-line values); blank lines and lines
# starting with # are skipped; an "export " prefix is allowed; one pair of
# surrounding '...' or "..." is removed from the value.
#
# docker/Dockerfile.{elysia,nextjs,nuxt4} embed a copy of this function; keep them in sync.
ptl_load_dotenv() {
  _ptl_n=0
  while IFS= read -r _ptl_line || [ -n "$_ptl_line" ]; do
    _ptl_n=$((_ptl_n + 1))
    _ptl_line=${_ptl_line%"$(printf '\r')"}
    _ptl_line=${_ptl_line#"${_ptl_line%%[! 	]*}"}
    case "$_ptl_line" in '' | '#'*) continue ;; esac
    _ptl_line=${_ptl_line#export }
    case "$_ptl_line" in
      *=*) ;;
      *) echo "load-dotenv: line $_ptl_n has no '='" >&2; return 1 ;;
    esac
    _ptl_key=${_ptl_line%%=*}
    _ptl_val=${_ptl_line#*=}
    case "$_ptl_key" in
      '' | [0-9]* | *[!A-Za-z0-9_]*) echo "load-dotenv: line $_ptl_n has an invalid variable name" >&2; return 1 ;;
    esac
    case "$_ptl_val" in
      \"*\") _ptl_val=${_ptl_val#\"}; _ptl_val=${_ptl_val%\"} ;;
      \'*\') _ptl_val=${_ptl_val#\'}; _ptl_val=${_ptl_val%\'} ;;
    esac
    export "$_ptl_key=$_ptl_val"
  done < "$1"
  unset _ptl_n _ptl_line _ptl_key _ptl_val
}
