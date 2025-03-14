OBJS = clm.o cmus.o headers.o
HDRS = $(wildcard ../headers/*.h)

libclm.so: $(OBJS) $(HDRS)
	 $(CC) -shared -o $@ $(OBJS)

%.o: %.c
	$(CC) -fPIC -o $@ -c $< $(CFLAGS)
