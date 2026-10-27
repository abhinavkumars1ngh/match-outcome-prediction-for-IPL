import { useEffect, useRef, useState } from 'react';
import './CinematicHero.css';

export default function CinematicHero({ setActivePage }) {
  const videoRef = useRef(null);
  const [playing, setPlaying] = useState(false);
  const [blocked, setBlocked] = useState(false);
  const [failed, setFailed] = useState(false);

  useEffect(() => {
    const video = videoRef.current;
    let disposed = false;
    // Native playback owns the timeline. No scroll events or manual seeking.
    video.play().catch(() => {
      if (!disposed) setBlocked(true);
    });
    return () => { disposed = true; video.pause(); };
  }, []);

  const togglePlayback = async () => {
    const video = videoRef.current;
    if (!video) return;
    if (!video.paused) {
      video.pause();
      return;
    }
    try {
      await video.play();
      setBlocked(false);
    } catch {
      setBlocked(true);
    }
  };
  const predict = () => {
    setActivePage('prediction');
    window.scrollTo({ top: 0, behavior: 'instant' });
  };

  return (
    <section className="cinematic-hero" aria-labelledby="homepage-heading">
      <div className="cinematic-hero-content">
        <h1 id="homepage-heading">Predict the Game.<br /><em>Understand the Numbers.</em></h1>
        <p className="cinematic-hero-description">Machine learning meets cricket intelligence. Explore IPL match predictions, statistical patterns, and explainable AI through one unified analytics platform.</p>
        <div className="cinematic-hero-actions">
          <button type="button" onClick={predict}>Explore Predictions <span aria-hidden="true">↗</span></button>
          <button type="button" className="cinematic-hero-secondary" onClick={() => document.getElementById('benchmarks-preview')?.scrollIntoView({ behavior: 'instant' })}>Discover Model Intelligence <span aria-hidden="true">→</span></button>
        </div>
        <div className="cinematic-hero-playback">
          {!failed && <button type="button" onClick={togglePlayback} aria-controls="homepage-video">{playing ? 'Pause background video' : 'Play background video'}</button>}
          <p role="status">{failed ? 'Video unavailable. Showing the original poster frame.' : blocked ? 'Automatic playback is unavailable. Select Play background video to try again.' : ''}</p>
        </div>
      </div>
      {/* Only original media belongs in this layer. Content and controls are siblings. */}
      <div className="cinematic-hero-media" aria-hidden="true">
        {failed ? <img src="/cricket-poster.jpg" alt="" /> : (
          <video
            id="homepage-video"
            ref={videoRef}
            src="/cricket_hero.mp4"
            poster="/cricket-poster.jpg"
            autoPlay
            loop
            muted
            playsInline
            preload="auto"
            disablePictureInPicture
            onPlaying={() => { setPlaying(true); setBlocked(false); }}
            onPause={() => setPlaying(false)}
            onError={() => setFailed(true)}
          />
        )}
      </div>
    </section>
  );
}
