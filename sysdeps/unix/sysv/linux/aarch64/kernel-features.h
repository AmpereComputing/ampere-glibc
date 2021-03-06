/* Set flags signalling availability of kernel features based on given
   kernel version number.  AArch64 version.
   Copyright (C) 2018 Free Software Foundation, Inc.
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
   License along with the GNU C Library; if not, see
   <http://www.gnu.org/licenses/>.  */

#include_next <kernel-features.h>

#undef __ASSUME_CLONE_DEFAULT
#define __ASSUME_CLONE_BACKWARDS 1

#ifdef __ILP32__
/* ARM fadvise64_64 reorganize the syscall arguments.  */
# define __ASSUME_FADVISE64_64_6ARG	1

/* Define this if your 32-bit syscall API requires 64-bit register
   pairs to start with an even-number register.  */
# define __ASSUME_ALIGNED_REGISTER_PAIRS	1
#endif /* __ILP32__ */
