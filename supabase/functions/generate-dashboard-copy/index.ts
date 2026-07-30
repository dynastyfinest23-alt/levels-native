// generate-dashboard-copy — Phase 2 Variable Reward copy layer.
//
// POST { loopId } → generates (or returns cached) four-part dashboard copy
// for the loop's scored Phase 1 assessment and caches exactly one row per
// loop in phase2_dashboard_views (one_dashboard_per_loop UNIQUE constraint).
//
// The one inviolable principle: the LLM never decides; functions do. This
// function reads the DETERMINISTIC result (dominant_zone, consistency_flag,
// was_clamped) that compute_center_of_gravity already wrote — it never sees
// raw answers, never re-scores, and the numeric score is deliberately
// withheld from the model so it cannot be echoed into copy. A digit guard
// rejects any LLM output that could leak a number; every rejection falls
// back to the static zone copy in fallback.ts.

import { createClient } from "npm:@supabase/supabase-js@2";
import Anthropic from "npm:@anthropic-ai/sdk";
import { DashboardCopy, FALLBACK_COPY, fallbackKey } from "./fallback.ts";

const REQUIRED_FIELDS = [
  "reality_tunnel",
  "hidden_benefit",
  "illusion",
  "bridge_question",
] as const;

const CORS_HEADERS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...CORS_HEADERS, "Content-Type": "application/json" },
  });
}

// Copy leaking any number could contradict the deterministic score display
// (or leak the withheld score itself). 3+ consecutive digits or any decimal
// number disqualifies the LLM output; two-digit day references stay legal.
function leaksNumbers(copy: DashboardCopy): boolean {
  return REQUIRED_FIELDS.some((field) => /\d{3,}|\d+\.\d+/.test(copy[field]));
}

// Em dashes are banned in all user-facing copy (Noah, 2026-07-19). The prompt
// forbids them, but a prompt is a request, not a guarantee -- so enforce it the
// same way numbers are enforced: reject the generation and use fallback copy.
function leaksEmDash(copy: DashboardCopy): boolean {
  return REQUIRED_FIELDS.some((field) => copy[field].includes("—"));
}

function buildSystemPrompt(wasClamped: boolean): string {
  const clampedIllusionRule = wasClamped
    ? `
For THIS user the assessment result was clamped at the single-assessment
ceiling. The "illusion" field MUST frame that ceiling exactly like this: a
peak reading is not arrival. The ceiling they met is the designed doorway
to Flow, which is earned across sustained verified loops, never claimed in
one sitting. Frame it as the shape of the climb, not a limit on them.`
    : "";

  return `You write the Phase 2 dashboard reveal copy for Levels, an app based on
Frederick Dodson's Levels of Energy framework. You receive the user's
already-computed energy zone and produce copy in a four-part reveal arc.
You describe an outcome; you never compute, adjust, or imply one.

Return JSON with exactly these four fields:

- reality_tunnel: names the perceptual pattern implied by their zone: how
  the world tends to read from where they stand (2-3 sentences).
- hidden_benefit: the secondary gain, meaning what staying at this zone has
  quietly protected them from (1-2 sentences).
- illusion: the belief that makes the zone feel permanent, reframed as a
  story rather than truth (1-2 sentences).${clampedIllusionRule}
- bridge_question: one open-ended question that becomes their first Phase 3
  answer. Personal and specific to the zone's pattern, never generic.

Hard rules:
- NEVER include numbers of any kind: no scores, ranges, counts, or dates.
- NEVER use an em dash. Not one, not a pair. Rewrite with a period, comma,
  colon, or parentheses instead. This applies to every field.
- NEVER imply Flow is reachable from a single assessment.
- A zone is a position in a climb, never an identity or a label.
- No manufactured urgency, no flattery, no toxic positivity. Warm, direct,
  second person.`;
}

async function generateLlmCopy(
  apiKey: string,
  input: { dominantZone: string; consistencyFlag: string; wasClamped: boolean },
): Promise<DashboardCopy | null> {
  const anthropic = new Anthropic({ apiKey });

  const response = await anthropic.messages.create({
    model: "claude-sonnet-4-6",
    max_tokens: 1024,
    system: buildSystemPrompt(input.wasClamped),
    output_config: {
      format: {
        type: "json_schema",
        schema: {
          type: "object",
          properties: {
            reality_tunnel: { type: "string" },
            hidden_benefit: { type: "string" },
            illusion: { type: "string" },
            bridge_question: { type: "string" },
          },
          required: [...REQUIRED_FIELDS],
          additionalProperties: false,
        },
      },
    },
    messages: [
      {
        role: "user",
        content:
          // Computed outputs only — centerOfGravity is deliberately absent.
          `Zone: ${input.dominantZone}\n` +
          `Consistency: ${input.consistencyFlag}\n` +
          `Clamped at single-assessment ceiling: ${input.wasClamped}`,
      },
    ],
  });

  if (response.stop_reason === "refusal") return null;

  const text = response.content.find((block) => block.type === "text")?.text;
  if (!text) return null;

  const parsed = JSON.parse(text) as DashboardCopy;
  const complete = REQUIRED_FIELDS.every(
    (field) => typeof parsed[field] === "string" && parsed[field].length > 0,
  );
  return complete ? parsed : null;
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: CORS_HEADERS });
  }
  if (req.method !== "POST") {
    return json({ error: "Method not allowed" }, 405);
  }

  try {
    const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
    const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
    const anthropicKey = Deno.env.get("ANTHROPIC_API_KEY") ?? "";

    // Service-role client: reads the authoritative computed result and owns
    // the cache write. Caller authorization is enforced explicitly below.
    const admin = createClient(supabaseUrl, serviceRoleKey);

    // --- Authorization: loop owner's JWT, or the service-role key (ops). ---
    const token = (req.headers.get("Authorization") ?? "").replace(
      /^Bearer\s+/i,
      "",
    );
    if (!token) return json({ error: "Missing Authorization header" }, 401);

    let callerId: string | null = null;
    const isServiceRole = token === serviceRoleKey;
    if (!isServiceRole) {
      const { data, error } = await admin.auth.getUser(token);
      if (error || !data.user) {
        return json({ error: "Invalid or expired session" }, 401);
      }
      callerId = data.user.id;
    }

    const { loopId } = await req.json().catch(() => ({}));
    if (typeof loopId !== "string" || loopId.length === 0) {
      return json({ error: "loopId (uuid string) is required" }, 400);
    }

    // --- Authoritative result: what compute_center_of_gravity decided. ---
    // center_of_gravity is selected ONLY to confirm the row is scored; it is
    // never passed to the model.
    const { data: assessment, error: assessmentError } = await admin
      .from("phase1_assessments")
      .select(
        "user_id, center_of_gravity, dominant_zone, consistency_flag, was_clamped",
      )
      .eq("loop_id", loopId)
      .maybeSingle();

    if (assessmentError) {
      return json(
        { error: `Assessment lookup failed: ${assessmentError.message}` },
        500,
      );
    }
    if (!assessment) {
      return json({ error: "No assessment found for this loop" }, 404);
    }
    if (!isServiceRole && assessment.user_id !== callerId) {
      return json({ error: "This loop does not belong to the caller" }, 403);
    }
    if (assessment.center_of_gravity === null || !assessment.dominant_zone) {
      return json({ error: "Assessment has not been scored yet" }, 409);
    }

    // --- Cache hit: one dashboard per loop, never regenerated. ---
    const CACHE_COLUMNS =
      "id, loop_id, zone_shown, generated_copy, bridge_question_shown, copy_source, generated_at";
    const { data: existing, error: cacheError } = await admin
      .from("phase2_dashboard_views")
      .select(CACHE_COLUMNS)
      .eq("loop_id", loopId)
      .maybeSingle();
    if (cacheError) {
      return json({ error: `Cache lookup failed: ${cacheError.message}` }, 500);
    }
    if (existing) {
      return json({ cached: true, view: existing });
    }

    // --- Generate: LLM when a key is configured, static fallback otherwise
    // or on any failure/number leak. ---
    const zone = assessment.dominant_zone as string;
    const wasClamped = assessment.was_clamped === true;
    const variant = fallbackKey(zone, wasClamped);

    let copy: DashboardCopy = FALLBACK_COPY[variant] ?? FALLBACK_COPY[zone];
    let copySource = "fallback";
    if (!copy) {
      return json({ error: `No fallback copy for zone '${zone}'` }, 500);
    }

    if (anthropicKey) {
      try {
        const llmCopy = await generateLlmCopy(anthropicKey, {
          dominantZone: zone,
          consistencyFlag: assessment.consistency_flag as string,
          wasClamped,
        });
        if (llmCopy && !leaksNumbers(llmCopy) && !leaksEmDash(llmCopy)) {
          copy = llmCopy;
          copySource = "llm";
        } else if (llmCopy) {
          const reason = leaksNumbers(llmCopy) ? "leaked a number" : "used an em dash";
          console.error(
            `LLM copy for loop ${loopId} ${reason}; using fallback`,
          );
        }
      } catch (err) {
        // Never fail the reveal over copy: surface in logs, fall back.
        console.error(`LLM generation failed for loop ${loopId}:`, err);
      }
    }

    // Validation before write: all four fields present and non-empty.
    const valid = REQUIRED_FIELDS.every(
      (field) => typeof copy[field] === "string" && copy[field].length > 0,
    );
    if (!valid) {
      return json({ error: "Generated copy failed field validation" }, 500);
    }

    // --- Cache write. bridge_question_shown is stored so Phase 3 can seed
    // its first prompt from it. Resolved (M6.3, 2026-07-23): Phase 3 reads
    // this column back (drill_controller.dart's fetchBridgeQuestion) and
    // renders it as the free-text prompt on the drill's first question
    // (drill_screen.dart) — the user's answer lands in
    // phase3_origin_drills.q1_free_text, keyed by loop_id. Verified live
    // in M6.1's full-loop run.
    const { data: inserted, error: insertError } = await admin
      .from("phase2_dashboard_views")
      .insert({
        loop_id: loopId,
        user_id: assessment.user_id,
        zone_shown: zone,
        generated_copy: copy,
        bridge_question_shown: copy.bridge_question,
        copy_source: copySource,
        generated_at: new Date().toISOString(),
      })
      .select(CACHE_COLUMNS)
      .single();

    if (insertError) {
      // Unique-violation race on one_dashboard_per_loop: another request won;
      // return its row as a cache hit rather than erroring.
      if (insertError.code === "23505") {
        const { data: raced } = await admin
          .from("phase2_dashboard_views")
          .select(CACHE_COLUMNS)
          .eq("loop_id", loopId)
          .single();
        if (raced) return json({ cached: true, view: raced });
      }
      return json({ error: `Cache write failed: ${insertError.message}` }, 500);
    }

    return json({ cached: false, view: inserted });
  } catch (err) {
    // Errors must surface (client architecture rule 3) — return the string.
    const message = err instanceof Error ? err.message : String(err);
    return json({ error: message }, 500);
  }
});
