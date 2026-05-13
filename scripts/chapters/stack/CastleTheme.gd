# =============================================================================
# CastleTheme.gd
# File: res://scripts/chapters/stack/CastleTheme.gd
# class_name: CastleTheme
#
# Central palette and StyleBox factory for the "Castle of Echoes" visual theme.
# Used by StackGame and StackVisualizer so both scenes share the same look.
#
# Palette concept:
#   DEEP / DARK / MID / LIGHT  — four tones of carved stone (darkest → lightest)
#   GOLD / GOLD_DIM            — royal trim; used for success, TOP badge, borders
#   TORCH                      — orange torchlight; push animation, progress fill
#   PARCHMENT / PARCHMENT_DIM  — aged paper; primary and secondary text
#   CRIMSON                    — blood-red; errors, wrong moves, overflow
#   EMERALD                    — correct actions, isEmpty=true positive state
#   SAPPHIRE                   — peek / info colour
#
# Usage:
#   var sty := CastleTheme.stone_panel()
#   my_panel.add_theme_stylebox_override("panel", sty)
#   lbl.add_theme_color_override("font_color", CastleTheme.C_PARCHMENT)
# =============================================================================

class_name CastleTheme

# ─────────────────────────────────────────────────────────────────────────────
#  PALETTE
# ─────────────────────────────────────────────────────────────────────────────

# Stone tones — used for backgrounds and default borders
const C_STONE_DEEP  := Color(0.07, 0.06, 0.09)   # scene background
const C_STONE_DARK  := Color(0.12, 0.11, 0.15)   # panel background
const C_STONE_MID   := Color(0.20, 0.18, 0.24)   # elevated surface / button bg
const C_STONE_LIGHT := Color(0.30, 0.27, 0.36)   # default border / separator

# Gold tones — accent, trim, success
const C_GOLD        := Color(0.85, 0.68, 0.20)   # primary accent (TOP badge, gold trim)
const C_GOLD_DIM    := Color(0.50, 0.38, 0.10)   # muted gold (scroll border, code panel)

# Atmospheric tones
const C_TORCH       := Color(0.95, 0.52, 0.12)   # torchlight orange (push anim, progress)
const C_TORCH_DIM   := Color(0.55, 0.28, 0.06)   # dim torch (progress bar background)

# Text tones
const C_PARCHMENT     := Color(0.90, 0.85, 0.70)   # primary text
const C_PARCHMENT_DIM := Color(0.60, 0.55, 0.43)   # secondary / muted text

# Feedback tones
const C_CRIMSON  := Color(0.85, 0.15, 0.15)   # error / wrong move / overflow
const C_EMERALD  := Color(0.22, 0.72, 0.38)   # correct / success / isEmpty true
const C_SAPPHIRE := Color(0.25, 0.55, 0.90)   # peek / info

# ─────────────────────────────────────────────────────────────────────────────
#  MARGIN HELPERS  (shared content padding for all panels)
# ─────────────────────────────────────────────────────────────────────────────
const _M_SM := 8    # small margin
const _M_MD := 12   # medium margin
const _M_LG := 16   # large margin

# ─────────────────────────────────────────────────────────────────────────────
#  STYLE FACTORIES
# ─────────────────────────────────────────────────────────────────────────────

# Standard carved-stone panel — the default surface for most UI elements.
static func stone_panel(border: Color = C_STONE_LIGHT,
		border_px: int = 1, margin: int = _M_MD) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color    = C_STONE_DARK
	s.border_color = border
	s.set_border_width_all(border_px)
	s.set_corner_radius_all(0)   # sharp edges = cut stone
	s.content_margin_left   = margin
	s.content_margin_right  = margin
	s.content_margin_top    = margin - 2
	s.content_margin_bottom = margin - 2
	return s

# Royal-decree panel — gold border on a slightly raised stone surface.
# Used for the task card and other high-priority announcements.
static func royal_panel() -> StyleBoxFlat:
	var s := stone_panel(C_GOLD, 3, _M_MD)
	s.bg_color = C_STONE_MID
	return s

# Alcove panel — recessed, darker than the wall around it.
# Used for the hint box (looks like a niche carved into the stone).
static func alcove_panel() -> StyleBoxFlat:
	var s := stone_panel(C_STONE_MID, 1, _M_MD)
	s.bg_color = Color(0.05, 0.04, 0.07)
	return s

# Scroll panel — aged parchment background with dim-gold trim.
# Used for the sequence banner (looks like a posted royal decree).
static func scroll_panel() -> StyleBoxFlat:
	var s := stone_panel(C_GOLD_DIM, 2, _M_SM)
	s.bg_color = Color(0.16, 0.12, 0.06)
	return s

# Code panel — dark stone with gold-dim border; monolithic tomb feeling.
# Used for the end-of-tier code snippet overlay.
static func code_panel() -> StyleBoxFlat:
	var s := stone_panel(C_GOLD_DIM, 2, _M_LG)
	s.bg_color = Color(0.06, 0.06, 0.10)
	return s

# Column shaft — the tall stone tower that holds the rune stack.
# No content margin — used as a pure visual backdrop, not a PanelContainer.
static func column_shaft() -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color    = Color(0.05, 0.04, 0.07)
	s.border_color = C_STONE_LIGHT
	s.set_border_width_all(2)
	s.set_corner_radius_all(0)
	# Gold top edge only (battlements effect)
	s.border_width_top = 3
	s.border_color     = C_STONE_LIGHT   # sides stay stone; top is set separately
	return s

# ── BUTTON STYLES ─────────────────────────────────────────────────────────────

static func btn_normal() -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color    = C_STONE_MID
	s.border_color = C_STONE_LIGHT
	s.set_border_width_all(2)
	s.set_corner_radius_all(0)
	s.content_margin_left   = _M_LG
	s.content_margin_right  = _M_LG
	s.content_margin_top    = _M_SM
	s.content_margin_bottom = _M_SM
	return s

static func btn_hover() -> StyleBoxFlat:
	var s := btn_normal()
	s.bg_color    = C_STONE_LIGHT
	s.border_color = C_GOLD
	s.set_border_width_all(3)
	return s

static func btn_pressed() -> StyleBoxFlat:
	var s := btn_normal()
	s.bg_color    = C_STONE_DARK
	s.border_color = C_GOLD_DIM
	return s

static func btn_danger_normal() -> StyleBoxFlat:
	var s := btn_normal()
	s.bg_color    = Color(0.22, 0.06, 0.06)
	s.border_color = Color(0.50, 0.12, 0.12)
	return s

static func btn_danger_hover() -> StyleBoxFlat:
	var s := btn_hover()
	s.bg_color    = Color(0.35, 0.08, 0.08)
	s.border_color = C_CRIMSON
	return s

static func btn_success_normal() -> StyleBoxFlat:
	var s := btn_normal()
	s.bg_color    = Color(0.06, 0.18, 0.10)
	s.border_color = Color(0.12, 0.38, 0.18)
	return s

static func btn_success_hover() -> StyleBoxFlat:
	var s := btn_hover()
	s.bg_color    = Color(0.08, 0.24, 0.14)
	s.border_color = C_EMERALD
	return s

static func btn_info_normal() -> StyleBoxFlat:
	var s := btn_normal()
	s.bg_color    = Color(0.06, 0.12, 0.22)
	s.border_color = Color(0.12, 0.28, 0.48)
	return s

static func btn_info_hover() -> StyleBoxFlat:
	var s := btn_hover()
	s.bg_color    = Color(0.08, 0.16, 0.30)
	s.border_color = C_SAPPHIRE
	return s

# ── PROGRESS BAR STYLES ───────────────────────────────────────────────────────

static func progress_bg() -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color    = C_TORCH_DIM
	s.border_color = C_STONE_LIGHT
	s.set_border_width_all(1)
	return s

static func progress_fill() -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = C_TORCH
	return s

static func progress_fill_danger() -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = C_CRIMSON
	return s

# ── ITEM TILE STYLES ──────────────────────────────────────────────────────────
# For stack item tiles (element-coloured rune slots carved from stone).

static func item_tile(element_color: Color, is_top: bool) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color    = element_color.darkened(0.72)
	s.border_color = element_color if is_top else element_color.darkened(0.40)
	s.set_border_width_all(3 if is_top else 1)
	# Top item has a golden outer glow simulated by wider top border
	if is_top:
		s.border_width_top = 4
	s.set_corner_radius_all(0)
	s.content_margin_left   = 10
	s.content_margin_right  = 10
	s.content_margin_top    = 8
	s.content_margin_bottom = 8
	return s

static func top_badge(element_color: Color) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color    = C_GOLD
	s.border_color = element_color
	s.set_border_width_all(1)
	s.set_corner_radius_all(0)
	s.content_margin_left   = 5
	s.content_margin_right  = 5
	s.content_margin_top    = 2
	s.content_margin_bottom = 2
	return s
