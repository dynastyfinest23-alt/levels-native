import { useState } from 'react';
import { waitlistConfig } from '../config';
import { supabase } from '../lib/supabase';

export default function Waitlist() {
  const [email, setEmail] = useState('');
  const [submitted, setSubmitted] = useState(false);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState('');

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!email.trim()) return;

    setLoading(true);
    setError('');

    try {
      const { data, error: rpcError } = await supabase.rpc('join_waitlist', {
        p_email: email.trim(),
      });

      if (rpcError) throw rpcError;

      // data is a JSON object from our function
      const result = data as { success: boolean; message?: string } | null;

      if (result?.success) {
        setSubmitted(true);
      } else {
        setError(result?.message || 'Something went wrong. Please try again.');
      }
    } catch (err) {
      console.error('Waitlist error:', err);
      setError('Could not connect. Please try again.');
    } finally {
      setLoading(false);
    }
  };

  return (
    <section
      id="waitlist"
      className="waitlist-section"
      style={{
        position: 'relative',
        width: '100%',
        background: '#0B0C15',
        zIndex: 7,
        padding: '16vh 8vw',
        display: 'flex',
        alignItems: 'center',
        justifyContent: 'center',
      }}
    >
      <div style={{ maxWidth: '560px', width: '100%', textAlign: 'center' }}>
        {waitlistConfig.eyebrow && (
          <p
            className="font-sans-body"
            style={{
              fontSize: 'clamp(10px, 0.9vw, 12px)',
              letterSpacing: '0.3em',
              color: 'rgba(236,237,244,0.4)',
              textTransform: 'uppercase',
              marginBottom: '24px',
            }}
          >
            {waitlistConfig.eyebrow}
          </p>
        )}

        {waitlistConfig.headline && (
          <h2
            className="font-serif-display"
            style={{
              fontSize: 'clamp(28px, 3.5vw, 44px)',
              fontWeight: 300,
              lineHeight: 1.2,
              color: '#ECEDF4',
              marginBottom: '20px',
            }}
          >
            {waitlistConfig.headline}
          </h2>
        )}

        {waitlistConfig.body && (
          <p
            className="font-sans-body"
            style={{
              fontSize: '16px',
              lineHeight: 1.7,
              color: 'rgba(236,237,244,0.55)',
              marginBottom: '48px',
            }}
          >
            {waitlistConfig.body}
          </p>
        )}

        {!submitted ? (
          <form
            onSubmit={handleSubmit}
            style={{
              display: 'flex',
              flexDirection: 'column',
              gap: '16px',
              alignItems: 'center',
            }}
          >
            <div
              className="waitlist-form-row"
              style={{
                display: 'flex',
                width: '100%',
                maxWidth: '440px',
                gap: '12px',
                flexWrap: 'wrap',
                justifyContent: 'center',
              }}
            >
              <input
                type="email"
                value={email}
                onChange={(e) => {
                  setEmail(e.target.value);
                  setError('');
                }}
                placeholder={waitlistConfig.placeholder || 'your@email.com'}
                required
                disabled={loading}
                className="font-sans-body"
                style={{
                  flex: '1 1 260px',
                  background: 'rgba(26, 29, 51, 0.6)',
                  border: '1px solid rgba(255,255,255,0.08)',
                  borderRadius: '999px',
                  padding: '14px 24px',
                  color: '#ECEDF4',
                  fontSize: '15px',
                  outline: 'none',
                  transition: 'border-color 0.3s',
                  opacity: loading ? 0.6 : 1,
                }}
                onFocus={(e) => {
                  e.currentTarget.style.borderColor = 'rgba(219, 126, 147, 0.5)';
                }}
                onBlur={(e) => {
                  e.currentTarget.style.borderColor = 'rgba(255,255,255,0.08)';
                }}
              />
              <button
                type="submit"
                disabled={loading}
                className="font-sans-body waitlist-submit-btn"
                style={{
                  background: '#DB7E93',
                  border: 'none',
                  borderRadius: '999px',
                  padding: '14px 32px',
                  color: '#0B0C15',
                  fontSize: '15px',
                  fontWeight: 500,
                  letterSpacing: '0.04em',
                  cursor: loading ? 'wait' : 'pointer',
                  transition: 'all 0.3s ease',
                  whiteSpace: 'nowrap',
                  opacity: loading ? 0.7 : 1,
                }}
                onMouseEnter={(e) => {
                  if (!loading) {
                    e.currentTarget.style.background = '#E08FA3';
                    e.currentTarget.style.boxShadow = '0 0 32px rgba(219, 126, 147, 0.3)';
                  }
                }}
                onMouseLeave={(e) => {
                  e.currentTarget.style.background = '#DB7E93';
                  e.currentTarget.style.boxShadow = 'none';
                }}
              >
                {loading ? 'Joining...' : waitlistConfig.ctaText}
              </button>
            </div>

            {error && (
              <p
                className="font-sans-body"
                style={{
                  fontSize: '13px',
                  color: '#DB7E93',
                  marginTop: '4px',
                }}
              >
                {error}
              </p>
            )}

            {waitlistConfig.disclaimer && !error && (
              <p
                className="font-sans-body"
                style={{
                  fontSize: '12px',
                  color: 'rgba(236,237,244,0.3)',
                  marginTop: '8px',
                }}
              >
                {waitlistConfig.disclaimer}
              </p>
            )}
          </form>
        ) : (
          <div
            style={{
              padding: '48px 32px',
              background: 'rgba(26, 29, 51, 0.4)',
              border: '1px solid rgba(219, 126, 147, 0.2)',
              borderRadius: '16px',
            }}
          >
            <p
              className="font-serif-display"
              style={{
                fontSize: 'clamp(20px, 2vw, 24px)',
                fontWeight: 300,
                color: '#ECEDF4',
                marginBottom: '12px',
              }}
            >
              {waitlistConfig.successTitle}
            </p>
            <p
              className="font-sans-body"
              style={{
                fontSize: '15px',
                color: 'rgba(236,237,244,0.6)',
              }}
            >
              {waitlistConfig.successBody}
            </p>
          </div>
        )}
      </div>
    </section>
  );
}
