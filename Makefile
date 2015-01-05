PROJECT := $(subst @,,$(notdir $(shell pwd)))_monitor
NAME = $(PROJECT)-build
RUN = docker run --rm --env CI=jenkins

.PHONY : test

all : pull build test

pull :
	docker pull quay.io/3scale/openresty:1.7.4.1

test : clean
	$(RUN) --name $(NAME) $(PROJECT)
bash : build
	$(RUN) -t -i -v $(shell pwd):/opt/slug $(PROJECT) script/docker.sh
build :
	docker build -t $(PROJECT) .

clean :
	- docker rm --force --volumes $(NAME) 2> /dev/null
	rm -rf release

release:
	rake release -- -y

vagrant:
	vagrant up
	vagrant ssh
lua/%.lua:

doc: lua/%.lua
	ldoc .
