/* SPDX-License-Identifier: GPL-2.0-only */
/* Error-only probe diagnostics. All data was cached by the admitted reader. */
#ifndef UKE_CAMERA_ROM_REPORT_H
#define UKE_CAMERA_ROM_REPORT_H

static int cam_cc_crm_rom_report(u32 client, const char *stage, u32 level,
			       int error)
{
	u32 i, words, rates;

	pr_err("Uke camera ROM refusal: stage=%s client=%u level=%u error=%d\n",
	       stage ?: "unknown", client, level, error);
	if (client >= ARRAY_SIZE(cam_cc_crm_native_tables))
		return error;
	words = cam_cc_crm_native_rom_words[client].count;
	rates = cam_cc_crm_native_tables[client].count;
	pr_err("Uke camera ROM cache: client=%u words=%u rates=%u\n",
	       client, words, rates);
	/* A corrupted cache must not turn diagnostics into an out-of-bounds read. */
	if (words > 14 || rates > CAM_CC_CRM_LEVELS)
		return error;
	for (i = 0; i < words; i++)
		pr_err("Uke camera ROM word: client=%u offset=%#x value=%#x\n",
		       client, cam_cc_crm_native_rom_words[client].offsets[i],
		       cam_cc_crm_native_rom_words[client].values[i]);
	for (i = 0; i < rates; i++)
		pr_err("Uke camera ROM rate: client=%u level=%u hz=%llu source=%u\n",
		       client, i + 1,
		       (unsigned long long)cam_cc_crm_native_tables[client].rates[i].hz,
		       cam_cc_crm_native_tables[client].rates[i].source);
	return error;
}

#endif /* UKE_CAMERA_ROM_REPORT_H */
