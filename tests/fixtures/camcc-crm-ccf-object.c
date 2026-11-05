// SPDX-License-Identifier: GPL-2.0-only
/* Unlinked COPR object: compile actual complete provider and admission adapters. */
#define UKE_CAMCC_OBJECT_TEST
#include "camcc-sm7675.c"

int uke_camcc_crm_ccf_attach_check(struct cam_cc_crm_clock *, struct cam_cc_crm_transport *);
int uke_camcc_crm_transport_vote_check(struct cam_cc_crm_transport *, u32, u32, u32);

int uke_camcc_crm_ccf_attach_check(struct cam_cc_crm_clock *clients,
				struct cam_cc_crm_transport *transport)
{
	int ret = cam_cc_crm_ccf_attach(clients);

	return ret ? ret : cam_cc_crm_pm_bind(transport);
}

int uke_camcc_crm_transport_vote_check(struct cam_cc_crm_transport *transport,
				     u32 kind, u32 resource, u32 value)
{
	return cam_cc_crm_transport_vote(transport, kind, resource, value);
}
