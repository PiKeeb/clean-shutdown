# clean-shutdown

`clean-shutdown` is a simple daemon that monitors a user-specified GPIO pin and triggers a clean software shutdown when that pin is asserted low. It offers ways to customise the behaviour of the shutdown process to fit most use-cases.

The code of `clean-shutdown` has been forked from [Pimoroni's GitHub](https://github.com/pimoroni/clean-shutdown) and modified to accommodate PiKeeb's single pin approach.

## Installation

The `setup.sh` script provided in this repository can be used to set your preference of GPIO pin to monitor in order to initiate the shutdown.

To setup the daemon, make sure that `git` is installed on your system, then run the following commands:
```bash
git clone https://github.com/PiKeeb/clean-shutdown
cd clean-shutdown
sudo ./setup.sh
```

## Usage

There is really not a lot that needs to be done once the daemon is in place - which will be the case after installation and reboot... this is all very straightforward!

That said, `clean-shutdown` has some interesting features that your particular use-case may require. For example, if you are using an input trigger you would normally expect the shutdown to occur as soon as you press the control. But what if that is not what you want?

`clean-shutdown` provides several useful parameters to adapt the shutdown behaviour or exact monitoring environment to your project, without requiring you to mess with the daemon code, or understand what it does in the finer details.

If you find yourself in such a need, fire up your favourite editor and open `/etc/cleanshutd.conf`. The parameters documented below can then be customised as desired.

Note that in order for parameters changes to take effect the deamon has to be restarted. The easier way to do that is to reboot the Pi, or run:

```
sudo service cleanshutd restart
```

## Parameters

### `daemon_active`

This is a pretty hacky way to pacify the daemon without needing to delve into the details of [systemd](https://www.freedesktop.org/wiki/Software/systemd/). Set to `0` to deactivate the daemon (technically the daemon will be started at boot time but it will do absolutely nothing). Set to `1` to reactivate.

### `trigger_pin`

Normally you'll set this up at install time and won't need to change it, but... as we do, next week you might buy a nice shiny (Pimoroni) HAT or pHAT and find that the pin you had your clean shutdown trigger wired to is required by your new friend. Just move the trigger button to another pin and reboot! The unit used for this parameter is the bcm number for the pin (4 or above recommended, 0-3 have particularities that make them slightly less straightforward to use, though the daemon will happily monitor them for you, so as long as you know what you're doing go right ahead).

### `poweroff_pin`

For products that support it (eg: OnOff SHIM), the `poweroff_pin` determines which pin will be pulled low right at the end of your Pi's shutdown process. If supported, this will cause power to your Pi to be cut completely.

### `hold_time`

This parameter determines the amount of time you must hold down the button until shutdown occurs. It defaults to 1 second to avoid accidental shutdowns. The unit for `hold_time` is expressed in seconds. Use `0` to shutdown as soon as the button is pressed.

### `shutdown_delay`

Most of the time you probably want your Pi to shutdown as soon as the trigger occurs, but sometimmes, like with the Zero Lipo, once the battery warning has been detected you still got some life of the LiPo before it is necessary to shut it down (the 'battery low' warning is activated at 3.4V, but the protection circuitry will only cut off the supply at 3.0V). The unit for `shutdown_delay` is expressed in minutes (`0`, the default, means immediate shutdown).

### `polling_rate`

This parameter determines how often the trigger is checked for. Normally, a small but reasonable value, say a second or 2 is adequate to detect a button press without polling constantly, but if you take the Zero Lipo example again it really does not matter if the monitoring is more relaxed, say if polling is performed every 30 seconds or so. There may be other use-cases where smaller or larger values are optimal, so there's a parameter for the occasion if you find yourself in one. Units for `polling_rate` are expressed in seconds.

## Parasitic Shutdowns

Be aware that altering the state of `trigger_pin` can throw you in a scenario where your Pi shuts down right away upon boot, if a process, dtoverlay, or HAT EEPROM, just to name a few possibilities, pulls it low on boot (or set it as an output, which implies it being driven low initially).

If this occurs right after you plugged a HAT, then try booting without it attached, and disable the cleatshutd service with:

```bash
sudo systemctl disable cleanshutd
```

There is another way, which is provided as an emergency solution for scenarios where reaching the bash prompt is not possible (because the Pi shuts down before you get a chance to do so).

In such cases, or as an alternative to the above, you may add the following to your `/boot/config.txt` file from another computer:

`disable_cleanshutd=1`
