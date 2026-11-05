// SPDX-License-Identifier: MIT
// Bounded private XML component extraction. Whole HDR policy still needs admission.
#ifndef UKE_O82_HDR_COMPONENTS_HPP
#define UKE_O82_HDR_COMPONENTS_HPP
#include "o82-hdr-tonemap.h"
#include "o82-hdr-pcc.h"
#include <tinyxml2.h>
#include <charconv>
#include <set>
#include <string>
#include <vector>
#include <utility>

namespace o82 {
inline constexpr std::size_t hdr_xml_limit=1024*1024;
struct HdrXmlComponents {
    HdrLogCurve curve;
    HdrPanelPcc pcc;
    HdrLuminanceRange range;
    // Preserve all policy, including fields not implemented by these components.
    // This is private data; never log it or infer complete-mode admission from it.
    std::string original_xml;
    std::vector<std::string> remaining_policy;
    bool operator==(const HdrXmlComponents &other) const {
        return curve==other.curve&&pcc==other.pcc&&
            range.black_nits==other.range.black_nits&&range.white_nits==other.range.white_nits&&
            original_xml==other.original_xml&&remaining_policy==other.remaining_policy;
    }
};
enum class HdrXmlError { none,size,xml,shape,duplicate,numeric,curve,pcc,rounding_mode };
namespace hdr_xml_detail {
inline bool whitespace(std::string_view value) {
    return value.find_first_not_of(" \r\n\t")==std::string_view::npos;
}
inline std::string_view trimmed(std::string_view value) {
    const auto start=value.find_first_not_of(" \r\n\t");
    if (start==std::string_view::npos) return {};
    return value.substr(start,value.find_last_not_of(" \r\n\t")-start+1);
}
inline HdrXmlError bounded_tree(const tinyxml2::XMLNode &node,unsigned depth,std::size_t &count) {
    if (depth>32||++count>8192) return HdrXmlError::size;
    if (node.ToUnknown()) return HdrXmlError::xml;
    if (const auto *element=node.ToElement()) {
        if (std::string_view(element->Name()).find(':')!=std::string_view::npos) return HdrXmlError::shape;
        for (auto *a=element->FirstAttribute();a;a=a->Next())
            if (std::string_view(a->Name()).starts_with("xmlns")||
                std::string_view(a->Name()).find(':')!=std::string_view::npos) return HdrXmlError::shape;
    }
    for (auto *child=node.FirstChild();child;child=child->NextSibling()) {
        const auto error=bounded_tree(*child,depth+1,count);
        if (error!=HdrXmlError::none) return error;
    }
    return HdrXmlError::none;
}
inline HdrXmlError container(const tinyxml2::XMLElement &element,
        std::span<const std::string_view> allowed={},bool attributes=false) {
    if (!attributes&&element.FirstAttribute()) return HdrXmlError::shape;
    std::set<std::string_view> names;
    for (auto *node=element.FirstChild();node;node=node->NextSibling()) {
        if (node->ToComment()) continue;
        if (const auto *text=node->ToText()) {
            if (!whitespace(text->Value())) return HdrXmlError::shape;
            continue;
        }
        const auto *child=node->ToElement();
        if (!child) return HdrXmlError::shape;
        const std::string_view name=child->Name();
        if (!names.insert(name).second) return HdrXmlError::duplicate;
        if (!allowed.empty()&&std::find(allowed.begin(),allowed.end(),name)==allowed.end())
            return HdrXmlError::shape;
    }
    return HdrXmlError::none;
}
template<class T> inline bool scalar(const tinyxml2::XMLElement &element,T &output) {
    if (element.FirstAttribute()) return false;
    const tinyxml2::XMLText *text=nullptr;
    for (auto *node=element.FirstChild();node;node=node->NextSibling()) {
        if (node->ToComment()) continue;
        if (!node->ToText()||text||node->ToText()->CData()) return false;
        text=node->ToText();
    }
    if (!text) return false;
    auto value=trimmed(text->Value());
    if (!value.empty()&&value[0]=='+') {
        value.remove_prefix(1);
        if (!value.empty()&&(value[0]=='+'||value[0]=='-')) return false;
    }
    if (value.empty()) return false;
    T candidate;
    const auto parsed=std::from_chars(value.data(),value.data()+value.size(),candidate,std::chars_format::general);
    if (parsed.ec!=std::errc{}||parsed.ptr!=value.data()+value.size()||!std::isfinite(candidate)) return false;
    output=candidate;
    return true;
}
} // namespace hdr_xml_detail

inline HdrXmlError parse_hdr_components(std::string_view xml,HdrXmlComponents &output) {
    using namespace hdr_xml_detail;
    if (xml.empty()||xml.size()>hdr_xml_limit) return HdrXmlError::size;
    if (xml.find('\0')!=std::string_view::npos) return HdrXmlError::xml;
    if (std::fegetround()!=FE_TONEAREST) return HdrXmlError::rounding_mode;
    tinyxml2::XMLDocument document(false,tinyxml2::PRESERVE_WHITESPACE);
    if (document.Parse(xml.data(),xml.size())!=tinyxml2::XML_SUCCESS) return HdrXmlError::xml;
    std::size_t count=0;
    const auto bounded=bounded_tree(document,0,count);
    if (bounded!=HdrXmlError::none) return bounded;
    const auto *root=document.RootElement();
    if (!root||std::string_view(root->Name())!="hdr_lib"||root->NextSiblingElement()) return HdrXmlError::shape;
    for (auto *node=document.FirstChild();node;node=node->NextSibling()) {
        if (node==root||node->ToComment()||node->ToDeclaration()) continue;
        if (node->ToText()&&whitespace(node->Value())) continue;
        return HdrXmlError::shape;
    }
    const auto root_error=container(*root,{},true);
    if (root_error!=HdrXmlError::none) return root_error;
    HdrXmlComponents candidate;
    for (auto *a=root->FirstAttribute();a;a=a->Next())
        candidate.remaining_policy.emplace_back("@"+std::string(a->Name()));
    constexpr std::array<std::string_view,4> extracted{
        "panel_min_luminance","panel_max_luminance","tone_map","panel_pcc"};
    for (const auto name:extracted) if (!root->FirstChildElement(name.data())) return HdrXmlError::shape;
    for (auto *node=root->FirstChildElement();node;node=node->NextSiblingElement())
        if (std::find(extracted.begin(),extracted.end(),node->Name())==extracted.end())
            candidate.remaining_policy.emplace_back(node->Name());
    if (!scalar(*root->FirstChildElement("panel_min_luminance"),candidate.range.black_nits)||
        !scalar(*root->FirstChildElement("panel_max_luminance"),candidate.range.white_nits)) return HdrXmlError::numeric;
    if (candidate.range.black_nits<0||candidate.range.white_nits<=candidate.range.black_nits||
        candidate.range.white_nits>10000) return HdrXmlError::numeric;
    const auto *tone=root->FirstChildElement("tone_map");
    constexpr std::array<std::string_view,1> points_name{"points"};
    const auto tone_error=container(*tone,points_name);
    if (tone_error!=HdrXmlError::none) return tone_error;
    const auto *points=tone->FirstChildElement("points");
    if (!points||points->FirstAttribute()) return HdrXmlError::shape;
    std::array<float,17> x{},y{};std::size_t nx=0,ny=0;
    for (auto *node=points->FirstChild();node;node=node->NextSibling()) {
        if (node->ToComment()) continue;
        if (const auto *text=node->ToText()) {
            if (!whitespace(text->Value())) return HdrXmlError::shape;
            continue;
        }
        const auto *element=node->ToElement();
        if (!element) return HdrXmlError::shape;
        const std::string_view name=element->Name();
        if (name!="x"&&name!="y") return HdrXmlError::shape;
        auto &at=name=="x"?nx:ny;auto &values=name=="x"?x:y;
        if (at>=17) return HdrXmlError::size;
        if (!scalar(*element,values[at++])) return HdrXmlError::numeric;
    }
    if (compile_hdr_log_curve(std::span(x).first(nx),std::span(y).first(ny),candidate.curve)!=HdrCurveError::none)
        return HdrXmlError::curve;
    const auto *pcc=root->FirstChildElement("panel_pcc");
    constexpr std::array<std::string_view,3> channels{"r","g","b"};
    const auto pcc_error=container(*pcc,channels);
    if (pcc_error!=HdrXmlError::none) return pcc_error;
    std::array<double,33> coefficients{};
    for (std::size_t channel=0;channel<3;++channel) {
        const auto *row=pcc->FirstChildElement(channels[channel].data());
        if (!row) return HdrXmlError::shape;
        const auto row_error=container(*row,hdr_pcc_names);
        if (row_error!=HdrXmlError::none) return row_error;
        for (std::size_t term=0;term<11;++term) {
            const auto *field=row->FirstChildElement(hdr_pcc_names[term].data());
            if (!field) return HdrXmlError::shape;
            if (!scalar(*field,coefficients[channel*11+term])) return HdrXmlError::numeric;
        }
    }
    if (compile_hdr_panel_pcc(coefficients,candidate.pcc)!=HdrPccError::none) return HdrXmlError::pcc;
    candidate.original_xml=xml;
    output=std::move(candidate);
    return HdrXmlError::none;
}
} // namespace o82
#endif
