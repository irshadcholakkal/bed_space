import './styles.css';

export const metadata = {
  title: 'Bedspace — Shared spaces, thoughtfully managed',
  description: 'Organize buildings, manage rent and keep your accommodation records together, connected to your own Google Sheets and Drive.',
  metadataBase: new URL('https://bedspace.thepercentagecompany.com'),
  alternates: { canonical: '/' },
};

export default function RootLayout({ children }) {
  return <html lang="en"><head>
    <meta name="theme-color" content="#080a0a" />
    <link rel="icon" href="/media/logo.png" />
    <link rel="preload" href="/media/serif.ttf" as="font" type="font/ttf" crossOrigin="anonymous" />
  </head><body>{children}</body></html>;
}
