import React from 'react';

interface OpenChamberLogoProps {
  className?: string;
  width?: number;
  height?: number;
  isAnimated?: boolean;
}

// Load logo from the public directory at runtime — the install script places
// the user's custom logo at /cowork-logo.png. No hardcoded base64.
export const OpenChamberLogo: React.FC<OpenChamberLogoProps> = ({
  className = '',
  width = 200,
  height = 140,
  isAnimated = false,
}) => {
  return (
    <>
      <style>{`
        @keyframes cowork-logo-pulse {
          0%, 100% { opacity: 1; }
          50% { opacity: 0.4; }
        }
      `}</style>
      <img
        src="/cowork-logo.png"
        alt=""
        width={width}
        height={height}
        className={className}
        style={{
          objectFit: 'contain',
          animation: isAnimated ? 'cowork-logo-pulse 3s ease-in-out infinite' : undefined,
        }}
        onError={(e) => { (e.target as HTMLImageElement).style.display = 'none'; }}
      />
    </>
  );
};
