// Static per-zone dashboard copy, used when no ANTHROPIC_API_KEY is set or
// when LLM generation fails/leaks numbers. Presentation only — the zone is
// decided by the database; this file never computes anything.
//
// Canonical four-part reveal schema (all consumers — this file, index.ts,
// and the Dart parser in lib/features/dashboard/dashboard_copy.dart — must
// stay in sync; they share no runtime):
//   reality_tunnel  — names the pattern implied by their zone (2-3 sentences)
//   hidden_benefit  — the secondary gain: what staying at this zone has
//                     quietly protected them from (1-2 sentences)
//   illusion        — the belief that makes the zone feel permanent, reframed
//                     as a story, not truth (1-2 sentences)
//   bridge_question — one open-ended question that becomes their first
//                     Phase 3 answer; personal, not generic
//
// Tone rules (CLAUDE.md): zones are positions in a climb, never labels; no
// manufactured urgency; never imply Flow is reachable from one assessment.

export interface DashboardCopy {
  reality_tunnel: string;
  hidden_benefit: string;
  illusion: string;
  bridge_question: string;
}

export const FALLBACK_COPY: Record<string, DashboardCopy> = {
  collapsed: {
    reality_tunnel:
      "From here the world reads as heavy and closed — effort feels pointless before it starts, and other people's ease looks like something you were skipped over for.",
    hidden_benefit:
      "Staying low has been a shelter: if nothing is attempted, nothing can be lost, and the numbness spares you the sharper feelings underneath.",
    illusion:
      "The illusion is permanence — that this weight is who you are rather than where you're standing. It's a position in a climb, and positions change.",
    bridge_question:
      "What is one small thing you could tend to today — not fix, just tend to?",
  },
  contracted: {
    reality_tunnel:
      "From here the world reads as scarce and risky — opportunities look like traps, and holding on tightly feels safer than reaching.",
    hidden_benefit:
      "The gripping has kept you vigilant. That wariness of losing has protected what little felt securable, and wanting has at least kept a direction alive.",
    illusion:
      "The illusion is that safety comes from contraction — that if you brace hard enough, loss can't reach you. Bracing mostly keeps the good out too.",
    bridge_question:
      "Where in your life would loosening your grip cost you less than the gripping already does?",
  },
  reactive: {
    reality_tunnel:
      "From here the world reads as a contest — slights land hard, being right matters more than being at ease, and energy comes in hot bursts.",
    hidden_benefit:
      "The heat is real fuel. It got you moving when nothing else did, and the instinct to defend your ground built a self worth protecting. That force brought you this far.",
    illusion:
      "The illusion is that the fire needs an opponent — that without something to push against, the energy disappears. It doesn't; it changes direction.",
    bridge_question:
      "What could this force build if it stopped needing something to fight?",
  },
  threshold: {
    reality_tunnel:
      "From here the world reads as workable — things are mostly fine, and there's a quiet awareness that 'fine' is not the same as alive.",
    hidden_benefit:
      "This calm has been earned ground. It gave you rest after the climb below it, and the steadiness here doesn't announce itself — it just keeps showing up.",
    illusion:
      "The illusion is that comfort is the summit — that wanting more would be ingratitude. The plateau is a resting point, not the top.",
    bridge_question:
      "If nothing in your life were wrong, what would you still want to build?",
  },
  builder: {
    reality_tunnel:
      "From here the world reads as buildable — you see levers where others see walls, and your word to yourself mostly gets kept.",
    hidden_benefit:
      "That openness compounds. The evenness you've reached isn't detachment — it's the steadiness that lets you act without needing the outcome to soothe you.",
    illusion:
      "The illusion is that building is the destination — that enough output will produce the state you're actually after. The next climb is lighter than it is busy.",
    bridge_question:
      "What would you make if you trusted the momentum instead of managing it?",
  },
  builder_clamped: {
    reality_tunnel:
      "From here the world reads as wide open — this assessment landed at the very top of what a single sitting can show, and the ceiling you touched is the instrument's, not yours.",
    hidden_benefit:
      "You've built the steadiness that makes sustained states possible. That foundation is exactly what the verified climb ahead is designed to stand on.",
    illusion:
      "The illusion is that a peak moment equals a resting state — the ceiling you met is the designed doorway to Flow, which opens only through sustained verified loops, never one assessment. That's not a limit on you; it's the shape of the climb.",
    bridge_question:
      "What would it look like to live at this level on an ordinary Tuesday?",
  },
  flow: {
    reality_tunnel:
      "From here the world reads as participatory — things move with you more often than against you, and effort has largely given way to engagement.",
    hidden_benefit:
      "The verified climb behind you is the point: this state rests on repetition, not luck, which is why it holds under load.",
    illusion:
      "The illusion is arrival — that this state now sustains itself on its own. It's a current you keep choosing, loop after loop, not a title you keep.",
    bridge_question:
      "Now that the climb is lighter, who or what climbs with you?",
  },
};

export const fallbackKey = (dominantZone: string, wasClamped: boolean): string =>
  dominantZone === "builder" && wasClamped ? "builder_clamped" : dominantZone;
