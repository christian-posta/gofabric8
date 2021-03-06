#
# Copyright (C) 2015 Red Hat, Inc.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#         http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

SHELL := /bin/bash
NAME := gofabric8
VERSION := $(shell cat version/VERSION)
OPENSHIFT_TAG := $(shell cat .openshift-version)
ROOT_PACKAGE := $(shell go list .)
GO_VERSION := $(shell go version)
PACKAGE_DIRS := $(shell go list -f '{{.Dir}}' ./...)
FORMATTED := $(shell go fmt ./...)

REV        := $(shell git rev-parse --short HEAD 2> /dev/null  || echo 'unknown')
BRANCH     := $(shell git rev-parse --abbrev-ref HEAD 2> /dev/null  || echo 'unknown')
BUILD_DATE := $(shell date +%Y%m%d-%H:%M:%S)
BUILDFLAGS := -ldflags \
  " -X $(ROOT_PACKAGE)/version.Version '$(VERSION)'\
		-X $(ROOT_PACKAGE)/version.Revision '$(REV)'\
		-X $(ROOT_PACKAGE)/version.Branch '$(BRANCH)'\
		-X $(ROOT_PACKAGE)/version.BuildDate '$(BUILD_DATE)'\
		-X $(ROOT_PACKAGE)/version.GoVersion '$(GO_VERSION)'"

build: *.go */*.go fmt
	CGO_ENABLED=0 godep go build $(BUILDFLAGS) -o build/$(NAME) -a $(NAME).go

install: *.go */*.go
	GOBIN=${GOPATH}/bin godep go install $(BUILDFLAGS) -a $(NAME).go

update-deps-old:
	echo $(OPENSHIFT_TAG) > .openshift-version && \
		pushd $(GOPATH)/src/github.com/openshift/origin && \
		git fetch origin && \
		git checkout -B $(OPENSHIFT_TAG) refs/tags/$(OPENSHIFT_TAG) && \
		godep restore && \
		popd && \
		godep save ./... && \
		godep update ...

fmt:
	@([[ ! -z "$(FORMATTED)" ]] && printf "Fixed unformatted files:\n$(FORMATTED)") || true

update-deps:
	echo $(OPENSHIFT_TAG) > .openshift-version && \
		pushd $(GOPATH)/src/github.com/openshift/origin && \
		git fetch origin && \
		git checkout -B $(OPENSHIFT_TAG) refs/tags/$(OPENSHIFT_TAG) && \
		godep restore && \
		popd && \
		godep save cmd/generate/generate.go && \
		godep update ... && \
		rm -rf Godeps/_workspace/src/k8s.io/kubernetes && \
		cp -r $(GOPATH)/src/github.com/openshift/origin/Godeps/_workspace/src/k8s.io/kubernetes Godeps/_workspace/src/k8s.io/kubernetes

release:
	rm -rf build release && mkdir build release
	for os in linux darwin ; do \
		CGO_ENABLED=0 GOOS=$$os ARCH=amd64 godep go build $(BUILDFLAGS) -o build/$(NAME)-$$os-amd64 -a $(NAME).go ; \
		tar --transform 's|^build/||' --transform 's|-.*||' -czvf release/$(NAME)-$(VERSION)-$$os-amd64.tar.gz build/$(NAME)-$$os-amd64 README.md LICENSE ; \
	done
	CGO_ENABLED=0 GOOS=windows ARCH=amd64 godep go build $(BUILDFLAGS) -o build/$(NAME)-$(VERSION)-windows-amd64.exe -a $(NAME).go
	zip --junk-paths release/$(NAME)-$(VERSION)-windows-amd64.zip build/$(NAME)-$(VERSION)-windows-amd64.exe README.md LICENSE
	go get -u github.com/progrium/gh-release
	gh-release create fabric8io/$(NAME) $(VERSION) $(BRANCH) $(VERSION)

clean:
		rm -rf build release

.PHONY: release clean
