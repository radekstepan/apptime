components:
	cd src/dashboard/app ; ../../../node_modules/.bin/component install

dashboard: components
	coffee src/dashboard/build.coffee

test:
	./node_modules/.bin/mocha --compilers coffee:coffee-script --reporter spec --ui exports --bail

.PHONY: test