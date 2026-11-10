# Bedspace landing design

The supplied visual reference is https://kero-ai.framer.website/.
The Flutter landing page follows its dark page structure: landscape hero,
alternating product rows, a two-card workflow carousel, three pricing cards,
comparison table, landscape/text transition, role tabs, guide cards and a large
footer wordmark. Bedspace's supplied cactus logo is used in navigation/footer.

Typography uses local Hedvig Letters Serif, Inter and Geist Mono font assets.
Scenes are bundled locally for PWA caching. Iconography uses outlined symbols.
Product illustrations and workflow examples describe Bedspace; the page does
not claim the reference template's customers, endorsements or AI capabilities.
The one-month trial, AED 50 monthly and AED 540 annual pricing are preserved.

## Motion and interactions

- Staggered word entrances fade, rise and blur into focus.
- Sections reveal once on entering the viewport with a slight scale/translation.
- The pinned navigation gains a blurred background after scrolling.
- The hero scenery moves at a slower rate than foreground content.
- Pricing illumination and paragraph emphasis follow scroll position.
- Cards lift on hover; workflow arrows/swipes and role tabs switch content.
- Navigation scrolls to sections, pricing opens registration, guide cards open
  readable dialogs, and sign-in opens the existing account form.
- Reduced-motion settings show content immediately and disable parallax.

The reference's source styles and assets were inspected. Interactive browser
access was unavailable in this environment; desktop/mobile Flutter renders and
widget tests cover layout, scroll reveals, reduced motion and interactive flows.
