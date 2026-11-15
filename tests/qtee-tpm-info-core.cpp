// SPDX-License-Identifier: GPL-2.0-only
// Same production core, bounded transport doubles; no firmware or device call.
#include "qtee-tpm-info-core.h"
#include <array>
#include <cstdint>
#include <iostream>
#include <map>
#include <stdexcept>

#ifndef __aarch64__
#error Native AArch64 qualification required
#endif
namespace {
void need(bool value) { if (!value) throw std::runtime_error("QTEE kernel-core fixture assertion"); }
enum class Fault {
 None, Begin, EnvironmentTransport, EnvironmentRemote, EnvironmentNull, EnvironmentErrorObject,
 ServiceTransport, ServiceRemote, ServiceNull, ServiceErrorObject, VersionTransport,
 VersionRemote, VersionShort, VersionLong, VersionStatus, VersionEcho, TypeTransport,
 TypeRemote, TypeShort, TypeLong, TypeStatus, TypeEcho, TypeUnknown, TypeNoReply,
};
struct Model {
 Fault fault = Fault::None;
 bool context = false;
 unsigned begins = 0, ends = 0, environments = 0, services = 0, queries = 0, releases = 0;
 std::uint32_t type = 0x6654504d;
 std::map<std::uintptr_t, unsigned> live;
 void* object(std::uintptr_t id) { ++live[id]; return reinterpret_cast<void*>(id); }
};
Model& model(void* c) { return *static_cast<Model*>(c); }
void put(unsigned char* p, size_t at, std::uint32_t value) {
 for (unsigned i = 0; i < 4; ++i) p[at+i] = value >> (i*8);
}
int begin(void* c) {
 auto& m = model(c); need(++m.begins == 1 && !m.context && m.live.empty());
 if (m.fault == Fault::Begin) return -12;
 m.context = true; return 0;
}
int environment(void* c, void** object, int* remote) {
 auto& m = model(c); need(m.context && ++m.environments == 1 && !*object && !*remote);
 if (m.fault == Fault::EnvironmentTransport) return -4;
 if (m.fault == Fault::EnvironmentRemote) { *remote = 11; return 0; }
 if (m.fault == Fault::EnvironmentNull) return 0;
 *object = m.object(2);
 if (m.fault == Fault::EnvironmentErrorObject) { *remote = 11; return 0; }
 return 0;
}
int service(void* c, void* env, void** object, int* remote) {
 auto& m = model(c); need(m.context && ++m.services == 1 && env == reinterpret_cast<void*>(2) &&
                        m.live.contains(2) && !*object && !*remote);
 if (m.fault == Fault::ServiceTransport) return -4;
 if (m.fault == Fault::ServiceRemote) { *remote = 11; return 0; }
 if (m.fault == Fault::ServiceNull) return 0;
 *object = m.object(3);
 if (m.fault == Fault::ServiceErrorObject) { *remote = 11; return 0; }
 return 0;
}
int query(void* c, void* object, __u32 command, __u8* response, __u32* bytes, int* remote) {
 auto& m = model(c);
 need(m.context && object == reinterpret_cast<void*>(3) && m.live.contains(3) && !*remote && *bytes == 12);
 need(command == (++m.queries == 1 ? 0x1000u : 0x80000u) && m.queries <= 2);
 for (unsigned i = 0; i < 12; ++i) need(response[i] == 0);
 if (m.queries == 1) {
  if (m.fault == Fault::VersionTransport) return -4;
  if (m.fault == Fault::VersionRemote) { *remote = 11; return 0; }
  put(response, 0, m.fault == Fault::VersionStatus ? 1 : 0);
  put(response, 4, m.fault == Fault::VersionEcho ? 3 : 0x1000);
  put(response, 8, 0xffffabcd);
  if (m.fault == Fault::VersionShort) *bytes = 11;
  if (m.fault == Fault::VersionLong) *bytes = 13;
 } else {
  if (m.fault == Fault::TypeTransport) return -4;
  if (m.fault == Fault::TypeRemote) { *remote = 11; return 0; }
  if (m.fault == Fault::TypeNoReply) return 0;
  put(response, 0, m.fault == Fault::TypeEcho ? 3 : 0x80000);
  put(response, 4, m.fault == Fault::TypeStatus ? 1 : 0);
  put(response, 8, m.fault == Fault::TypeUnknown ? 0 : m.type);
  if (m.fault == Fault::TypeShort) *bytes = 11;
  if (m.fault == Fault::TypeLong) *bytes = 13;
 }
 return 0;
}
void release(void* c, void* object) {
 auto& m = model(c); const auto id = reinterpret_cast<std::uintptr_t>(object);
 need(m.context && m.live.contains(id) && m.live[id] > 0);
 // Teardown must release service before the environment.
 if (id == 2) need(!m.live.contains(3));
 if (--m.live[id] == 0) m.live.erase(id);
 ++m.releases;
}
void end(void* c) {
 auto& m = model(c); need(++m.ends == 1 && m.live.empty()); m.context = false;
}
constexpr uke_qtee_info_ops operations{begin, environment, service, query, release, end};
}
int main() {
 unsigned refused = 0, successes = 0;
 auto run = [&](Fault fault, std::uint32_t kind) {
  Model m; m.fault = fault; m.type = kind;
  uke_qtee_info_report report{};
  uke_qtee_info_run(&operations, &m, &report);
  need(m.begins == 1 && m.ends == 1 && !m.context && m.live.empty());
  need(report.invocation_attempts == m.environments + m.services + m.queries && report.vendor_queries == m.queries);
  if (fault == Fault::None) {
   need(report.stage == UKE_QTEE_INFO_DONE && !report.transport && !report.remote && !report.malformed);
   need(report.major == 0xffff && report.minor == 0xabcd && report.invocation_attempts == 4 && report.vendor_queries == 2 && m.releases == 2);
   need(report.kind == (kind == 0x6654504d ? UKE_QTEE_INFO_FIRMWARE : kind == 0x6454504d ? UKE_QTEE_INFO_DISCRETE : UKE_QTEE_INFO_NONE));
   ++successes;
  } else {
   need(report.stage != UKE_QTEE_INFO_DONE && (report.transport || report.remote || report.malformed));
   const auto f = static_cast<unsigned>(fault);
   const auto stage = f == 1 ? UKE_QTEE_INFO_CONTEXT : f <= 5 ? UKE_QTEE_INFO_ENVIRONMENT :
    f <= 9 ? UKE_QTEE_INFO_SERVICE : f <= 15 ? UKE_QTEE_INFO_VERSION : UKE_QTEE_INFO_TYPE;
   need(report.stage == stage && report.kind == UKE_QTEE_INFO_UNKNOWN);
   ++refused;
  }
 };
 for (const auto kind : {0x6654504du, 0x6454504du, 0x4e6f6e65u}) run(Fault::None, kind);
 for (unsigned value = 1; value <= static_cast<unsigned>(Fault::TypeNoReply); ++value) run(static_cast<Fault>(value), 0x6654504d);
 std::cout << "{\"same_production_core\":true,\"transport_doubled\":true,\"positive_types\":" << successes <<
  ",\"refused_cases\":" << refused << ",\"all_owned_references_released\":true,\"no_automatic_retry\":true,\"previous_reply_cleared\":true,\"firmware_called\":false,\"physical_tpm_qualified\":false}\n";
}
