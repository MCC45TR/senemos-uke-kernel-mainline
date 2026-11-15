/* SPDX-License-Identifier: GPL-2.0-only */
/* Actual Linux callbacks with independent pthread PCM/RX/workqueue providers. */
#include <assert.h>
#include <errno.h>
#include <pthread.h>
#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>
#include <stdatomic.h>
#include <stdio.h>
#include <stdlib.h>
#include <time.h>

typedef pthread_mutex_t spinlock_t;
static _Thread_local unsigned int spin_depth;
static void spin_take(spinlock_t *p) { assert(!pthread_mutex_lock(p)); spin_depth++; }
static void spin_drop(spinlock_t *p) { assert(spin_depth); spin_depth--; assert(!pthread_mutex_unlock(p)); }
#define spin_lock_irqsave(p, flags) ((flags) = 0, spin_take(p))
#define spin_unlock_irqrestore(p, flags) ((void)(flags), spin_drop(p))
#define container_of(p, t, m) ((t *)((char *)(p) - offsetof(t, m)))

struct context;
struct work_struct {
 pthread_mutex_t lock; pthread_cond_t changed; pthread_t thread;
 void (*function)(struct work_struct *);
 struct context *context;
 bool pending, running, paused, stop;
};
struct snd_pcm_substream { struct context *context; };
struct q6apm_graph { struct context *context; };
struct q6apm_dai_rtd {
 struct snd_pcm_substream *substream; struct q6apm_graph *graph;
 int state; spinlock_t pcm_period_lock;
 struct work_struct pcm_period_work; bool pcm_period_closed;
};
struct context {
 struct q6apm_dai_rtd *prtd; struct snd_pcm_substream substream;
 struct q6apm_graph graph; pthread_mutex_t stream_lock;
 pthread_mutex_t signal_lock; pthread_cond_t signal;
 atomic_int acknowledgement, entered, notifications, reads, queued;
 atomic_int cancel_entered, close_done, hw_position, notified_position;
 unsigned int event;
};
static const int independent_queue;
#define system_unbound_wq (&independent_queue)
enum {
 APM_CLIENT_EVENT_WATERMARK_EVENT = 1, APM_CLIENT_EVENT_CMD_EOS_DONE,
 APM_CLIENT_EVENT_DATA_WRITE_DONE, APM_CLIENT_EVENT_DATA_READ_DONE,
 Q6APM_STREAM_STOPPED = 1, Q6APM_STREAM_RUNNING = 2
};
static void signal_context(struct context *c)
{
 assert(!pthread_mutex_lock(&c->signal_lock));
 assert(!pthread_cond_broadcast(&c->signal));
 assert(!pthread_mutex_unlock(&c->signal_lock));
}
static bool await_flag(struct context *c, atomic_int *flag)
{
 struct timespec deadline; assert(!clock_gettime(CLOCK_REALTIME, &deadline));
 deadline.tv_sec += 2;
 assert(!pthread_mutex_lock(&c->signal_lock));
 while (!atomic_load(flag)) {
  int ret = pthread_cond_timedwait(&c->signal, &c->signal_lock, &deadline);
  if (ret == ETIMEDOUT) break;
  assert(!ret);
 }
 bool ready = atomic_load(flag);
 assert(!pthread_mutex_unlock(&c->signal_lock));
 return ready;
}
static void snd_pcm_period_elapsed(struct snd_pcm_substream *substream)
{
 struct context *c = substream->context;
 assert(!spin_depth);
 atomic_store(&c->entered, 1); signal_context(c);
 assert(!pthread_mutex_lock(&c->stream_lock));
 atomic_store(&c->notified_position, atomic_load(&c->hw_position));
 atomic_fetch_add(&c->notifications, 1);
 assert(!pthread_mutex_unlock(&c->stream_lock));
}
static int q6apm_read(struct q6apm_graph *graph)
{
 atomic_fetch_add(&graph->context->reads, 1); return 0;
}
static void *work_loop(void *arg)
{
 struct work_struct *w = arg;
 assert(!pthread_mutex_lock(&w->lock));
 for (;;) {
  while ((!w->pending || w->paused) && !w->stop)
   assert(!pthread_cond_wait(&w->changed, &w->lock));
  if (w->stop) break;
  w->pending = false; w->running = true;
  assert(!pthread_mutex_unlock(&w->lock));
  w->function(w);
  assert(!pthread_mutex_lock(&w->lock));
  w->running = false; assert(!pthread_cond_broadcast(&w->changed));
 }
 assert(!pthread_mutex_unlock(&w->lock)); return NULL;
}
static bool queue_work(const int *queue, struct work_struct *w)
{
 assert(queue == system_unbound_wq);
 assert(spin_depth == 1);
 atomic_fetch_add(&w->context->queued, 1);
 assert(!pthread_mutex_lock(&w->lock));
 bool added = !w->pending; w->pending = true;
 assert(!pthread_cond_signal(&w->changed));
 assert(!pthread_mutex_unlock(&w->lock)); return added;
}
static void cancel_work_sync(struct work_struct *w)
{
 assert(!spin_depth);
 atomic_store(&w->context->cancel_entered, 1); signal_context(w->context);
 assert(!pthread_mutex_lock(&w->lock));
 w->pending = false;
 while (w->running) assert(!pthread_cond_wait(&w->changed, &w->lock));
 assert(!pthread_mutex_unlock(&w->lock));
}

#include "native-pcm-period-helpers.inc"
#include "native-pcm-period-event.inc"

static struct context *fresh(bool paused)
{
 struct context *c = calloc(1, sizeof(*c)); assert(c);
 c->prtd = calloc(1, sizeof(*c->prtd)); assert(c->prtd);
 assert(!pthread_mutex_init(&c->stream_lock, NULL));
 assert(!pthread_mutex_init(&c->signal_lock, NULL));
 assert(!pthread_cond_init(&c->signal, NULL));
 struct q6apm_dai_rtd *p = c->prtd;
 assert(!pthread_mutex_init(&p->pcm_period_lock, NULL));
 c->substream.context = c; c->graph.context = c;
 p->substream = &c->substream; p->graph = &c->graph; p->state = Q6APM_STREAM_RUNNING;
 struct work_struct *w = &p->pcm_period_work;
 assert(!pthread_mutex_init(&w->lock, NULL));
 assert(!pthread_cond_init(&w->changed, NULL));
 w->context = c; w->function = q6apm_pcm_period_work; w->paused = paused;
 assert(!pthread_create(&w->thread, NULL, work_loop, w)); return c;
}
static void pause_worker(struct context *c, bool pause)
{
 struct work_struct *w = &c->prtd->pcm_period_work;
 assert(!pthread_mutex_lock(&w->lock)); w->paused = pause;
 assert(!pthread_cond_broadcast(&w->changed));
 assert(!pthread_mutex_unlock(&w->lock));
}
static void flush_worker(struct context *c)
{
 struct work_struct *w = &c->prtd->pcm_period_work;
 assert(!pthread_mutex_lock(&w->lock));
 while (w->pending || w->running) assert(!pthread_cond_wait(&w->changed, &w->lock));
 assert(!pthread_mutex_unlock(&w->lock));
}
static void destroy(struct context *c)
{
 q6apm_pcm_period_quiesce(c->prtd);
 struct work_struct *w = &c->prtd->pcm_period_work;
 assert(!pthread_mutex_lock(&w->lock)); w->stop = true;
 assert(!pthread_cond_broadcast(&w->changed)); assert(!pthread_mutex_unlock(&w->lock));
 assert(!pthread_join(w->thread, NULL));
 assert(!pthread_cond_destroy(&w->changed)); assert(!pthread_mutex_destroy(&w->lock));
 assert(!pthread_mutex_destroy(&c->prtd->pcm_period_lock));
 assert(!pthread_mutex_destroy(&c->stream_lock)); assert(!pthread_cond_destroy(&c->signal));
 assert(!pthread_mutex_destroy(&c->signal_lock)); free(c->prtd); free(c);
}
static void *rx_then_ack(void *arg)
{
 struct context *c = arg;
 event_handler(c->event, 0, NULL, c->prtd);
 /* The next ordered GPR packet is the APM command completion. */
 atomic_store(&c->acknowledgement, 1); signal_context(c); return NULL;
}
static void *close_periods(void *arg)
{
 struct context *c = arg; q6apm_pcm_period_quiesce(c->prtd);
 atomic_store(&c->close_done, 1); signal_context(c); return NULL;
}
static void progress(unsigned int event)
{
 struct context *c = fresh(false); c->event = event;
 atomic_store(&c->hw_position, 17);
 assert(!pthread_mutex_lock(&c->stream_lock));
 pthread_t rx; assert(!pthread_create(&rx, NULL, rx_then_ack, c));
 /* APM must complete while STOP still owns the PCM stream mutex. */
 assert(await_flag(c, &c->acknowledgement));
 assert(!pthread_join(rx, NULL)); assert(!atomic_load(&c->notifications));
 assert(!pthread_mutex_unlock(&c->stream_lock)); flush_worker(c);
 assert(atomic_load(&c->notifications) == 1 && atomic_load(&c->notified_position) == 17);
 assert(atomic_load(&c->reads) == (event == APM_CLIENT_EVENT_DATA_READ_DONE));
 destroy(c);
}
int main(void)
{
 (void)q6apm_pcm_period_elapsed; (void)cancel_work_sync;
 const unsigned int notifications[] = { APM_CLIENT_EVENT_WATERMARK_EVENT,
  APM_CLIENT_EVENT_DATA_WRITE_DONE, APM_CLIENT_EVENT_DATA_READ_DONE };
 for (unsigned int i = 0; i < 3; i++) progress(notifications[i]);
 struct context *c = fresh(false);
 c->prtd->state = Q6APM_STREAM_STOPPED;
 event_handler(APM_CLIENT_EVENT_DATA_READ_DONE, 0, NULL, c->prtd); flush_worker(c);
 assert(atomic_load(&c->notifications) == 1 && !atomic_load(&c->reads)); destroy(c);
 c = fresh(false); event_handler(APM_CLIENT_EVENT_CMD_EOS_DONE, 0, NULL, c->prtd);
 assert(c->prtd->state == Q6APM_STREAM_STOPPED && !atomic_load(&c->queued)); destroy(c);
 c = fresh(false); event_handler(UINT32_MAX, 0, NULL, c->prtd);
 assert(!atomic_load(&c->queued) && !atomic_load(&c->reads)); destroy(c);
 c = fresh(true); q6apm_pcm_period_quiesce(c->prtd);
 event_handler(APM_CLIENT_EVENT_DATA_WRITE_DONE, 0, NULL, c->prtd);
 assert(!atomic_load(&c->queued)); destroy(c);
 c = fresh(true); event_handler(APM_CLIENT_EVENT_DATA_WRITE_DONE, 0, NULL, c->prtd);
 q6apm_pcm_period_quiesce(c->prtd);
 assert(!c->prtd->pcm_period_work.pending && !atomic_load(&c->notifications)); destroy(c);
 c = fresh(false); assert(!pthread_mutex_lock(&c->stream_lock));
 event_handler(APM_CLIENT_EVENT_DATA_WRITE_DONE, 0, NULL, c->prtd);
 assert(await_flag(c, &c->entered));
 pthread_t closer; assert(!pthread_create(&closer, NULL, close_periods, c));
 assert(await_flag(c, &c->cancel_entered)); assert(!atomic_load(&c->close_done));
 assert(!pthread_mutex_unlock(&c->stream_lock)); assert(!pthread_join(closer, NULL));
 assert(atomic_load(&c->close_done) && atomic_load(&c->notifications) == 1); destroy(c);
 c = fresh(true);
 for (unsigned int i = 1; i <= 128; i++) {
  atomic_store(&c->hw_position, (int)i);
  event_handler(APM_CLIENT_EVENT_DATA_WRITE_DONE, 0, NULL, c->prtd);
 }
 pause_worker(c, false); flush_worker(c);
 assert(atomic_load(&c->notifications) == 1 && atomic_load(&c->notified_position) == 128); destroy(c);
 c = fresh(false); assert(!pthread_mutex_lock(&c->stream_lock));
 event_handler(APM_CLIENT_EVENT_DATA_WRITE_DONE, 0, NULL, c->prtd);
 assert(await_flag(c, &c->entered));
 for (unsigned int i = 1; i <= 128; i++) {
  atomic_store(&c->hw_position, (int)i);
  event_handler(APM_CLIENT_EVENT_DATA_WRITE_DONE, 0, NULL, c->prtd);
 }
 assert(!pthread_mutex_unlock(&c->stream_lock)); flush_worker(c);
 assert(atomic_load(&c->notifications) == 2 && atomic_load(&c->notified_position) == 128); destroy(c);
 for (unsigned int n = 0; n < 24; n++) {
  c = fresh(true); c->event = notifications[n % 3];
  pthread_t rx, stop;
  assert(!pthread_create(&rx, NULL, rx_then_ack, c));
  assert(!pthread_create(&stop, NULL, close_periods, c));
  assert(!pthread_join(rx, NULL)); assert(!pthread_join(stop, NULL));
  assert(!c->prtd->pcm_period_work.pending && !atomic_load(&c->notifications)); destroy(c);
 }
 puts("Actual PCM period callbacks: 11 scenarios and 24 enqueue/close races, ordered-RX command progress under the held PCM mutex, capture/EOS and bounded coalescing passed; synthetic only.");
 return 0;
}
