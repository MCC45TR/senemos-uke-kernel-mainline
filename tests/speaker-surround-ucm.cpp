// SPDX-License-Identifier: MIT
// Original ALSA configuration parser only; no card, PCM or mixer is opened.
#include <alsa/asoundlib.h>
#include <cassert>
#include <cstdio>
#include <cstring>
#include <memory>
#include <string>
using Config=std::unique_ptr<snd_config_t,decltype(&snd_config_delete)>;
static Config load(const char* file) {
 snd_config_t* raw=nullptr;assert(!snd_config_top(&raw));Config config(raw,snd_config_delete);
 snd_input_t* input=nullptr;assert(!snd_input_stdio_open(&input,file,"r"));
 const int result=snd_config_load(raw,input);snd_input_close(input);assert(!result);return config;
}
static snd_config_t* node(snd_config_t* config,const char* key) {
 snd_config_t* value=nullptr;assert(!snd_config_search(config,key,&value));return value;
}
static std::string serialized(snd_config_t* config) {
 snd_output_t* output=nullptr;assert(!snd_output_buffer_open(&output));assert(!snd_config_save(config,output));
 char* data=nullptr;const size_t bytes=snd_output_buffer_string(output,&data);assert(data&&bytes);
 const std::string result(data,bytes);snd_output_close(output);return result;
}
int main(int argc,char** argv) {
 assert(argc==5);auto base=load(argv[1]);const auto expected=serialized(base.get());
 for(int i=2;i<=3;i++) {
  auto config=load(argv[i]);long channels=0;const char* pcm=nullptr;
  auto* count=node(config.get(),"SectionDevice.Speaker.Value.PlaybackChannels");
  auto* device=node(config.get(),"SectionDevice.Speaker.Value.PlaybackPCM");
  assert(!snd_config_get_integer(count,&channels)&&channels==(i==2?6:8));
  assert(!snd_config_get_string(device,&pcm)&&!strcmp(pcm,"hw:${CardId},1"));
  assert(!snd_config_set_integer(count,4));assert(!snd_config_set_string(device,"uke_speakers:${CardId}"));
  assert(serialized(config.get())==expected);
 }
 auto root=load(argv[4]);
 for(const char* name:{"HiFi Surround 5.1","HiFi Surround 7.1"}) {
  // Dots in a use-case name are literal ALSA node IDs, not search separators.
  auto* cases=node(root.get(),"SectionUseCase");bool found=false;
  snd_config_iterator_t i,next;
  snd_config_for_each(i,next,cases) {
   const char* id=nullptr;assert(!snd_config_get_id(snd_config_iterator_entry(i),&id));
   if(!strcmp(id,name))found=true;
  }
  assert(found);
 }
 puts("Original ALSA surround UCM parser:6/8 direct hardware profiles, unchanged quad/microphone/DP controls and both verbs passed; no device acceptance.");
}
