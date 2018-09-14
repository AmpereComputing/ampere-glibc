/* Copyright (C) 2012-2018 Free Software Foundation, Inc.

   This file is part of the GNU C Library.

   The GNU C Library is free software; you can redistribute it and/or
   modify it under the terms of the GNU Lesser General Public
   License as published by the Free Software Foundation; either
   version 2.1 of the License, or (at your option) any later version.

   The GNU C Library is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
   Lesser General Public License for more details.

   You should have received a copy of the GNU Lesser General Public
   License along with the GNU C Library.  If not, see
   <http://www.gnu.org/licenses/>.  */

#include <sysdep.h>
#include "memset-reg.h"

#ifndef MEMSET
# define MEMSET memset
#endif

/* Assumptions:
 *
 * ARMv8-a, AArch64, unaligned accesses
 *
 */

ENTRY_ALIGN (MEMSET, 6)

	DELOUSE (0)
	DELOUSE (2)

	bfi	valw, valw, 8, 8
	bfi	valw, valw, 16, 16
	bfi	val, val, 32, 32

1:	add	dstend, dstin, count

	cmp	count, 96
	b.hi	L(set_long)
	cmp	count, 16
	b.hs	L(set_medium)

	/* Set 0..15 bytes.  */
	tbz	count, 3, 1f
	str	val, [dstin]
	str	val, [dstend, -8]
	ret

	.p2align 3
1:	tbz	count, 2, 2f
	str	valw, [dstin]
	str	valw, [dstend, -4]
	ret
2:	cbz	count, 3f
	strb	valw, [dstin]
	tbz	count, 1, 3f
	strh	valw, [dstend, -2]
3:	ret

	.p2align 3
	/* Set 16..96 bytes.  */
L(set_medium):
	stp	val, val, [dstin]
	tbnz	count, 6, L(set96)
	stp	val, val, [dstend, -16]
	tbz	count, 5, 1f
	stp	val, val, [dstin, 16]
	stp	val, val, [dstend, -32]
1:	ret

	.p2align 4
	/* Set 64..96 bytes.  Write 64 bytes from the start and
	   32 bytes from the end.  */
L(set96):
	stp	val, val, [dstin, 16]
	stp	val, val, [dstin, 32]
	stp	val, val, [dstin, 48]
	stp	val, val, [dstend, -32]
	stp	val, val, [dstend, -16]
	ret

	.p2align 3
L(set_long):
	stp	val, val, [dstin]
	bic	dst, dstin, 15
#	cmp	count, 512
#	ccmp	val, 0, 0, cs
#	b.eq	L(try_zva)
L(no_zva):
	sub	count, dstend, dst	/* Count is 16 too large.  */
	sub	count, count, 64+16+1	/* Adjust count and bias for loop.  */
1:	stp	val, val, [dst, 16]
	stp	val, val, [dst, 32]
	stp	val, val, [dst, 48]
	stp	val, val, [dst, 64]!
L(tail64):
	subs	count, count, 64
	b.hs	1b
	tbz	count, 5, 1f
	stp	val, val, [dst, 16]
	stp	val, val, [dst, 32]
1:	stp	val, val, [dstend, -32]
	stp	val, val, [dstend, -16]
	ret

L(try_zva):
#ifdef ZVA_MACRO
	zva_macro
#else
	.p2align 3
	mrs	tmp1, dczid_el0
	tbnz	tmp1w, 4, L(no_zva)
	and	tmp1w, tmp1w, 15
	cmp	tmp1w, 4	/* ZVA size is 64 bytes.  */
	b.ne	 L(zva_128)

L(zva_64):
	stp	val, val, [dst, 16]
	stp	val, val, [dst, 32]
	stp	val, val, [dst, 48]
	bic	dst, dst, 63

	/*
	 * Above memory writes might cross cache line boundary, and cause a
	 * partially dirty cache line. But it seems that DC ZVA can not handle
	 * zeroing of partial dirty cache line efficiently, probably it still
	 * requires load of untouched part of the cache line before zeroing.
	 *
	 * Write the first 64 byte aligned block using stp to force a fully
	 * dirty cache line.
	 */
	stp	val, val, [dst, 64]
	stp	val, val, [dst, 80]
	stp	val, val, [dst, 96]
	stp	val, val, [dst, 112]

	sub	count, dstend, dst	/* Count is now 128 too large.	*/
	sub	count, count, 128+64+64+1	/* Adjust count and bias for loop.  */
	add	dst, dst, 128
1:	dc	zva, dst
	add	dst, dst, 64
	subs	count, count, 64
	b.hs	1b

	/*
	 * Write the last 64 byte aligned block using stp to force a fully
	 * dirty cache line.
	 */
	stp	val, val, [dst, 0]
	stp	val, val, [dst, 16]
	stp	val, val, [dst, 32]
	stp	val, val, [dst, 48]

	tbz	count, 5, 1f
	stp	val, val, [dst, 64]
	stp	val, val, [dst, 80]
1:	stp	val, val, [dstend, -32]
	stp	val, val, [dstend, -16]
	ret

	.p2align 3
L(zva_128):
	cmp	tmp1w, 5	/* ZVA size is 128 bytes.  */
	b.ne	L(zva_other)

	stp	val, val, [dst, 16]
	stp	val, val, [dst, 32]
	stp	val, val, [dst, 48]
	stp	val, val, [dst, 64]
	stp	val, val, [dst, 80]
	stp	val, val, [dst, 96]
	stp	val, val, [dst, 112]
	bic	dst, dst, 127
	sub	count, dstend, dst	/* Count is now 128 too large.	*/
	sub	count, count, 128+128+1	/* Adjust count and bias for loop.  */
1:	add	dst, dst, 128
	dc	zva, dst
	subs	count, count, 128
	b.hs	1b
	tbz	count, 6, 1f
	stp	val, val, [dst, 128]
	stp	val, val, [dst, 144]
	stp	val, val, [dst, 160]
	stp	val, val, [dst, 176]
1:	stp	val, val, [dstend, -64]
	stp	val, val, [dstend, -48]
	stp	val, val, [dstend, -32]
	stp	val, val, [dstend, -16]
	ret

L(zva_other):
	mov	tmp2w, 4
	lsl	zva_lenw, tmp2w, tmp1w
	add	tmp1, zva_len, 64	/* Max alignment bytes written.	 */
	cmp	count, tmp1
	b.lo	L(no_zva)

	sub	tmp2, zva_len, 1
	add	tmp1, dst, zva_len
	bic	tmp1, tmp1, tmp2	/* Aligned dc zva start address.  */
	add	dst, dst, 16
	subs	count, tmp1, dst	/* Actual alignment bytes to write.  */
	beq	2f
1:	stp	val, val, [dst], 64
	stp	val, val, [dst, -48]
	stp	val, val, [dst, -32]
	stp	val, val, [dst, -16]
	subs	count, count, 64
	b.hi	1b
2:	mov	dst, tmp1
	sub	count, dstend, tmp1	/* Remaining bytes to write.  */
	subs	count, count, zva_len
	b.lo	4f
3:	dc	zva, dst
	add	dst, dst, zva_len
	subs	count, count, zva_len
	b.hs	3b
	cbnz	count, 4f
    ret
4:	add	count, count, tmp2
	sub	dst, dst, 16
	b	L(tail64)
#endif

END (MEMSET)
libc_hidden_builtin_def (MEMSET)
