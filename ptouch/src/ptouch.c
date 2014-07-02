/*
 * Copyright (c) 2014 Citrix Systems, Inc.
 * 
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2 of the License, or
 * (at your option) any later version.
 * 
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 * 
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
 */


static char rcsid[] = "$Id: ptouch.c,v 1.2 2011/02/17 10:02:22 root Exp $";

/*
 * $Log: ptouch.c,v $
 * Revision 1.2  2011/02/17 10:02:22  root
 * *** empty log message ***
 *
 * Revision 1.1  2011/02/16 22:24:36  root
 * *** empty log message ***
 *
 */



#include "project.h"

static void
init (FILE * f)
{
  fprintf (f, "\e@");
}

static void
set_density (FILE * f, int d)
{
  fprintf (f, "\eiD%c", d);
}

static void
set_mode (FILE * f, int feed, int auto_cut, int mirror)
{
  int v;

  v = feed & 0x1f;
  if (auto_cut)
    v |= 0x40;
  if (!mirror)
    v |= 0x80;

  fprintf (f, "\eiM%c", v);
}

static void
set_page (FILE * f, int quality, int pre_cut, int width_in_mm,
          int height_in_mm, int lines)
{
  fprintf (f, "\eiz");
  fprintf (f, "%c", quality ? 0x40 : 0);
  fprintf (f, "%c", pre_cut ? 1 : 0);
  fprintf (f, "%c", width_in_mm);
  fprintf (f, "%c", height_in_mm);
  fprintf (f, "%c", lines & 0xff);
  fprintf (f, "%c", lines >> 8);
  fwrite ("\0\0\0", 4, 1, f);
}

static void
send_raster (FILE * f, void *data, int n)
{
  fprintf (f, "g%c%c", n >> 8, n & 0xff);
  fwrite (data, 1, n, f);
}

static void
cutter (FILE * f, int cut)
{
  fprintf (f, "\eiA%c%c", cut ? 1 : 0, 0);
}

void
print_bitmap (FILE * f, bit ** bits, int w, int h, int tape_width_in_mm)
{
  int bpl = 90;
  uint8_t *buf;
  int x, y;
  int o, c;
  int xmargin = (bpl * 8) - 5;

  init (f);
  set_density (f, 3);
  cutter (f, 1);
  set_mode (f, 0, 1, 0);
  set_page (f, 1, 0, tape_width_in_mm, 0, h);
  set_page (f, 1, 0, tape_width_in_mm, 0, h);

  buf = malloc (bpl + 1);       /*Extra byte for dumping extra bits */
  buf++;

  for (y = 0; y < h; ++y)
    {
      memset (buf, 0, bpl);

      c = 1 << (7 - (xmargin & 7));
      o = xmargin >> 3;

      for (x = 0; x < w; ++x)
        {

          if (bits[y][x])
            buf[o] |= c;

          c <<= 1;
          if (!(c & 0xff))
            {
              if (o >= 0)
                o--;
              c = 0x1;
            }
        }
      send_raster (f, buf, bpl);
    }
  fputc (0xc, f);               //Form Feed
  set_mode (f, 0, 1, 0);
  fputc (0x1a, f);              //Eject
}

int
main (int argc, char *argv[])
{
  FILE *f;
  int w, h;
  bit **bits;
  int tape_width;

  if ((argc != 2) && (argc != 3))
    {
      fprintf (stderr,
               "Usage:\n%s tape_width_in_mm [file.pbm] > /dev/usb/lp0\n",
               argv[0]);
      exit (1);
    }

  if (argc == 3)
    {
      f = fopen (argv[2], "r");
  } else
    {
      f = stdin;
    }

  tape_width = atoi (argv[1]);
  if (!tape_width)
    {
      fprintf (stderr, "Invalid tape_width\n");
      exit (1);
    }

  w = h = 0;
  bits = pbm_readpbm (f, &w, &h);

  if (!bits || !w || !h)
    {
      fprintf (stderr, "Failed to read input bitmap\n");
      exit (1);
    }

  print_bitmap (stdout, bits, w, h, tape_width);

  return 0;
}
