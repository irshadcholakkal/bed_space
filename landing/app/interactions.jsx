'use client';

import { useEffect, useState } from 'react';
import { Icon, ProductGraphic } from './graphics';

export function HostingTransition() {
  useEffect(() => {
    // Preserve old email/OAuth/payment return links when the root becomes Next.
    const query = new URLSearchParams(location.search);
    const fragment = new URLSearchParams(location.hash.slice(1));
    if (location.hash.startsWith('#/') && !location.hash.startsWith('#//')) {
      location.replace('/app' + location.hash.slice(1));
      return;
    }
    if (['code', 'error', 'access_token', 'refresh_token', 'token_hash', 'billing'].some(key => query.has(key) || fragment.has(key))) {
      location.replace('/app/' + location.search + location.hash);
      return;
    }
    // Existing Flutter root workers must update to the retirement worker.
    try {
      // This is only a routing hint. Flutter still restores and verifies the
      // actual Supabase session before opening any protected workspace.
      if (localStorage.getItem('flutter.bedspace_session_user')) {
        location.replace('/app/');
        return;
      }
    } catch { /* The public landing page works with storage disabled. */ }
    // Do not touch IndexedDB, auth sessions or the new /app/ worker.
    if ('serviceWorker' in navigator) {
      navigator.serviceWorker.getRegistrations().then(registrations => {
        for (const registration of registrations) {
          if (new URL(registration.scope).pathname === '/') registration.update().catch(() => {});
        }
      }).catch(() => {});
    }
    const navigation = document.querySelector('.site-nav');
    const updateNavigation = () => navigation?.classList.toggle('scrolled', window.scrollY > 45);
    updateNavigation();
    window.addEventListener('scroll', updateNavigation, { passive: true });
    return () => window.removeEventListener('scroll', updateNavigation);
  }, []);
  return null;
}

const workflows = [
  [ ['bed', 'See where there is room to grow.', 'Review buildings and vacancies before placing your next tenant.', 'At the start of the day'],
    ['card', 'Keep every payment in perspective.', 'Bring rent, recorded payments and outstanding balances into one view.', 'When rent comes around'] ],
  [ ['receipt', 'A receipt, ready when you are.', 'Prepare an invoice or receipt and save a PDF copy to your own Drive folder.', 'When it is time to share'],
    ['folder', 'Your records, still your records.', 'Open your accommodation spreadsheet in the Google account you connected.', 'At the end of the month'] ],
];
export function Workflows() {
  const [slide, setSlide] = useState(0);
  return <><div className="workflow-grid" aria-live="polite">{workflows[slide].map(([icon, title, body, tag], index) =>
    <article className={`workflow-card ${index === 0 ? 'scenic-card' : ''}`} key={title}><Icon name={icon} size={30} /><h3>{title}</h3><p>{body}</p><span className="tag">Example workflow / {tag}</span></article>
  )}</div><div className="carousel-controls"><button className="icon-button previous" aria-label="Previous workflow" onClick={() => setSlide(1 - slide)}><Icon name="arrow" size={17} /></button>
    {[0, 1].map(index => <button key={index} className={`carousel-dot ${index === slide ? 'selected' : ''}`} onClick={() => setSlide(index)} aria-label={`Show workflow ${index + 1}`} aria-pressed={index === slide} />)}
    <button className="icon-button" aria-label="Next workflow" onClick={() => setSlide(1 - slide)}><Icon name="arrow" size={17} /></button></div></>;
}

const plans = [
  ['Settle in', 'AED 0', 'for your first month', 'Get to know your new workspace.', ['One calendar month free', 'Buildings, rooms, beds and tenants', 'Rent and expense tracking', 'Connect your Google account', 'Invoice and receipt PDFs'], 'Start free trial', 'monthly'],
  ['Monthly', 'AED 50', '/month + other charges', 'A little flexibility for your business.', ['Full workspace after your trial', 'Customer-owned Google Sheets', 'Private Google Drive folder', 'Invoices and receipts', 'Renew with a confirmed payment'], 'Choose monthly', 'monthly'],
  ['Annual', 'AED 540', '/year + other charges', 'AED 45/month equivalent. Save AED 60/year.', ['Everything in monthly', '10% off the annual base price', 'One calendar year of paid access', 'Your existing Google storage', 'The same complete workspace'], 'Choose annual', 'annual'],
];
export function Pricing() {
  const [annual, setAnnual] = useState(false);
  return <><div className="billing-switch" role="group" aria-label="Preferred billing cycle"><button aria-pressed={!annual} onClick={() => setAnnual(false)}>Monthly</button><button aria-pressed={annual} onClick={() => setAnnual(true)}>Annual · save 10%</button></div>
    <div className="plan-grid">{plans.map(([title, price, period, description, features, button, billing], index) =>
      <article key={title} className={`plan ${index === (annual ? 2 : 1) ? 'highlighted' : ''}`}>
        <h3>{title}</h3><div className="price">{price}</div><p className="period">{period}</p><p className="plan-description">{description}</p>
        <div className="plan-features"><span className="tag">Included in your workspace</span><ul>{features.map(feature => <li key={feature}><Icon name="check" size={15} />{feature}</li>)}</ul></div>
        <a className="button primary" href={`/app/signup?billing=${index === 0 ? (annual ? 'annual' : 'monthly') : billing}`}>{button}</a>
      </article>)}</div></>;
}

export function Roles() {
  const [role, setRole] = useState(0);
  const labels = ['Owners', 'Managers', 'Rent collection', 'Documents'];
  const descriptions = ['A clear overview of the buildings, rooms and beds in your business.', 'Keep tenant details and available spaces together while you manage the day.', 'See recorded rent, payments and balances in the same workspace.', 'Create invoices and receipts, with copies saved in your Google Drive.'];
  return <div className="role-section"><div className="role-tabs" role="tablist" aria-label="Explore your workflow">{labels.map((label, index) => <button role="tab" id={`role-${index}`} aria-controls="role-panel" aria-selected={role === index} key={label} onClick={() => setRole(index)} onKeyDown={event => {
    if (event.key === 'ArrowRight' || event.key === 'ArrowLeft') {
      event.preventDefault();
      const next = (index + (event.key === 'ArrowRight' ? 1 : 3)) % 4;
      setRole(next); document.getElementById(`role-${next}`)?.focus();
    }
  }}>{label}</button>)}</div><div role="tabpanel" id="role-panel" aria-labelledby={`role-${role}`}><ProductGraphic kind={[0, 0, 1, 2][role]} /><p className="role-description">{descriptions[role]}</p></div></div>;
}
