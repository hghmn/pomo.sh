# pomo.sh

Pomodoro style cli task timer/tracker.

## Usage

Place the script in your PATH, eg: `~/bin/pomo.sh`. Start a pomodoro timer by running `pomo start`. The script will prompt you for a task title and tags. Check timer by running `pomo status` (also try minimal status with `pomo -m status`). Stop a currently running pomo timer with `pomo stop`. Extend a currently running, or resume (duplicate) your last task with `pomo continue`.

This script will attempt to read and write to `~/.local/share/pomo/log`. This can be overwritten by setting the environment variable `POMO_FILE_LOC=/path/to/file`.
