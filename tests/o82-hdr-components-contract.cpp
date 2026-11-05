// SPDX-License-Identifier: MIT
// Actual unchanged JSON decoder -> bounded XML components -> curve/PCC.
#include "o82-color-profile.cpp"
#include "o82-hdr-components.hpp"
#include <sstream>
#include <iomanip>
namespace {
unsigned hdr_component_cases=0,hdr_component_refusals=0,hdr_bridge_cases=0;
void hdr_component_check(bool ok) { ++hdr_component_cases;if (!ok) throw std::runtime_error("synthetic HDR component assertion"); }
std::string hdr_xml_fixture(unsigned variant=0) {
    std::string xml="<?xml version=\"1.0\"?><hdr_lib version=\"synthetic\">";
    xml+="<panel_min_luminance>0.001</panel_min_luminance><panel_max_luminance>1000</panel_max_luminance>";
    xml+="<QDCM_version>synthetic</QDCM_version><adaptive_tonemapper><enable>1</enable><future_policy>preserve</future_policy></adaptive_tonemapper>";
    xml+="<tone_map><points>";
    for (int i=0;i<17;++i) xml+="<x>"+std::to_string(i-8)+"</x>";
    for (int i=0;i<17;++i) xml+="<y>"+std::to_string(variant?std::min(i-8,6):i-8)+"</y>";
    xml+="</points></tone_map><panel_pcc>";
    constexpr const char *rows[]{"r","g","b"};
    for (unsigned channel=0;channel<3;++channel) {
        xml+="<"+std::string(rows[channel])+">";
        for (unsigned i=0;i<11;++i) {
            const auto key=o82::hdr_pcc_names[i];
            const std::string value=i==channel+1?"1":i==0&&channel==0?"0.00000000000000011102230246251565":"0";
            xml+="<"+std::string(key)+">"+value+"</"+std::string(key)+">";
        }
        xml+="</"+std::string(rows[channel])+">";
    }
    xml+="</panel_pcc></hdr_lib>";
    return xml;
}
std::string hdr_replace(std::string value,std::string_view before,std::string_view after) {
    const auto at=value.find(before);hdr_component_check(at!=std::string::npos);
    value.replace(at,before.size(),after);return value;
}
o82::HdrXmlComponents hdr_parse_fixture(const std::string &xml) {
    o82::HdrXmlComponents p;
    hdr_component_check(o82::parse_hdr_components(xml,p)==o82::HdrXmlError::none);
    hdr_component_check(p.original_xml==xml&&p.curve.count==17);
    hdr_component_check(p.remaining_policy==std::vector<std::string>({"@version","QDCM_version","adaptive_tonemapper"}));
    for (unsigned i=0;i<17;++i) hdr_component_check(p.curve.source[i]==float(int(i)-8));
    for (unsigned c=0;c<3;++c)
        for (unsigned term=0;term<11;++term) {
            const double expected=term==c+1?1:term==0&&c==0?0x1p-53:0;
            hdr_component_check(p.pcc.coefficients[c][term]==expected);
        }
    return p;
}
void hdr_component_failure_cases() {
    const auto xml=hdr_xml_fixture();auto output=hdr_parse_fixture(xml),preserved=output;
    const auto reject=[&](const std::string &input) {
        hdr_component_check(o82::parse_hdr_components(input,output)!=o82::HdrXmlError::none&&output==preserved);
        ++hdr_component_refusals;
    };
    reject("");reject(std::string(o82::hdr_xml_limit+1,' '));reject(xml+"<extra/>");reject(xml+"bad");
    reject(hdr_replace(xml,"<hdr_lib version=\"synthetic\">","<hdr_lib xmlns=\"urn:foreign\">"));
    reject(hdr_replace(xml,"<panel_pcc>","<panel_pcc extra=\"x\">"));
    reject(hdr_replace(xml,"<c>0.00000000000000011102230246251565</c>","<c>1</c><c>2</c>"));
    reject(hdr_replace(xml,"<r>1</r>","<r>1junk</r>"));
    reject(hdr_replace(xml,"<r>1</r>","<r>nan</r>"));
    reject(hdr_replace(xml,"<r>1</r>","<r>1e999</r>"));
    reject(hdr_replace(xml,"<r>1</r>","<r>+-1</r>"));
    reject(hdr_replace(xml,"<r>1</r>","<r>&#49;</r>"));
    reject(hdr_replace(xml,"<r>1</r>","<r><![CDATA[1]]></r>"));
    reject(hdr_replace(xml,"<r>1</r>","<r>1<extra/></r>"));
    reject(hdr_replace(xml,"<r>1</r>","<r attr=\"x\">1</r>"));
    reject(hdr_replace(xml,"<rr>0</rr>","<unknown>0</unknown>"));
    reject(hdr_replace(xml,"<x>-7</x>","<x>-8</x>"));
    reject(hdr_replace(xml,"<y>-7</y>","<y>-9</y>"));
    reject(hdr_replace(xml,"<x>-8</x>",""));
    reject(hdr_replace(xml,"<points>","<points><x>-9</x><y>-9</y>"));
    reject(hdr_replace(xml,"<panel_max_luminance>1000</panel_max_luminance>","<panel_max_luminance>0</panel_max_luminance>"));
    reject(hdr_replace(xml,"<hdr_lib",std::string("<!DOCTYPE hdr_lib [<!ENTITY e SYSTEM \"file:///unread\">]><hdr_lib")));
    auto nul=xml;nul.insert(80,1,'\0');reject(nul);
    std::string deep;for (unsigned i=0;i<40;++i)deep+="<a>";for(unsigned i=0;i<40;++i)deep+="</a>";
    reject(hdr_replace(xml,"<QDCM_version>synthetic</QDCM_version>",deep));
    hdr_component_check(!std::fesetround(FE_DOWNWARD));reject(xml);
    hdr_component_check(!std::fesetround(FE_TONEAREST));
}
int hdr_duplicate_control() {
    auto xml=hdr_xml_fixture();xml=hdr_replace(xml,"<r>1</r>","<r>1</r><r>2</r>");
    o82::HdrXmlComponents parsed;
    const auto error=o82::parse_hdr_components(xml,parsed);
    if(error!=o82::HdrXmlError::duplicate){std::puts("Required XML duplicate-field assertion rejected mutant");return 44;}
    return 0;
}
void hdr_actual_decoder_bridge() {
    constexpr char digits[]="0123456789abcdef";
    for(unsigned variant=0;variant<2;++variant) {
        const auto xml=hdr_xml_fixture(variant);auto expected=hdr_parse_fixture(xml);
        for(unsigned encoding=0;encoding<3;++encoding) {
            Json raw(json_object_new_object(),json_object_put);
            hdr_component_check(bool(raw)&&!json_object_object_add(raw.get(),"blob",json_object_new_string(xml.c_str())));
            std::string bytes=json_object_to_json_string_ext(raw.get(),JSON_C_TO_STRING_PLAIN);
            if(encoding)for(std::size_t i=encoding-1;i+1<bytes.size();i+=2)std::swap(bytes[i],bytes[i+1]);
            std::string hex;for(unsigned char c:bytes){hex+=digits[c>>4];hex+=digits[c&15];}
            Json mode(json_object_new_object(),json_object_put);
            hdr_component_check(bool(mode)&&!json_object_object_add(mode.get(),"PostBlendHdrBlob",json_object_new_string(hex.c_str())));
            auto decoded=decode(mode.get(),"PostBlendHdrBlob");
            o82::HdrXmlComponents parsed;
            hdr_component_check(o82::parse_hdr_components(text_field(decoded.get(),"blob"),parsed)==o82::HdrXmlError::none&&parsed==expected);
            for(unsigned i=1;i<=1024;++i) {
                const float grey=float(i)/1024;
                float mapped=std::numeric_limits<float>::quiet_NaN();
                hdr_component_check(o82::map_hdr_normalized_luminance(parsed.curve,parsed.range,grey,
                    o82::HdrCurveDirection::to_panel,mapped)==o82::HdrCurveError::none);
                const float poison=std::numeric_limits<float>::quiet_NaN();
                std::array<float,3> output{poison,poison,poison};
                hdr_component_check(o82::map_hdr_panel_pcc(parsed.pcc,{mapped,mapped,mapped},output)==o82::HdrPccError::none);
                const double target=std::clamp((10000.0*grey-0.001)/(1000.0-0.001),0.0,1.0);
                for(unsigned channel=0;channel<3;++channel)
                    hdr_component_check(std::abs(double(output[channel])-target)<4e-6);
                ++hdr_bridge_cases;
            }
        }
    }
}
} // namespace
extern "C" int __wrap_main(int argc,char **argv) {
    try {
        if(argc==2&&!std::strcmp(argv[1],"--duplicate-control"))return hdr_duplicate_control();
        hdr_component_check(argc==1&&std::fegetround()==FE_TONEAREST);
        hdr_component_failure_cases();hdr_actual_decoder_bridge();
        self_test();
        std::printf("HDR XML components: %u assertions, %u refusals, %u actual-decoder/achromatic curve-PCC cases; all remaining policy retained\n",
            hdr_component_cases,hdr_component_refusals,hdr_bridge_cases);
        return 0;
    }catch(const std::exception &error){std::fprintf(stderr,"HDR synthetic fixture: %s\n",error.what());return 1;}
}
