// SPDX-License-Identifier: MIT
// Offline HDR panel polynomial; no preset data, I/O or display activation.
#ifndef UKE_O82_HDR_PCC_H
#define UKE_O82_HDR_PCC_H
#include <algorithm>
#include <array>
#include <cfenv>
#include <cmath>
#include <cstddef>
#include <limits>
#include <span>
#include <string_view>

namespace o82 {
static_assert(sizeof(float) == 4 && std::numeric_limits<float>::is_iec559 &&
              std::numeric_limits<float>::digits == 24);
static_assert(sizeof(double) == 8 && std::numeric_limits<double>::is_iec559 &&
              std::numeric_limits<double>::digits == 53);
enum class HdrPccTerm : std::size_t { c,r,g,b,rr,gg,bb,rg,gb,rb,rgb };
inline constexpr std::array<std::string_view,11> hdr_pcc_names{
    "c","r","g","b","rr","gg","bb","rg","gb","rb","rgb"};
struct HdrPanelPcc {
    std::array<std::array<double,11>,3> coefficients{};
    bool operator==(const HdrPanelPcc &) const = default;
};
enum class HdrPccError { none,size,nonfinite,range,rounding_mode };
namespace hdr_pcc_detail {
inline float multiply32(float a,float b) { volatile float value=a*b; return value; }
inline double multiply64(double a,double b) { volatile double value=a*b; return value; }
inline double add64(double a,double b) { volatile double value=a+b; return value; }
inline bool valid(const HdrPanelPcc &pcc) {
    for (const auto &row:pcc.coefficients)
        for (const auto value:row) if (!std::isfinite(value)) return false;
    return true;
}
} // namespace hdr_pcc_detail
inline HdrPccError compile_hdr_panel_pcc(std::span<const double> input,HdrPanelPcc &output) {
    if (input.size()!=33) return HdrPccError::size;
    HdrPanelPcc candidate;
    for (std::size_t i=0;i<33;++i) candidate.coefficients[i/11][i%11]=input[i];
    if (!hdr_pcc_detail::valid(candidate)) return HdrPccError::nonfinite;
    output=candidate;
    return HdrPccError::none;
}
inline HdrPccError map_hdr_panel_pcc(const HdrPanelPcc &pcc,
        const std::array<float,3> &input,std::array<float,3> &output) {
    using namespace hdr_pcc_detail;
    if (!valid(pcc)) return HdrPccError::nonfinite;
    for (const float value:input) if (!std::isfinite(value)) return HdrPccError::nonfinite;
    if (std::fegetround()!=FE_TONEAREST) return HdrPccError::rounding_mode;
    const float r=input[0],g=input[1],b=input[2];
    std::array<double,11> basis{};
    basis[1]=r; basis[2]=g; basis[3]=b;
    basis[4]=multiply32(r,r); basis[5]=multiply32(g,g); basis[6]=multiply32(b,b);
    basis[7]=multiply32(r,g); basis[8]=multiply32(g,b); basis[9]=multiply32(r,b);
    basis[10]=multiply32(float(basis[7]),b);
    for (std::size_t i=1;i<basis.size();++i)
        if (!std::isfinite(basis[i])) return HdrPccError::range;
    // Exact accumulation order: linear, rg/gb/rb, squares, rgb, constant.
    constexpr std::array<std::size_t,10> order{1,2,3,7,8,9,4,5,6,10};
    std::array<float,3> candidate;
    for (std::size_t channel=0;channel<3;++channel) {
        const auto &row=pcc.coefficients[channel];
        double value=multiply64(row[order[0]],basis[order[0]]);
        for (std::size_t i=1;i<order.size();++i)
            value=add64(value,multiply64(row[order[i]],basis[order[i]]));
        value=add64(row[0],value);
        if (!std::isfinite(value)) return HdrPccError::range;
        // The inspected caller converts to binary32 before Clipping(0,1).
        volatile float converted=static_cast<float>(value);
        candidate[channel]=std::clamp(float(converted),0.0f,1.0f);
    }
    output=candidate;
    return HdrPccError::none;
}
} // namespace o82
#endif
