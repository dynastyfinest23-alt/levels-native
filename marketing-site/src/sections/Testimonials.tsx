import { useEffect, useRef } from 'react';
import gsap from 'gsap';
import { ScrollTrigger } from 'gsap/ScrollTrigger';
import { testimonialsConfig } from '../config';

gsap.registerPlugin(ScrollTrigger);

export default function Testimonials() {
  const sectionRef = useRef<HTMLDivElement>(null);
  const cardsRef = useRef<HTMLDivElement>(null);

  useEffect(() => {
    const section = sectionRef.current;
    const cards = cardsRef.current;
    if (!section || !cards) return;

    const ctx = gsap.context(() => {
      gsap.fromTo(
        cards.children,
        { opacity: 0, y: 50 },
        {
          opacity: 1,
          y: 0,
          duration: 0.8,
          stagger: 0.2,
          ease: 'power2.out',
          scrollTrigger: {
            trigger: section,
            start: 'top 75%',
            toggleActions: 'play none none none',
          },
        }
      );
    });

    return () => ctx.revert();
  }, []);

  return (
    <section
      ref={sectionRef}
      id="testimonials"
      className="testimonials-section"
      style={{
        position: 'relative',
        width: '100%',
        background: '#0B0C15',
        zIndex: 5,
        padding: '16vh 8vw',
      }}
    >
      <div style={{ maxWidth: '1200px', margin: '0 auto' }}>
        {testimonialsConfig.eyebrow && (
          <p
            className="font-sans-body"
            style={{
              fontSize: 'clamp(11px, 1vw, 13px)',
              letterSpacing: '0.3em',
              color: 'rgba(236,237,244,0.4)',
              textTransform: 'uppercase',
              marginBottom: '16px',
              textAlign: 'center',
            }}
          >
            {testimonialsConfig.eyebrow}
          </p>
        )}

        {testimonialsConfig.title && (
          <h2
            className="font-serif-display"
            style={{
              fontSize: 'clamp(28px, 3.5vw, 44px)',
              fontWeight: 300,
              lineHeight: 1.2,
              color: '#ECEDF4',
              marginBottom: '72px',
              textAlign: 'center',
            }}
          >
            {testimonialsConfig.title}
          </h2>
        )}

        <div
          ref={cardsRef}
          className="testimonials-grid"
          style={{
            display: 'grid',
            gridTemplateColumns: 'repeat(auto-fit, minmax(300px, 1fr))',
            gap: '32px',
          }}
        >
          {testimonialsConfig.quotes.map((quote, i) => (
            <div
              key={i}
              className="testimonial-card"
              style={{
                background: 'rgba(26, 29, 51, 0.6)',
                border: '1px solid rgba(255,255,255,0.06)',
                borderRadius: '16px',
                padding: 'clamp(24px, 3vw, 40px) clamp(20px, 2.5vw, 36px)',
                position: 'relative',
                backdropFilter: 'blur(8px)',
                WebkitBackdropFilter: 'blur(8px)',
              }}
            >
              {/* Quote mark */}
              <div
                style={{
                  position: 'absolute',
                  top: '24px',
                  left: '28px',
                  fontFamily: "'Fraunces', Georgia, serif",
                  fontSize: '64px',
                  fontWeight: 300,
                  color: 'rgba(219, 126, 147, 0.25)',
                  lineHeight: 1,
                  pointerEvents: 'none',
                }}
              >
                "
              </div>

              <p
                className="font-sans-body"
                style={{
                  fontSize: 'clamp(14px, 1.1vw, 16px)',
                  lineHeight: 1.8,
                  color: 'rgba(236,237,244,0.75)',
                  marginBottom: '32px',
                  paddingTop: '16px',
                }}
              >
                {quote.text}
              </p>

              <div style={{ display: 'flex', alignItems: 'center', gap: '16px' }}>
                <div
                  style={{
                    width: '40px',
                    height: '40px',
                    borderRadius: '50%',
                    background: 'rgba(219, 126, 147, 0.15)',
                    display: 'flex',
                    alignItems: 'center',
                    justifyContent: 'center',
                    fontFamily: "'Inter', sans-serif",
                    fontSize: 'clamp(12px, 1vw, 14px)',
                    fontWeight: 600,
                    color: '#DB7E93',
                  }}
                >
                  {quote.initials}
                </div>
                <div>
                  <p
                    className="font-sans-body"
                    style={{
                      fontSize: 'clamp(13px, 1vw, 15px)',
                      fontWeight: 500,
                      color: '#ECEDF4',
                      lineHeight: 1.4,
                    }}
                  >
                    {quote.name}
                  </p>
                  <p
                    className="font-sans-body"
                    style={{
                      fontSize: 'clamp(11px, 0.9vw, 13px)',
                      color: 'rgba(236,237,244,0.4)',
                      lineHeight: 1.4,
                    }}
                  >
                    {quote.role}
                  </p>
                </div>
              </div>
            </div>
          ))}
        </div>
      </div>
    </section>
  );
}
