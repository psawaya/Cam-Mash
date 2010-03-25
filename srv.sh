#! /bin/bash
#exec sudo /usr/sbin/thttpd -C thttpd.conf -D 

cp flash/stratus_test.swf static/stratus_test.swf #Only needed when using the cheesy web.py server
python cam_mash_app.py #Start said cheesy server.