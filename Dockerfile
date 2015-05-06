FROM debian:jessie

MAINTAINER Addis Dittebrandt <addis.dittebrandt@gmail.com>

WORKDIR /

RUN apt-get update

RUN apt-get -y install \
    sudo \
    supervisor \
    lighttpd \
    php5-cli \
    php5-cgi \
    php5 \
    php5-mysql \
    php5-curl \
    php5-json \
    php5-gd \
    php-apc \
    npm \
    nodejs-legacy \
    openssh-server \
    git \
    mercurial \
    subversion \
    python-pygments

RUN apt-get clean

RUN useradd -u 12633 -d / phd
RUN useradd -u 12634 -d / vcs

ENV PHABRICATOR_DIR /opt/phabricator
RUN mkdir $PHABRICATOR_DIR
WORKDIR $PHABRICATOR_DIR

ADD VAR_PHABRICATOR_DIR/phabricator.sh $PHABRICATOR_DIR/
ADD VAR_PHABRICATOR_DIR/setup.sh $PHABRICATOR_DIR/

RUN git clone https://github.com/phacility/libphutil.git
RUN git clone https://github.com/phacility/arcanist.git
RUN git clone https://github.com/phacility/phabricator.git

WORKDIR $PHABRICATOR_DIR/phabricator/support/aphlict/server/

RUN npm install ws

WORKDIR $PHABRICATOR_DIR
RUN chown -R phd .

RUN mkdir -p /var/repo
RUN chown -R phd /var/repo

RUN mkdir -p /var/storage
RUN chown -R www-data /var/storage

ENV SUPERVISORD_DIR /opt/supervisord
RUN mkdir $SUPERVISORD_DIR
WORKDIR $SUPERVISORD_DIR

ADD VAR_SUPERVISORD_DIR/supervisord.conf $SUPERVISORD_DIR/

ENV START_DIR /opt/start
RUN mkdir $START_DIR
WORKDIR $START_DIR

ADD VAR_START_DIR/start.sh $START_DIR/

WORKDIR /

RUN mkdir /var/run/lighttpd
RUN chown www-data:www-data /var/run/lighttpd
RUN chmod 0750 /var/run/lighttpd

ADD etc_lighttpd_conf-available/20-rewrite.conf     /etc/lighttpd/conf-available/
ADD etc_lighttpd_conf-available/30-phabricator.conf /etc/lighttpd/conf-available/

RUN lighttpd-enable-mod fastcgi
RUN lighttpd-enable-mod fastcgi-php
RUN lighttpd-enable-mod rewrite
RUN lighttpd-enable-mod phabricator

RUN sed -i "s/disable_functions/;disable_functions/g" /etc/php5/cgi/php.ini
RUN sed -i "s/post_max_size =.*/post_max_size = 32M/g" /etc/php5/cgi/php.ini
RUN sed -i "s/^\(;\?\)opcache\.validate_timestamps.*/opcache.validate_timestamps=0/g" /etc/php5/cgi/php.ini

RUN mkdir /var/run/sshd

ADD etc_sudoers.d/30-phabricator /etc/sudoers.d/

RUN sed -i "s/vcs\:\(\!\|\!\!\)/vcs\:NP/g" /etc/shadow

RUN mkdir /usr/libexec
RUN cp $PHABRICATOR_DIR/phabricator/resources/sshd/phabricator-ssh-hook.sh /usr/libexec/
RUN chown root  /usr/libexec/phabricator-ssh-hook.sh
RUN chmod 755   /usr/libexec/phabricator-ssh-hook.sh

RUN sed -i "s/^VCSUSER.*/VCSUSER=\"vcs\"/g" /usr/libexec/phabricator-ssh-hook.sh
RUN sed -i "s|^ROOT.*|ROOT=\"$PHABRICATOR_DIR/phabricator\"|g" /usr/libexec/phabricator-ssh-hook.sh

RUN cp $PHABRICATOR_DIR/phabricator/resources/sshd/sshd_config.phabricator.example /etc/ssh/sshd_config.phabricator

RUN sed -i "s|^AuthorizedKeysCommandUser\s.*|AuthorizedKeysCommandUser vcs|g" /etc/ssh/sshd_config.phabricator
RUN sed -i "s|^AllowUsers\s.*|AllowUsers vcs|g" /etc/ssh/sshd_config.phabricator

EXPOSE 22
EXPOSE 80
EXPOSE 22280

VOLUME /var/repo /var/storage

CMD $START_DIR/start.sh
