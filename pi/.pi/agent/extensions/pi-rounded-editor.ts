/**
 * pi-rounded-editor — Wraps any editor (e.g. pi-powerline-footer) with
 * rounded box-drawing borders matching oh-my-pi style.
 *
 * Layout:
 *   ╭─ π > Opus 4.6 > thinking:high > ~/project ─────────────╮
 *   │ > line 1                                                │
 *   ╰  > cursor line                                         ╯
 */
import type { ExtensionAPI } from "@mariozechner/pi-coding-agent";
import { visibleWidth } from "@mariozechner/pi-tui";

// Strip CSI/OSC/APC sequences so border detection ignores color codes,
// hyperlinks, and pi's zero-width CURSOR_MARKER APC escape.
const ESCAPE_RE = /\x1b(?:\[[0-9;?]*[ -/]*[@-~]|\][\s\S]*?(?:\x07|\x1b\\)|_[\s\S]*?(?:\x07|\x1b\\))/g;
const BORDER_RE = /^\s*─{3,}/;

function stripControlSequences(str: string): string {
  return str.replace(ESCAPE_RE, "").replace(/[\x00-\x1f\x7f]/g, "");
}

export default function (pi: ExtensionAPI) {
  pi.on("session_start", (_event, ctx) => {
    const originalSet = ctx.ui.setEditorComponent.bind(ctx.ui);

    ctx.ui.setEditorComponent = (factory: any) => {
      if (!factory) {
        originalSet(factory);
        return;
      }

      const wrappedFactory = (tui: any, theme: any, keybindings: any) => {
        const editor = factory(tui, theme, keybindings);
        const innerRender = editor.render.bind(editor);

        editor.render = (width: number): string[] => {
          if (width < 14) return innerRender(width);

          // Reserve 4 columns for a softer frame:
          // │␠ content ␠│
          const innerWidth = width - 4;
          const lines: string[] = innerRender(innerWidth);
          if (lines.length < 2) return lines;

          // Theme border accent color (#82aaff blue in tokyonight-moon — matches pi logo)
          const borderAnsi = ctx.ui.theme.getFgAnsi("borderAccent");
          const rst = "\x1b[0m";
          const bc = (s: string) => `${borderAnsi}${s}${rst}`;

          // Detect border lines
          const isBorder = (line: string): boolean => {
            const s = stripControlSequences(line || "");
            return s.length > 2 && BORDER_RE.test(s);
          };

          // Find first and last border lines
          let topIdx = -1;
          let botIdx = -1;
          for (let i = 0; i < lines.length; i++) {
            if (isBorder(lines[i])) {
              if (topIdx === -1) topIdx = i;
              botIdx = i;
            }
          }
          if (topIdx === -1 || topIdx === botIdx) return lines;

          const result: string[] = [];

          // ── Merged top border ──
          if (topIdx > 0) {
            // Any lines before the status (rare)
            for (let i = 0; i < topIdx - 1; i++) result.push(lines[i] || "");

            const status = lines[topIdx - 1] || "";
            const statusW = visibleWidth(status);
            const fill = Math.max(0, width - 4 - statusW);
            result.push(bc("╭─") + status + bc("─".repeat(fill) + "─╮"));
          } else {
            result.push(bc("╭" + "─".repeat(width - 2) + "╮"));
          }

          // ── Content lines ──
          const contentStart = topIdx + 1;
          const contentEnd = botIdx;
          const contentCount = contentEnd - contentStart;

          if (contentCount > 0) {
            for (let i = contentStart; i < contentEnd; i++) {
              const isLast = i === contentEnd - 1;
              const line = lines[i] || "";
              const vw = visibleWidth(line);

              if (isLast) {
                const inset = vw <= width - 6 ? 2 : 1;
                const lastLineWidth = width - 2 - inset * 2;
                const pad = Math.max(0, lastLineWidth - vw);
                result.push(
                  bc("╰" + " ".repeat(inset)) +
                    line +
                    " ".repeat(pad) +
                    bc(" ".repeat(inset) + "╯")
                );
              } else {
                const pad = Math.max(0, innerWidth - vw);
                result.push(bc("│ ") + line + " ".repeat(pad) + bc(" │"));
              }
            }
          } else {
            result.push(bc("╰  ") + " ".repeat(width - 6) + bc("  ╯"));
          }

          // ── Spacer for breathing room before footer ──
          result.push("");

          // ── Autocomplete dropdown (anything after the bottom border) ──
          for (let i = botIdx + 1; i < lines.length; i++) {
            result.push(lines[i] || "");
          }

          return result;
        };

        return editor;
      };

      originalSet(wrappedFactory);
    };
  });
}
