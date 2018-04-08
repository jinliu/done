# MIT License

# Copyright (c) 2016 Francisco Lourenço & Daniel Wehner

# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:

# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.

# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.

set -g __done_version 1.6.0

function __done_get_window_id
	if type -q lsappinfo
		lsappinfo info -only bundleID (lsappinfo front) | cut -d '"' -f4
	else if type -q xprop
	and test $DISPLAY
		xprop -root 32x '\t$0' _NET_ACTIVE_WINDOW | cut -f 2
	end
end

function __done_tmux_active
	if type -q tmux
		set mypid %self
		if tmux list-panes -a -F "#{window_active} #{pane_pid}" | grep "^0 $mypid" > /dev/null
			return 0
		end
		return 1
	end
	return 1
end

function __is_focused
	if test $__done_initial_window_id != (__done_get_window_id)
		return 0
	end
	__done_tmux_active
	return $status
end


# verify that the system has graphical capabilites before initializing
if test -z "$SSH_CLIENT"  # not over ssh
and test -n __done_get_window_id  # is able to get window id

	set -g __done_initial_window_id ''
	set -q __done_min_cmd_duration; or set -g __done_min_cmd_duration 5000
	set -q __done_exclude; or set -g __done_exclude 'git (?!push|pull)'

	function __done_started --on-event fish_preexec
		set __done_initial_window_id (__done_get_window_id)
	end

	function __done_ended --on-event fish_prompt
		set -l exit_status $status

		if test $CMD_DURATION
		and test $CMD_DURATION -gt $__done_min_cmd_duration # longer than notify_duration
		and __is_focused  # terminal or window not in foreground
		and not string match -qr $__done_exclude $history[1] # don't notify on git commands which might wait external editor

			# Store duration of last command
			set duration (echo "$CMD_DURATION" | humanize_duration)

			set -l title "Done in $duration"
			set -l wd (pwd | sed "s,^$HOME,~,")
			set -l message "$wd/ $history[1]"

			if test $exit_status -ne 0
				set title "Failed ($exit_status) after $duration"
			end

			if set -q __done_notification_command
				eval $__done_notification_command
			else if type -q terminal-notifier  # https://github.com/julienXX/terminal-notifier
				terminal-notifier -message "$message" -title "$title" -sender "$__done_initial_window_id"

			else if type -q osascript  # AppleScript
				osascript -e "display notification \"$message\" with title \"$title\""

			else if type -q notify-send # Linux notify-send
				set -l urgency
				if test $exit_status -ne 0
					set urgency "--urgency=critical"
				end
				notify-send $urgency --icon=terminal --app-name=fish "$title" "$message"

			else  # anything else
				echo -e "\a" # bell sound
			end

		end
	end

end

