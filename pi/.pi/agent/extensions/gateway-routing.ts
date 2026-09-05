/**
 * gateway-routing
 *
 * Makes `compat.vercelGatewayRouting` from models.json actually reach the
 * Vercel AI Gateway. pi 0.85.x applies that setting only in the
 * openai-completions adapter, but every model in the built-in
 * `vercel-ai-gateway` catalog rides the anthropic-messages transport, which
 * never sends it. The gateway's /v1/messages endpoint does honor
 * `providerOptions.gateway.{only,order}` (verified 2026-09-05: a bogus `only`
 * returns 400 listing anthropic, bedrock, claudeaws, vertexAnthropic for
 * Claude models), so without this the routing pins are inert and any request
 * can land on a backend with a separate prompt cache.
 *
 * Behavior: for `vercel-ai-gateway` models whose compat carries
 * `vercelGatewayRouting`, inject `providerOptions.gateway` into the request
 * payload unless the payload already has one (so this becomes a no-op the day
 * pi's adapter sends it). Nothing else is touched.
 *
 * Upstream: earendil-works/pi#9211.
 */

import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";

interface GatewayRouting {
	only?: string[];
	order?: string[];
}

export default function (pi: ExtensionAPI) {
	pi.on("before_provider_request", (event, ctx) => {
		const model = ctx.model;
		if (!model || model.provider !== "vercel-ai-gateway") return;
		const routing = (model.compat as { vercelGatewayRouting?: GatewayRouting } | undefined)?.vercelGatewayRouting;
		if (!routing || (!routing.only && !routing.order)) return;
		const payload = event.payload as Record<string, unknown>;
		const existing = payload.providerOptions as { gateway?: unknown } | undefined;
		if (existing?.gateway) return;
		const gateway: GatewayRouting = {};
		if (routing.only) gateway.only = routing.only;
		if (routing.order) gateway.order = routing.order;
		return { ...payload, providerOptions: { ...(existing ?? {}), gateway } };
	});
}
