import Link from "next/link";
export default function StaffNotFound() { return <div className="empty-state"><h1>Staff profile not found</h1><p>The profile is unavailable in your current context.</p><Link href="/admin/staff">Return to staff</Link></div>; }
