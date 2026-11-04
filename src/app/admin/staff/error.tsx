"use client";
export default function StaffError({ reset }: { reset: () => void }) { return <div role="alert" className="empty-state"><h2>Staff could not load</h2><p>Try the request again.</p><button type="button" onClick={reset}>Try again</button></div>; }
