import type { ExtensionAPI } from "@mariozechner/pi-coding-agent";

/**
 * Copilot endpoint fix.
 *
 * pi-ai ships every github-copilot model with a static
 * `baseUrl: https://api.individual.githubcopilot.com`. The real, credential-scoped
 * host lives on the auth resolution (`githubCopilotOAuth.toAuth()` derives it from the
 * token's `proxy-ep`), and pi applies it in `ModelRuntime.prepareRequest()` — so the
 * main agent is always fine.
 *
 * Extensions that run their own `agentLoop` never reach `prepareRequest()`. They call
 * `modelRegistry.getApiKeyAndHeaders()`, which returns apiKey/headers/env but drops
 * baseUrl, and then send the raw model. On a Copilot business or enterprise seat that
 * request hits the wrong virtual host and gets `421 Misdirected Request`
 * (pi-observational-memory surfaces this as "observer returned no observations").
 *
 * This extension resolves the credential's real host once per session and pushes it
 * down as a provider-level override, so *every* consumer — main agent, extensions,
 * subagents — sees the correct `model.baseUrl`.
 *
 * Safe by construction:
 *   - only touches the github-copilot provider, and only when a credential exists;
 *   - the host is read from the live credential, never hardcoded, so individual,
 *     business and GHES enterprise seats all resolve correctly;
 *   - a no-op when the resolved host already matches (i.e. individual seats);
 *   - `prepareRequest()` still overrides with the freshest auth value for the main
 *     agent, so this can only ever agree with pi, never fight it.
 *
 * See ~/.dotfiles/docs/observational-memory-copilot-421.md
 */

const PROVIDER = "github-copilot";

type State = { applied?: string; checked?: string; reason?: string };

export default function (pi: ExtensionAPI) {
	const state: State = {};

	async function apply(ctx: any, notifyOnFix: boolean): Promise<void> {
		const current = ctx.modelRegistry.getProvider(PROVIDER)?.baseUrl;
		state.checked = current;

		let resolved: string | undefined;
		try {
			resolved = (await ctx.modelRegistry.getProviderAuth(PROVIDER))?.auth?.baseUrl;
		} catch (error) {
			state.reason = `auth lookup failed: ${error instanceof Error ? error.message : String(error)}`;
			return;
		}

		if (!resolved) {
			state.reason = "no github-copilot credential (nothing to fix)";
			return;
		}
		if (resolved === current) {
			state.reason = "provider baseUrl already matches the credential";
			state.applied = undefined;
			return;
		}

		pi.registerProvider(PROVIDER, { baseUrl: resolved });
		await ctx.modelRegistry.refresh();
		state.applied = resolved;
		state.reason = `overrode ${current} -> ${resolved}`;
		if (notifyOnFix && ctx.hasUI) {
			ctx.ui?.notify(`Copilot endpoint fix: using ${new URL(resolved).host} for github-copilot models`, "info");
		}
	}

	pi.on("session_start", async (_event, ctx) => {
		await apply(ctx, true);
	});

	pi.registerCommand("copilot-endpoint", {
		description: "Show/re-apply the GitHub Copilot baseUrl override",
		handler: async (_args, ctx) => {
			await apply(ctx, false);
			const model = ctx.modelRegistry.find(PROVIDER, "claude-haiku-4.5") ?? ctx.modelRegistry.getAll().find((m: any) => m.provider === PROVIDER);
			const lines = [
				`provider baseUrl : ${ctx.modelRegistry.getProvider(PROVIDER)?.baseUrl ?? "n/a"}`,
				`model baseUrl    : ${model?.baseUrl ?? "n/a"}`,
				`override applied : ${state.applied ?? "no"}`,
				`reason           : ${state.reason ?? "n/a"}`,
			];
			ctx.ui?.notify(lines.join("\n"), state.applied || state.reason?.startsWith("provider baseUrl already") ? "info" : "warning");
		},
	});
}
