#include <stdio.h>
#include <sys/timerfd.h>
#include <stdlib.h>
#include <errno.h>
#include <string.h>
#include <time.h>
#include <sys/epoll.h>
#include <unistd.h>

int main(int argc, char** argv) {

	if (argc != 2) {
		fprintf(stderr, "Usage: ./rtcwaker NEXTTIME\n");
		return -1;
	}

	int timer;
	struct itimerspec its;
	struct itimerspec new_its;
	timer = timerfd_create(CLOCK_REALTIME_ALARM, TFD_CLOEXEC);
	printf("Timerfd_create returned %d\n", timer);
	if (timer == -1) {
		printf("Timerfd_create returned error %s \n", strerror(errno));
		return -1;
	}

	int res;
	res = timerfd_gettime(timer, &its);

	if (res == -1) {
		printf("timerfd_gettime returned error %s \n", strerror(errno));
		return -1;
	}

	printf("Current clock values:\ntv_sec:  %ld %ld\ntv_nsec: %ld %ld\n", its.it_interval.tv_sec, its.it_interval.tv_nsec, its.it_value.tv_sec, its.it_value.tv_nsec); 

	long int newtime = atol(argv[1]);
	new_its.it_value.tv_sec = newtime;
	new_its.it_value.tv_nsec = 0;
	new_its.it_interval.tv_sec = 0;
	new_its.it_interval.tv_nsec = 0;

	struct epoll_event epollEvent;
	struct epoll_event newEvents;
	int epoller;

	epoller = epoll_create1(0);
	epollEvent.events = EPOLLIN;
	epollEvent.data.fd = timer;
	epoll_ctl(epoller, EPOLL_CTL_ADD, timer, &epollEvent);
	
	res = timerfd_settime(timer, TFD_TIMER_ABSTIME, &new_its, &its);

	if (res == -1) {
		printf("timerfd_settime returned error %s \n", strerror(errno));
		return -1;
	}

	res = timerfd_gettime(timer, &its);

	if (res == -1) {
		printf("timerfd_gettime returned error %s \n", strerror(errno));
		return -1;
	}

	printf("Current clock values:\ntv_sec:  %ld %ld\ntv_nsec: %ld %ld\n", its.it_interval.tv_sec, its.it_interval.tv_nsec, its.it_value.tv_sec, its.it_value.tv_nsec); 

	printf("Entering epoll event loop\n");

	while (1) {
		int numEvents = epoll_wait(epoller, &newEvents, 1, -1);
		if (numEvents > 0) {
			printf("Picked up an epoll event\n");
			break;

		}

	} 
	printf("Exiting.\n");
	close(epoller);
	close(timer);

	return 0;
}
