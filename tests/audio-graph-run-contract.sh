#!/usr/bin/env bash
# Exercise actual shared graph START/STOP with a synthetic command transport.
set -euo pipefail
kernel=${1:?Pass prepared kernel tree}
work=$(mktemp -d)
trap 'rm -r -- "$work"' EXIT
cat > "$work/check.c" <<'C'
#include <assert.h>
#include <errno.h>
#include <limits.h>
#include <pthread.h>
#include <stdbool.h>
#include <stdio.h>
struct mutex { pthread_mutex_t native; };
static void mutex_lock(struct mutex *m) { assert(!pthread_mutex_lock(&m->native)); }
static void mutex_unlock(struct mutex *m) { assert(!pthread_mutex_unlock(&m->native)); }
static struct mutex *acquire_mutex(struct mutex *m) { mutex_lock(m); return m; }
static void cleanup_mutex(struct mutex **m) { mutex_unlock(*m); }
#define guard(name) struct mutex *guard_instance __attribute__((cleanup(cleanup_##name)))=acquire_##name
#define EXPORT_SYMBOL_GPL(name)
#define APM_CMD_GRAPH_START 1
#define APM_CMD_GRAPH_STOP 2
struct q6apm { struct mutex cmd_lock; bool removing; };
struct audioreach_graph { struct q6apm *apm; int start_count; };
struct q6apm_graph { struct audioreach_graph *ar_graph; };
static int command_error, starts, stops;
static int audioreach_graph_mgmt_cmd(struct audioreach_graph *g, unsigned opcode)
{
 (void)g;
 if (opcode==APM_CMD_GRAPH_START) starts++;
 else { assert(opcode==APM_CMD_GRAPH_STOP); stops++; }
 return command_error;
}
C
awk '/^int q6apm_graph_(start|stop)\(/ {emit=1} emit {print} emit && /^}/ {emit=0}' \
 "$kernel/sound/soc/qcom/qdsp6/q6apm.c" >> "$work/check.c"
cat >> "$work/check.c" <<'C'
struct job { struct q6apm_graph *graph; bool stop; };
static void *run(void *arg)
{
 struct job *job=arg;
 assert(!(job->stop?q6apm_graph_stop(job->graph):q6apm_graph_start(job->graph)));
 return NULL;
}
int main(void)
{
 (void)acquire_mutex; (void)cleanup_mutex;
 struct q6apm apm={.cmd_lock={.native=PTHREAD_MUTEX_INITIALIZER}};
 struct audioreach_graph shared={.apm=&apm};
 struct q6apm_graph a={.ar_graph=&shared}, b={.ar_graph=&shared};
 command_error=-EIO;
 assert(q6apm_graph_start(&a)==-EIO && !shared.start_count && starts==1);
 command_error=0;
 assert(!q6apm_graph_start(&a) && shared.start_count==1 && starts==2);
 command_error=-ETIMEDOUT;
 assert(q6apm_graph_stop(&a)==-ETIMEDOUT);
 if(shared.start_count!=1) fprintf(stderr,"Failed STOP consumed the last active graph reference\n");
 assert(shared.start_count==1 && stops==1);
 assert(q6apm_graph_stop(&a)==-ETIMEDOUT && shared.start_count==1 && stops==2);
 command_error=0;
 assert(!q6apm_graph_stop(&a) && !shared.start_count && stops==3);
 assert(!q6apm_graph_stop(&a) && stops==3);
 assert(!q6apm_graph_start(&a) && !q6apm_graph_start(&b) && shared.start_count==2 && starts==3);
 assert(!q6apm_graph_stop(&a) && shared.start_count==1 && stops==3);
 assert(!q6apm_graph_stop(&b) && !shared.start_count && stops==4);
 shared.start_count=INT_MAX;
 assert(q6apm_graph_start(&a)==-EOVERFLOW && shared.start_count==INT_MAX && starts==3);
 shared.start_count=0; apm.removing=true;
 assert(q6apm_graph_start(&a)==-ENODEV && !shared.start_count && starts==3);
 shared.start_count=1;
 assert(!q6apm_graph_stop(&a) && !shared.start_count && stops==5);
 apm.removing=false;
 struct job jobs[2]={{.graph=&a},{.graph=&b}};
 pthread_t workers[2];
 for(int phase=0;phase<2;phase++) {
  for(int i=0;i<2;i++) { jobs[i].stop=phase; assert(!pthread_create(&workers[i],NULL,run,&jobs[i])); }
  for(int i=0;i<2;i++) assert(!pthread_join(workers[i],NULL));
  assert(shared.start_count==(phase?0:2));
 }
 assert(starts==4 && stops==6);
 assert(!pthread_mutex_destroy(&apm.cmd_lock.native));
}
C
${CC:-cc} -std=gnu11 -Wall -Wextra -Werror -pthread -fsanitize=address,undefined \
 -fno-omit-frame-pointer "$work/check.c" -o "$work/check"
"$work/check"
printf 'APM actual-source shared START/STOP errors, retry, overflow, removal and threaded accounting passed.\n'
