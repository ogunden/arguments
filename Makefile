NAME = arguments.js

SRC = ids.opa main.opa

all: $(NAME)

$(NAME): $(SRC)
	opa $(SRC) -o $(NAME)

clean:
	rm -f error.log access.log package.json $(NAME)
