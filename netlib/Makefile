CFLAGS = -ggdb
LDFLAGS = -g

LIB_OBJ = Socket.o ServerSocket.o

all : netlib.a

netlib.a: $(LIB_OBJ)
	ar rcs $@ $(LIB_OBJ)

clean:
	rm -f *.o netlib.a

