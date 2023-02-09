#!/bin/bash
DOMAIN_ADDR="example.com"
OTHER_DOMAIN="otherexample.com"
MAIL_ADDR="mail.$DOMAIN_ADDR"
EXTRA_MAIL_ADDR="mail.$OTHER_DOMAIN"
LIMITED_ADMIN_MAIL="user@$DOMAIN_ADDR"
PUBLIC_IP=$(curl api.ipify.org)
PRIVATE_IP=1.2.3.4
ZIMBRA8_UBUNTU22_URL="https://files.zimbra.com/downloads/8.8.15_GA/zcs-8.8.15_GA_4179.UBUNTU20_64.20211118033954.tgz"
ZEXTRAS9_UBUNTU22_URL="download.zextras.com/zcs-9.0.0_OSE_UBUNTU20_latest-zextras.tgz"
CRON_LINE='12 5 * * * /usr/bin/certbot renew --pre-hook "/usr/local/bin/certbot_zimbra.sh -p" --renew-hook "/usr/local/bin/certbot_zimbra.sh -r "'

# UTILITY FUNCTIONS

export TERMINAL_COLUMNS="$(stty -a 2> /dev/null | grep -Po '(?<=columns )\d+' || echo 0)"

print_separator() {
    for ((i = 0; i < "$TERMINAL_COLUMNS"; i++)); do
        printf $1
    done
}

echo_run() {
    line_count=$(wc -l <<<$1)
    echo -n ">$(if [ ! -z ${2+x} ]; then echo "($2)"; fi)_ $(sed -e '/^[[:space:]]*$/d' <<<$1 | head -1 | xargs)"
    if (($line_count > 1)); then
        echo -n "(command truncated....)"
    fi
    echo
    if [ -z ${2+x} ]; then
        eval $1
    else
        FUNCTIONS=$(declare -pf)
        echo "$FUNCTIONS; $1" | sudo --preserve-env -H -u $2 bash
    fi
    print_separator "+"
    echo -e "\n"
}

# ACTION FUNCTIONS

echo_initial_configuration() {
    echo_run "cat /etc/netplan/*"
    echo_run "echo $DOMAIN_ADDR"
    echo_run "echo $MAIL_ADDR"
    echo_run "echo $EXTRA_MAIL_ADDR"
    echo_run "echo $PUBLIC_IP"
    echo_run "echo $PRIVATE_IP"
    echo_run "lsb_release -d"
    echo "These ports should be open on the external firewall: 22, 80, 443, 7071, 25, 110, 143, 465, 587, 993, and 995. Test it with nc -l PORT."
    echo "Setup A records from ${MAIL_ADDR} and ${EXTRA_MAIL_ADDR} to ${PUBLIC_IP}."
    echo "Setup MX records from ${DOMAIN_ADDR} to ${MAIL_ADDR} and TXT records."
    echo "Check reverse DNS in https://mxtoolbox.com/ReverseLookup.aspx from ${PUBLIC_IP} to ${MAIL_ADDR}."
    echo ""
    echo_run "dig mx ${DOMAIN_ADDR}"
    echo_run "dig ${MAIL_ADDR}"
}

server_initial_setup() {
    echo_run "apt update -y"
    echo_run "apt upgrade -y"
    echo_run "apt autoremove -y"
    echo_run "apt install telnet -y"
    echo_run "ln -fs /usr/share/zoneinfo/Asia/Tehran /etc/localtime"
    echo_run "dpkg-reconfigure -f noninteractive tzdata"
    echo_run "reboot"
}

update_rsyslog() {
    echo "comment out following lines:"
    echo 'module(load="imudp")'
    echo 'input(type="imudp" port="514")"'
    echo_run "nano /etc/rsyslog.conf"
    echo_run "systemctl restart rsyslog"
    echo_run "systemctl enable rsyslog"
}

update_local_dns() {
    echo_run "hostnamectl set-hostname ${MAIL_ADDR}"
    echo_run 'echo "${PRIVATE_IP} ${MAIL_ADDR} mail" >> /etc/hosts'
}

install_zimbra() {
    echo_run "apt install net-tools -y"
    echo_run "cd /tmp"
    echo_run "wget $ZIMBRA_UBUNTU22_DOWNLOAD"
    echo_run "tar xzvf zcs-8.8.15_GA_4179.UBUNTU20_64.20211118033954.tgz"
    echo_run "cd zcs-8.8.15_GA_4179.UBUNTU20_64.20211118033954/"
    echo_run "./install.sh"
}

change_zimbra_default_to_http() {
    echo_run "su - zimbra -c 'zmprov gs $(zmhostname) zimbraReverseProxyHttpEnabled'"
    echo_run "su - zimbra -c 'zmprov gs $(zmhostname) zimbraReverseProxyMailMode'"
    echo_run "su - zimbra -c 'zmprov ms $(zmhostname) zimbraReverseProxyMailMode redirect'"
    echo_run "su - zimbra -c 'zmcontrol restart'"
}

install_https() {
    echo_run "wget https://raw.githubusercontent.com/YetOpen/certbot-zimbra/master/certbot_zimbra.sh -P /usr/local/bin"
    echo_run "chmod +x /usr/local/bin/certbot_zimbra.sh"
    echo_run "apt install telnet certbot -y"
    echo_run "certbot_zimbra.sh --new --extra-domain ${MAIL_ADDR} --extra-domain ${EXTRA_MAIL_ADDR}"
    echo_run "apt purge --remove certbot -y"
    echo_run "snap install --classic certbot"
    echo_run "ln -s /snap/bin/certbot /usr/bin/certbot"
    echo_run 'certbot --force-renewal --preferred-chain "ISRG Root X1" renew'
    echo_run "/usr/local/bin/certbot_zimbra.sh -d"
    echo_run "rm -rf /usr/bin/certbot"
    echo_run "apt purge --remove snapd -y"
    echo_run "apt autoremove -y"
    echo_run "rm -rf /root/snap/"
    echo_run "systemctl daemon-reload"
    echo_run "df -h"
    echo_run "apt install certbot -y"
    echo_run "(crontab -u $(whoami) -l; echo "$CRON_LINE" ) | crontab -u $(whoami) -"
}

install_fail2ban() {
    echo_run "apt install fail2ban -y"
    echo_run "fail2ban-client status"
    echo_run "fail2ban-client status sshd"
}

install_firewall() {
    echo_run "cp zimbra_ufw /etc/ufw/applications.d/zimbra"
    echo_run "ufw allow Zimbra"
    echo_run "ufw allow ssh"
    echo_run "ufw enable"
    echo_run "ufw status"
}

final_checks(){
    echo_run "htop"
    echo_run "tail -f /var/log/zimbra.log"
    echo_run "tail -f /var/log/syslog"
    echo_run "du -sh /opt/"
}

create_a_limited_access_admin() {
    echo_run "cp delegate-admin.sh /usr/local/bin/"
    echo_run "chmod +x /usr/local/bin/delegate-admin.sh"
    echo_run "su - zimbra -c 'zmprov ma ${DOMAIN_ADDR} zimbraIsDelegatedAdminAccount TRUE zimbraAdminConsoleUIComponents accountListView zimbraAdminConsoleUIComponents downloadsView zimbraAdminConsoleUIComponents DLListView zimbraAdminConsoleUIComponents aliasListView zimbraAdminConsoleUIComponents resourceListView'"
    echo_run "su - zimbra -c 'zmprov grr global usr ${LIMITED_ADMIN_MAIL} adminLoginCalendarResourceAs'"
    echo_run "su - zimbra -c 'delegate-admin.sh ${LIMITED_ADMIN_MAIL} ${DOMAIN_ADDR}'"
}

install_zextras_theme() {
    echo_run "wget download.zextras.com/zextras-theme-installer/latest/zextras-theme-ubuntu.tgz"
    echo_run "tar xvf zextras-theme-ubuntu.tgz"
    echo_run "cd zextras-theme-installer && sudo ./install.sh"
    echo_run "su - zimbra -c 'zmmailboxdctl restart'"
    echo_rum "cd .. && rm zextras-theme-ubuntu.tgz zextras-theme-installer"
    echo_run "su - zimbra -c 'for i in `zmprov -l gaa`; do zmprov ma ${i} zimbraAvailableSkin zextras zimbraPrefSkin zextras;done;'"
}

ACTIONS=(
    echo_initial_configuration
    server_initial_setup
    update_rsyslog
    update_local_dns
    install_zimbra
    change_zimbra_default_to_http
    install_https
    install_fail2ban
    install_firewall
    final_checks
    create_a_limited_access_admin
)

while true; do
    echo "Which action? $(if [ ! -z ${LAST_ACTION} ]; then echo "($LAST_ACTION)"; fi)"
    for i in "${!ACTIONS[@]}"; do
        echo -e "\t$((i + 1)). ${ACTIONS[$i]}"
    done
    read ACTION
    LAST_ACTION=$ACTION
    print_separator "-"
    $ACTION
    print_separator "-"
done
