#!/usr/bin/env zsh

# Copyright (c) 2018, Zsolt Lengyel
# inject command to the active tmux session

# usage example: ./tmux-inject.zsh ls

# usage in gsl: 
# in preferences/general/console aplications click on edit and paste this into the window, then save it:
# osascript -e 'do shell script "/path/to/tmux-inject.zsh \"telnet %h %p\" "'

tmux="/usr/local/bin/tmux"

# set the maximum number of tmux panes, after this limit, new window is created:
max_pane_per_window=4


# command is eighter $1 or ls
command_to_send=${1:-"ls"} 

# get and save the current active tmux pane id
active_pane=$($tmux display -p -F ':#{session_id}:#I:#P:#{pane_active}:#{window_active}:#{session_attached}' )
a_active_pane=("${(@s/:/)active_pane}")

active_session=${a_active_pane[2]//$}
active_window=$a_active_pane[3]
active_pane=$a_active_pane[4]

pane_count=$($tmux list-panes | wc -l)

if [ "$pane_count" -ge $max_pane_per_window ]; then
  #
  # inject to next window
  #

  window_count=$($tmux list-windows | wc -l)
  $tmux new-window -t 0: -n $(($window_count + 1)); $tmux send -t 0:$(($window_count + 1)) $command_to_send ENTER
  # echo "<=$max_pane_per_window pane";
  # echo $pane_count;
else
  #
  # inject to next pane
  #

  # list pane sizes with id:
  pane_sizes=$($tmux list-panes -t 0: -F "#{pane_index} #{pane_width} #{pane_height}")

  #find the bigest pane (multiply x and y and sort the result)
  biggest_pane=$(echo $pane_sizes | awk '{ print $1, $2 * $3 }' | sort -nr -k2,2 | head -1 )

  #get biggest pane values and id:
  biggest_pane_id=$(echo $biggest_pane | awk '{ print $1 }')
  biggest_pane_x=$(echo $pane_sizes | awk -v biggest_pane_id="$biggest_pane_id" '{if ($1 == biggest_pane_id) print $2;}')
  biggest_pane_y=$(echo $pane_sizes | awk -v biggest_pane_id="$biggest_pane_id" '{if ($1 == biggest_pane_id) print $3;}')

  # in a terminal one "pixel" the width is 2.125 times smaller then the height. y = 2.125x if you
  # check your cursor size, you can find it out with:  tput setab 7; printf ' \n'; tput sgr0
  # or tput smso; printf ' \n'; tput sgr0
  biggest_pane_x=$(( $biggest_pane_x/2.125 ))

  # if wider, hsplit, if taller, vsplit: 
  if [[ "$biggest_pane_x" -ge "$biggest_pane_y" ]]; then 
    $tmux split-window -h -t $active_session:$active_window.$biggest_pane_id; $tmux send $command_to_send ENTER
  else
    $tmux split-window -v -t $active_session:$active_window.$biggest_pane_id; $tmux send $command_to_send ENTER
  fi
fi

