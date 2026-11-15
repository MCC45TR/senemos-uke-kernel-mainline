/* SPDX-License-Identifier: GPL-2.0-only */
#ifndef UKE_QTEE_TPM_INFO_H
#define UKE_QTEE_TPM_INFO_H
struct qcomtee;
void uke_qtee_tpm_info_attach(struct qcomtee *qcomtee);
void uke_qtee_tpm_info_detach(struct qcomtee *qcomtee);
#endif
