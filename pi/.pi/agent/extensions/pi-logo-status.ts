/**
 * pi-logo-status — publishes a pi glyph as an extension status, so it can be
 * promoted into its own powerline item via `powerline.customItems`.
 *
 * pi-powerline-footer has no "pi logo" segment — icons.ts defines
 * NERD_ICONS.pi (U+E22C, nf-oct-pi) but no segment renders it — and the
 * `hostname` segment always prints os.hostname(). Publishing a status is the
 * supported way to get an arbitrary item into the footer: powerline's
 * renderCustomSegment() reads ctx.extensionStatuses.get(statusKey) and renders
 * the value verbatim, so a bare glyph comes through as-is.
 *
 * Pairs with, in settings.json:
 *   "customItems": [{ "id": "pi-logo", "statusKey": "pi-logo", "position": "left" }]
 *   "layout": { "left": ["custom:pi-logo", ...] }
 */
import type { ExtensionAPI } from "@mariozechner/pi-coding-agent";

const STATUS_KEY = "pi-logo";
const NERD_PI = "\uE22C"; //  nf-oct-pi
const PLAIN_PI = "\u03C0"; // π  U+03C0

// Mirrors pi-powerline-footer's own hasNerdFonts() (icons.ts:157) so the glyph
// degrades to π anywhere TERM_PROGRAM doesn't survive — tmux, plain ssh, etc.
// Both glyphs measure 1 cell, so the footer layout is identical either way.
function hasNerdFonts(): boolean {
  if (process.env.POWERLINE_NERD_FONTS === "1") return true;
  if (process.env.POWERLINE_NERD_FONTS === "0") return false;
  if (process.env.GHOSTTY_RESOURCES_DIR) return true;
  const term = (process.env.TERM_PROGRAM || "").toLowerCase();
  return ["iterm", "wezterm", "kitty", "ghostty", "alacritty"].some((t) => term.includes(t));
}

export default function (pi: ExtensionAPI) {
  pi.on("session_start", (_event, ctx) => {
    ctx.ui.setStatus(STATUS_KEY, hasNerdFonts() ? NERD_PI : PLAIN_PI);
  });
}
