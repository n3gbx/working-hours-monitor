# Working hours monitor

The project consists of a set of scripts that are interrelated to perform common tasks for monitoring, parsing, logging and retrieving information about the status of the user's desktop - locked or not. Bases on the logged information, user can track and analyze the time spent at the computer.

## Features :dizzy:

* **Easy to install**

  With the script which will do whole setup, only a couple of commands separate the user from the beginning of using the program after installation.
  
* **One script - one task** 

  The project has two main ideas - monitoring and data aggregation. Specialy for those tasks there are two head scripts - ```wh_mon.sh``` and ```wh_get.sh``` respectively.
  
* **Use modes**

  The user has the option to choose how to use the script for monitoring: in foreground or like a systemctl daemon.
  
* **Human readable logs**

  Much attention was paid to logging information, for ease to understand what happens during the ```wh_mon.sh``` running.
  
* **Aggregation flexibility**

  Ease and flexibility in data aggregation is provided by the diverse options and their variations, which allows the user to collect data for any period of time.

## Getting Started :electric_plug:

These instructions will help you to understand how to deploy a project to your workstation for testing, development, or usage purposes.

### Prerequisites

Unfortunately, the script was tested and supports only Ubuntu so far.
What are the requirements for your system that you should consider to continue:

* Ubuntu 18.04 and greater
* Bash 4.0 and greater
* GNOME desktop environment (Unity will be included)

### Files
* ```wh_mon.sh``` - used to start dbus-monitor process, listen on it stdout about lockscreen state, parse them and log to .csv file
* ```wh_get.sh``` - used to parse .csv file, retrieve information and print it in user-friendly format
* ```wh_daemon.service``` - is a systemd [unit](https://www.freedesktop.org/software/systemd/man/systemd.unit.html) file to start ```wh_mon.sh``` script as [service](https://www.freedesktop.org/software/systemd/man/systemd.service.html)
* ```wh_install.sh``` - used to run compatibility tests and copy script files to their destinations
* ```wh_help.sh``` - includes basic commands wrappers

### Installing

1. ```git clone https://github.com/n3gbx/working-hours-monitor```
2. In Terminal, navigate to ```working-hours-monitor``` folder
3. Run ```sudo -E wh_install.sh``` command to start compatibility tests and copy script files to desired directories

OR

3. Copy ```wh_mon.sh``` and ```wh_help.sh``` script files to ```/usr/local/bin```
4. Make them executable: ```sudo chmod +x /usr/local/bin/wh_*.sh```
5. Copy ```wh_daemon.service``` to ```/etc/systemd/system```
6. Make it executable: ```chmod +x /etc/systemd/system/wh_daemon.service```
7. Create ```wh_table.csv``` file inside ```/var/log``` directory
8. Change the owner: ```sudo chown $USER:$USER /var/log/wh_table.csv```

### Usage

**Foreground**

To run ```wh_mon.sh``` from the Terminal tab as a standart bash process:

``` 
$ bash wh_mon.sh 
```

If your .csv file has the onwer differ from the current user:

``` 
$ sudo bash wh_mon.sh 
```

To change .csv file path, please pass it as a first script argument:

```
$ bash wh_mon.sh [path]
```

**Daemon**

To start the ```wh_mon.sh``` as a service (it will trigger ```wh_mon.sh```):

```
$ sudo systemctl start wh_daemon
``` 

To manage daemon, use standart ```systemctl``` options like.

In order for the script to run as a daemon at system startup:

```
$ sudo systemctl enable wh_daemon
``` 
And to disable:

```
$ sudo systemctl disable wh_daemon
```

### Logging

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

So now, if the user will lock or unlock the screen, appropriate log messages appears:

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

To retrieve information, use ```$ bash wh_get.sh``` command. If the date present within specified .csv file, you will see smth like that:

```
date         start   spent      end     break     overtime total      
2019-11-09   20:23   0h14m19s   04:23   0h0m10s   0h0m0s   0h14m29s 
```

For more information about ```wh_get.sh``` options, please read help adding ```-h``` option
