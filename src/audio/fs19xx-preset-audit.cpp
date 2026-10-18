// SPDX-License-Identifier: GPL-2.0-only
// Host-only structural audit. Format: MiCode audio 8eb0eccb fs19xx/fsm-dev.h.
// CRC-16/IBM matches fsm_calc_checksum(); no register or calibration values output.
#include <array>
#include <cstdint>
#include <fstream>
#include <iostream>
#include <iterator>
#include <set>
#include <span>
#include <stdexcept>
#include <string>
#include <vector>

namespace {
using Bytes=std::vector<uint8_t>;
void require(bool value,const char *reason){if(!value)throw std::runtime_error(reason);}
uint16_t word(std::span<const uint8_t> b,size_t at){
    require(at<=b.size()&&b.size()-at>=2,"truncated word");
    return uint16_t(b[at])|(uint16_t(b[at+1])<<8);
}
uint16_t crc(std::span<const uint8_t> bytes){
    uint16_t value=0;
    for(auto byte:bytes){value^=byte;for(unsigned i=0;i<8;i++)value=(value>>1)^((value&1)?0xa001:0);}
    return value;
}
struct Device{uint16_t address,type,sections,position;};
std::array<Device,4> audit(std::span<const uint8_t> b){
    require(b.size()>=44&&b.size()<=65534&&b.size()%2==0,"invalid preset size");
    require(word(b,22)==b.size(),"declared size mismatch");
    require(word(b,26)==4,"Uke requires four distinct amplifier descriptions");
    require(crc(b.subspan(26))==word(b,24),"preset checksum mismatch");
    std::array<Device,4> devices{};std::set<uint16_t> addresses,offsets;
    for(size_t i=0;i<4;i++){
        size_t at=word(b,28+4*i);
        require(word(b,30+4*i)==0,"unsupported top-level section type");
        require(at>=44&&at<=b.size()&&b.size()-at>=40,"device header out of bounds");
        require(offsets.insert(at).second,"duplicate device offset");
        require(word(b,at)&0x8000,"invalid device preset revision");
        const auto count=word(b,at+26),address=word(b,at+30),type=word(b,at+32);
        require(address>=0x34&&address<=0x37&&addresses.insert(address).second,"wrong or duplicate amplifier address");
        require((type>>8)==0x17||(type>>8)==0x29,"unreviewed FS-family device type");
        const size_t index=at+40;
        uint16_t position=0;
        require(count<=(b.size()-index)/4,"device index table out of bounds");
        for(size_t n=0;n<count;n++){
            const size_t offset=word(b,index+4*n);
            require(word(b,index+4*n+2)<7,"unreviewed nested section type");
            require(offset>=4*count&&offset<=b.size()-index&&b.size()-index-offset>=2,"nested section out of bounds");
            if(word(b,index+4*n+2)==1){
                const size_t info=index+offset;
                const size_t length=word(b,info);
                require(length>(size_t)16&&length<=(b.size()-info-2)/2,"speaker-info table out of bounds");
                require(position==0,"duplicate speaker-info table");
                position=word(b,info+2+16*2);
                require(position==1||position==2||position==4||position==8,"unreviewed position mask");
            }
        }
        devices[i]={address,type,count,position};
    }
    return devices;
}
void put(Bytes &b,size_t at,uint16_t value){b.at(at)=value;b.at(at+1)=value>>8;}
void seal(Bytes &b){put(b,24,crc(std::span<const uint8_t>(b).subspan(26)));}
Bytes fixture(bool info=false){
    const size_t stride=info?80:40;
    Bytes b(44+4*stride);put(b,22,b.size());put(b,26,4);
    for(size_t i=0;i<4;i++){
        size_t at=44+stride*i;put(b,28+4*i,at);put(b,at,0x8001);put(b,at+30,0x34+i);put(b,at+32,0x2900);
        if(info){put(b,at+26,1);put(b,at+40,4);put(b,at+42,1);put(b,at+44,17);put(b,at+78,1<<i);}
    }
    seal(b);return b;
}
void self_test(){
    auto b=fixture();(void)audit(b);
    auto reject=[](const Bytes &bad){bool refused=false;try{(void)audit(bad);}catch(const std::exception&){refused=true;}require(refused,"negative fixture was accepted");};
    for(size_t n=0;n<b.size();n++){auto short_file=b;short_file.resize(n);reject(short_file);}
    auto bad=b;bad.back()^=1;reject(bad);
    for(auto field:std::array<size_t,5>{26,28,44+26,44+30,44+32}){
        bad=b;put(bad,field,0xffff);seal(bad);reject(bad);
    }
    bad=b;put(bad,32,44);seal(bad);reject(bad);
    b=fixture(true);require(audit(b)[3].position==8,"speaker-info position mismatch");
    for(auto field:std::array<size_t,3>{84,88,122}){bad=b;put(bad,field,0xffff);seal(bad);reject(bad);}
    require(crc(std::span<const uint8_t>(reinterpret_cast<const uint8_t*>("123456789"),9))==0xbb3d,"CRC reference vector mismatch");
    std::cout<<"Preset structural and negative fixtures passed; no hardware qualification.\n";
}
}
int main(int argc,char **argv){
    try{
        if(argc==2&&std::string(argv[1])=="--self-test"){self_test();return 0;}
        require(argc==2,"usage: fs19xx-preset-audit FILE.fsm | --self-test");
        std::ifstream file(argv[1],std::ios::binary);require(bool(file),"cannot open preset file");
        Bytes bytes;char byte;
        while(file.get(byte)){require(bytes.size()<65534,"preset exceeds format size");bytes.push_back(uint8_t(byte));}
        require(file.eof(),"preset read failed");const auto devices=audit(bytes);
        std::cout<<"{\"structural_audit\":\"PASS\",\"size\":"<<bytes.size()<<",\"devices\":[";
        for(size_t i=0;i<devices.size();i++){if(i)std::cout<<',';const auto &d=devices[i];std::cout<<"{\"address\":"<<d.address<<",\"preset_type\":"<<d.type<<",\"sections\":"<<d.sections<<",\"preset_position_mask\":"<<d.position<<'}';}
        std::cout<<"],\"nested_payload_semantics_qualified\":false,\"live_chip_match\":false,\"speaker_admissible\":false}\n";
    }catch(const std::exception &e){std::cerr<<"preset audit: "<<e.what()<<'\n';return 1;}
}
