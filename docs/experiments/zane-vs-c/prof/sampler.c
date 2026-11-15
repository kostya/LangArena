// LD_PRELOAD sampler: SIGPROF every SAMPLER_US (default 50) microseconds of wall time, records the PC; at exit
// writes "pc count" lines to $SAMPLER_OUT. Resolve with symbolize.py.
#define _GNU_SOURCE
#include <signal.h>
#include <stdio.h>
#include <stdlib.h>
#include <sys/time.h>
#include <time.h>
#include <ucontext.h>
#include <stdint.h>
#define N (1<<22)
static uintptr_t pcs[N]; static volatile long n;
static void h(int s, siginfo_t *i, void *c) { (void)s;(void)i; ucontext_t *u=c; long k=n; if(k<N){pcs[k]=u->uc_mcontext.gregs[REG_RIP]; n=k+1;} }
static void done(void) {
  const char *o=getenv("SAMPLER_OUT"); if(!o) return; FILE *f=fopen(o,"w");
  FILE *m=fopen("/proc/self/maps","r"); char line[512]; while(fgets(line,sizeof line,m)) fprintf(f,"#%s",line); fclose(m);
  for(long k=0;k<n;k++) fprintf(f,"%lx\n",pcs[k]); fclose(f);
}
__attribute__((constructor)) static void start(void) {
  if(!getenv("SAMPLER_OUT")) return;
  struct sigaction a={0}; a.sa_sigaction=h; a.sa_flags=SA_SIGINFO|SA_RESTART; sigaction(SIGPROF,&a,0);
  /* A POSIX timer on CLOCK_MONOTONIC runs on high-resolution timers, unlike
     ITIMER_PROF, which fires on the kernel's tick. SAMPLER_US sets the
     period (default 50). Wall time: run the program pinned and alone. */
  long us = getenv("SAMPLER_US") ? atol(getenv("SAMPLER_US")) : 50;
  if (us <= 0) { fprintf(stderr, "sampler: SAMPLER_US must be positive\n"); return; }
  struct sigevent ev = {0}; ev.sigev_notify = SIGEV_SIGNAL; ev.sigev_signo = SIGPROF;
  timer_t id;
  struct timespec p = {us / 1000000, (us % 1000000) * 1000};
  struct itimerspec t = {p, p};
  if (timer_create(CLOCK_MONOTONIC, &ev, &id) || timer_settime(id, 0, &t, 0)) {
    perror("sampler: timer"); return;
  }
  atexit(done);
}
