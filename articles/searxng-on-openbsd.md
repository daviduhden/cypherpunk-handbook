# **Self-Hosted SearXNG instance securely over Tor onion service on OpenBSD**
Written by FlyWithMe (a SimpleX Chat user) — Updated Jun 8, 2026

This guide is dedicated to teaching OpenBSD users how to securely self-hosting a SearXNG instante through .onion address (Hidden Service). We will do everything separating privileges and leaving few permissions as possible.

This guide is based on this outdated ass guide and it's a copy of it but with relevant adaptations:
https://www.tumfatig.net/2023/self-hosted-searxng-instance-on-openbsd/

The original documentation for Linux is available here:
https://docs.searxng.org/admin/installation-searxng.html

I’m doing it on OpenBSD 7.9.

## Preliminary steps

### Set up a dedicated user:

```
$ nano /etc/login.conf.d/searxng

searxng:\
        :openfiles=4096:\
        :tc=daemon:
```

```
$ useradd -g =uid -c "SearXNG metasearch engine" \
  -L searxng -s /sbin/nologin -d /home/searxng   \
  -m -r 2000..2500 _searxng
```

### Raise some system limits:

```
$ nano /etc/sysctl.conf

kern.seminfo.semmni=1024
kern.seminfo.semmns=4096
kern.seminfo.semmnu=1024
kern.seminfo.semmsl=1024
kern.seminfo.semopm=1024
```

```
$ egrep -v "^#" /etc/sysctl.conf | xargs sysctl
```

## Installation

### Install some minimum system dependencies:

```
$ pkg_add git python libxslt
```

### Install SearXNG sources and prepare the environment:

```
$ doas -u _searxng /bin/ksh -c 'cd /home/searxng && exec /bin/ksh -l'
```

```
$ echo "umask 077" >> ~/.profile
$ git clone https://github.com/searxng/searxng ~/src
```

```
$ python3 -m venv ~/pyenv
$ echo ". ~/pyenv/bin/activate" >> ~/.profile
$ ^D
```

### Install the required Python modules:

If you want, use `torsocks` with every git clone/pull or pip command to install over Tor.

```
$ doas -u _searxng /bin/ksh -c 'cd /home/searxng && exec /bin/ksh -l'
```

```
$ command -v python && python --version

/home/searxng/pyenv/bin/python
Python 3.13.13
```

```
$ pip install -U pip setuptools wheel pyyaml msgspec typing-extensions pybind11
```

If you want SOCKS support:

```
$ pip install "httpx[socks]" httpx-socks pysocks
```

```
$ cd ~/src
$ pip install --use-pep517 --no-build-isolation -e .

(...)
Successfully built searxng
Installing collected packages: pytz, whitenoise, valkey, sniffio, six, shellingham, python-socks, pygments, mdurl, markupsafe, lxml, itsdangerous, isodate, idna, hyperframe, hpack, h11, click, certifi, blinker, babel, async-timeout, annotated-doc, werkzeug, python-dateutil, markdown-it-py, jinja2, httpcore, h2, anyio, rich, httpx, flask, typer, httpx-socks, flask-babel, searxng
(...)
Successfully installed annotated-doc-0.0.4 anyio-4.13.0 async-timeout-5.0.1 babel-2.18.0 blinker-1.9.0 certifi-2026.5.20 click-8.4.1 flask-3.1.3 flask-babel-4.0.0 h11-0.16.0 h2-4.3.0 hpack-4.1.0 httpcore-1.0.9 httpx-0.28.1 httpx-socks-0.10.0 hyperframe-6.1.0 idna-3.18 isodate-0.7.2 itsdangerous-2.2.0 jinja2-3.1.6 lxml-6.1.1 markdown-it-py-4.2.0 markupsafe-3.0.3 mdurl-0.1.2 pygments-2.20.0 python-dateutil-2.9.0.post0 python-socks-2.8.1 pytz-2026.2 rich-15.0.0 searxng-2026.6.7+9d49a9f34 shellingham-1.5.4 six-1.17.0 sniffio-1.3.1 typer-0.26.7 valkey-6.1.1 werkzeug-3.1.8 whitenoise-6.12.0
```

# Configuration

I’ll be using a configuration file that shall not be modified during source updates. It is then stored in $HOME.

```
$ doas -u _searxng /bin/ksh -c 'cd /home/searxng && exec /bin/ksh -l'
```

```
$ sed -i -e "s/ultrasecretkey/$(openssl rand -hex 16)/g" ~/src/searx/settings.yml > /home/searxng/settings.yml
```

```
$ echo 'export SEARXNG_SETTINGS_PATH=/home/searxng/settings.yml' >> ~/.profile
```

### Tor configuration

For use every command with Tor only by default, put this in your .profile. After that you don't need to use torsocks anymore for the searxng user (and it will fail anyway):

```
export ALL_PROXY='socks5h://127.0.0.1:9050'
export HTTP_PROXY="$ALL_PROXY" HTTPS_PROXY="$ALL_PROXY"
```

Also configure this in ~/settings.yml, in output section:

```
output:
  request_timeout: 10.0
  max_request_timeout: 30.0
  pool_connections: 200
  retries: 2
  extra_proxy_timeout: 30
  using_tor_proxy: true
  proxies:
    all://:
      - socks5h://127.0.0.1:9050
```

```
$ . ~/.profile
```

```
$ nano ~/settings.yml
```

Check that everything works as expected (use with torsocks if you haven't configured .profile as I said earlier):

```
$ python ~/src/searx/webapp.py

2026-06-08 03:40:07,287 ERROR:searx: Error while getting the version: fatal: not a git repository (or any parent up to mount point /)
Stopping at filesystem boundary (GIT_DISCOVERY_ACROSS_FILESYSTEM not set).
(...)
2026-06-08 03:40:07,338 ERROR:searx: Error while getting the git URL & branch: fatal: not a git repository (or any parent up to mount point /)
Stopping at filesystem boundary (GIT_DISCOVERY_ACROSS_FILESYSTEM not set).
(...)
 * Serving Flask app 'webapp'
 * Debug mode: off
^C
```

To use SearXNG through an .onion address, do this:

```
$ nano /etc/tor/torrc:

HiddenServiceDir /var/tor/searx_hidden_service/
HiddenServiceVersion 3
HiddenServicePort 80 127.0.0.1:8888
```

Then:
```
cat /var/tor/searx_hidden_service/hostname

output: example.onion
```

Put the .onion address that appears in Tor Browser.

# Daemonize using Gunicorn

Keep It Simple, Stupid!

```
$ doas -u _searxng /bin/ksh -c 'cd /home/searxng && exec /bin/ksh -l'

$ pip install gunicorn
(...)
Successfully installed gunicorn-26.0.0
```

```
$ nano searxng.conf.py

# Server Socket ========================================================
bind = "127.0.0.1:8888"
backlog = 128

# Worker Processes =====================================================
workers = 1
threads = 2
keepalive = 5
worker_class = "gthread"
threads = 4
timeout = 120
graceful_timeout = 30

# Process Naming =======================================================
proc_name = "searxng"

# Config File ==========================================================
wsgi_app = "searx.webapp:application"

# Server Mechanics =====================================================
chdir = "/home/searxng/src"

# Logging ==============================================================
accesslog = '-'
errorlog = '-'

syslog = True
syslog_addr = 'unix:///dev/log#dgram'
syslog_facility = 'daemon'
syslog_prefix = 'searxng'
```

There is no startup file for Gunicorn. So let’s create one:

```
$ nano /etc/rc.d/searxng

#!/bin/ksh
#
# PROVIDE: searxng
# REQUIRE: NETWORKING

name="searxng"
rcvar="${name}_enable"

: ${searxng_enable:="NO"}
: ${searxng_user:="_searxng"}
: ${searxng_home:="/home/searxng"}
: ${searxng_pyenv:="${searxng_home}/pyenv"}
: ${searxng_bind:="127.0.0.1:8888"}
: ${searxng_pid:="${searxng_home}/searxng.pid"}
: ${searxng_log:="${searxng_home}/searxng.log"}
: ${searxng_settings:="${searxng_home}/settings.yml"}
: ${searxng_conf:="${searxng_home}/searxng.conf.py"}

daemon="${searxng_pyenv}/bin/gunicorn"
daemon_flags="-b ${searxng_bind} -c ${searxng_conf} searx.webapp:application --pid ${searxng_pid}"
daemon_user="${searxng_user}"

. /etc/rc.d/rc.subr

rc_bg=NO
rc_reload=NO

rc_start() {
    touch "${searxng_log}"
    chown "${searxng_user}" "${searxng_log}" 2>/dev/null || :
    rc_exec "env PYTHONPATH='${searxng_home}/src' SEARXNG_SETTINGS_PATH='${searxng_settings}' ${daemon} ${daemon_flags} >> '${searxng_log}' 2>&1 &"
}

rc_check() {
    if [ -f "${searxng_pid}" ]; then
        kill -0 "$(cat ${searxng_pid})" >/dev/null 2>&1 && return 0
    fi
    pgrep -u "${searxng_user}" -f "${daemon}" >/dev/null 2>&1
}

rc_stop() {
    if [ -f "${searxng_pid}" ]; then
        kill -TERM "$(cat ${searxng_pid})" 2>/dev/null || :
        # wait up to 30s for process to exit
        for i in 0 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15; do
            sleep 2
            kill -0 "$(cat ${searxng_pid})" >/dev/null 2>&1 || break
        done
        # force kill if still alive
        kill -KILL "$(cat ${searxng_pid})" 2>/dev/null || :
        rm -f "${searxng_pid}" 2>/dev/null || :
    else
        pkill -u "${searxng_user}" -f "${daemon}" || true
    fi
}

rc_cmd "$1"

```

```
$ chmod 0555 /etc/rc.d/searxng
$ rcctl enable searxng
$ rcctl start searxng
searxng(ok)
```

# Updating SearXNG

SearXNG follows a rolling release model. This means that the latest commit on the master branch is to be considered the latest stable version. As there are a few steps to repeat, I just wrote a script to update.

```
$ doas -u _searxng nano ~_searxng/update.sh

cd ~/src
git fetch origin "HEAD"
git reset --hard "origin/HEAD"
pip install -U pip
pip install -U setuptools
pip install -U wheel
pip install -U pyyaml
pip install -U msgspec
pip install -U typing-extensions
pip install -U pybind11
pip install -U pysocks
#  Do not uncomment this line if this error appears when trying to update httpx-socks:
#  searxng 202x.x.x+xxxxxxxxx requires httpx-socks[asyncio]==0.10.0",
#  but you have httpx-socks x.xx.x which is incompatible.
#pip install -U httpx-socks

#  Use this instead until searxng update its dependence version:
pip install --force-reinstall "httpx-socks[asyncio]==0.10.0"

pip install -U "httpx[socks]"
pip install --use-pep517 --no-build-isolation -U -e .
```

```
$ chmod 0750 ~_searxng/update.sh
```

To upgrade you just need to do:

```
$ doas -u _searxng ksh -l ~_searxng/update
$ doas -u _searxng ksh -l ~_searxng/update_img
$ diff -U2 ./src/searx/settings.yml settings.yml

$ rcctl restart searxng
searxng(ok)
searxng(ok)
```

# The End:

With this steps you don't need to configure httpd, acme-client, relayd and expose through a reverse-proxy to get an SSL certificate and do the HTTP to HTTPS redirection like the official guide says, because onion services already provide end‑to‑end integrity/encryption. This way you get less attack surface, more stability and better maintenance for long term. The official guide also doesn't teach you how to configure httpd and acme-client so whatever.

But if you want to securely host SearXNG through the clearnet, then you will certainly need to configure it to have HTTPS.


El Psy Kongroo!
