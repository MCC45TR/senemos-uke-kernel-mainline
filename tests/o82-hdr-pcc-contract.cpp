// SPDX-License-Identifier: MIT
// Synthetic polynomial inputs; independent integer binary32/binary64 model.
#include "o82-hdr-pcc.h"
#include <bit>
#include <cassert>
#include <cstdint>
#include <cstdio>
#include <cstring>
namespace {
using Wide = unsigned __int128;
struct Binary { bool negative = false; std::uint64_t mantissa = 0; int power = 0; };
unsigned bits(Wide value) { unsigned n = 0; while (value) { value >>= 1; ++n; } return n; }
Binary raw_float(std::uint32_t raw) {
    const auto exponent = (raw >> 23) & 255;
    assert(exponent != 255);
    return {bool(raw >> 31), (raw & 0x7fffff) | (exponent ? 0x800000u : 0),
            exponent ? int(exponent) - 150 : -149};
}
// Independently round a rational times a power of two to binary32/binary64.
// No floating-point arithmetic supplies any oracle result.
Binary rounded(bool negative, Wide numerator, Wide denominator, int power,
               unsigned precision = 24) {
    assert(denominator && (precision == 24 || precision == 53));
    if (!numerator) return {};
    int order = int(bits(numerator)) - int(bits(denominator));
    if (order >= 0 ? numerator < (denominator << order) :
                     (numerator << -order) < denominator) --order;
    const int minimum_power = precision == 24 ? -149 : -1074;
    int result_power = std::max(order + power - int(precision) + 1, minimum_power);
    const int shift = power - result_power;
    if (shift >= 0) {
        assert(bits(numerator) + shift <= 127);
        numerator <<= shift;
    } else {
        // An input much smaller than half of the smallest subnormal rounds0.
        if (bits(denominator) + unsigned(-shift) > 127) return {};
        denominator <<= -shift;
    }
    auto quotient = numerator / denominator, remainder = numerator % denominator;
    quotient += remainder > denominator / 2 ||
                (!(denominator & 1) && remainder == denominator / 2 && (quotient & 1));
    if (quotient == (Wide(1) << precision)) { quotient >>= 1; ++result_power; }
    assert(quotient < (Wide(1) << precision));
    return {negative, std::uint64_t(quotient), result_power};
}
Binary convert(Binary in, unsigned precision = 24) {
    return rounded(in.negative, in.mantissa, 1, in.power, precision);
}
Binary plus(Binary a, Binary b, unsigned precision = 24) {
    if (!a.mantissa) return convert(b, precision);
    if (!b.mantissa) return convert(a, precision);
    if (std::abs(a.power - b.power) > 100) return convert(a.power > b.power ? a : b, precision);
    const int power = std::min(a.power, b.power);
    assert(bits(a.mantissa) + unsigned(a.power - power) <= 127);
    assert(bits(b.mantissa) + unsigned(b.power - power) <= 127);
    const Wide x = Wide(a.mantissa) << (a.power - power), y = Wide(b.mantissa) << (b.power - power);
    if (a.negative == b.negative) return rounded(a.negative, x + y, 1, power, precision);
    return x >= y ? rounded(a.negative, x - y, 1, power, precision) :
                    rounded(b.negative, y - x, 1, power, precision);
}
Binary times(Binary a, Binary b, unsigned precision = 24) {
    return rounded(a.negative != b.negative, Wide(a.mantissa) * b.mantissa, 1,
                   a.power + b.power, precision);
}
Binary divided(Binary a, Binary b, unsigned precision = 24) {
    assert(b.mantissa);
    return rounded(a.negative != b.negative, a.mantissa, b.mantissa,
                   a.power - b.power, precision);
}
std::uint32_t encode(Binary value) {
    if (!value.mantissa) return 0;
    const int top = int(std::bit_width(value.mantissa)) - 1;
    const int exponent = top + value.power;
    assert(exponent <= 127);
    const auto sign = std::uint32_t(value.negative) << 31;
    if (exponent < -126) {
        const int shift = value.power + 149;
        assert(shift >= 0 && shift < 24);
        return sign | std::uint32_t(value.mantissa << shift);
    }
    const auto mantissa = value.mantissa << (23 - top);
    return sign | (std::uint32_t(exponent + 127) << 23) |
           (std::uint32_t(mantissa) & 0x7fffffu);
}
Binary binary(float value) { return raw_float(std::bit_cast<std::uint32_t>(value)); }
Binary binary(double value) {
    const auto raw=std::bit_cast<std::uint64_t>(value);const auto exponent=(raw>>52)&2047;
    assert(exponent!=2047);
    return {bool(raw>>63),(raw&0xfffffffffffffu)|(exponent?0x10000000000000u:0),
            exponent?int(exponent)-1075:-1074};
}
unsigned pcc_cases=0,pcc_refusals=0,wide_basis_differences=0;
std::array<float,3> reference(const o82::HdrPanelPcc &pcc,const std::array<float,3> &rgb,bool wide=false) {
    std::array<Binary,11> term{};term[1]=binary(rgb[0]);term[2]=binary(rgb[1]);term[3]=binary(rgb[2]);
    const unsigned precision=wide?53:24;
    term[4]=times(term[1],term[1],precision);term[5]=times(term[2],term[2],precision);
    term[6]=times(term[3],term[3],precision);term[7]=times(term[1],term[2],precision);
    term[8]=times(term[2],term[3],precision);term[9]=times(term[1],term[3],precision);
    term[10]=times(wide?convert(term[7],24):term[7],term[3],precision);
    std::array<float,3> output;
    for (unsigned row=0;row<3;++row) {
        const auto &c=pcc.coefficients[row];
        // Independently model the inspected instruction chain with integer
        // significands. No native float multiply/add supplies oracle values.
        auto v=plus(times(binary(c[1]),term[1],53),times(binary(c[2]),term[2],53),53);
        v=plus(v,times(binary(c[3]),term[3],53),53);
        v=plus(v,times(binary(c[7]),term[7],53),53);
        v=plus(v,times(binary(c[8]),term[8],53),53);
        v=plus(v,times(binary(c[9]),term[9],53),53);
        v=plus(v,times(binary(c[4]),term[4],53),53);
        v=plus(v,times(binary(c[5]),term[5],53),53);
        v=plus(v,times(binary(c[6]),term[6],53),53);
        v=plus(v,times(binary(c[10]),term[10],53),53);
        v=plus(binary(c[0]),v,53);
        output[row]=std::clamp(std::bit_cast<float>(encode(convert(v,24))),0.0f,1.0f);
    }
    return output;
}
bool equal(const std::array<float,3> &a,const std::array<float,3> &b) {
    for (unsigned i=0;i<3;++i)
        if (!(a[i]==0&&b[i]==0)&&std::bit_cast<std::uint32_t>(a[i])!=std::bit_cast<std::uint32_t>(b[i])) return false;
    return true;
}
void verify(const o82::HdrPanelPcc &pcc,const std::array<float,3> &rgb) {
    std::array<float,3> actual{123,456,789};
    assert(o82::map_hdr_panel_pcc(pcc,rgb,actual)==o82::HdrPccError::none);
    const auto expected=reference(pcc,rgb);
    assert(equal(actual,expected));pcc_cases++;
    wide_basis_differences+=!equal(expected,reference(pcc,rgb,true));
}
std::uint32_t seed=0x7635b928u;
std::uint32_t random_word() { seed^=seed<<13;seed^=seed>>17;seed^=seed<<5;return seed; }
bool generated(unsigned trials,bool control=false) {
    for (unsigned trial=0;trial<trials;++trial) {
        o82::HdrPanelPcc pcc;
        for (auto &row:pcc.coefficients) {
            row[0]=0.5;
            for (unsigned i=1;i<11;++i) row[i]=double(int(random_word()%33)-16)/512;
        }
        const std::array<float,3> rgb{
            float(random_word()%200000)/133333-0.25f,
            float(random_word()%200000)/133333-0.25f,
            float(random_word()%200000)/133333-0.25f};
        if (control) {
            std::array<float,3> actual{};
            if (o82::map_hdr_panel_pcc(pcc,rgb,actual)!=o82::HdrPccError::none) return false;
            if (!equal(actual,reference(pcc,rgb))) return true;
        } else verify(pcc,rgb);
    }
    return false;
}
void basis_and_boundaries() {
    for (unsigned channel=0;channel<3;++channel)
        for (unsigned term=0;term<11;++term) {
            o82::HdrPanelPcc pcc;pcc.coefficients[channel][term]=0.75;
            for (const auto rgb:{std::array<float,3>{0,0,0},{1,1,1},{.25f,.5f,.75f},
                                {-.5f,1.25f,.125f}}) verify(pcc,rgb);
        }
    o82::HdrPanelPcc identity;
    for (unsigned c=0;c<3;++c) identity.coefficients[c][c+1]=1;
    for (const auto rgb:{std::array<float,3>{0,0,0},{1,1,1},{-.25f,1.25f,.5f}}) verify(identity,rgb);
    o82::HdrPanelPcc cancelled;
    cancelled.coefficients[0][1]=1;cancelled.coefficients[0][2]=-1;
    std::array<float,3> out{};
    assert(o82::map_hdr_panel_pcc(cancelled,{2,1.5f,0},out)==o82::HdrPccError::none&&out[0]==0.5f);
    verify(cancelled,{2,1.5f,0});
    o82::HdrPanelPcc ordered;
    ordered.coefficients[0][0]=0.25;ordered.coefficients[0][1]=0x1p54;
    ordered.coefficients[0][2]=-0x1p54;ordered.coefficients[0][3]=0.5;
    assert(o82::map_hdr_panel_pcc(ordered,{1,1,1},out)==o82::HdrPccError::none&&out[0]==0.75f);
    verify(ordered,{1,1,1});
    ordered={};ordered.coefficients[0][0]=0.25;ordered.coefficients[0][1]=0x1p54;
    ordered.coefficients[0][7]=-0x1p54;ordered.coefficients[0][4]=0.5;
    assert(o82::map_hdr_panel_pcc(ordered,{1,1,1},out)==o82::HdrPccError::none&&out[0]==0.75f);
    verify(ordered,{1,1,1});
    std::array<double,33> values{};values[1]=values[13]=values[25]=1;
    o82::HdrPanelPcc compiled;
    assert(o82::compile_hdr_panel_pcc(values,compiled)==o82::HdrPccError::none&&compiled==identity);pcc_cases++;
}
void refusals() {
    using E=o82::HdrPccError;
    std::array<double,33> values{};o82::HdrPanelPcc pcc;
    const auto original=pcc;
    assert(o82::compile_hdr_panel_pcc(std::span(values).first(32),pcc)==E::size&&pcc==original);pcc_refusals++;
    for (const double invalid:{std::numeric_limits<double>::quiet_NaN(),
            std::numeric_limits<double>::infinity(),-std::numeric_limits<double>::infinity()}) {
        for (unsigned i=0;i<33;++i) {
            values[i]=invalid;
            assert(o82::compile_hdr_panel_pcc(values,pcc)==E::nonfinite&&pcc==original);pcc_refusals++;
            values[i]=0;
        }
    }
    std::array<float,3> output{123,456,789};const auto preserved=output;
    for (unsigned c=0;c<3;++c) {
        for (const float invalid:{std::numeric_limits<float>::quiet_NaN(),
                std::numeric_limits<float>::infinity(),-std::numeric_limits<float>::infinity()}) {
            std::array<float,3> rgb{};rgb[c]=invalid;
            assert(o82::map_hdr_panel_pcc(pcc,rgb,output)==E::nonfinite&&output==preserved);pcc_refusals++;
        }
    }
    pcc.coefficients[2][10]=std::numeric_limits<double>::quiet_NaN();
    assert(o82::map_hdr_panel_pcc(pcc,{0,0,0},output)==E::nonfinite&&output==preserved);pcc_refusals++;
    pcc={};
    assert(o82::map_hdr_panel_pcc(pcc,{1e30f,0,0},output)==E::range&&output==preserved);pcc_refusals++;
    pcc.coefficients[2][1]=pcc.coefficients[2][2]=std::numeric_limits<double>::max();
    assert(o82::map_hdr_panel_pcc(pcc,{1,1,0},output)==E::range&&output==preserved);pcc_refusals++;
    pcc={};assert(!std::fesetround(FE_UPWARD));
    assert(o82::map_hdr_panel_pcc(pcc,{0,0,0},output)==E::rounding_mode&&output==preserved);pcc_refusals++;
    assert(!std::fesetround(FE_TONEAREST));
}
} // namespace
int main(int argc,char **argv) {
    if (argc==2&&!std::strcmp(argv[1],"--cross-precision-control")) {
        if (generated(50000,true)) { std::puts("Required PCC cross-product precision assertion rejected mutant");return 43; }
        return 0;
    }
    assert(argc==1&&std::fegetround()==FE_TONEAREST);
    basis_and_boundaries();refusals();generated(25000);
    assert(wide_basis_differences>100);
    std::printf("HDR PCC: %u exact integer-oracle cases, %u refusals, %u wider-basis differences\n",
                pcc_cases,pcc_refusals,wide_basis_differences);
    return 0;
}
