# LunaBSD look and feel

How LunaBSD looks, and where each piece comes from. All artwork is
original and drawn from code by [`branding/make-art.py`](../branding/make-art.py):
change the script, run it, commit what it writes.

```sh
python3 branding/make-art.py     # needs Pillow, fontTools, rsvg-convert, IBM Plex
```

## The idea

Printed matter on an instrument: a parchment page with a fine measuring
grid, dark ink, thin rules, square markers, and menus where the chosen line
is swept in ink. The installer's interaction language is inspired by the
menus of NieR:Automata (no assets of the game are used: the palette, shapes,
type and code are LunaBSD's own). Restraint over decoration: one mark, one
grid, one accent colour that only appears when something is dangerous.

## The mark

A crescent inside an instrument ring, with one small square on the ring and
two short ticks (west and south). The crescent is the moon (Luna); the ring
and ticks make it an instrument rather than a picture; the square is the
marker that recurs everywhere in the interface.

| File | Use |
|---|---|
| `branding/lunabsd-logo.svg` | the mark, ink: light backgrounds |
| `branding/lunabsd-logo-reverse.svg` | the mark, paper: dark backgrounds |
| `branding/lunabsd-logo-small.svg` | 16 to 32 px: crescent and square only (the ring would blur) |
| `branding/lunabsd-wordmark.svg` | LUNABSD: LUNA in Plex Sans Medium, BSD in Light, tracking 0.32 em, outlined |
| `branding/lunabsd-lockup.svg`, `-reverse.svg` | mark, a rule, the wordmark |

Keep clear space of a quarter of the ring's diameter around the mark. Do not
recolour it other than ink or paper, add effects, or redraw the crescent.

## Colour

| Token | Hex | Use |
|---|---|---|
| Parchment | `#D1CDB7` | page background |
| Grid | `#CAC5AE` | the 8 px grid on parchment |
| Paper | `#DCD8C0` | raised surfaces (panels, fields); text on ink |
| Weak | `#BAB5A1` | hard offset shadows, washes, quiet rules |
| Soft | `#58544A` | secondary text (4.7:1 on parchment) |
| Ink | `#454138` | text, header strips, chosen rows, rules (6.4:1) |
| Signal | `#8A3322` | erasing a disk, errors (5.1:1) |
| Ochre | `#5E4A1C` | limitations, notes that need attention (5.3:1) |
| Night | `#211F1A` | dark backgrounds (night wallpaper, terminal) |

Text colours meet WCAG AA (4.5:1) on parchment and on paper. Status is never
colour alone: it is also a word (OK, NOTE, LIMITED, NO) or a shape.

## Type

IBM Plex Sans (interface) and IBM Plex Mono (codes, sizes, progress, logs);
both under the SIL Open Font License, packaged by FreeBSD as `plex-ttf`.
Capitals with wide tracking for short labels and titles only; sentence case
for everything people read.

## Where it appears

| Place | What | Source |
|---|---|---|
| Boot menu | ASCII wordmark and crescent (the moon in colour). FreeBSD's loader keeps UEFI screens in text mode by default (`efi_max_resolution="1x1"`); with a graphics resolution set, the same menu shows the PNG pictures instead | `branding/loader/` (`brand-luna.lua`, `logo-luna.lua`, `lunabsd-brand.png`, `lunabsd-logo.png`) |
| Live USB and installer | the whole design system | `installer/qml/` |
| Desktop | wallpaper: parchment by day, night with a dark colour scheme (Plasma's `images_dark`) | `branding/lunabsd-wallpaper*.jpg` |
| Login screen | parchment wallpaper as SDDM background | `lib/branding.sh` |
| About this System | name, logo, website | `/etc/xdg/kcm-about-distrorc` |
| Terminal | fastfetch logo (blocks and braille, two colours) and key colours | `branding/fastfetch-logo.txt`, `files/shell/fastfetch.jsonc` |
| `os-release` | `NAME=LunaBSD`, `ID=lunabsd`, `ID_LIKE=freebsd`, `LOGO=lunabsd` | `files/rc.d/lunabsd_osrelease` |

## The terminal logo

What `fastfetch` shows (two colours: the moon in paper, the ring in a
darker tone; generated, like everything else, from the mark's geometry):

```
           ⣀⡤⠤⠖⠒⠒⠒⠒⠲⠤⢤⣀
       ⢀⡤⠚⠉            ⠉⠓⢤⡀
     ⢀⠔⠉   ⣀▄⡶⠂            ⢠⣤⣤
    ⡴⠃  ⢀▄███              ⠸⠿⠿
   ⡞   ▄████                  ⢰
  ⡼   █████⡇                   ⢧
 ⢠⠇  ⢸█████⡇                   ⠸⡄
 ⢸   ███████                    ⡇
 ⢸   ███████▄                   ⡇
 ⠘⡆  ⢸████████⡀                ⢰⠃
  ⢳   ██████████▄⡀        ⣀⡔   ⡞
   ⢧   ▀██████████████████▀   ⡼
    ⠳⡄  ⠈▀██████████████▀⠁  ⢠⠞
     ⠈⠢⣀   ⠉▀████████▀⠉   ⣀⠔⠁
       ⠈⠓⢤⣀            ⣀⡤⠚⠁
           ⠉⠓⠒⠦⠤⠤⠤⠤⠴⠒⠚⠉
```

## The installer's components

`installer/qml/`: `Panel` (paper, ink header strip, hard offset shadow),
`MenuRow` (square marker; band above and below on hover; ink sweep when
chosen), `LButton` (the same sweep), `LField` (label above, problem below),
`Segmented`, `LSlider` (ruled, square handle), `StatusTag`, `Meter`
(segments), `Busy`, `PageHeader` (light wide capitals, offset shadow,
decoding into place), `LPage` (margins, scrolling, entrance). Colours and
fonts are defined once, at the top of `Main.qml`.
