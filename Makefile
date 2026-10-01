.PHONY: build install test clean

build:
	./scripts/build-app.sh

install: build
	./scripts/install-app.sh

test:
	swift test

clean:
	swift package clean
	rm -rf dist
