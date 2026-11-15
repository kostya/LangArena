#include "json.c"
int main(void){ char *t=generate_json_for_parsing(25000); fputs(t,stdout); return 0; }
