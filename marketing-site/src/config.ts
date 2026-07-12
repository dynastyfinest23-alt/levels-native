export interface SiteConfig {
  language: string
  siteTitle: string
  siteDescription: string
}

export interface NavLink {
  label: string
  targetId: string
}

export interface NavigationConfig {
  brandMark: string
  links: NavLink[]
}

export interface HeroConfig {
  wordmarkText: string
  eyebrow: string
  titleLine1: string
  titleLine2: string
  descriptionLine1: string
  descriptionLine2: string
  ctaText: string
  ctaTargetId: string
}

export interface PhilosophyConfig {
  eyebrow: string
  title: string
  body: string
  rollingWords: string[]
}

export interface VisionConfig {
  eyebrow: string
  headline: string
  paragraphs: string[]
}

export interface QuoteData {
  text: string
  name: string
  role: string
  initials: string
}

export interface TestimonialsConfig {
  eyebrow: string
  title: string
  quotes: QuoteData[]
}

export interface WaitlistConfig {
  eyebrow: string
  headline: string
  body: string
  placeholder: string
  ctaText: string
  disclaimer: string
  successTitle: string
  successBody: string
}

export interface ProjectMeta {
  label: string
  value: string
}

export interface ProjectData {
  id: string
  title: string
  location: string
  year: string
  image: string
  subtitle: string
  meta: ProjectMeta[]
  paragraphs: string[]
}

export interface GalleryConfig {
  sectionLabel: string
  title: string
  projects: ProjectData[]
}

export interface MediumItem {
  cn: string
  en: string
  description: string
}

export interface MediumsConfig {
  sectionLabel: string
  items: MediumItem[]
}

export interface FooterEntry {
  text: string
  href?: string
}

export interface FooterColumn {
  heading: string
  entries: FooterEntry[]
}

export interface FooterConfig {
  visionText: string
  brandName: string
  columns: FooterColumn[]
  copyright: string
  videoPath: string
}

export interface ProjectDetailConfig {
  backLabel: string
}

export const siteConfig: SiteConfig = {
  language: "en",
  siteTitle: "Levels: Your energy has a shape",
  siteDescription: "A personal energy tracking app. Assess your current state, illuminate your position, climb with purpose, and hold the change. Built on a lineage of consciousness frameworks spanning centuries.",
}

export const navigationConfig: NavigationConfig = {
  brandMark: "LV",
  links: [
    { label: "Vision", targetId: "vision" },
    { label: "Journey", targetId: "gallery" },
    { label: "Tracks", targetId: "mediums" },
  ],
}

export const heroConfig: HeroConfig = {
  wordmarkText: "LEVELS",
  eyebrow: "PERSONAL ENERGY TRACKING",
  titleLine1: "Your energy",
  titleLine2: "has a shape.",
  descriptionLine1: "A seven-question reading of where you are.",
  descriptionLine2: "A guided climb toward a clearer, more peaceful life.",
  ctaText: "Begin the reading",
  ctaTargetId: "philosophy",
}

export const philosophyConfig: PhilosophyConfig = {
  eyebrow: "THE SIX ZONES",
  title: "From collapse to flow",
  body: "Every state you pass through is a position in a climb, not a label. The spectrum runs from cold dim indigo to radiant warm gold. Each zone is a doorway, not a destination.",
  rollingWords: ["COLLAPSED", "CONTRACTED", "REACTIVE", "THRESHOLD", "BUILDER", "FLOW"],
}

export const visionConfig: VisionConfig = {
  eyebrow: "WHY THIS EXISTS",
  headline: "Raising consciousness is the only real climb.",
  paragraphs: [
    "Levels is built on a conviction that most people carry quietly: the background hum of suffering is not mandatory. Human beings can live without the friction that drains their days.",
    "This is not spirituality dressed as an app. It is a behavioral system. The assessment reads your current energetic position. The protocols target the specific block holding you there. The verification windows check whether the shift has stuck.",
    "The goal is not a score. It is a shift in how you experience being alive. Less reactivity. Less contraction. Less of the invisible drag that makes ordinary days feel heavy. A painless, peaceful life is not an abstraction. It is a state that can be reached, verified, and sustained.",
    "To the Source from which all arises: the boundless, the infinite, the Most High. This work is offered in service of all beings. May it serve as a gentle ladder for anyone ready to climb.",
    "We are building this because the world does not need more productivity tools. It needs more people operating from clarity."
  ],
}

export const testimonialsConfig: TestimonialsConfig = {
  eyebrow: "WHAT PEOPLE SAY",
  title: "The shift is real",
  quotes: [
    {
      text: "I had spent years in reactive mode, snapping at small things, exhausted by 2 PM. The reading showed me exactly where I was standing, and the drills gave me something concrete to do about it. For the first time, change felt like work, not magic.",
      name: "M. Chen",
      role: "Software engineer, Phase 3",
      initials: "MC",
    },
    {
      text: "The verification window is what sold me. I have done enough self-help to know that a weekend of feeling good means nothing. Day 21 showed me the change had actually held. That is the difference between a mood and a transformation.",
      name: "J. Okonkwo",
      role: "Designer, completed 3 loops",
      initials: "JO",
    },
    {
      text: "I came in skeptical. I thought it would be another personality quiz with a pretty dashboard. Instead, the bridge question from Phase 2 sat with me for days. The app does not tell you what to think. It shows you what you are already doing.",
      name: "S. Patel",
      role: "Physician, Phase 2",
      initials: "SP",
    },
  ],
}

export const waitlistConfig: WaitlistConfig = {
  eyebrow: "EARLY ACCESS",
  headline: "See your shape clearly.",
  body: "Levels is opening in limited release. Join the waitlist to be among the first to begin the climb.",
  placeholder: "your@email.com",
  ctaText: "Join the waitlist",
  disclaimer: "No spam. One email when we are ready.",
  successTitle: "You are on the list.",
  successBody: "We will be in touch when the climb opens.",
}

export const galleryConfig: GalleryConfig = {
  sectionLabel: "THE JOURNEY / 001",
  title: "Read · See · Climb · Hold",
  projects: [
    {
      id: "assessment",
      title: "READ",
      location: "Phase 1",
      year: "7 questions",
      image: "images/assessment.jpg",
      subtitle: "The Opportunity Mirror",
      meta: [
        { label: "INPUT", value: "Behavioral answers" },
        { label: "OUTPUT", value: "Center of Gravity" },
      ],
      paragraphs: [
        "The assessment is a reading, not a quiz. Seven behavioral questions, each spanning the full spectrum, produce a Center of Gravity score that maps your current energetic position.",
        "No personality types. No permanent labels. Just a moment-in-time snapshot of where you stand on the climb, grounded in observable behavior rather than self-reported mood.",
        "The questions probe how you react to opportunity, conflict, inertia, scarcity, locus of control, body state, and meaning. Each answer is a position, not a judgment.",
      ],
    },
    {
      id: "dashboard",
      title: "SEE",
      location: "Phase 2",
      year: "Reveal",
      image: "images/dashboard.jpg",
      subtitle: "The illumination",
      meta: [
        { label: "STYLE", value: "Four-part reveal" },
        { label: "OUTPUT", value: "Reality tunnel + bridge" },
      ],
      paragraphs: [
        "The reveal is a ritual. Your score appears, settled, not counted up. Then, tap by tap, four panels illuminate your position: the pattern this zone implies, the hidden benefit it provides, the illusion that makes it feel permanent, and a single bridge question that opens the door to Phase 3.",
        "The copy is personalized to your reading, generated to feel earned and slightly unpredictable in framing, while the number itself is deterministic, never random.",
        "Low zones get dignity. The reading is dimmer, quieter, never alarming. Every position on the spectrum is a starting point, not a diagnosis.",
      ],
    },
    {
      id: "drills",
      title: "CLIMB",
      location: "Phase 3",
      year: "Protocols",
      image: "images/drills.jpg",
      subtitle: "Origin work",
      meta: [
        { label: "METHOD", value: "Guided drills" },
        { label: "TARGET", value: "Dominant block" },
      ],
      paragraphs: [
        "Climbing is not positive thinking. It is targeted work on the specific block your assessment illuminated. The dominant pattern holding your current position in place.",
        "Each protocol is a guided drill, not a lecture. You answer the bridge question from Phase 2, then move through origin work designed to loosen the grip of that particular pattern.",
        "The work is effortful. That is the point. Investment is what makes the climb durable.",
      ],
    },
    {
      id: "verify",
      title: "HOLD",
      location: "Phase 4 to 5",
      year: "Durability",
      image: "images/verify.jpg",
      subtitle: "Verified change",
      meta: [
        { label: "WINDOW", value: "Day 5 to 7, Day 21" },
        { label: "GATE", value: "Loop classification" },
      ],
      paragraphs: [
        "A single assessment can show you where you are. Verified change requires time. Two reassessment windows check whether your climb has stuck, or whether old patterns have crept back in.",
        "Day 5 to 7 is the first checkpoint: has the shift held? Day 21 is the durability gate: is this a true ascension, a residual charge, or a false positive? The classification determines your next loop: new climb, deepening protocol, or track reassignment.",
        "Flow-band states are not reachable from one quiz. They are earned across verified loops. The ceiling rises with each confirmed ascension.",
      ],
    },
  ],
}

export const mediumsConfig: MediumsConfig = {
  sectionLabel: "THE FOUR TRACKS",
  items: [
    {
      cn: "Complete",
      en: "COMPLETION",
      description: "The work of finishing what was started. Clearing the open loops that drain energy.",
    },
    {
      cn: "Audit",
      en: "BELIEF AUDIT",
      description: "Examining the assumptions that hold the current zone in place. What if the limitation isn't real?",
    },
    {
      cn: "Embody",
      en: "EMBODIMENT",
      description: "Daily practice that makes the new state feel like home, not a performance.",
    },
    {
      cn: "Commit",
      en: "COMMITMENT",
      description: "The decision to stay with the climb when the initial momentum fades.",
    },
  ],
}

export const footerConfig: FooterConfig = {
  visionText: "The goal is not a number on a screen. It is a human being operating from clarity instead of reactivity. A world with more people in their right energetic state is a world with less unnecessary suffering. That is what we are building toward.",
  brandName: "LEVELS",
  columns: [
    {
      heading: "JOURNEY",
      entries: [
        { text: "Read", href: "#gallery" },
        { text: "See", href: "#gallery" },
        { text: "Climb", href: "#gallery" },
        { text: "Hold", href: "#gallery" },
      ],
    },
    {
      heading: "CONNECT",
      entries: [
        { text: "hello@levels.app", href: "mailto:hello@levels.app" },
        { text: "Join waitlist", href: "#waitlist" },
      ],
    },
  ],
  copyright: "© Levels 2025",
  videoPath: "",
}

export const projectDetailConfig: ProjectDetailConfig = {
  backLabel: "← Back",
}

export function getProjectById(id: string): ProjectData | undefined {
  return galleryConfig.projects.find((p) => p.id === id)
}
