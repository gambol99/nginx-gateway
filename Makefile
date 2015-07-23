#
#   Author: Rohith
#   Date: 2015-06-23 15:26:48 +0100 (Tue, 23 Jun 2015)
#
#  vim:ts=2:sw=2:et
#

AUTHOR=gambol99
NAME=nginx-gateway

.PHONY: build

default: build

build:
	sudo /usr/bin/docker build -t ${AUTHOR}/${NAME} .

test:
	bin/nginx_config -f examples/config.json -D -t config/nginx/nginx.erb
