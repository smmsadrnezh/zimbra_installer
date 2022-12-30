DOMAIN_ADDR="example.com"
MAIL_ADDR="mail.$DOMAIN_ADDR"
EXTRA_MAIL_ADDR="mail.OTHERDOMAIN.COM"
PUBLIC_IP=$(curl api.ipify.org)
PRIVATE_IP=1.2.3.4

# UTILITY FUNCTIONS

function print_separator() {
    for ((i = 0; i < "$TERMINAL_COLUMNS"; i++)); do
        printf $1
    done
}

function echo_run() {
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
	echo "Setup A records from ${MAIL_ADDR} and ${EXTRA_MAIL_ADDR} to ${PUBLIC_IP}"
	echo "Setup MX records from ${DOMAIN_ADDR} to ${MAIL_ADDR} and TXT records"
	echo "Check reverse dns in https://mxtoolbox.com/ReverseLookup.aspx from ${PUBLIC_IP} to ${MAIL_ADDR}"
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
	echo "${PRIVATE_IP} ${MAIL_ADDR} mail" >> /etc/hosts
}

install_zimbra() {
	echo_run "apt install net-tools -y"
	echo_run "cd /tmp"
	echo_run "wget https://files.zimbra.com/downloads/8.8.15_GA/zcs-8.8.15_GA_4179.UBUNTU20_64.20211118033954.tgz"
	echo_run "tar xzvf zcs-8.8.15_GA_4179.UBUNTU20_64.20211118033954.tgz"
	echo_run "cd zcs-8.8.15_GA_4179.UBUNTU20_64.20211118033954/"
	echo_run "./install.sh"
}

change_zimbra_default_to_http() {
	echo "su - zimbra"
	echo "zmprov gs $(zmhostname) zimbraReverseProxyHttpEnabled"
	echo "zmprov gs $(zmhostname) zimbraReverseProxyMailMode"
	echo "zmprov ms $(zmhostname) zimbraReverseProxyMailMode redirect"
	echo "zmcontrol restart"
	echo "exit"
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
	echo_run "crontab -e"
	echo '12 5 * * * /usr/bin/certbot renew --pre-hook "/usr/local/bin/certbot_zimbra.sh -p" --renew-hook "/usr/local/bin/certbot_zimbra.sh -r "'
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
