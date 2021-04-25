#!/bin/sh

RTCWAKER=/home/user/rtcwaker
LAST_ALARM=0

# This script should be the only one calling rtcwaker
killall rtcwaker

# First, we need to find the bus ID that KDE Kclock is running on

while true; do
	KCLOCKD_PID=$(pidof kclockd)
	if [ -z "$KCLOCKD_PID" ] ;then
		# It probably hasn't started yet. Sleep till then.
		sleep 5
		continue
	fi

	KCLOCKD_BUS_ADDRESS=$(cat /proc/$KCLOCKD_PID/environ | grep "DBUS_SESSION_BUS_ADDRESS" | cut -d "=" -f2-)
	echo "Found DBUS session bus address: ${KCLOCKD_BUS_ADDRESS}"
	break
done

export DBUS_SESSION_BUS_ADDRESS=$KCLOCKD_BUS_ADDRESS

while true; do
	NEXT_EARLIEST_TIMER=0

	# Find the earliest running timer and set it in NEXT_EARLIEST_TIMER. 
	# If none exist, NEXT_EARLIEST_TIMER should be untouched at 0
	for timer in $(qdbus org.kde.kclockd | grep Timers/) ; do
		if $(qdbus org.kde.kclockd $timer org.kde.kclock.Timer.running); then
			echo "Found timer: ${timer}"
			let TIMER_CLOCKTIME="$(date '+%s') - $(qdbus org.kde.kclockd $timer org.kde.kclock.Timer.elapsed) + $(qdbus org.kde.kclockd $timer org.kde.kclock.Timer.length)"
			# Do this to account for 1 second offsets between qdbus calls, because the pinephone is slow
			let TEMP_EARLIEST_TIMER="$NEXT_EARLIEST_TIMER - 1"
			if [ $NEXT_EARLIEST_TIMER -eq 0 ] || [ $TIMER_CLOCKTIME -lt $TEMP_EARLIEST_TIMER ]; then
				echo "Setting NEXT_EARLIEST_TIMER to ${TIMER_CLOCKTIME}"
				NEXT_EARLIEST_TIMER=$TIMER_CLOCKTIME
			fi
		fi
	done

	# If no running timers were found, then NEXT_EARLIEST_TIMER should be 0

	NEXT_KALARM=0

	NEXT_KCLOCK_ALARM=$(qdbus org.kde.kclockd /Alarms getNextAlarm)

	if [ $NEXT_EARLIEST_TIMER -eq 0 ]; then
		# Case: TIMER is 0. If KCLOCK is also 0, then we hit the sleep case.
		NEXT_KALARM=$NEXT_KCLOCK_ALARM
	elif [ $NEXT_KCLOCK_ALARM -eq 0 ]; then
		# Case: KCLOCK is 0 and TIMER is non-zero
		NEXT_KALARM=$NEXT_EARLIEST_TIMER
	else
		# Case: Neither KCLOCK nor TIMER are 0
		EARLIER_TIME=0
		if [ $NEXT_EARLIEST_TIMER -le $NEXT_KCLOCK_ALARM ]; then
			NEXT_KALARM=$NEXT_EARLIEST_TIMER
		else
			NEXT_KALARM=$NEXT_KCLOCK_ALARM
		fi
	fi

	NOW=$(date '+%s')
	ALARM_IS_SET=false
	NEEDS_NEW_ALARM=false

	echo $NEXT_KALARM
	echo $NOW

	if [ $LAST_ALARM -ne 0 ] && [ $LAST_ALARM -lt $NOW ]; then
		echo "The set alarm is in the past, it should be over now."
		LAST_ALARM=0
	fi

	if [ $NEXT_KALARM -eq 0 ]; then
		echo "No alarm has been set, it seems. Time to sleep"
	else
		ALARM_IS_SET=true
	fi

	if $ALARM_IS_SET; then
		if [ $NEXT_KALARM -lt $NOW ]; then
			echo "Something is very wrong"
		else
			echo "Next KAlarm is in the future, good good."
			NEEDS_NEW_ALARM=true

		fi
	fi

	if $NEEDS_NEW_ALARM; then
		if [ $NEXT_KALARM -lt $LAST_ALARM ]; then
			echo "Alarm has shifted earlier than what is set!"
			echo "Killing existing rtcwaker processes"
			killall rtcwaker

			LAST_ALARM=$NEXT_KALARM
			echo "Starting rtc waker for time ${NEXT_KALARM}"
			echo "NEXT_KALARM: ${NEXT_KALARM}	LAST_ALARM: ${LAST_ALARM}"
			$RTCWAKER $NEXT_KALARM 2>&1 | logger &
		elif [ $LAST_ALARM -eq 0 ]; then
			echo "Looks like no alarm has been set! Setting new alarm"
			LAST_ALARM=$NEXT_KALARM
			echo "Starting rtc waker for time ${NEXT_KALARM}"
			echo "NEXT_KALARM: ${NEXT_KALARM}	LAST_ALARM: ${LAST_ALARM}"
			$RTCWAKER $NEXT_KALARM 2>&1 | logger &
		elif [ $NEXT_KALARM -eq $LAST_ALARM ]; then
			echo "Good good, the alarm is set and on its way"
		else
			# NEXT_KALARM is greater than $LAST_ALARM, but LAST_ALARM is not less than NOW.
			# This means the timer or alarm has been shifted into the future
			echo "The currently set alarm has been deactivated or delayed. ${RTCWAKER} must be killed and the process restarted."
			LAST_ALARM=0
			killall rtcwaker
			# This continue should break the outer while loop
			continue
		fi
	fi

	echo "Checking back in a minute"
	sleep 60
done
