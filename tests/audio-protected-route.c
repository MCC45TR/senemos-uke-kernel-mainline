/* SPDX-License-Identifier: GPL-2.0-only */
/* Real Linux route callbacks, compiled ALSA topology metadata, no hardware. */
#include <assert.h>
#include <stdint.h>
#include <stdbool.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#define LIMIT 128
struct audioreach_module { uint32_t instance_id; };
struct module_record { char name[128]; unsigned graph,source,output,destination,input,mid; struct audioreach_module module; };
static struct module_record modules[LIMIT];
static unsigned nmodules;
struct snd_soc_dobj { void *private; };
struct soc_mixer_control { struct snd_soc_dobj dobj; };
struct snd_kcontrol_new { const char *name; unsigned long private_value; };
struct snd_soc_dapm_widget { int num_kcontrols; struct snd_kcontrol_new *kcontrol_news; };
struct snd_ar_control { unsigned graph_id,module_instance_id; struct snd_soc_dapm_widget *w; };
struct snd_soc_component { void *dev; };
struct snd_soc_dapm_route { const char *sink,*control,*source; };
struct audioreach_graph_info { unsigned src_mod_inst_id,src_mod_op_port_id,dst_mod_inst_id,dst_mod_ip_port_id; };
struct q6apm { int lock,graph_info_idr; };
static struct q6apm apm;
static struct audioreach_graph_info graph;
static struct snd_ar_control frontend={.graph_id=1},backend={.graph_id=40};
static struct soc_mixer_control mixer_control={.dobj={.private=&frontend}};
static struct snd_kcontrol_new mixer_news={.name="MultiMedia2",.private_value=(unsigned long)&mixer_control};
static struct snd_soc_dapm_widget mixer_widget={.num_kcontrols=1,.kcontrol_news=&mixer_news};
static void mutex_lock(int *value){ assert(!*value);++*value; }
static void mutex_unlock(int *value){ assert(*value==1);--*value; }
static struct q6apm *dev_get_drvdata(void *device){ assert(device==&apm);return &apm; }
static struct audioreach_graph_info *idr_find(int *unused,unsigned id){ (void)unused;assert(id==40);return &graph; }
static struct audioreach_module *audioreach_find_module(struct snd_soc_component *component,const char *name){
 (void)component;
 for(unsigned i=0;i<nmodules;++i) {
  if(!strcmp(name,modules[i].name))return &modules[i].module;
 }
 return NULL;
}
static struct snd_ar_control *audioreach_find_widget(struct snd_soc_component *component,const char *name){
 (void)component;if(!strcmp(name,"SECONDARY_TDM_RX_0 Audio Mixer"))return &backend;
 if(!strcmp(name,"MultiMedia2"))return &frontend;
 return NULL;
}
#include "actual-route-functions.h"
static char *trim(char *s){while(*s==' '||*s=='\t')++s;size_t n=strlen(s);while(n&&(s[n-1]==' '||s[n-1]=='\t'||s[n-1]=='\n'||s[n-1]=='\r'))s[--n]=0;return s;}
static struct module_record *named(const char *name){
 for(unsigned i=0;i<nmodules;++i) {
  if(!strcmp(name,modules[i].name))return &modules[i];
 }
 abort();
}
struct edge {unsigned source,output,destination,input;};
int main(int argc,char **argv){
 assert(argc==3);FILE *file=fopen(argv[1],"r");assert(file);char line[1024];
 while(fgets(line,sizeof(line),file)){
  assert(strchr(line,'\n')&&nmodules<LIMIT);struct module_record *m=&modules[nmodules++];
  assert(sscanf(line,"%127[^\t]\t%u\t%u\t%u\t%u\t%u\t%u\t%u",m->name,&m->graph,&m->module.instance_id,&m->source,&m->output,&m->destination,&m->input,&m->mid)==8);
  for(unsigned j=0;j+1<nmodules;++j)assert(modules[j].module.instance_id!=m->module.instance_id);
 }
 fclose(file);assert(nmodules>0);backend.w=&mixer_widget;
 struct snd_soc_component component={.dev=&apm};
 file=fopen(argv[2],"r");assert(file);
 while(fgets(line,sizeof(line),file)){
  char sink[128],control[128],source[128];assert(strchr(line,'\n'));
  assert(sscanf(line,"%127[^,],%127[^,],%127[^\n]",sink,control,source)==3);
  char *c=trim(control);struct snd_soc_dapm_route route={.sink=trim(sink),.control=*c?c:NULL,.source=trim(source)};
  assert(!audioreach_route_load(&component,0,&route));
 }
 fclose(file);audioreach_connect_sub_graphs(&apm,&frontend,&backend,1);assert(!apm.lock);
 struct edge edges[LIMIT];unsigned count=0;
 edges[count++]=(struct edge){graph.src_mod_inst_id,graph.src_mod_op_port_id,graph.dst_mod_inst_id,graph.dst_mod_ip_port_id};
 for(unsigned i=0;i<nmodules;++i){struct module_record *m=&modules[i];if(m->graph==40&&m->destination){assert(count<LIMIT);edges[count++]=(struct edge){m->source,m->output,m->destination,m->input};}}
 for(unsigned i=0;i<count;++i){
  assert(edges[i].source&&edges[i].output&&edges[i].destination&&edges[i].input);
  for(unsigned j=0;j<i;++j){
   if(edges[i].destination==edges[j].destination&&edges[i].input==edges[j].input){fprintf(stderr,"Duplicate DSP input: 0x%x/%u\n",edges[i].destination,edges[i].input);abort();}
   assert(edges[i].source!=edges[j].source||edges[i].output!=edges[j].output);
  }
 }
 assert(count==4&&graph.src_mod_inst_id==named("spk.converter")->module.instance_id&&graph.dst_mod_inst_id==named("spk.mfc")->module.instance_id);
 assert(named("spk.mfc")->destination==named("spk.fs.rx")->module.instance_id);
 assert(named("spk.fs.rx")->destination==named("spk.sink")->module.instance_id);
 assert(named("spk.vi.source")->destination==named("spk.fs.tx")->module.instance_id);
 assert(named("spk.fs.rx")->mid==0x10001111&&named("spk.fs.tx")->mid==0x10001110);
 puts("Actual Linux DAPM route callbacks and compiled topology: unique DSP ports, MFC/RX/sink and VI/TX paths retained.");
 return 0;
}
