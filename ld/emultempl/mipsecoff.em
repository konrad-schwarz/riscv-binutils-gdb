# This shell script emits a C file. -*- C -*-
# It does some substitutions.
if [ -z "$MACHINE" ]; then 
  OUTPUT_ARCH=${ARCH}
else
  OUTPUT_ARCH=${ARCH}:${MACHINE}
fi
cat >e${EMULATION_NAME}.c <<EOF
/* This file is is generated by a shell script.  DO NOT EDIT! */

/* Handle embedded relocs for MIPS.
   Copyright 1994, 1995, 1997, 2000 Free Software Foundation, Inc.
   Written by Ian Lance Taylor <ian@cygnus.com> based on generic.em.

This file is part of GLD, the Gnu Linker.

This program is free software; you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation; either version 2 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program; if not, write to the Free Software
Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA 02111-1307, USA.  */

#define TARGET_IS_${EMULATION_NAME}

#include "bfd.h"
#include "sysdep.h"
#include "bfdlink.h"

#include "ld.h"
#include "ldmain.h"
#include "ldmisc.h"

#include "ldexp.h"
#include "ldlang.h"
#include "ldfile.h"
#include "ldemul.h"

static void gld${EMULATION_NAME}_before_parse PARAMS ((void));
static void gld${EMULATION_NAME}_after_open PARAMS ((void));
static void check_sections PARAMS ((bfd *, asection *, PTR));
static void gld${EMULATION_NAME}_after_allocation PARAMS ((void));
static char *gld${EMULATION_NAME}_get_script PARAMS ((int *isfile));

static void
gld${EMULATION_NAME}_before_parse()
{
#ifndef TARGET_			/* I.e., if not generic.  */
  const bfd_arch_info_type *arch = bfd_scan_arch ("${OUTPUT_ARCH}");
  if (arch)
    {
      ldfile_output_architecture = arch->arch;
      ldfile_output_machine = arch->mach;
      ldfile_output_machine_name = arch->printable_name;
    }
  else
    ldfile_output_architecture = bfd_arch_${ARCH};
#endif /* not TARGET_ */
}

/* This function is run after all the input files have been opened.
   We create a .rel.sdata section for each input file with a non zero
   .sdata section.  The BFD backend will fill in these sections with
   magic numbers which can be used to relocate the data section at run
   time.  This will only do the right thing if all the input files
   have been compiled using -membedded-pic.  */

static void
gld${EMULATION_NAME}_after_open ()
{
  bfd *abfd;

  if (! command_line.embedded_relocs
      || link_info.relocateable)
    return;

  for (abfd = link_info.input_bfds; abfd != NULL; abfd = abfd->link_next)
    {
      asection *datasec;

      /* As first-order business, make sure that each input BFD is ECOFF. It
         better be, as we are directly calling an ECOFF backend function.  */
      if (bfd_get_flavour (abfd) != bfd_target_ecoff_flavour)
	einfo ("%F%B: all input objects must be ECOFF for --embedded-relocs\n");

      datasec = bfd_get_section_by_name (abfd, ".sdata");

      /* Note that we assume that the reloc_count field has already
         been set up.  We could call bfd_get_reloc_upper_bound, but
         that returns the size of a memory buffer rather than a reloc
         count.  We do not want to call bfd_canonicalize_reloc,
         because although it would always work it would force us to
         read in the relocs into BFD canonical form, which would waste
         a significant amount of time and memory.  */
      if (datasec != NULL && datasec->reloc_count > 0)
	{
	  asection *relsec;

	  relsec = bfd_make_section (abfd, ".rel.sdata");
	  if (relsec == NULL
	      || ! bfd_set_section_flags (abfd, relsec,
					  (SEC_ALLOC
					   | SEC_LOAD
					   | SEC_HAS_CONTENTS
					   | SEC_IN_MEMORY))
	      || ! bfd_set_section_alignment (abfd, relsec, 2)
	      || ! bfd_set_section_size (abfd, relsec,
					 datasec->reloc_count * 4))
	    einfo ("%F%B: can not create .rel.sdata section: %E\n");
	}

      /* Double check that all other data sections are empty, as is
         required for embedded PIC code.  */
      bfd_map_over_sections (abfd, check_sections, (PTR) datasec);
    }
}

/* Check that of the data sections, only the .sdata section has
   relocs.  This is called via bfd_map_over_sections.  */

static void
check_sections (abfd, sec, sdatasec)
     bfd *abfd;
     asection *sec;
     PTR sdatasec;
{
  if ((bfd_get_section_flags (abfd, sec) & SEC_CODE) == 0
      && sec != (asection *) sdatasec
      && sec->reloc_count != 0)
    einfo ("%B%X: section %s has relocs; can not use --embedded-relocs\n",
	   abfd, bfd_get_section_name (abfd, sec));
}

/* This function is called after the section sizes and offsets have
   been set.  If we are generating embedded relocs, it calls a special
   BFD backend routine to do the work.  */

static void
gld${EMULATION_NAME}_after_allocation ()
{
  bfd *abfd;

  if (! command_line.embedded_relocs
      || link_info.relocateable)
    return;

  for (abfd = link_info.input_bfds; abfd != NULL; abfd = abfd->link_next)
    {
      asection *datasec, *relsec;
      char *errmsg;

      datasec = bfd_get_section_by_name (abfd, ".sdata");

      if (datasec == NULL || datasec->reloc_count == 0)
	continue;

      relsec = bfd_get_section_by_name (abfd, ".rel.sdata");
      ASSERT (relsec != NULL);

      if (! bfd_mips_ecoff_create_embedded_relocs (abfd, &link_info,
						   datasec, relsec,
						   &errmsg))
	{
	  if (errmsg == NULL)
	    einfo ("%B%X: can not create runtime reloc information: %E\n",
		   abfd);
	  else
	    einfo ("%X%B: can not create runtime reloc information: %s\n",
		   abfd, errmsg);
	}
    }
}

static char *
gld${EMULATION_NAME}_get_script(isfile)
     int *isfile;
EOF

if test -n "$COMPILE_IN"
then
# Scripts compiled in.

# sed commands to quote an ld script as a C string.
sc="-f stringify.sed"

cat >>e${EMULATION_NAME}.c <<EOF
{			     
  *isfile = 0;

  if (link_info.relocateable == true && config.build_constructors == true)
    return
EOF
sed $sc ldscripts/${EMULATION_NAME}.xu                     >> e${EMULATION_NAME}.c
echo '  ; else if (link_info.relocateable == true) return' >> e${EMULATION_NAME}.c
sed $sc ldscripts/${EMULATION_NAME}.xr                     >> e${EMULATION_NAME}.c
echo '  ; else if (!config.text_read_only) return'         >> e${EMULATION_NAME}.c
sed $sc ldscripts/${EMULATION_NAME}.xbn                    >> e${EMULATION_NAME}.c
echo '  ; else if (!config.magic_demand_paged) return'     >> e${EMULATION_NAME}.c
sed $sc ldscripts/${EMULATION_NAME}.xn                     >> e${EMULATION_NAME}.c
echo '  ; else return'                                     >> e${EMULATION_NAME}.c
sed $sc ldscripts/${EMULATION_NAME}.x                      >> e${EMULATION_NAME}.c
echo '; }'                                                 >> e${EMULATION_NAME}.c

else
# Scripts read from the filesystem.

cat >>e${EMULATION_NAME}.c <<EOF
{			     
  *isfile = 1;

  if (link_info.relocateable == true && config.build_constructors == true)
    return "ldscripts/${EMULATION_NAME}.xu";
  else if (link_info.relocateable == true)
    return "ldscripts/${EMULATION_NAME}.xr";
  else if (!config.text_read_only)
    return "ldscripts/${EMULATION_NAME}.xbn";
  else if (!config.magic_demand_paged)
    return "ldscripts/${EMULATION_NAME}.xn";
  else
    return "ldscripts/${EMULATION_NAME}.x";
}
EOF

fi

cat >>e${EMULATION_NAME}.c <<EOF

struct ld_emulation_xfer_struct ld_${EMULATION_NAME}_emulation = 
{
  gld${EMULATION_NAME}_before_parse,
  syslib_default,
  hll_default,
  after_parse_default,
  gld${EMULATION_NAME}_after_open,
  gld${EMULATION_NAME}_after_allocation,
  set_output_arch_default,
  ldemul_default_target,
  before_allocation_default,
  gld${EMULATION_NAME}_get_script,
  "${EMULATION_NAME}",
  "${OUTPUT_FORMAT}",
  NULL,	/* finish */
  NULL,	/* create output section statements */
  NULL,	/* open dynamic archive */
  NULL,	/* place orphan */
  NULL,	/* set symbols */
  NULL,	/* parse args */
  NULL,	/* unrecognized file */
  NULL,	/* list options */
  NULL,	/* recognized file */
  NULL 	/* find_potential_libraries */
};
EOF
