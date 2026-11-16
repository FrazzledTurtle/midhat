midhat_log_to_stdout() {
  [[ ${MIDHAT_LOG_TO_STDOUT:-} == "1" || -z ${MIDHAT_INSTALL_LOG_FILE:-} ]]
}

midhat_log_line() {
  if midhat_log_to_stdout; then
    echo "$1"
  else
    echo "$1" >>"$MIDHAT_INSTALL_LOG_FILE"
  fi
}

start_install_log() {
  if ! midhat_log_to_stdout; then
    mkdir -p "$(dirname "$MIDHAT_INSTALL_LOG_FILE")"
    touch "$MIDHAT_INSTALL_LOG_FILE"
    chmod 666 "$MIDHAT_INSTALL_LOG_FILE" 2>/dev/null || true
  fi

  export MIDHAT_START_TIME="${MIDHAT_START_TIME:-$(date '+%Y-%m-%d %H:%M:%S')}"
  export MIDHAT_START_EPOCH="${MIDHAT_START_EPOCH:-$(date +%s)}"

  midhat_log_line "=== Mid’hat Setup Started: $MIDHAT_START_TIME ==="
}

stop_install_log() {
  local end_time end_epoch duration mins secs
  end_time=$(date '+%Y-%m-%d %H:%M:%S')
  end_epoch=$(date +%s)

  midhat_log_line "=== Mid’hat Setup Completed: $end_time ==="

  if [[ -n ${MIDHAT_START_EPOCH:-} ]]; then
    duration=$((end_epoch - MIDHAT_START_EPOCH))
    mins=$((duration / 60))
    secs=$((duration % 60))
    midhat_log_line "Mid’hat setup: ${mins}m ${secs}s"
  fi
}

run_logged() {
  local script="$1"
  local exit_code errexit_was_set=0

  midhat_log_line "[$(date '+%Y-%m-%d %H:%M:%S')] Starting: $script"

  case $- in
    *e*)
      errexit_was_set=1
      set +e
      ;;
  esac

  local runner=(bash -eE)
  if [[ ${MIDHAT_INSTALL_DEBUG:-} == "1" ]]; then
    runner=(bash -x -eE)
  fi

  if midhat_log_to_stdout; then
    PS4='+ ${BASH_SOURCE[0]##*/}:${LINENO}:${FUNCNAME[0]:-main}: ' \
      "${runner[@]}" -c 'source "$1"' bash "$script" </dev/null 2>&1
  else
    PS4='+ ${BASH_SOURCE[0]##*/}:${LINENO}:${FUNCNAME[0]:-main}: ' \
      "${runner[@]}" -c 'source "$1"' bash "$script" </dev/null >>"$MIDHAT_INSTALL_LOG_FILE" 2>&1
  fi

  exit_code=$?
  (( errexit_was_set )) && set -e

  if (( exit_code == 0 )); then
    midhat_log_line "[$(date '+%Y-%m-%d %H:%M:%S')] Completed: $script"
  else
    midhat_log_line "[$(date '+%Y-%m-%d %H:%M:%S')] Failed: $script (exit code: $exit_code)"
  fi

  return $exit_code
}
