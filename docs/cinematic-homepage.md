# Cinematic homepage

The existing React/Vite app, state-based navigation, API client, and analytics are preserved. Analytics pages are now loaded on demand. No frontend dependencies were added.

## Media

`frontend/public/cricket_hero.mp4` and `gemini_generated_video_ab4f50d3.mp4` match the supplied Gemini clip. The other supplied recording is a screen recording of the previous homepage, not the hero source.

Source: H.264, 1280×720, 24 fps, 10.005 seconds, AAC audio. Original I-frame intervals reach 4.17 seconds. The derived `cricket-scroll.mp4` is silent H.264, 10 seconds, fast-start, 40 keyframes (one every six frames / 250 ms), 5,206,564 bytes. The originals are untouched. `scripts/optimize-cricket-video.ps1 -FFmpeg <path>` reproduces the video and poster.

The footage includes generated interface text and numbers. These are cinematic imagery, not application metrics. An on-screen caption identifies this; chapter-four results use the existing live benchmark data or the homepage's fallback verified against `results/model_comparison.csv`.

## Timeline and lifecycle

A 600vh section pins a viewport-height stage below the stable 64px navigation. Progress is clamped `(scrollY - sectionStart) / (sectionHeight - stageHeight)`. Video time is progress × duration, clamped to the final decodable frame at the endpoint. Chapter starts are 0, .21, .42, .63, .84, following the batting/stadium/close-up/wide-view footage.

Scroll events schedule at most one animation frame. Geometry is cached and remeasured on resize/layout changes. Only DOM styles and video time change during scrolling; React does not rerender for each scroll. Seeks are serialized; seek completion schedules the latest target. No autoplay, playback loop, or idle animation loop. Seek granularity still depends on the browser decoder and source frame rate.

Listeners, observers, scheduled frames, and buffering timeout are cleaned up. Inactive chapters are inert and hidden from assistive technology. Chapter navigation, skip link, and CTAs allow leaving the sequence immediately.

At widths ≤760px, heights ≤620px, reduced-motion, data-saver, or ≤2 reported CPU cores, the story uses a poster with all five chapters in document flow and no video element. Media failure retains the poster and functioning desktop chapters. Counter animations respect reduced motion and cancel on unmount.

## Browser verification (25 October 2026)

Tested against the actual application at localhost:5173 with its live API:

- Forward progress 0 → .27 → .50 → .72 → 1 produced video times 0 → 2.699 → 5 → 7.200 → 9.96 seconds.
- Reverse progress 1 → .50 → .12 → 0 produced 9.96 → 5 → 1.201 → 0 seconds.
- Stationary checks at start and at 6.7499 seconds retained the same time; video remained paused throughout.
- All five chapter indicators and headings follow progress; stage remains pinned at 64px.
- Benchmark CTA lands at the real 12-row comparison. Prediction CTA unmounts the video.
- Historical MI/CSK fixture, Wankhede venue, and prediction submission returned the live consensus, model breakdown, and XAI panel without application errors.
- Widths 1440, 1024, 390, and 320 have no horizontal overflow. Mobile and reduced-motion expose all chapters without loading video.
- Forced video-request failure retains the poster and story controls. The deliberately aborted request creates an expected network error during that test.
- Keyboard focus avoids inactive chapters. Navigating away removes the video and its animation work.
- Production build passes. Lint completes with existing warnings in unrelated application components; no warnings in the cinematic component.

Physical low-end devices and non-Chromium browsers have not been tested.

Additional verification: decoded pixel checks differ at 0, 5, and 9.96 seconds; zero requestAnimationFrame calls were scheduled during a stationary observation. All six lazily loaded analytics destinations render successfully. Video-error fallback chapter navigation was rechecked after the scheduled update.

## Video-fit revision (25 October 2026)

Removed the extra 1.22× scale and replaced viewport-filling cropping with an explicit 16:9 film box, capped by both available width and stage height. The film is right-aligned within the full-width dark hero; a soft edge matte conceals the original video's embedded white webpage rails. No blur or video filter is applied. Editorial type is smaller, the copy column narrower, and source interface lettering is masked behind the copy.

Header height is now observed and measured rather than assumed to be 64px. The stage fills the actual remaining viewport height, and seeking/navigation use the measured stage and section bounds. Metadata initialization explicitly seeks the opening frame. The poster was extracted at time zero from the original, at native 1280×720 resolution. The existing optimized video was not transcoded again.

Mobile/tablet fallback now applies at widths ≤1000px, preserving the frame's proportions above the copy instead of magnifying the poster behind it. Short viewports, reduced motion, data saver, and low-resource fallback remain supported.

Verified actual CSS viewports: 1920×1080, 1440×900, 1280×720, 1024×768, 768×1024, and 390×844. Every film box had a 16:9 aspect ratio, fit the stage, and produced no horizontal overflow. On the laptop model chapter, content ended at y=630.55 and controls began at y=654.32, with no overlap. Forward/reverse samples mapped 0/.25/.50/.75/1 to 0/2.4995/5.0004/7.4999/9.96 seconds. A stationary frame stayed at 4.649434 seconds. The live MI/CSK prediction, XAI, and twelve-row benchmark navigation passed again. Console had no application errors; production build passed and lint retained existing warnings.

### Remaining source-footage limitation

Frame-by-frame inspection of the original at 0.05, 0.5, 1, 1.5, 2, and 2.5 seconds confirms that the glowing ball and looping neon trajectory are baked into the pixels. There is no CSS, canvas, or 3D ball in the homepage to repair. The original animation is preserved and no duplicate ball was introduced. Its trajectory, leather texture, seam, and spin have NOT been physically corrected: that requires editing/replacing the embedded effect in the source footage, which conflicts with preserving the original video. CSS fit and scroll corrections cannot supply missing source detail or repair the recorded ball motion.
