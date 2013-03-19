# If you're using anything but the default, change this to
# point to your installation destination directory.
RD=../rump

all: webbrowser

webbrowser: webbrowser.c
	cc -g $< -o $@ -I${RD}/include -L${RD}/lib -Wl,-R${RD}/lib -Wl,--no-as-needed -lrumpnet_virtif -lrumpnet_config -lrumpdev_bpf -lrumpnet_netinet -lrumpnet_net -lrumpnet -lrump -lrumpuser -lpthread -ldl

clean:
	rm -f webbrowser *core
