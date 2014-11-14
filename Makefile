PROJECT := $(subst @,,$(notdir $(shell pwd)))
NAME = $(PROJECT)-build
RUN = docker run --rm --env CI=jenkins

.PHONY : test

all : pull build test

pull :
	docker pull quay.io/3scale/openresty:1.7.4.1

test : clean
	$(RUN) --name $(NAME) $(PROJECT)
bash :
	$(RUN) -t -i $(PROJECT) bash
build :
	docker build -t $(PROJECT) .

clean : 
	- docker rm --force --volumes $(NAME) 2> /dev/null
	rm -rf release

release:
	rake release -- -y

lua/%.lua:

doc: lua/%.lua
	ldoc .
