import { useEffect, useRef } from 'react';
import gsap from 'gsap';
import { ScrollTrigger } from 'gsap/ScrollTrigger';
import { visionConfig } from '../config';

gsap.registerPlugin(ScrollTrigger);

export default function VisionSection() {
  const sectionRef = useRef<HTMLDivElement>(null);
  const contentRef = useRef<HTMLDivElement>(null);
  const lineRef = useRef<HTMLDivElement>(null);

  useEffect(() => {
    const section = sectionRef.current;
    const content = contentRef.current;
    const line = lineRef.current;
    if (!section || !content || !line) return;

    const ctx = gsap.context(() => {
      // Accent line grows on scroll
      gsap.fromTo(
        line,
        { scaleX: 0 },
        {
          scaleX: 1,
          duration: 1.2,
          ease: 'power3.out',
          scrollTrigger: {
            trigger: section,
            start: 'top 75%',
            toggleActions: 'play none none none',
          },
        }
      );

      // Content fades up
      gsap.fromTo(
        content.children,
        { opacity: 0, y: 40 },
        {
          opacity: 1,
          y: 0,
          duration: 0.9,
          stagger: 0.15,
          ease: 'power2.out',
          scrollTrigger: {
            trigger: section,
            start: 'top 70%',
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
      id="vision"
      style={{
        position: 'relative',
        width: '100%',
        minHeight: '100vh',
        background: '#0B0C15',
        zIndex: 4,
        display: 'flex',
        alignItems: 'center',
        justifyContent: 'center',
        padding: '20vh 8vw',
      }}
    >
      <div
        ref={contentRef}
        style={{
          maxWidth: '720px',
          textAlign: 'center',
        }}
      >
        {visionConfig.eyebrow && (
          <p
            className="font-sans-body"
            style={{
              fontSize: '12px',
              letterSpacing: '0.3em',
              color: 'rgba(236,237,244,0.4)',
              textTransform: 'uppercase',
              marginBottom: '40px',
            }}
          >
            {visionConfig.eyebrow}
          </p>
        )}

        <div
          ref={lineRef}
          style={{
            width: '64px',
            height: '1px',
            background: '#DB7E93',
            margin: '0 auto 48px',
            transformOrigin: 'left center',
          }}
        />

        {visionConfig.headline && (
          <h2
            className="font-serif-display"
            style={{
              fontSize: 'clamp(32px, 4.5vw, 56px)',
              fontWeight: 300,
              lineHeight: 1.2,
              color: '#ECEDF4',
              marginBottom: '48px',
            }}
          >
            {visionConfig.headline}
          </h2>
        )}

        {visionConfig.paragraphs.map((para, i) => (
          <p
            key={i}
            className="font-sans-body"
            style={{
              fontSize: '17px',
              lineHeight: 2,
              color: 'rgba(236,237,244,0.65)',
              fontWeight: 400,
              marginBottom: i < visionConfig.paragraphs.length - 1 ? '28px' : '0',
            }}
          >
            {para}
          </p>
        ))}
      </div>
    </section>
  );
}
