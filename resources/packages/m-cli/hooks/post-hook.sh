#!/bin/bash

function completion_logic() {
	COMP_CWORD="$NODECLIAC_COMP_INDEX"
	prev="$NODECLIAC_PREV"
	cmd="$NODECLIAC_ARG_1"
	sub="$NODECLIAC_ARG_2"
	case "$cmd" in
		dir)
			case "$prev" in
				delete) echo -e "empty\ndsfiles"; return ;;
				dsfiles) echo -e "on\noff"; return ;;
			esac
			;;
		disk)
			case "$sub" in
				# _m_disk
				verify|repair) [[ $COMP_CWORD == 3 ]] && echo -e "disk\nvolume"; return ;;
				format)
					case $COMP_CWORD in
						3) echo -e "ExFAT\nJHFS+\nMS-DOS\nvolume" ;;
						4) [[ "$NODECLIAC_ARG_3" == "volume" ]] && echo -e "ExFAT\nJHFS+\nMS-DOS" ;;
					esac
					return
				;;
				rename) [[ $COMP_CWORD == 3 ]] && \
				echo -e "$(grep -oE '(disk[0-9s]+)' <<< "$(diskutil list)")"; return ;;
				# echo -e "$(perl -lne 'print $1 if /(disk[0-9s]+)/' <<< "$(diskutil list)")"; return ;;

				# _m_dock
				autohide) [[ $COMP_CWORD == 3 ]] && echo -e "YES\nNO"; return ;;
				magnification) [[ $COMP_CWORD == 3 ]] && echo -e "YES\nNO"; return ;;
				position) [[ $COMP_CWORD == 3 ]] && echo -e "BOTTOM\nLEFT\nRIGHT"; return ;;
			esac
			;;
		dock)
			case "$sub" in
				autohide) [[ $COMP_CWORD == 3 ]] && echo -e "YES\nNO"; return ;;
				magnification) [[ $COMP_CWORD == 3 ]] && echo -e "YES\nNO"; return ;;
				position) [[ $COMP_CWORD == 3 ]] && echo -e "BOTTOM\nLEFT\nRIGHT"; return ;;
			esac
			;;
		finder) [[ $COMP_CWORD == 3 ]] && echo -e "YES\nNO"; return ;;
		screensaver) [[ $sub == "askforpassword" && $COMP_CWORD == 3 ]] && echo -e "YES\nNO"; return ;;
	esac
}
completion_logic
