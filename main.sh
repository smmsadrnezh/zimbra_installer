DOMAIN_ADDR="example.com"
MAIL_ADDR="mail.$DOMAIN_ADDR"
EXTRA_MAIL_ADDR="mail.OTHERDOMAIN.COM"
PUBLIC_IP=$(curl api.ipify.org)
PRIVATE_IP=1.2.3.4
cat /etc/netplan/*

echo "Setup DNS for ${DOMAIN_ADDR} and ${MAIL_ADDR}"
dig mx ${DOMAIN_ADDR}
dig ${MAIL_ADDR}

apt update -y
apt upgrade -y
apt autoremove -y
dpkg-reconfigure tzdata
echo "reboot" 

nano /etc/rsyslog.conf
echo "comment out following lines:"
echo 'module(load="imudp")'
echo 'input(type="imudp" port="514")"'
systemctl restart rsyslog
systemctl enable rsyslog

hostnamectl set-hostname ${MAIL_ADDR}
echo "${PRIVATE_IP} ${MAIL_ADDR} mail" >> /etc/hosts

apt install net-tools -y
cd /tmp
wget https://files.zimbra.com/downloads/8.8.15_GA/zcs-8.8.15_GA_4179.UBUNTU20_64.20211118033954.tgz
tar xzvf zcs-8.8.15_GA_4179.UBUNTU20_64.20211118033954.tgz 
cd zcs-8.8.15_GA_4179.UBUNTU20_64.20211118033954/
./install.sh

su - zimbra
zmprov gs $(zmhostname) zimbraReverseProxyHttpEnabled
zmprov gs $(zmhostname) zimbraReverseProxyMailMode
zmprov ms $(zmhostname) zimbraReverseProxyMailMode redirect
zmcontrol restart
exit
wget https://raw.githubusercontent.com/YetOpen/certbot-zimbra/master/certbot_zimbra.sh -P /usr/local/bin
chmod +x /usr/local/bin/certbot_zimbra.sh
apt install telnet certbot -y
certbot_zimbra.sh --new --extra-domain ${MAIL_ADDR} --extra-domain ${EXTRA_MAIL_ADDR}
apt purge --remove certbot -y
snap install --classic certbot
ln -s /snap/bin/certbot /usr/bin/certbot
certbot --force-renewal --preferred-chain "ISRG Root X1" renew
/usr/local/bin/certbot_zimbra.sh -d
rm -rf /usr/bin/certbot
apt purge --remove snapd -y
apt autoremove -y
rm -rf /root/snap/
systemctl daemon-reload
df -h
apt install telnet certbot -y
crontab -e
echo '12 5 * * * /usr/bin/certbot renew --pre-hook "/usr/local/bin/certbot_zimbra.sh -p" --renew-hook "/usr/local/bin/certbot_zimbra.sh -r "'

apt install fail2ban -y
fail2ban-client status
fail2ban-client status sshd

nano /etc/ufw/applications.d/zimbra

[Zimbra]
title=Zimbra Collaboration Server
description=Zimbra
ports=25,80,110,143,443,465,587,993,995,7071/tcp

ufw allow Zimbra
ufw allow ssh
ufw enable
ufw status

htop
tail -f /var/log/zimbra.log
tail -f /var/log/syslog
df -h
du -sh /opt/
