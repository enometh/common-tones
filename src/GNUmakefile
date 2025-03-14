OBJS = clm.o cmus.o headers.o sound.o xen.o audio.o io.o
HDRS = $(wildcard ../headers/*.h)

libclm.so: $(OBJS) $(HDRS)
	 $(CC) -shared -o $@ $(OBJS) -lm -lasound -ldl

%.o: %.c
	$(CC) -fPIC -o $@ -c $< $(CFLAGS) -I../headers
