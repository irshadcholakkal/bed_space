export function Icon({ name = 'grid', size = 22 }) {
  const paths = {
    grid: <><rect x="3" y="3" width="7" height="7" rx="1" /><rect x="14" y="3" width="7" height="7" rx="1" /><rect x="3" y="14" width="7" height="7" rx="1" /><rect x="14" y="14" width="7" height="7" rx="1" /></>,
    folder: <path d="M3 7V5a2 2 0 0 1 2-2h5l3 4h6a2 2 0 0 1 2 2v10a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2V7Z" />,
    receipt: <><path d="M5 3l2 2 3-2 2 2 3-2 2 2 2-2v18l-2-2-2 2-3-2-2 2-3-2-2 2V3Z" /><path d="M9 9h6M9 13h6" /></>,
    bed: <><path d="M3 18V9m18 9V9M3 14h18M5 14V6h14v8M7 10h3m4 0h3M3 18h18" /></>,
    lock: <><rect x="5" y="10" width="14" height="11" rx="2" /><path d="M8 10V7a4 4 0 0 1 8 0v3M12 14v3" /></>,
    check: <path d="m5 12 4 4L19 6" />,
    arrow: <path d="M5 12h14m-6-6 6 6-6 6" />,
    diagonal: <path d="M6 18 18 6M6 6h12v12" />,
    rocket: <><path d="M12 17 7 12C9 5 14 3 21 3c0 7-2 12-9 14ZM7 12H3l3-6h5M12 17v4l6-3v-5M5 16l-2 5 5-2" /><circle cx="16" cy="8" r="2" /></>,
    card: <><rect x="3" y="5" width="18" height="14" rx="2" /><path d="M3 10h18M7 15h3" /></>,
  };
  return <svg width={size} height={size} viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.4" strokeLinecap="round" strokeLinejoin="round" aria-hidden="true">{paths[name] || paths.grid}</svg>;
}

const demos = [
  { title: 'Your connected spaces', icon: 'grid', rows: [['Building A', '12 rooms'], ['Room 101', '4 beds'], ['Available', '2 beds']] },
  { title: 'Rent at a glance', icon: 'receipt', rows: [['Rent recorded', 'AED 4,800'], ['Invoice', 'Ready'], ['Receipt', 'PDF']] },
  { title: 'Your Google workspace', icon: 'folder', rows: [['Accommodation records', 'Google Sheets'], ['Document copies', 'Google Drive'], ['Account details', 'Bedspace']] },
];

export function ProductGraphic({ kind = 0 }) {
  const data = demos[kind];
  return <div className={`product-graphic graphic-${kind}`}><div className="product-window">
    <div className="window-bar"><span className="window-dots"><i /><i /><i /></span><span className="tag">Illustrative demo</span></div>
    <div className="window-content"><Icon name={data.icon} size={28} /><h3>{data.title}</h3>
      {data.rows.map(([label, value]) => <div className="demo-row" key={label}><Icon name={data.icon} size={15} /><span>{label}</span><small>{value}</small></div>)}
      <p className="window-note"><Icon name="lock" size={12} />Your workspace. Your Google account.</p>
    </div>
  </div></div>;
}
