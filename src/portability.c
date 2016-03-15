/* -*- Mode: C; tab-width: 4; indent-tabs-mode: nil; c-basic-offset: 4 -*-
 *
 * Copyright © 2014-2016 Michael Catanzaro
 *
 * This program is free software: you can redistribute it and/or modify it under
 * the terms of the GNU General Public License as published by the Free Software
 * Foundation, either version 2 of the License, or (at your option) any later
 * version. See http://www.gnu.org/copyleft/gpl.html the full text of the
 * license.
 */

#include "portability.h"

#if HAVE_LINUX_PRCTL_H
#include <signal.h>

#include <linux/prctl.h>
#include <sys/prctl.h>
#endif

/*
 * When called in the engine process before exec, this ensures
 * the engine is terminated in the event that we crash.
 */
void maybe_kill_orphan_engine ()
{
#if HAVE_LINUX_PRCTL_H
    prctl (PR_SET_PDEATHSIG, SIGTERM);
#endif
}
