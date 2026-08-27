CFLAGS += -g3 -Og
OBJS = clm.o cmus.o headers.o sound.o xen.o audio.o io.o
HDRS = $(wildcard ../headers/*.h)

all: libclm.so sndplay

libclm.so: $(OBJS) $(HDRS)
	 $(CC) -shared -o $@ $(OBJS) -lm -lasound -ldl

%.o: %.c
	$(CC) -fPIC -o $@ -c $< $(CFLAGS) -I../headers

sndplay: $(OBJS) sndplay.o
	$(CC) -o $@ $^ -lm -lasound

libclm.a: $(OBJS)
	ar cr $@ $^

clean:
	rm -fv $(OBJS) libclm.so libclm.a