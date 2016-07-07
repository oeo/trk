export NODE_ENV = test
export TAKY_DEV = 1

main:
	iced --runtime inline --output build -c src
	git add build/* -f

