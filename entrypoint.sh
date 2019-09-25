#!/bin/sh
# check name 
if [[ $WKUSER == root ]]; then
    echo "WKUSER must not be root"
    exit 1
fi
if [ $WKUID -lt 1000 ]; then
    echo "WKUID must not be less than 1000"
    exit 1
fi

if [ ! -n "${WKGID+1}" ]; then
    WKGID=$WKUID
fi

if [ $WKGID -lt 1000 ]; then
    echo "WKGID must not be less than 1000"
    exit 1
fi
# set config files
cp -n /opt/rc/.bashrc /opt/rc/.inputrc /opt/rc/.fzf.bash /root/
cp -R /opt/rc/.fzf /root/
cp -n /opt/rc/.bashrc /opt/rc/.inputrc /opt/rc/.fzf.bash /home/$WKUSER/
cp -R /opt/rc/.fzf /home/$WKUSER
chown $WKUID:$WKGID /home/$WKUSER/.bashrc /home/$WKUSER/.inputrc /home/$WKUSER/.fzf.bash 
chown -R $WKUID:$WKGID /home/$WKUSER/.fzf

# user set
groupadd $WKUSER -g $WKGID
useradd $WKUSER -u $WKUID -g $WKGID -m -d /home/$WKUSER -s /bin/bash -p $WKUSER
chown -R $WKUSER:$WKGID /home/$WKUSER/
echo $WKUSER:$PASSWD | chpasswd
[[ -v ROOTPASSWD ]] && echo root:$ROOTPASSWD | chpasswd || echo root:$PASSWD | chpasswd
unset ROOTPASSWD

# config privilege 
chmod 777 /root /opt/miniconda3/pkgs
for d in $(find /root -maxdepth 1 -name ".*" -type d); do find $d -type d | xargs chmod 777 ; done
for d in $(find /root -maxdepth 1 -name ".*" -type d | grep -v fzf ); do find $d -type f | grep -v vim | xargs chmod 666 ; done
for d in $(find /home/$WKUSER -maxdepth 1 -name ".*"); do chown -R $WKUSER:$WKGID $d ; done

# sshd server 
mkdir -p /var/run/sshd
rm -r /etc/ssh/ssh*key
echo "Port 8822" >> /etc/ssh/sshd_config
echo "PermitRootLogin yes" >> /etc/ssh/sshd_config
dpkg-reconfigure openssh-server 

# code-server
echo "[program:code-server]" >>/opt/config/supervisord.conf
echo "command=/opt/code-server/code-server /home/$WKUSER -P '$PASSWD' -d /home/$WKUSER/.config/.vscode -e /home/$WKUSER/.config/.vscode-extentions">>/opt/config/supervisord.conf
echo "user=$WKUSER" >>/opt/config/supervisord.conf
echo "stdout_logfile = /opt/log/code-server.log" >>/opt/config/supervisord.conf

# jupyter config
SHA1=$(/opt/miniconda3/bin/python /opt/config/passwd.py $PASSWD)
echo "c.ContentsManager.root_dir = '/home/$WKUSER'" >> /opt/config/jupyter_lab_config.py
echo "c.NotebookApp.notebook_dir = '/home/$WKUSER'" >> /opt/config/jupyter_lab_config.py  # Notebook启动目录
echo "c.NotebookApp.password = '$SHA1'" >> /opt/config/jupyter_lab_config.py

echo ""
echo "========================= starting services with USER $WKUSER whose UID is $WKUID ================================"
# rstudio
systemctl enable rstudio-server
service rstudio-server restart
# start with supervisor
/usr/bin/supervisord -c /opt/config/supervisord.conf
