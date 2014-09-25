REPO=brainslug

OPENRESTY_VERSION=1.5.12.1
TAG=latest
IMAGE=$(REPO):$(TAG)
REGISTRY=quay.io/3scale/brainslug

.PHONY: clean quay image build run rebuild update push preview production

# image is default task
image: release build

preview: TAG = preview
preview: quay

production: TAG = production
production: quay

quay: clean update image push

release:
	rake release -- -y

clean:
	rm -rf release

update:
	docker pull quay.io/3scale/openresty:$(OPENRESTY_VERSION)

push:
	docker tag $(IMAGE) $(REGISTRY):$(TAG)
	docker push $(REGISTRY):$(TAG)

build: release
	docker build -t $(IMAGE) --rm .

rebuild: clean build

run:
	docker run -t -i --rm -p 7071:7071 -p 10002:10002 --name brainslug $(IMAGE) $(CMD)

start:
	docker run -d -P $(IMAGE) $(CMD)

bash: CMD = bash
bash: run
