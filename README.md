# rtcsyncwake-pinephone

A simple way to enable the Pinephone to wake itself from sleep (ideally) without root privs.

If you're on a KDE Plasma Mobile PostmarketOS Pinephone, you can also use my shell script and OpenRC 
init script to have all KClock alarms and timers wake your Pinephone from suspend and ring the alarms.

# Installation

## Building `rtcwaker`

```sh
$ gcc -o rtcwaker rtcwaker.c
```

## Configuring `rtcwaker`

There are two ways to setup `rtcwaker` such that it will run as a regular (non-root) user.

1. Using capabilities (Preferred)

```sh
$ sudo setcap cap_wake_alarm+ep /full/path/to/rtcwaker
```

If you get `Operation not supported` or similar, either a) your kernel lacks support for
capabilities, b) your filesystem lacks support for xattrs or is mounted without xattr support, or
c) your kernel is not configured with xattr support for your filesystem.

If you're not sure what the 3 possiblilites mean or how to resolve them, you can always try option 2

2. Using setuid (Should be fine for `rtcwaker`)

```sh
$ sudo chown root:root rtcwaker
$ sudo chmod u+s rtcwaker
```

# Usage

To have the Pinephone wake from suspend at time 1619387000:

```sh
$ ./rtcwaker 1619387000
```

To run it in the background after you close your shell, you can run:

```sh
$ ./rtcwaker 1619387000 & disown
```

# Using the Shell Scripts 

The `rtcsync.sh` shell script fetches the next timer or alarm from Plasma Mobile's KClock
and tells `rtcwaker` to wake the phone at that time so the alarm can ring.

If you're on PostmarketOS, feel free to also use the `rtcsyncwake` init script to start this
process automatically. 

## Requirements

- qdbus
- Plasma Mobile KClock

## rtcsync.sh

First, set `RTCWAKER` to your `rtcwaker` binary. If you placed `rtcwaker` in your `$PATH`, you
can also set it to just `rtcwaker`.

```sh
#!/bin/sh

# RTCWAKER=/home/user/rtcwaker
RTCWAKER=/path/to/your/rtcwaker
```

Next, make it executable and run it

```sh
$ chmod +x rtcsync.sh
$ ./rtcsync.sh
Found DBUS session bus address: ...
```

## rtcsyncwake (OpenRC)

First, set `command` to your `rtcsync.sh` shell script, and switch `command_user` to your user.

Note: this should probably be the same user who's running KDE

```sh
#!/sbin/openrc-run

...

# command="/home/user/rtcsync.sh"
command="/path/to/your/rtcsync.sh"
command_background=true
# command_user="user:user"
command_user="your-user:your-user"
pidfile= ...

...
```

Next move it to `/etc/init.d/`, make it executable, and add it to OpenRC's default runlevel

```sh
$ sudo cp rtcsyncwake /etc/init.d/
$ sudo chmod +x /etc/init.d/rtcsyncwake
$ sudo rc-update add rtcsyncwake default
```

# FAQs

### Why did you do this? And why didn't you implement it in [this other way]?

You'll probably find those answers on [my blog](https://vkraven.com/posts/2021-04-22-adventures-pinephone-part-1.html).

### I have two wakeups I want to schedule. How do I set two wakeups?

```sh
./rtcwaker [TIMESTAMP_1] & ./rtcwaker [TIMESTAMP_2] &
```

### How can I tell if `rtcwaker` is actually running?

```sh
ps -a | grep rtcwaker
```

### I ran `./rtcwaker TIMESTAMP` and my Pinephone woke up, but there was no alarm! Why?

`rtcwaker` only schedules a wakeup from the hardware clock - it doesn't contain any code to play an alarm sound.

If you're on Plasma Mobile, `rtcsync.sh` can be used to synchronise the hardware wakeup with KClock's scheduled
alarms and timers. I.e., `rtcwaker` wakes the phone, and KClock rings the alarm.

### Why didn't you code in an alarm-sound-ringer into `rtcwaker`?

I wanted `rtcwaker` to be useful for more than just alarms. For example, if you wanted to implement a 
"wake up and fetch notifications regularly" feature, you could write a script to spawn an
`rtcwaker` process every 5 minutes.

Also, KClock already does an awesome job at ringing alarms. 

### When I run `rtcsync.sh` I get a message like `0: unknown operand`. What's going on?

You're probably missing `qdbus`, or you're running Plasma Mobile without dbus (? is this even possible?). Try 
installing `qdbus`, and making sure dbus is running.

### I'm not running PostmarketOS / I'm running Manjaro KDE Plasma Mobile, but I really want to use your scripts! How can I do so?

Follow the installation instructions above for `rtcwaker` and `rtcsync.sh`. Then create a systemd service to start
`rtcsync.sh` as your user (with `User=` and optionally `Group=`). 

Ideally, schedule it to start after KDE has started (probably `multi-user.target`).

By the way, systemd system timers can already wake the Pinephone from suspend, so you could also consider just using systemd
alone instead. Check out the fantastic [wake-mobile](https://gitlab.gnome.org/kailueke/wake-mobile) if you're curious.

### I'm running Phosh and I really want Gnome Clocks to automatically wake my Pinephone!

I tried Phosh a few times but never really got into it. `rtcwaker` will still wake your phone at whatever time you
ask it to, but you'll have to synchronise Gnome Clock alarms with `rtcwaker` one way or another.

Also note that [this issue](https://gitlab.com/mobian1/issues/-/issues/110) is still open in the Mobian Gitlab repo.
Phosh has an odd habit of not going back into suspend if woken up by the rtc... YMMV. Also, check out [wake-mobile](https://gitlab.gnome.org/kailueke/wake-mobile).
