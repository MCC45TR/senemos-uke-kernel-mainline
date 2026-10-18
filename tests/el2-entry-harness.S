/* SPDX-License-Identifier: MIT */
	.section .text, "ax"
	.global _start
_start:
	adr	x10, .Lstarted
	mov	x11, #0x09000000
1:
	ldrb	w12, [x10], #1
	cbz	w12, 2f
	str	w12, [x11]
	b	1b
2:
	msr	DAIFSet, #0xf
	mov	x0, #0x40010000
	mov	x1, xzr
	mov	x2, xzr
	mov	x3, xzr
#ifdef BAD_ARGS
	mov	x1, #1
#endif
#ifdef BAD_CACHE
	mrs	x9, CurrentEL
	cmp	x9, #8
	b.ne	1f
	mrs	x10, SCTLR_EL2
	orr	x10, x10, #4
	msr	SCTLR_EL2, x10
	b	2f
1:
	mrs	x10, SCTLR_EL1
	orr	x10, x10, #4
	msr	SCTLR_EL1, x10
2:
	isb
#endif
#ifdef BAD_STAGE2
	mrs	x10, HCR_EL2
	orr	x10, x10, #1
	msr	HCR_EL2, x10
	isb
#endif
#ifdef SECONDARY
	bl	uke_el2_secondary_entry
#else
	bl	uke_el2_primary_entry
#endif
	mov	x10, #0x40010000
	cmp	x0, x10
	b.ne	.Lfailure
	orr	x10, x1, x2
	orr	x10, x10, x3
	cbnz	x10, .Lfailure
	mrs	x10, CurrentEL
	cmp	x10, #8
	b.ne	.Lfailure
	adr	x0, .Lpass
	b	.Lprint
	.global uke_el2_test_refused
uke_el2_test_refused:
	cmp	x0, #EXPECTED_REASON
	b.ne	.Lfailure
	adr	x0, .Lrefused
	b	.Lprint
.Lfailure:
	adr	x0, .Lfail
.Lprint:
	mov	x10, #0x09000000
1:
	ldrb	w11, [x0], #1
	cbz	w11, 2f
	str	w11, [x10]
	b	1b
2:
	mov	x0, #0x20
	adr	x1, .Lexit
	hlt	#0xf000
3:
	wfe
	b	3b
.Lpass: .asciz "UKE_EL2_ENTRY_PASS\n"
.Lstarted: .asciz "UKE_EL2_TEST_STARTED\n"
.Lrefused: .asciz "UKE_EL2_ENTRY_REFUSED\n"
.Lfail: .asciz "UKE_EL2_ENTRY_FAIL\n"
	.balign 8
.Lexit: .quad 0x20026, 0
