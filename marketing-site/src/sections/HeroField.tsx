import { heroConfig } from '../config';

export default function HeroField() {
  const textShadow = '0 2px 24px rgba(0,0,0,0.45)';

  if (!heroConfig.wordmarkText && !heroConfig.titleLine1) {
    return null;
  }

  return (
    <section
      style={{
        position: 'relative',
        width: '100%',
        minHeight: '100vh',
        display: 'flex',
        overflow: 'hidden',
      }}
    >
      <div className="hero-grid">
        <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
          <h2
            className="font-serif-display"
            style={{
              fontSize: 'clamp(48px, 7vw, 112px)',
              fontWeight: 300,
              color: '#ffffff',
              letterSpacing: '0.15em',
              textShadow,
              margin: 0,
            }}
          >
            {heroConfig.wordmarkText}
          </h2>
        </div>

        <div className="hero-content-col">
          {heroConfig.eyebrow && (
            <p
              className="font-sans-body hero-margin"
              style={{
                fontSize: 'clamp(12px, 1.5vw, 14px)',
                letterSpacing: '0.3em',
                color: 'rgba(255,255,255,0.75)',
                textTransform: 'uppercase',
                marginBottom: '28px',
                textShadow,
              }}
            >
              {heroConfig.eyebrow}
            </p>
          )}

          <h1
            className="font-serif-display hero-margin"
            style={{
              fontSize: 'clamp(32px, 3vw, 52px)',
              fontWeight: 300,
              lineHeight: 1.3,
              color: '#ffffff',
              wordBreak: 'keep-all',
              overflowWrap: 'break-word',
              marginBottom: '24px',
              textShadow,
            }}
          >
            {heroConfig.titleLine1}
            {heroConfig.titleLine2 && (
              <>
                <br />
                {heroConfig.titleLine2}
              </>
            )}
          </h1>

          {(heroConfig.descriptionLine1 || heroConfig.descriptionLine2) && (
            <p
              className="font-sans-body hero-margin"
              style={{
                fontSize: 'clamp(14px, 1.2vw, 16px)',
                lineHeight: 1.9,
                color: 'rgba(255,255,255,0.75)',
                fontWeight: 300,
                marginBottom: '40px',
                textShadow,
              }}
            >
              {heroConfig.descriptionLine1}
              {heroConfig.descriptionLine2 && (
                <>
                  <br />
                  {heroConfig.descriptionLine2}
                </>
              )}
            </p>
          )}

          {heroConfig.ctaText && (
            <button
              className="font-sans-body hero-margin"
              onClick={() => {
                if (heroConfig.ctaTargetId) {
                  document
                    .getElementById(heroConfig.ctaTargetId)
                    ?.scrollIntoView({ behavior: 'smooth', block: 'start' });
                }
              }}
              style={{
                background: 'rgba(255,255,255,0.08)',
                border: '1px solid rgba(255,255,255,0.5)',
                borderRadius: '40px',
                padding: '14px 32px',
                color: '#ffffff',
                fontSize: 'clamp(13px, 1.1vw, 15px)',
                letterSpacing: '0.15em',
                cursor: 'pointer',
                transition: 'all 0.3s ease',
                backdropFilter: 'blur(6px)',
                WebkitBackdropFilter: 'blur(6px)',
              }}
              onMouseEnter={(e) => {
                e.currentTarget.style.background = 'rgba(255,255,255,0.18)';
                e.currentTarget.style.borderColor = 'rgba(255,255,255,0.8)';
              }}
              onMouseLeave={(e) => {
                e.currentTarget.style.background = 'rgba(255,255,255,0.08)';
                e.currentTarget.style.borderColor = 'rgba(255,255,255,0.5)';
              }}
            >
              {heroConfig.ctaText}
            </button>
          )}
        </div>
      </div>
    </section>
  );
}
