# Working hours monitor

Working hours monitor is a set of scripts to monitor, log and fetch information about the time when the screen was locked or unlocked.

Bases on that it helps to control when the user was at the computer and when not.

## Requirements

* Ubuntu 18.04 and greater
* Bash 4.0 and greater
* GNOME desktop environment (Unity will be included)

## Description

### Main files
* ```wh_mon.sh``` - used to start dbus-monitor process, listen on it stdout about lockscreen state, parse them and log to .csv file
* ```wh_get.sh``` - used to parse .csv file, retrieve information and print it in user-friendly format
* ```wh_daemon.service``` - is a systemd [unit](https://www.freedesktop.org/software/systemd/man/systemd.unit.html) file to start ```wh_mon.sh``` script as [service](https://www.freedesktop.org/software/systemd/man/systemd.service.html)

### Additional files
* ```wh_install.sh``` - used to run compatibility tests and copy script files to their destinations
* ```wh_help.sh``` - includes basic command wrappers

## Installation

```git clone https://github.com/n3gbx/working-hours-monitor```

### Unpacking

* In Terminal, navigate to ```working-hours-monitor``` folder
* Run ```sudo -E wh_install.sh``` command to start compatibility tests and copy script files to desired directories

-OR-

* Copy ```wh_mon.sh``` and ```wh_help.sh``` script files to ```/usr/local/bin```
* Make them executable: ```sudo chmod +x /usr/local/bin/wh_*.sh```
* Copy ```wh_daemon.service``` to ```/etc/systemd/system```
* Make it executable: ```chmod +x /etc/systemd/system/wh_daemon.service```
* Create ```wh_table.csv``` file inside ```/var/log``` directory
* Change the owner: ```sudo chown $USER:$USER /var/log/wh_table.csv```

## Modes

### Foreground

```wh_mon.sh``` can be launched from the Terminal tab as a standart bash script, so it will work in foreground:

```bash wh_mon.sh```

To change .csv file path, please pass it as a first script argument:

```bash wh_mon.sh <CSV_ABSOLUTE_PATH>```

### Daemon

To start the ```wh_mon.sh``` as a service, run ```sudo systemctl start wh_daemon```, it will trigger ```wh_mon.sh```. To manage daemon, use standart ```systemctl``` options like ```status```, ```stop```, etc.

In order for the script to run as a daemon at system startup, use ```sudo systemctl enable wh_daemon``` command.

## Logging

If everything was passed successfully, you will see the following output:

```
[2019-11-09 20:23:39][I] wh_mon.sh: /var/log/wh_table.csv exists and it's valid 
[2019-11-09 20:23:39][I] wh_mon.sh: PID=12458 
[2019-11-09 20:23:39][I] wh_mon.sh: gnome-session PID=1824 
[2019-11-09 20:23:39][V] export DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/1000/bus 
[2019-11-09 20:23:39][I] wh_mon.sh: starting new dbus-monitor process 
[2019-11-09 20:23:39][I] wh_mon.sh: waiting dbus-monitor to start 
[2019-11-09 20:23:39][V] seconds left: 10 
[2019-11-09 20:23:39][V] dbus-monitor found: 12477 
[2019-11-09 20:23:39][I] wh_mon.sh: dbus-monitor PID=12477 
[2019-11-09 20:23:39][I] wh_mon.sh: writing 'started' into the wh_table.csv
```

So now, if the user will lock or unlock the screen, appropriate log messages should appear:

```
...
[2019-11-09 20:26:18][I] wh_mon.sh: writing 'locked' into the wh_table.csv 
[2019-11-09 20:26:23][I] wh_mon.sh: writing 'unlocked' into the wh_table.csv 
```

And the .csv file should include the following:

```
date,time,message
2019-11-09,20:23:39,started
2019-11-09,20:26:18,locked
2019-11-09,20:26:23,unlocked
```

To retrieve information, use ```bash wh_get.sh -p true -d "<START_DATE>:<END_DATE>"``` command. If the date present within specified .csv file, you will see the smth like that:

```
date         start   spent      end     break     overtime total      
2019-11-09   20:23   0h14m19s   04:23   0h0m10s   0h0m0s   0h14m29s 
```

For more information about ```wh_get.sh``` options, please read help ```bash wh_get.sh -h```
