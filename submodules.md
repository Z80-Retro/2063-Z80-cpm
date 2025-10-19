## Adding a submodule

	git submodule add https://github.com/Z80-Retro/xmodem80.git filesystem/utils/xmodem80
	git add .
	git commit
	git push


## Pulling a newly added submodule into an existing clone

	git pull
	git submodule init

## Checking status

	git submodule status
