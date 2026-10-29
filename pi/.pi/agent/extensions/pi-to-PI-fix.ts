import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";

// Rewrite standalone lowercase "pi" to "PI" in Anthropic system instructions.
// Keep paths like ~/.pi/ and pi-coding-agent, tool declarations, and history intact.
//
// Two layers, because neither alone covers every request:
// 1. context_with_system: request-local transform of system messages (including
//    mid-conversation section diffs). Automatic custom-message turns skip
//    before_agent_start, so this operates on each outgoing context instead.
// 2. before_provider_request: rewrites the final payload's `system` blocks. Needed
//    when an extension forces a system prompt via before_agent_start (pi-subagents
//    children do this): Pi's forced-prompt projection runs *after* context handlers
//    and replaces the leading system message with the untransformed forced text.
const PATTERN = /(?<=^|\s)pi(?=\s|[,.]|$)/gm;
const replace = (text: string) => text.replace(PATTERN, "PI");

export default function (pi: ExtensionAPI) {
  pi.on("context_with_system", (event, ctx) => {
    if (ctx.model?.provider !== "anthropic") return;
    let changed = false;
    const rewrite = (text: string) => {
      const result = replace(text);
      if (result !== text) changed = true;
      return result;
    };
    const messages = event.messages.map((message) => {
      if (message.role !== "system") return message;
      const content = typeof message.content === "string"
        ? rewrite(message.content)
        : message.content.map((part) => ({ ...part, text: rewrite(part.text) }));
      const sections = message.sections
        ? Object.fromEntries(Object.entries(message.sections).map(([name, text]) => [
          name, typeof text === "string" ? rewrite(text) : text,
        ]))
        : undefined;
      return { ...message, content, ...(sections ? { sections } : {}) };
    });
    if (changed) return { messages };
  });

  pi.on("before_provider_request", (event, ctx) => {
    if (ctx.model?.provider !== "anthropic") return;
    const payload = event.payload as { system?: unknown } | undefined;
    if (!payload || typeof payload !== "object") return;
    const { system } = payload;
    if (typeof system === "string") {
      const next = replace(system);
      return next === system ? undefined : { ...payload, system: next };
    }
    if (!Array.isArray(system)) return;
    let changed = false;
    const next = system.map((block) => {
      if (!block || typeof block !== "object" || typeof block.text !== "string") return block;
      const text = replace(block.text);
      if (text === block.text) return block;
      changed = true;
      return { ...block, text };
    });
    return changed ? { ...payload, system: next } : undefined;
  });
}
