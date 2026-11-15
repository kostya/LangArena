// harness.c: time C's Json::ParseMapping body on coords.json (dump.c writes
// it: the text C's prepare makes for 25000 coords), best and median of N
// iterations. Built from c/ after `make prod`, e.g.:
//   gcc -O2 -Ic/src -Ic/deps/yyjson/src dump.c c/target/prod/src/{helper,benchmark}.o \
//       c/target/deps/prod/yyjson.o -lm -o dump && ./dump > coords.json
//   gcc -O2 -w [-DCOPY] [-DZFLOW [-DNOLIST]] [-DCURSOR] -Ic/deps/yyjson/src harness.c yyjson.o -o h
//   taskset -c 2 ./h coords.json 300
// -DZFLOW: the port's shape before step 14 (a pointer array, then three
// non-inlined lookups per point by a key that is not a literal, a growing
// list, a second sum loop); -DNOLIST drops the list; -DCURSOR: one pass,
// lookups by a cursor.
// -DCOPY: copy the text into a fresh malloc buffer first (what the port's zane_copy does).
// -DREAD=sym: call a differently-named yyjson_read_opts (e.g. zanec's compiled one).
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>
#include "yyjson.h"
#ifdef READ
#define STR_(x) #x
#define STR(x) STR_(x)
yyjson_doc *zread(char *, size_t, yyjson_read_flag, const yyjson_alc *, yyjson_read_err *) __asm__(STR(READ));
#define RD(t,n) zread(t,n,0,NULL,NULL)
#else
#define RD(t,n) yyjson_read_opts(t,n,0,NULL,NULL)
#endif
static double now(void){struct timespec t;clock_gettime(CLOCK_MONOTONIC,&t);return t.tv_sec+t.tv_nsec*1e-9;}
__attribute__((noinline)) static double get(yyjson_val**vals,size_t cnt,long index,long axis){static const char*keys[]={"x","y","z"};
  if(index<1||(size_t)index>cnt||axis<0||axis>2) abort(); return yyjson_get_num(yyjson_obj_get(vals[index-1],keys[axis]));}
static yyjson_val*cur_v,*cur_arr; static size_t cur_i;
__attribute__((noinline)) static double cget(size_t cnt,long index,long axis){static const char*keys[]={"x","y","z"};
  if(index<1||(size_t)index>cnt||axis<0||axis>2) abort();
  if((size_t)index!=cur_i){ if((size_t)index==cur_i+1&&cur_v) cur_v=unsafe_yyjson_get_next(cur_v); else cur_v=yyjson_arr_get(cur_arr,index-1); cur_i=index; }
  return yyjson_get_num(yyjson_obj_get(cur_v,keys[axis]));}
static int cmp(const void*a,const void*b){double x=*(double*)a,y=*(double*)b;return x<y?-1:x>y;}
int main(int argc,char**argv){
  FILE*f=fopen(argv[1],"rb"); fseek(f,0,2); long n=ftell(f); rewind(f);
  char*text=malloc(n+1); fread(text,1,n,f); text[n]=0;
  int iters=argc>2?atoi(argv[2]):300; double *ts=malloc(iters*sizeof(double)); double acc=0;
  for(int it=0;it<iters;it++){
    double t0=now();
    char*src=text;
#ifdef COPY
    src=malloc(n); memcpy(src,text,n);
#endif
    yyjson_doc*doc=RD(src,n);
    yyjson_val*c=yyjson_obj_get(yyjson_doc_get_root(doc),"coordinates");
    double x=0,y=0,z=0; size_t i,m; yyjson_val*v;
#ifdef CURSOR
    size_t cnt=yyjson_arr_size(c); cur_v=NULL; cur_i=0; cur_arr=c;
    for(size_t k=1;k<=cnt;k++){ x+=cget(cnt,k,0); y+=cget(cnt,k,1); z+=cget(cnt,k,2); }
#elif defined(ZFLOW)
    size_t cnt=yyjson_arr_size(c); yyjson_val**vals=malloc(cnt*sizeof*vals);
    yyjson_arr_foreach(c,i,m,v) vals[i]=v;
    typedef struct{double x,y,z;}P; size_t cap=0,len=0; P*pts=NULL;
    for(size_t k=1;k<=cnt;k++){ double a=get(vals,cnt,k,0),b=get(vals,cnt,k,1),d=get(vals,cnt,k,2);
#ifdef NOLIST
      x+=a;y+=b;z+=d; continue;
#endif
      if(len==cap){cap=cap?cap*2:4;pts=realloc(pts,cap*sizeof(P));} pts[len++]=(P){a,b,d}; }
    for(size_t k=0;k<len;k++){x+=pts[k].x;y+=pts[k].y;z+=pts[k].z;}
    free(pts); free(vals);
#else
    yyjson_arr_foreach(c,i,m,v){ x+=yyjson_get_num(yyjson_obj_get(v,"x")); y+=yyjson_get_num(yyjson_obj_get(v,"y")); z+=yyjson_get_num(yyjson_obj_get(v,"z")); }
#endif
    yyjson_doc_free(doc);
#ifdef COPY
    free(src);
#endif
    ts[it]=now()-t0; acc+=x+y+z;
  }
  qsort(ts,iters,sizeof(double),cmp);
  printf("best %.3f ms  median %.3f ms  (%g)\n",ts[0]*1e3,ts[iters/2]*1e3,acc);
}
