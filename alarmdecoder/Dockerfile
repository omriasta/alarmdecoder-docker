# Pull base image
FROM debian:jessie
MAINTAINER AlarmDecoder <ad2usb@support.nutech.com>

# Replace sources to use archive and bypass date checking
RUN echo "deb http://archive.debian.org/debian/ jessie main" > /etc/apt/sources.list \
    && echo "deb http://archive.debian.org/debian-security jessie/updates main" >> /etc/apt/sources.list \
    && echo "Acquire::Check-Valid-Until false;" > /etc/apt/apt.conf.d/10-nocheckvalid \
    && echo "Acquire::Check-Date false;" >> /etc/apt/apt.conf.d/10-nocheckvalid

RUN apt-get update && apt-get install -y --force-yes sudo
RUN sudo mkdir -p /etc/ser2sock

RUN echo "pi\tALL=(ALL) NOPASSWD: ALL" | sudo tee -a /etc/sudoers

#disable service
RUN sudo systemctl disable serial-getty@ttyAMA0.service

# Install dependencies
RUN sudo apt-get update && sudo apt-get install -y --force-yes\
    supervisor \
    wget \
    unzip \
    minicom \
    telnet \
    libssl-dev \
    autoconf \
    automake \
    avahi-daemon \
    libffi-dev \
    screen \
    nginx \
    curl \
    build-essential \
    libpcre3-dev \
    libpcre++-dev \
    zlib1g-dev \
    libcurl4-openssl-dev \
    gunicorn \
    sendmail \
    sqlite3 \
    git \
    miniupnpc \
    python2.7 \
    python2.7-dev \
    python-pip \
    python-virtualenv \
    python-cryptography \
    libffi-dev \
    libssl-dev \
    gcc \
    --no-install-recommends && \
    sudo rm -rf /var/lib/apt/lists/*

#setup hostname
RUN sudo su -c 'echo alarmdecoder > /etc/hostname'

#setup avahi config
RUN sudo echo -e '<?xml version="1.0" standalone="no"?>\n\
<!DOCTYPE service-group SYSTEM "avahi-service.dtd">\n\
<service-group>\n\
\t<name replace-wildcards="yes">%h</name>\n\
\t<service>\n\
\t\t<type>_device-info._tcp</type>\n\
\t\t<port>0</port>\n\
\t\t<txt-record>model=AlarmDecoder</txt-record>\n\
\t</service>\n\
\t<service>\n\
\t\t<type>_ssh._tcp</type>\n\
\t\t<port>22</port>\n\
\t</service>\n\
</service-group>'\
>> /etc/avahi/services/alarmdecoder.service

# Define working directory
WORKDIR /opt

RUN echo 'LANG=C.UTF-8' | sudo tee /etc/default/locale
RUN sudo ln -s /etc/locale/alias /usr/share/locale/locale.alias
#RUN sudo dpkg-reconfigure locales

#make sure pip and setuptools are the latest available
RUN sudo pip install "setuptools==44.1.1"
RUN sudo pip install "pip<21.0"
#install ser2sock and alarmdecoder python library
#RUN sudo git clone http://github.com/nutechsoftware/ser2sock.git
COPY ./ser2sock /opt/ser2sock
#RUN sudo git clone http://github.com/nutechsoftware/alarmdecoder.git
COPY ./alarmdecoder /opt/alarmdecoder
RUN sudo /usr/sbin/useradd pi
RUN echo 'pi:raspberry' | chpasswd
RUN sudo chown -R pi:pi /opt/ser2sock /opt/alarmdecoder

WORKDIR /opt/ser2sock
RUN ./configure
RUN make
RUN sudo cp ser2sock /usr/local/bin/
RUN sudo cp -R etc/ser2sock/* /etc/ser2sock/
RUN sudo cp init/ser2sock /etc/init.d/
RUN sudo update-rc.d ser2sock defaults

WORKDIR /opt/alarmdecoder
RUN pip install "setuptools-scm<2.0"
RUN pip install "future<21.0"
RUN pip install "pyserial==2.7"
RUN sudo python setup.py install

#install nginx by source
RUN sudo service nginx stop
RUN sudo apt-get -y --force-yes remove nginx nginx-full
RUN sudo apt-get clean
ENV VERSION 1.12.1
WORKDIR /home/pi
RUN curl http://nginx.org/download/nginx-$VERSION.tar.gz | tar zxvf -
WORKDIR /home/pi/nginx-$VERSION
RUN pwd
RUN ./configure --sbin-path=/usr/sbin/nginx --conf-path=/etc/nginx/nginx.conf --pid-path=/var/run/nginx.pid --error-log-path=/var/log/nginx/error.log --http-log-path=/var/log/nginx/access.log --with-http_ssl_module --with-ipv6
RUN make
RUN sudo make install
RUN sudo mkdir -p /var/www
RUN sudo cp html/* /var/www
RUN sudo mkdir -p /etc/nginx/ssl

WORKDIR /home/pi
#cleanup nginx droppings
RUN sudo rm -r nginx-$VERSION

#upgrade gunicorn, hold packages from apt
RUN sudo pip install "gunicorn==19.0"
RUN sudo ln -sf /usr/local/bin/gunicorn /usr/bin/gunicorn

#hold packages so apt does not overwrite
RUN sudo echo "nginx hold" | sudo dpkg --set-selections
RUN sudo echo "gunicorn hold" | sudo dpkg --set-selections

RUN sudo pip install "httplib2==0.19"

#install webapp
WORKDIR /opt
#RUN sudo git clone http://github.com/nutechsoftware/alarmdecoder-webapp.git
COPY alarmdecoder-webapp /opt/alarmdecoder-webapp
RUN sudo chown -R pi:pi alarmdecoder-webapp
WORKDIR /opt/alarmdecoder-webapp
#RUN git fetch origin
#RUN git checkout dev
#RUN git checkout master
RUN pip install "pip==20.3.4"
RUN pip install "wheel==0.37.1"
RUN pip install "cffi==0.8.2"
RUN pip install --no-deps cryptography==2.8
RUN sudo pip install -r requirements.txt --upgrade-strategy=only-if-needed
WORKDIR /opt/alarmdecoder-webapp/contrib/opencv
RUN sudo ./opencv.sh
RUN sudo rm -r OpenCV
WORKDIR /opt/alarmdecoder-webapp
RUN python manage.py initdb
RUN sudo cp contrib/nginx/alarmdecoder /etc/nginx/sites-available/
RUN sudo ln -s /etc/nginx/sites-available/alarmdecoder /etc/nginx/sites-enabled/
RUN sudo rm /etc/nginx/sites-enabled/default
RUN sudo cp contrib/gunicorn.d/alarmdecoder /etc/gunicorn.d/
RUN sudo chown -R pi:pi /etc/ser2sock
RUN sudo usermod -a -G dialout pi
RUN sudo chgrp dialout /etc/hosts /etc/hostname 
RUN sudo chmod g+w /etc/hosts /etc/hostname 

#gunicorn systemd file
RUN sudo echo -e '[Unit]\n\
Description=gunicorn daemon\n\
After=network.target\n\
\n\
[Service]\n\
PIDFile=/run/gunicorn/pid\n\
User=pi\n\
Group=dialout\n\
WorkingDirectory=/opt/alarmdecoder-webapp\n\
ExecStart=/usr/local/bin/gunicorn --worker-class=socketio.sgunicorn.GeventSocketIOWorker --timeout=120 --env=POLICY_SERVER=0 --log-level=debug wsgi:application\n\
ExecReload=/bin/kill -s HUP $MAINPID\n\
ExecStop=/bin/kill -s TERM $MAINPID\n\
PrivateTmp=true\n\
\n\
[Install]\n\
WantedBy=multi-user.target\n'\
>> /etc/systemd/user/gunicorn.service


#nginx systemd file
RUN sudo echo -e '[Unit]\n\
Description=The NGINX HTTP and reverse proxy server\n\
After=syslog.target network.target remote-fs.target nss-lookup.target\n\
\n\
[Service]\n\
Type=forking\n\
PIDFile=/run/nginx.pid\n\
ExecStartPre=/usr/sbin/nginx -t\n\
ExecStart=/usr/sbin/nginx\n\
ExecReload=/bin/kill -s HUP $MAINPID\n\
ExecStop=/bin/kill -s QUIT $MAINPID\n\
PrivateTmp=true\n\
\n\
[Install]\n\
WantedBy=multi-user.target\n'\
>> /etc/systemd/user/nginx.service


#nginx logrotate
RUN sudo echo -e '/opt/alarmdecoder-webapp/instance/logs/*.log {\n\
  weekly\n\
  missingok\n\
  rotate 5\n\
  compress\n\
  delaycompress\n\
  notifempty\n\
  create 0640 pi pi\n\
  sharedscripts\n\
}'\
>> /etc/logrotate.d/alarmdecoder

#gunicorn logrotate
RUN sudo echo -e '/var/log/gunicorn/*.log {\n\
  weekly\n\
  missingok\n\
  rotate 5\n\
  compress\n\
  delaycompress\n\
  notifempty\n\
  create 0640 www-data www-data\n\
  sharedscripts\n\
  postrotate\n\
  [ -s /run/gunicorn/alarmdecoder.pid ] && kill -USR1 `cat /run/gunicorn/alarmdecoder.pid`\n\
  endscript\n\
}'\
>> /etc/logrotate.d/gunicorn

#fix ser2sock config
RUN sudo sed -i 's/raw_device_mode = 0/raw_device_mode = 1/g' /etc/ser2sock/ser2sock.conf

#fix permissions on webapp directory
RUN sudo chown -R pi:pi /opt/alarmdecoder-webapp

#expose ports
EXPOSE 80 443 5000 10000

USER pi

VOLUME /opt /etc/ser2sock /etc/nginx /var/log

RUN mkdir -p /var/log/supervisor
RUN sudo chmod -R 777 /var/log/supervisor

COPY supervisord.conf /etc/supervisor/conf.d/supervisord.conf
COPY gen_certs.sh /home/pi/gen_certs.sh
RUN sudo chmod +x /home/pi/gen_certs.sh

RUN sudo apt-get install -y --force-yes logrotate

COPY start_services.sh /usr/local/bin/start_services.sh
RUN sudo chmod +x /usr/local/bin/start_services.sh

#Chage start args in ser2sock to run as pi user
RUN sudo sed -i 's/EXTRA_START_ARGS=/#EXTRA_START_ARGS=/g' /etc/init.d/ser2sock
RUN sudo sed -i 's/##EXTRA_START_ARGS=/EXTRA_START_ARGS=/g' /etc/init.d/ser2sock
RUN sudo sed -i 's/#RUN_AS=.*/RUN_AS=pi:pi/g' /etc/init.d/ser2sock

# Define default command
CMD ["sudo", "/usr/bin/supervisord", "-c", "/etc/supervisor/conf.d/supervisord.conf"]
