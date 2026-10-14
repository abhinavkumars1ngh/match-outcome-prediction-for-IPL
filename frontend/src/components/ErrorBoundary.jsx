// ErrorBoundary.jsx — Catch errors gracefully without a blank screen
import React from 'react';

export default class ErrorBoundary extends React.Component {
  constructor(props) {
    super(props);
    this.state = { hasError: false, error: null, errorInfo: null };
  }

  static getDerivedStateFromError(error) {
    return { hasError: true, error };
  }

  componentDidCatch(error, errorInfo) {
    console.error('IPL Info Uncaught Component Error:', error, errorInfo);
    this.setState({ errorInfo });
  }

  handleReset = () => {
    this.setState({ hasError: false, error: null, errorInfo: null });
    window.location.reload();
  };

  render() {
    if (this.state.hasError) {
      return (
        <div style={{
          minHeight: '100vh',
          display: 'flex',
          flexDirection: 'column',
          alignItems: 'center',
          justifyContent: 'center',
          padding: '24px',
          background: '#f8fafc',
          color: '#1e293b',
          fontFamily: "'Inter', sans-serif",
          textAlign: 'center',
        }}>
          <div style={{
            background: '#ffffff',
            border: '1px solid #e2e8f0',
            borderRadius: '12px',
            padding: '32px',
            maxWidth: '560px',
            boxShadow: '0 10px 25px -5px rgba(0,0,0,0.05)',
          }}>
            <div style={{ fontSize: '3rem', marginBottom: '16px' }}>🏏</div>
            <h2 style={{ fontSize: '1.4rem', fontWeight: 700, marginBottom: '8px', color: '#0f172a' }}>
              Something went wrong loading IPL Info
            </h2>
            <p style={{ color: '#64748b', fontSize: '0.9rem', marginBottom: '20px' }}>
              An unexpected render error occurred. The application intercepted this error to prevent a black screen.
            </p>
            {this.state.error && (
              <pre style={{
                background: '#f1f5f9',
                color: '#dc2626',
                padding: '12px',
                borderRadius: '8px',
                fontSize: '0.8rem',
                textAlign: 'left',
                overflowX: 'auto',
                marginBottom: '20px',
              }}>
                {this.state.error.toString()}
              </pre>
            )}
            <button
              onClick={this.handleReset}
              style={{
                background: '#ffcb05',
                color: '#1e293b',
                border: 'none',
                fontWeight: 700,
                fontSize: '0.9rem',
                padding: '10px 24px',
                borderRadius: '8px',
                cursor: 'pointer',
              }}
            >
              Reload Application
            </button>
          </div>
        </div>
      );
    }

    return this.props.children;
  }
}
