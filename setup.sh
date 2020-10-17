#!/bin/bash

: <<'DISCLAIMER'

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES
OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT
HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
OTHER DEALINGS IN THE SOFTWARE.

This script is licensed under the terms of the MIT license.
Unless otherwise noted, code reproduced herein
was written for this script.

- ILWrites -

DISCLAIMER

# script control variables

productname="Clean Shutdown Daemon" # the name of the product to install
scriptname="setup.sh" # the name of this script
spacereq=20 # minimum size required on root partition in MB
debugmode="no" # whether the script should use debug routines
debuguser="none" # optional test git user to use in debug mode
debugpoint="none" # optional git repo branch or tag to checkout
forcesudo="yes" # whether the script requires to be ran with root privileges
promptreboot="yes" # whether the script should always prompt user to reboot
mininstall="no" # whether the script enforces minimum install routine
customcmd="yes" # whether to execute commands specified before exit
armhfonly="yes" # whether the script is allowed to run on other arch
armv6="yes" # whether armv6 processors are supported
armv7="yes" # whether armv7 processors are supported
armv8="yes" # whether armv8 processors are supported
raspbianonly="no" # whether the script is allowed to run on other OSes
pkgdeplist=() # list of dependencies
defaultconf="/etc/cleanshutd.conf"

FORCE=""
PRODUCT=""
USERPIN=""

ASK_TO_REBOOT=false
CURRENT_SETTING=false
MIN_INSTALL=false
FAILED_PKG=false
REMOVE_PKG=false
UPDATE_DB=false

AUTOSTART=~/.config/lxsession/LXDE-pi/autostart
BOOTCMD=/boot/cmdline.txt
CONFIG=/boot/config.txt
APTSRC=/etc/apt/sources.list
INITABCONF=/etc/inittab
BLACKLIST=/etc/modprobe.d/raspi-blacklist.conf
LOADMOD=/etc/modules

RPIPOOL="http://archive.raspberrypi.org/debian/pool"
RPIGPIO1="raspi-gpio_0.20170105_armhf.deb"

# function define

confirm() {
    if [ "$FORCE" == '-y' ]; then
        true
    else
        read -r -p "$1 [y/N] " response < /dev/tty
        if [[ $response =~ ^(yes|y|Y)$ ]]; then
            true
        else
            false
        fi
    fi
}

prompt() {
        read -r -p "$1 [y/N] " response < /dev/tty
        if [[ $response =~ ^(yes|y|Y)$ ]]; then
            true
        else
            false
        fi
}

success() {
    echo -e "$(tput setaf 2)$1$(tput sgr0)"
}

inform() {
    echo -e "$(tput setaf 6)$1$(tput sgr0)"
}

warning() {
    echo -e "$(tput setaf 1)$1$(tput sgr0)"
}

newline() {
    echo ""
}

progress() {
    count=0
    until [ $count -eq 7 ]; do
        echo -n "..." && sleep 1
        ((count++))
    done;
    if ps -C $1 > /dev/null; then
        echo -en "\r\e[K" && progress $1
    fi
}

sudocheck() {
    if [ $(id -u) -ne 0 ]; then
        echo -e "Install must be run as root. Try 'sudo ./$scriptname'\n"
        exit 1
    fi
}

sysclean() {
    sudo apt-get clean && sudo apt-get autoclean
    sudo apt-get -y autoremove &> /dev/null
}

sysupdate() {
    if ! $UPDATE_DB; then
        echo "Updating apt indexes..." && progress apt-get &
        sudo apt-get update 1> /dev/null || { warning "Apt failed to update indexes!" && exit 1; }
        sleep 3 && UPDATE_DB=true
    fi
}

sysupgrade() {
    sudo apt-get upgrade
    sudo apt-get clean && sudo apt-get autoclean
    sudo apt-get -y autoremove &> /dev/null
}

sysreboot() {
    warning "Some changes made to your system require"
    warning "your computer to reboot to take effect."
    echo
    if prompt "Would you like to reboot now?"; then
        sync && sudo reboot
    fi
}

apt_pkg_req() {
    APT_CHK=$(dpkg-query -W -f='${Status}\n' "$1" 2> /dev/null | grep "install ok installed")

    if [ "" == "$APT_CHK" ]; then
        echo "$1 is required"
        true
    else
        echo "$1 is already installed"
        false
    fi
}

apt_pkg_install() {
    echo "Installing $1..."
    sudo apt-get --yes install "$1" 1> /dev/null || { inform "Apt failed to install $1!\nFalling back on pypi..." && return 1; }
}

config_set() {
    if [ -n $defaultconf ]; then
        sudo sed -i "s|#\?$1=.*$|$1=$2|" $defaultconf
    else
        sudo sed -i "s|#\?$1=.*$|$1=$2|" $3
    fi
}

: <<'MAINSTART'

Perform all global variables declarations as well as function definition
above this section for clarity, thanks!

MAINSTART

# checks and init

if [ $forcesudo == "yes" ]; then
    sudocheck
fi


echo -e "Installing dependencies..."

if apt_pkg_req "raspi-gpio" &> /dev/null; then
    if ! apt_pkg_install "raspi-gpio" &> /dev/null; then
        DEBDIR=`mktemp -d /tmp/pimoroni.XXXXXX` && cd $DEBDIR
        wget $RPIPOOL/main/r/raspi-gpio/$RPIGPIO1 &> /dev/null
        sudo dpkg -i $DEBDIR/$RPIGPIO1
    fi
fi

for pkgdep in ${pkgdeplist[@]}; do
    if apt_pkg_req "$pkgdep"; then
        sysupdate && apt_pkg_install "$pkgdep"
    fi
done

echo -e "\nInstalling daemon..."

sudo cp ./daemon/etc/init.d/cleanshutd /etc/init.d/
sudo cp ./daemon/usr/bin/cleanshutd /usr/bin/
sudo chmod +x /usr/bin/cleanshutd

sudo systemctl daemon-reload
sudo systemctl enable cleanshutd
sudo cp ./daemon/etc/cleanshutd.conf /etc/

read -p "Are you installing this script on PiKeeb? (y/n) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]
then
    PRODUCT="PiKeeb"
fi

if [ "$PRODUCT" == "PiKeeb" ]; then
    echo -e "\nInstalling GPIO Power Off support...\n"
    sudo cp ./daemon/lib/systemd/system-shutdown/gpio-poweroff /lib/systemd/system-shutdown/gpio-poweroff
    echo -e "\nApplying default settings for PiKeeb..."
    config_set trigger_pin 26
    config_set poweroff_pin 26
    config_set hold_time 0
    config_set shutdown_delay 0
    config_set polling_rate 1
else
    if [ -z "$PRODUCT" ]; then
        if [ -n "$USERPIN" ]; then
            config_set trigger_pin "$USERPIN"
        else
            echo
            read -r -p "\nWhat BCM pin would you like to use as a trigger for the shutdown? " bcmnumber < /dev/tty
            if [ $bcmnumber -ge 4 &>/dev/null ] && [ $bcmnumber -le 27 &>/dev/null ]; then
                config_set trigger_pin $bcmnumber
            else
              warning "\nInput not recognised as a valid BCM pin number!"
              echo "\nEdit /etc/cleanshutd.conf manually to specify the correct pin"
            fi
            read -r -p "\nWhat BCM pin would you like to pull low on shutdown?" bcmnumber < /dev/tty
            if [ $bcmnumber -ge 4 &>/dev/null ] && [ $bcmnumber -le 27 &>/dev/null ]; then
                sudo cp ./daemon/lib/systemd/system-shutdown/gpio-poweroff /lib/systemd/system-shutdown/gpio-poweroff
                config_set poweroff_pin $bcmnumber
            else
                warning "\nInput not recognised as a valid BCM pin number!"
                echo "\nEdit /etc/cleanshutd.conf manually to specify the correct pin"
            fi
            echo "\nIf you wish to change any of the daemon parameters, please edit /etc/cleanshutd.conf manually."
        fi
    fi
fi

success "\nAll done!\n"

if [ "$FORCE" != '-y' ]; then
    sysreboot
fi; echo

exit 0
